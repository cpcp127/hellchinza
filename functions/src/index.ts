import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();
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
export const onCommentCreatedSendNotification = functions
  .region("us-central1")
  .firestore
  .document("feeds/{feedId}/comments/{commentId}")
  .onCreate(async (snap, context) => {
    const {feedId, commentId} = context.params;
    const comment = snap.data();

    if (!comment) return;

    const authorUid = comment.authorUid as string | undefined;
    const content = (comment.content as string | undefined) ?? "";

    if (!authorUid) return;

    const feedRef = db.collection("feeds").doc(feedId);
    const feedSnap = await feedRef.get();
    if (!feedSnap.exists) return;

    const feedData = feedSnap.data() ?? {};
    const targetUid = feedData.authorUid as string | undefined;

    // 피드 작성자가 없으면 중단
    if (!targetUid) return;

    // 본인 글에 본인이 댓글 단 경우 푸시 안 보냄
    if (targetUid === authorUid) return;

    // 댓글 작성자 정보 조회
    const senderUserSnap = await db.collection("users").doc(authorUid).get();
    const senderUser = senderUserSnap.data() ?? {};
    const senderNickname =
      (senderUser.nickname as string | undefined) ?? "누군가";

    // 대상 유저 알림 설정 확인
    const targetUserSnap = await db.collection("users").doc(targetUid).get();
    const targetUser = targetUserSnap.data() ?? {};
    const notificationSettings =
      (targetUser.notificationSettings as Record<string, unknown> | undefined) ??
      {};

    // ✅ 키가 없으면 기본 true
    const allowComment =
      typeof notificationSettings.comment === "boolean" ?
        notificationSettings.comment :
        true;

    const body =
      `${senderNickname}님이 회원님의 피드에 댓글을 남겼습니다.`;

    // 1) 알림 문서 저장
    const notificationRef = db
      .collection("users")
      .doc(targetUid)
      .collection("notifications")
      .doc();

    await notificationRef.set({
      id: notificationRef.id,
      type: "comment",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      feedId,
      commentId,
      senderUid: authorUid,
      senderNickname,
      title: "새 댓글",
      body,
      contentPreview: content.length > 60 ? `${content.substring(0, 60)}...` : content,
    });

    // 푸시 허용 안 하면 문서만 저장하고 끝
    if (!allowComment) return;

    // 대상 유저의 fcm 토큰 조회
    const tokenSnap = await db
      .collection("users")
      .doc(targetUid)
      .collection("fcmTokens")
      .get();

    if (tokenSnap.empty) return;

    const tokens = tokenSnap.docs
      .map((doc) => ((doc.data().token as string | undefined) ?? "").trim())
      .filter((token: string) => token.length > 0);

    if (tokens.length === 0) return;

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: "새 댓글",
        body,
      },
      data: {
        type: "comment",
        feedId,
        commentId,
        senderUid: authorUid,
        senderNickname,
      },
      android: {
        notification: {
          channelId: "social",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);

    // invalid token 정리
    const invalidTokens: string[] = [];

    response.responses.forEach(
      (r: admin.messaging.SendResponse, index: number) => {
        if (!r.success) {
          const code = r.error?.code ?? "";
          if (
            code === "messaging/invalid-registration-token" ||
           code === "messaging/registration-token-not-registered"
          ) {
            invalidTokens.push(tokens[index]);
          }
        }
      },
    );

    for (const token of invalidTokens) {
      await db
        .collection("users")
        .doc(targetUid)
        .collection("fcmTokens")
        .doc(token)
        .delete();
    }
  });
