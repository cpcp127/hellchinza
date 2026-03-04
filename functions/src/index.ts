import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const bucket = admin.storage().bucket();

/** 월요일 시작(00:00) 기준으로 주 시작일 구하기 */
function startOfWeekMonday(date: Date): Date {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = d.getDay(); // 0=Sun..6=Sat
  const diff = (weekday + 6) % 7; // Monday 기준 offset (Mon=0)
  d.setDate(d.getDate() - diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

/** weekKey: YYYY-MM-DD (월요일 날짜) */
function weekKeyFromDate(weekStart: Date): string {
  const y = weekStart.getFullYear();
  const m = String(weekStart.getMonth() + 1).padStart(2, "0");
  const dd = String(weekStart.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

function getCreatedAt(data: any): Date | null {
  const ts = data?.createdAt;
  if (!ts) return null;

  // Firestore Timestamp
  if (typeof ts.toDate === "function") return ts.toDate();

  // millis number
  if (typeof ts === "number") return new Date(ts);

  // ISO string
  if (typeof ts === "string") {
    const d = new Date(ts);
    if (!isNaN(d.getTime())) return d;
  }

  return null;
}

/** 오운완 피드 판별 */
function isOowFeed(data: any): boolean {
  if (!data) return false;
  return data.mainType === "오운완";
  // ✅ "개인 오운완만" 카운트하고 싶으면 아래 주석 해제
  // return data.mainType === "오운완" && (data.meetId == null);
}

/** 주간 count 증감 적용 */
async function applyWeeklyDelta(uid: string, weekStart: Date, delta: number) {
  const key = weekKeyFromDate(weekStart);
  const ref = db
    .collection("stats_users")
    .doc(uid)
    .collection("oowWeekly")
    .doc(key);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const prev = snap.exists ? (snap.data()?.count ?? 0) : 0;
    const next = Math.max(0, prev + delta);

    // 문서가 없고 next=0이면 굳이 만들지 않음
    if (!snap.exists && next === 0) return;

    tx.set(
      ref,
      {
        weekStart: admin.firestore.Timestamp.fromDate(weekStart),
        count: next,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

/**
 * feeds/{feedId} 문서가 create/update/delete 될 때
 * 오운완이면 stats_users/{uid}/oowWeekly/{weekKey} 를 유지
 */
export const onFeedWriteUpdateWeeklyOow = functions.firestore
  .document("feeds/{feedId}")
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    const uid = (after?.authorUid ?? before?.authorUid);
    if (!uid) return;

    function isOow(data: any) {
      if (!data) return false;
      if (data.mainType !== "오운완") return false;
      if (data.meetId !== null && data.meetId !== undefined) return false; // 개인만
      return true;
    }

    function getDate(d: any): Date | null {
      if (!d) return null;
      if (d.toDate) return d.toDate();
      if (d instanceof Date) return d;
      return null;
    }

    function startOfDay(d: Date) {
      return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }

    function pad2(n: number) {
      return n.toString().padStart(2, "0");
    }

    function dateKey(d: Date) {
      return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}`;
    }

    function startOfWeekMonday(d: Date) {
      const day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
      const weekday = day.getDay();
      const diff = (weekday + 6) % 7;
      day.setDate(day.getDate() - diff);
      day.setHours(0, 0, 0, 0);
      return day;
    }

    async function hasAnyOowOnDay(uid: string, day: Date) {
      const start = admin.firestore.Timestamp.fromDate(startOfDay(day));
      const end = admin.firestore.Timestamp.fromDate(
        new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
      );

      const snap = await db
        .collection("feeds")
        .where("authorUid", "==", uid)
        .where("mainType", "==", "오운완")
        .where("meetId", "==", null)
        .where("createdAt", ">=", start)
        .where("createdAt", "<", end)
        .limit(1)
        .get();

      return !snap.empty;
    }

    const affectedDays: Date[] = [];

    if (before && isOow(before)) {
      const d = getDate(before.createdAt);
      if (d) affectedDays.push(startOfDay(d));
    }

    if (after && isOow(after)) {
      const d = getDate(after.createdAt);
      if (d) affectedDays.push(startOfDay(d));
    }

    const uniqueDays = new Map<string, Date>();
    for (const d of affectedDays) {
      uniqueDays.set(dateKey(d), d);
    }

    for (const day of uniqueDays.values()) {
      const dayKey = dateKey(day);
      const weekStart = startOfWeekMonday(day);
      const weekKey = dateKey(weekStart);

      const dailyRef = db
        .collection("stats_users")
        .doc(uid)
        .collection("oowDaily")
        .doc(dayKey);

      const weeklyRef = db
        .collection("stats_users")
        .doc(uid)
        .collection("oowWeekly")
        .doc(weekKey);

      const existsNow = await hasAnyOowOnDay(uid, day);

      await db.runTransaction(async (tx) => {
        const dailySnap = await tx.get(dailyRef);
        const prev = dailySnap.exists ? dailySnap.data()?.hasOow === true : false;

        if (prev === existsNow) return;

        tx.set(dailyRef, {
          dateKey: dayKey,
          weekKey,
          weekStart: admin.firestore.Timestamp.fromDate(weekStart),
          hasOow: existsNow,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        const weeklySnap = await tx.get(weeklyRef);
        const prevCount = weeklySnap.exists ? weeklySnap.data()?.count ?? 0 : 0;

        const delta = existsNow ? 1 : -1;
        const nextCount = Math.max(0, prevCount + delta);

        tx.set(weeklyRef, {
          weekKey,
          weekStart: admin.firestore.Timestamp.fromDate(weekStart),
          count: nextCount, // 🔥 이제 '운동한 날 수'
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      });
    }
  });


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


