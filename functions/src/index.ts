import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();
const bucket = admin.storage().bucket();

type DocRef = FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
type QueryDoc = FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>;

async function deleteDocsInChunks(
  docs: QueryDoc[],
  chunkSize = 400,
): Promise<void> {
  for (let i = 0; i < docs.length; i += chunkSize) {
    const chunk = docs.slice(i, i + chunkSize);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

async function deleteSubcollectionByPath(
  collectionPath: string,
  pageSize = 200,
): Promise<void> {
  while (true) {
    const snap = await db.collection(collectionPath).limit(pageSize).get();
    if (snap.empty) break;
    await deleteDocsInChunks(snap.docs, pageSize);
  }
}

async function safeDeleteDoc(ref: DocRef): Promise<void> {
  const snap = await ref.get();
  if (snap.exists) {
    await ref.delete();
  }
}

async function safeDeleteStorageFiles(paths: (string | null | undefined)[]) {
  for (const path of paths) {
    if (!path) continue;
    try {
      await bucket.file(path).delete({ignoreNotFound: true});
    } catch (e) {
      functions.logger.warn("storage delete failed", {path, error: String(e)});
    }
  }
}

function extractStoragePathFromUrl(url?: string | null): string | null {
  if (!url) return null;

  // gs://bucket/path/to/file
  if (url.startsWith("gs://")) {
    const idx = url.indexOf("/", 5);
    return idx >= 0 ? url.substring(idx + 1) : null;
  }

  // https://firebasestorage.googleapis.com/.../o/<encodedPath>?...
  try {
    const u = new URL(url);
    const marker = "/o/";
    const idx = u.pathname.indexOf(marker);
    if (idx >= 0) {
      const encoded = u.pathname.substring(idx + marker.length);
      return decodeURIComponent(encoded);
    }
  } catch (_) {}

  return null;
}

async function removeUidFromArrayFieldAcrossQuery(
  query: FirebaseFirestore.Query,
  fieldName: string,
  uid: string,
  pageSize = 200,
) {
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let q = query.limit(pageSize);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.update(doc.ref, {
        [fieldName]: admin.firestore.FieldValue.arrayRemove(uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < pageSize) break;
  }
}

async function removeUidFromMapAndArrayInChatRooms(uid: string) {
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  while (true) {
    let q = db.collection("chatRooms").orderBy(admin.firestore.FieldPath.documentId()).limit(200);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const updates: Record<string, unknown> = {};
      let changed = false;

      const userUids = Array.isArray(data.userUids) ? data.userUids as string[] : [];
      const visibleUids = Array.isArray(data.visibleUids) ? data.visibleUids as string[] : [];

      if (userUids.includes(uid)) {
        updates.userUids = admin.firestore.FieldValue.arrayRemove(uid);
        changed = true;
      }

      if (visibleUids.includes(uid)) {
        updates.visibleUids = admin.firestore.FieldValue.arrayRemove(uid);
        changed = true;
      }

      if (data.unreadCountMap && typeof data.unreadCountMap === "object" && uid in data.unreadCountMap) {
        updates[`unreadCountMap.${uid}`] = admin.firestore.FieldValue.delete();
        changed = true;
      }

      if (data.activeAtMap && typeof data.activeAtMap === "object" && uid in data.activeAtMap) {
        updates[`activeAtMap.${uid}`] = admin.firestore.FieldValue.delete();
        changed = true;
      }

      if (changed) {
        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        batch.update(doc.ref, updates);
      }
    }

    await batch.commit();
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 200) break;
  }
}

async function deleteUserCommentsEverywhere(uid: string) {
  // top-level feed comments group
  const commentSnap = await db.collectionGroup("comments")
    .where("authorUid", "==", uid)
    .get();

  await deleteDocsInChunks(commentSnap.docs);
}

async function cleanupLikesAndMembership(uid: string) {
  // feeds.likeUids
  await removeUidFromArrayFieldAcrossQuery(
    db.collection("feeds").where("likeUids", "array-contains", uid).orderBy(admin.firestore.FieldPath.documentId()),
    "likeUids",
    uid,
  );

  // meets.memberUids
  await removeUidFromArrayFieldAcrossQuery(
    db.collection("meets").where("memberUids", "array-contains", uid).orderBy(admin.firestore.FieldPath.documentId()),
    "memberUids",
    uid,
  );

  // lightnings.memberUids (collectionGroup)
  await removeUidFromArrayFieldAcrossQuery(
    db.collectionGroup("lightnings").where("memberUids", "array-contains", uid).orderBy(admin.firestore.FieldPath.documentId()),
    "memberUids",
    uid,
  );
}

async function rejectOrDeleteMeetRequestsByUid(uid: string) {
  const reqSnap = await db.collectionGroup("requests")
    .where("uid", "==", uid)
    .get();

  await deleteDocsInChunks(reqSnap.docs);
}

async function deleteAuthoredLightnings(uid: string) {
  const lightningSnap = await db.collectionGroup("lightnings")
    .where("authorUid", "==", uid)
    .get();

  for (const doc of lightningSnap.docs) {
    const data = doc.data() || {};
    const imageUrls = Array.isArray(data.imageUrls) ? data.imageUrls as string[] : [];
    const storagePaths = imageUrls.map((u) => extractStoragePathFromUrl(u));

    await safeDeleteStorageFiles(storagePaths);
    await doc.ref.delete();
  }
}

async function deleteAuthoredFeeds(uid: string) {
  const feedSnap = await db.collection("feeds")
    .where("authorUid", "==", uid)
    .get();

  for (const doc of feedSnap.docs) {
    const data = doc.data() || {};

    // feed 하위 comments 먼저 삭제
    await deleteSubcollectionByPath(`feeds/${doc.id}/comments`);

    const imageUrls = Array.isArray(data.imageUrls) ? data.imageUrls as string[] : [];
    const storagePaths = imageUrls.map((u) => extractStoragePathFromUrl(u));

    await safeDeleteStorageFiles(storagePaths);
    await doc.ref.delete();
  }
}

async function deleteAuthoredMeets(uid: string) {
  const meetSnap = await db.collection("meets")
    .where("authorUid", "==", uid)
    .get();

  for (const meetDoc of meetSnap.docs) {
    // requests 삭제
    await deleteSubcollectionByPath(`meets/${meetDoc.id}/requests`);

    // lightnings 삭제
    const lightningSnap = await meetDoc.ref.collection("lightnings").get();
    for (const lightningDoc of lightningSnap.docs) {
      const data = lightningDoc.data() || {};
      const imageUrls = Array.isArray(data.imageUrls) ? data.imageUrls as string[] : [];
      const storagePaths = imageUrls.map((u) => extractStoragePathFromUrl(u));
      await safeDeleteStorageFiles(storagePaths);
      await lightningDoc.ref.delete();
    }

    await meetDoc.ref.delete();
  }
}

async function cleanupFriendsAndBlocks(uid: string) {
  // users/{uid}/friends, users/{uid}/blocks 삭제
  await deleteSubcollectionByPath(`users/${uid}/friends`);
  await deleteSubcollectionByPath(`users/${uid}/blocks`);

  // 다른 유저들의 friends / blocks 에서도 제거
  const friendRefs = await db.collectionGroup("friends")
    .where("uid", "==", uid)
    .get();
  await deleteDocsInChunks(friendRefs.docs);

  const blockRefs = await db.collectionGroup("blocks")
    .where("uid", "==", uid)
    .get();
  await deleteDocsInChunks(blockRefs.docs);
}

export const deleteUserData = functions
  .region("us-central1")
  .https
  .onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const uid = context.auth.uid;

    try {
      functions.logger.info("deleteUserData start", {uid});

      // 1) 내가 작성한 댓글 전체 삭제
      await deleteUserCommentsEverywhere(uid);

      // 2) 좋아요/멤버십/요청 등 참조 제거
      await cleanupLikesAndMembership(uid);
      await rejectOrDeleteMeetRequestsByUid(uid);
      await removeUidFromMapAndArrayInChatRooms(uid);

      // 3) 내가 작성한 번개 / 피드 / 모임 삭제
      await deleteAuthoredLightnings(uid);
      await deleteAuthoredFeeds(uid);
      await deleteAuthoredMeets(uid);

      // 4) 유저 하위 데이터 / 역참조 정리
      await cleanupFriendsAndBlocks(uid);

      // 5) workoutGoal 정리 (users/{uid} 문서 삭제 전에 별도 삭제 안 해도 되지만 명시)
      // users/{uid} 문서를 통째로 지울 예정

      // 6) users/{uid} 삭제
      await safeDeleteDoc(db.collection("users").doc(uid));

      // 7) refresh token revoke 후 Auth user 삭제
      await auth.revokeRefreshTokens(uid);
      await auth.deleteUser(uid);

      functions.logger.info("deleteUserData success", {uid});
      return {ok: true};
    } catch (e) {
      functions.logger.error("deleteUserData failed", {uid, error: String(e)});
      throw new functions.https.HttpsError(
        "internal",
        "회원 탈퇴 처리 중 오류가 발생했습니다.",
      );
    }
  });
