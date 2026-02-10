import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const bucket = admin.storage().bucket();

/**
 * ✅ 너가 말한 구조 기준:
 * - users/{uid}
 * - feeds/{feedId} (필드: authorUid, likeUids: string[], poll.options[].voterUids: string[])
 * - feeds/{feedId}/comments/{commentId}
 * - Storage:
 *   - feeds/{feedId}/... (피드 이미지 폴더)
 *   - users/{uid}/... (프로필 이미지 폴더)
 */

const BATCH_LIMIT = 450; // 500 바로 아래로 안전하게
const PAGE_LIMIT = 300;  // Firestore 페이지네이션용(원하면 조절)

export const deleteUserData = functions.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const uid = context.auth.uid;

  try {
    // 0) (선택) 소프트락/표시: 탈퇴 진행중 플래그를 걸고 싶으면 여기서 users/{uid} 업데이트 후 진행
    // await db.collection("users").doc(uid).set({ deleting: true }, { merge: true });

    // 1) 내가 작성한 피드 목록(페이지네이션)
    const myFeedIds: string[] = [];
    let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;

    while (true) {
      let q = db
        .collection("feeds")
        .where("authorUid", "==", uid)
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(PAGE_LIMIT);

      if (last) q = q.startAfter(last);

      const snap = await q.get();
      if (snap.empty) break;

      for (const doc of snap.docs) myFeedIds.push(doc.id);
      last = snap.docs[snap.docs.length - 1];

      if (snap.size < PAGE_LIMIT) break;
    }

    // 2) 내가 쓴 피드들: (a) comments 서브컬렉션 삭제 (b) feed 문서 삭제 (c) storage 폴더 삭제
    //    - 댓글 삭제는 batch 500 제한 때문에 feed마다 반복/페이지로 지움
    for (const feedId of myFeedIds) {
      await deleteSubcollectionAll(`feeds/${feedId}/comments`);
      await db.collection("feeds").doc(feedId).delete().catch(() => null);
      await deleteStorageFolder(`feeds/${feedId}/`);
    }

    // 3) 다른 사람 피드들에서 "내 uid 흔적" 제거
    // 3-1) likeUids는 array-contains로 걸러서 업데이트 (전체 스캔 X)
    await removeUidFromLikeUids(uid);

    // 3-2) poll.options[].voterUids는 구조상 쿼리로 특정하기 어려움
    //      규모가 작으면 전체 스캔 가능하지만, 커지면 "역인덱스"를 따로 두는 걸 추천
    //      일단은 안전하게 전체 스캔 방식도 제공(아래 함수)
    await removeUidFromPollVoters(uid);

    // 4) 사용자 문서 삭제
    await db.collection("users").doc(uid).delete().catch(() => null);

    // 5) 프로필/유저 스토리지 폴더 삭제
    await deleteStorageFolder(`users/${uid}/`);

    // 6) Auth 계정 삭제 (Callable은 admin 권한으로 가능)
    await admin.auth().deleteUser(uid);

    return { success: true, deletedFeeds: myFeedIds.length };
  } catch (e: any) {
    console.error("deleteUserData error", e);
    throw new functions.https.HttpsError("internal", e?.message ?? "회원 데이터 삭제 실패");
  }
});

/**
 * ✅ 특정 서브컬렉션을 전부 삭제 (페이지네이션 + batch 제한 처리)
 * path 예: "feeds/{feedId}/comments"
 */
async function deleteSubcollectionAll(collectionPath: string) {
  const colRef = db.collection(collectionPath);

  while (true) {
    const snap = await colRef.limit(PAGE_LIMIT).get();
    if (snap.empty) break;

    // batch 여러 번 나눠 커밋
    let batch = db.batch();
    let opCount = 0;

    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      opCount++;

      if (opCount >= BATCH_LIMIT) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) await batch.commit();

    if (snap.size < PAGE_LIMIT) break;
  }
}

/**
 * ✅ likeUids에서 uid 제거
 * - feeds where likeUids array-contains uid 로 필요한 문서만 가져옴
 */
async function removeUidFromLikeUids(uid: string) {
  let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let q = db
      .collection("feeds")
      .where("likeUids", "array-contains", uid)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PAGE_LIMIT);

    if (last) q = q.startAfter(last);

    const snap = await q.get();
    if (snap.empty) break;

    let batch = db.batch();
    let opCount = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      if (Array.isArray(data.likeUids) && data.likeUids.includes(uid)) {
        const next = data.likeUids.filter((u: string) => u !== uid);
        batch.update(doc.ref, { likeUids: next });
        opCount++;

        if (opCount >= BATCH_LIMIT) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
    }

    if (opCount > 0) await batch.commit();

    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE_LIMIT) break;
  }
}

/**
 * ✅ poll.options[].voterUids 에서 uid 제거
 * - 이 구조는 Firestore 쿼리로 "uid가 포함된 문서만" 찾기 어렵다.
 * - 규모가 커지면 역인덱스(예: userVotes/{uid}/feeds/{feedId})를 만들어서 처리하는 게 정답.
 * - 지금은 "전체 feeds 스캔" 방식(너가 준 코드와 동일 방향) + batch 제한/페이지네이션만 안전하게.
 */
async function removeUidFromPollVoters(uid: string) {
  let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let q = db
      .collection("feeds")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PAGE_LIMIT);

    if (last) q = q.startAfter(last);

    const snap = await q.get();
    if (snap.empty) break;

    let batch = db.batch();
    let opCount = 0;

    for (const doc of snap.docs) {
      const data: any = doc.data();
      const poll = data.poll;

      if (!poll?.options || !Array.isArray(poll.options)) continue;

      let changed = false;
      const nextOptions = poll.options.map((o: any) => {
        const voters: string[] = Array.isArray(o.voterUids) ? o.voterUids : [];
        if (!voters.includes(uid)) return o;

        changed = true;
        return { ...o, voterUids: voters.filter((u) => u !== uid) };
      });

      if (changed) {
        batch.update(doc.ref, { poll: { ...poll, options: nextOptions } });
        opCount++;

        if (opCount >= BATCH_LIMIT) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
    }

    if (opCount > 0) await batch.commit();

    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE_LIMIT) break;
  }
}

/**
 * ✅ Storage 폴더(prefix) 통째로 삭제 (페이지네이션 대응)
 * path 예: "feeds/{feedId}/" 또는 "users/{uid}/"
 */
async function deleteStorageFolder(prefix: string) {
  let pageToken: string | undefined = undefined;

  while (true) {
    const res = await bucket.getFiles({
      prefix,
      autoPaginate: false,
      maxResults: 1000,
      pageToken,
    });

    const files = res[0];
    const apiResponse = res[2] as any;

    if (!files.length) break;

    await Promise.allSettled(files.map((f) => f.delete()));

    pageToken = apiResponse?.nextPageToken;
    if (!pageToken) break;
  }
}

