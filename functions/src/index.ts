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

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v) => typeof v === "string") : [];
}

function asStringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function asObject(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object"
    ? (value as Record<string, unknown>)
    : null;
}

function clampCount(value: unknown, delta: number): number {
  const current = typeof value === "number" ? value : 0;
  const next = current + delta;
  return next < 0 ? 0 : next;
}

function pickNextHost(userUids: string[], leavingUid: string): string | null {
  const candidates = userUids.filter((uid) => uid !== leavingUid);
  if (candidates.length === 0) return null;

  const randomIndex = Math.floor(Math.random() * candidates.length);
  return candidates[randomIndex];
}

async function deleteDocsInChunks(
  docs: QueryDoc[],
  chunkSize = 400,
): Promise<void> {
  if (docs.length === 0) return;

  for (let i = 0; i < docs.length; i += chunkSize) {
    const chunk = docs.slice(i, i + chunkSize);
    if (chunk.length === 0) continue;

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
  if (!collectionPath) return;

  while (true) {
    const snap = await db.collection(collectionPath).limit(pageSize).get();
    if (snap.empty) break;
    await deleteDocsInChunks(snap.docs, pageSize);
  }
}

async function safeDeleteDoc(ref: DocRef): Promise<void> {
  const snap = await ref.get();
  if (!snap.exists) return;
  await ref.delete();
}

function toStoragePath(input?: string | null): string | null {
  if (!input) return null;

  if (
    !input.startsWith("http://") &&
    !input.startsWith("https://") &&
    !input.startsWith("gs://")
  ) {
    return input;
  }

  if (input.startsWith("gs://")) {
    const idx = input.indexOf("/", 5);
    return idx >= 0 ? input.substring(idx + 1) : null;
  }

  try {
    const url = new URL(input);
    const marker = "/o/";
    const idx = url.pathname.indexOf(marker);
    if (idx >= 0) {
      const encoded = url.pathname.substring(idx + marker.length);
      return decodeURIComponent(encoded);
    }
  } catch (_) {}

  return null;
}

async function safeDeleteStorageFiles(
  pathsOrUrls: (string | null | undefined)[],
): Promise<void> {
  if (!Array.isArray(pathsOrUrls) || pathsOrUrls.length === 0) return;

  for (const value of pathsOrUrls) {
    const path = toStoragePath(value);
    if (!path) continue;

    try {
      await bucket.file(path).delete({ignoreNotFound: true});
    } catch (e) {
      functions.logger.warn("storage delete failed", {
        path,
        error: e instanceof Error ? e.message : String(e),
      });
    }
  }
}

async function getUserNickname(uid: string): Promise<string> {
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) return "회원";

  const nickname = userSnap.data()?.nickname;
  return typeof nickname === "string" && nickname.trim().length > 0
    ? nickname.trim()
    : "회원";
}

async function cleanupMyProfileImage(uid: string): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return;

  const data = snap.data() || {};
  const photoPath = asStringOrNull(data.photoPath);
  const photoUrl = asStringOrNull(data.photoUrl);

  await safeDeleteStorageFiles([photoPath, photoUrl]);
}

async function deleteUserCommentsEverywhere(uid: string): Promise<void> {
  functions.logger.info("query comments start", {uid});

  const commentSnap = await db
    .collectionGroup("comments")
    .where("authorUid", "==", uid)
    .get();

  functions.logger.info("query comments done", {
    uid,
    count: commentSnap.size,
  });

  if (commentSnap.empty) return;
  await deleteDocsInChunks(commentSnap.docs);
}

async function deleteUserLikesEverywhere(uid: string): Promise<void> {
  functions.logger.info("query likes start", {uid});

  const likeSnap = await db
    .collectionGroup("likes")
    .where("uid", "==", uid)
    .get();

  functions.logger.info("query likes done", {
    uid,
    count: likeSnap.size,
  });

  if (likeSnap.empty) return;
  await deleteDocsInChunks(likeSnap.docs);
}

async function rejectOrDeleteMeetRequestsByUid(uid: string): Promise<void> {
  functions.logger.info("query requests start", {uid});

  const reqSnap = await db
    .collectionGroup("requests")
    .where("uid", "==", uid)
    .get();

  functions.logger.info("query requests done", {
    uid,
    count: reqSnap.size,
  });

  if (reqSnap.empty) return;
  await deleteDocsInChunks(reqSnap.docs);
}

async function deleteChatRoomCompletely(
  chatRoomId?: string | null,
): Promise<void> {
  if (!chatRoomId) return;

  const roomRef = db.collection("chatRooms").doc(chatRoomId);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) return;

  await deleteSubcollectionByPath(`chatRooms/${chatRoomId}/messages`);
  await roomRef.delete();
}

async function deleteLightningDoc(
  lightningRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const snap = await lightningRef.get();
  if (!snap.exists) return;

  const data = snap.data() || {};
  const imageUrls = asStringArray(data.imageUrls);

  await safeDeleteStorageFiles(imageUrls);
  await lightningRef.delete();
}

async function deleteMeetDoc(
  meetRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const meetSnap = await meetRef.get();
  if (!meetSnap.exists) return;

  const data = meetSnap.data() || {};
  const imageUrls = asStringArray(data.imageUrls);
  const chatRoomId = asStringOrNull(data.chatRoomId);

  await deleteSubcollectionByPath(`${meetRef.path}/requests`);

  const lightningSnap = await meetRef.collection("lightnings").get();
  if (!lightningSnap.empty) {
    for (const lightningDoc of lightningSnap.docs) {
      await deleteLightningDoc(lightningDoc.ref);
    }
  }

  await deleteChatRoomCompletely(chatRoomId);
  await safeDeleteStorageFiles(imageUrls);
  await meetRef.delete();
}

async function leaveParticipatedMeets(uid: string): Promise<void> {
  functions.logger.info("query meets start", {uid});

  const snap = await db
    .collection("meets")
    .where("userUids", "array-contains", uid)
    .get();

  functions.logger.info("query meets done", {
    uid,
    count: snap.size,
  });

  if (snap.empty) return;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const userUids = asStringArray(data.userUids);

    if (!userUids.includes(uid)) continue;

    const isHost = data.authorUid === uid;
    const nextUserUids = userUids.filter((userUid) => userUid !== uid);

    if (isHost && nextUserUids.length === 0) {
      await deleteMeetDoc(doc.ref);
      continue;
    }

    const updates: Record<string, unknown> = {
      userUids: nextUserUids,
      currentMemberCount: clampCount(data.currentMemberCount, -1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (isHost) {
      const nextHostUid = pickNextHost(userUids, uid);
      updates.authorUid = nextHostUid;
      if (!nextHostUid) {
        updates.needApproval = false;
      }
    }

    await doc.ref.update(updates);
  }
}

async function leaveParticipatedLightnings(uid: string): Promise<void> {
  functions.logger.info("query lightnings start", {uid});

  const snap = await db
    .collectionGroup("lightnings")
    .where("userUids", "array-contains", uid)
    .get();

  functions.logger.info("query lightnings done", {
    uid,
    count: snap.size,
  });

  if (snap.empty) return;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const userUids = asStringArray(data.userUids);

    if (!userUids.includes(uid)) continue;

    const isHost = data.authorUid === uid;
    const nextUserUids = userUids.filter((userUid) => userUid !== uid);

    if (isHost && nextUserUids.length === 0) {
      await deleteLightningDoc(doc.ref);
      continue;
    }

    const updates: Record<string, unknown> = {
      userUids: nextUserUids,
      currentMemberCount: clampCount(data.currentMemberCount, -1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (isHost) {
      const nextHostUid = pickNextHost(userUids, uid);
      updates.authorUid = nextHostUid;
    }

    await doc.ref.update(updates);
  }
}

async function leaveChatRoomsAsMember(
  uid: string,
  nickname: string,
): Promise<void> {
  functions.logger.info("query chatRooms start", {uid});

  const snap = await db
    .collection("chatRooms")
    .where("userUids", "array-contains", uid)
    .get();

  functions.logger.info("query chatRooms done", {
    uid,
    count: snap.size,
  });

  if (snap.empty) return;

  for (const roomDoc of snap.docs) {
    const data = roomDoc.data() || {};
    const updates: Record<string, unknown> = {};
    let changed = false;

    const userUids = asStringArray(data.userUids);
    const visibleUids = asStringArray(data.visibleUids);
    const unreadCountMap = asObject(data.unreadCountMap);
    const activeAtMap = asObject(data.activeAtMap);
    const chatPushOffMap = asObject(data.chatPushOffMap);

    if (userUids.includes(uid)) {
      updates.userUids = admin.firestore.FieldValue.arrayRemove(uid);
      changed = true;
    }

    if (visibleUids.includes(uid)) {
      updates.visibleUids = admin.firestore.FieldValue.arrayRemove(uid);
      changed = true;
    }

    if (unreadCountMap && uid in unreadCountMap) {
      updates[`unreadCountMap.${uid}`] = admin.firestore.FieldValue.delete();
      changed = true;
    }

    if (activeAtMap && uid in activeAtMap) {
      updates[`activeAtMap.${uid}`] = admin.firestore.FieldValue.delete();
      changed = true;
    }

    if (chatPushOffMap && uid in chatPushOffMap) {
      updates[`chatPushOffMap.${uid}`] = admin.firestore.FieldValue.delete();
      changed = true;
    }

    if (changed) {
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      await roomDoc.ref.update(updates);
    }

    if (data.type === "group") {
      const systemText = `${nickname}님이 채팅방을 나갔어요.`;
      const messageRef = roomDoc.ref.collection("messages").doc();

      await messageRef.set({
        id: messageRef.id,
        authorUid: "system",
        type: "system",
        text: systemText,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await roomDoc.ref.update({
        lastMessageText: systemText,
        lastMessageType: "system",
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
}

async function deleteAuthoredFeeds(uid: string): Promise<void> {
  functions.logger.info("query authored feeds start", {uid});

  const snap = await db
    .collection("feeds")
    .where("authorUid", "==", uid)
    .get();

  functions.logger.info("query authored feeds done", {
    uid,
    count: snap.size,
  });

  if (snap.empty) return;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const imageUrls = asStringArray(data.imageUrls);

    await deleteSubcollectionByPath(`feeds/${doc.id}/comments`);
    await deleteSubcollectionByPath(`feeds/${doc.id}/likes`);
    await safeDeleteStorageFiles(imageUrls);
    await doc.ref.delete();
  }
}

async function cleanupFriendsAndBlocks(uid: string): Promise<void> {
  await deleteSubcollectionByPath(`users/${uid}/friends`);
  await deleteSubcollectionByPath(`users/${uid}/blocks`);

  functions.logger.info("query reverse friends start", {uid});
  const friendSnap = await db
    .collectionGroup("friends")
    .where("uid", "==", uid)
    .get();
  functions.logger.info("query reverse friends done", {
    uid,
    count: friendSnap.size,
  });
  if (!friendSnap.empty) {
    await deleteDocsInChunks(friendSnap.docs);
  }

  functions.logger.info("query reverse blocks start", {uid});
  const blockSnap = await db
    .collectionGroup("blocks")
    .where("uid", "==", uid)
    .get();
  functions.logger.info("query reverse blocks done", {
    uid,
    count: blockSnap.size,
  });
  if (!blockSnap.empty) {
    await deleteDocsInChunks(blockSnap.docs);
  }
}

async function cleanupUserNotifications(uid: string): Promise<void> {
  await deleteSubcollectionByPath(`users/${uid}/notifications`);
}

export const deleteUserData = functions
  .region("us-central1")
  .https
  .onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
    }

    const uid = context.auth.uid;

    try {
      functions.logger.info("deleteUserData start", {uid});

      const nickname = await getUserNickname(uid);

      functions.logger.info("cleanup profile image start", {uid});
      await cleanupMyProfileImage(uid);
      functions.logger.info("cleanup profile image done", {uid});

      functions.logger.info("delete user comments start", {uid});
      await deleteUserCommentsEverywhere(uid);
      functions.logger.info("delete user comments done", {uid});

      functions.logger.info("delete user likes start", {uid});
      await deleteUserLikesEverywhere(uid);
      functions.logger.info("delete user likes done", {uid});

      functions.logger.info("delete meet requests start", {uid});
      await rejectOrDeleteMeetRequestsByUid(uid);
      functions.logger.info("delete meet requests done", {uid});

      functions.logger.info("leave participated meets start", {uid});
      await leaveParticipatedMeets(uid);
      functions.logger.info("leave participated meets done", {uid});

      functions.logger.info("leave participated lightnings start", {uid});
      await leaveParticipatedLightnings(uid);
      functions.logger.info("leave participated lightnings done", {uid});

      functions.logger.info("leave chat rooms start", {uid});
      await leaveChatRoomsAsMember(uid, nickname);
      functions.logger.info("leave chat rooms done", {uid});

      functions.logger.info("delete authored feeds start", {uid});
      await deleteAuthoredFeeds(uid);
      functions.logger.info("delete authored feeds done", {uid});

      functions.logger.info("cleanup notifications start", {uid});
      await cleanupUserNotifications(uid);
      functions.logger.info("cleanup notifications done", {uid});

      functions.logger.info("cleanup friends/blocks start", {uid});
      await cleanupFriendsAndBlocks(uid);
      functions.logger.info("cleanup friends/blocks done", {uid});

      functions.logger.info("delete user doc start", {uid});
      await safeDeleteDoc(db.collection("users").doc(uid));
      functions.logger.info("delete user doc done", {uid});

      functions.logger.info("auth delete start", {uid});
      await auth.revokeRefreshTokens(uid);
      await auth.deleteUser(uid);
      functions.logger.info("auth delete done", {uid});

      functions.logger.info("deleteUserData success", {uid});
      return {ok: true};
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      const stack = e instanceof Error ? e.stack : undefined;

      functions.logger.error("deleteUserData failed", {
        uid,
        message,
        stack,
      });

      throw new functions.https.HttpsError("internal", message);
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

    if (!targetUid) return;
    if (targetUid === authorUid) return;

    const senderUserSnap = await db.collection("users").doc(authorUid).get();
    const senderUser = senderUserSnap.data() ?? {};
    const senderNickname =
      (senderUser.nickname as string | undefined) ?? "누군가";

    const targetUserSnap = await db.collection("users").doc(targetUid).get();
    if (!targetUserSnap.exists) return;

    const targetUser = targetUserSnap.data() ?? {};
    const notificationSettings =
      (targetUser.notificationSettings as Record<string, unknown> | undefined) ??
      {};

    const allowComment =
      typeof notificationSettings.comment === "boolean" ?
        notificationSettings.comment :
        true;

    const body = `${senderNickname}님이 회원님의 피드에 댓글을 남겼습니다.`;

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
      contentPreview:
        content.length > 60 ? `${content.substring(0, 60)}...` : content,
    });

    if (!allowComment) return;

    const tokens = Array.isArray(targetUser.fcmTokens) ?
      (targetUser.fcmTokens as string[]).filter(
        (token: string) => token.trim().length > 0,
      ) :
      [];

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

    if (invalidTokens.length > 0) {
      await db.collection("users").doc(targetUid).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

export const sendLikeNotification = functions.firestore
  .document("feeds/{feedId}/likes/{uid}")
  .onCreate(async (snap, context) => {
    const feedId = context.params.feedId;
    const uid = context.params.uid;

    const feedDoc = await db.collection("feeds").doc(feedId).get();
    if (!feedDoc.exists) return;

    const feed = feedDoc.data();
    const targetUid = feed?.authorUid as string | undefined;

    // 피드 작성자 없으면 중단
    if (!targetUid) return;

    // 본인 좋아요는 알림 안 보냄
    if (targetUid === uid) return;

    // 좋아요 누른 유저 정보
    const userDoc = await db.collection("users").doc(uid).get();
    const nickname = (userDoc.data()?.nickname as string | undefined) ?? "누군가";

    // 대상 유저 알림 설정 확인
    const targetUserDoc = await db.collection("users").doc(targetUid).get();
    const notificationSettings =
      (targetUserDoc.data()?.notificationSettings ??
        {}) as Record<string, unknown>;

    // ✅ 키 없으면 기본 true
    const allowLike =
      typeof notificationSettings.like === "boolean" ?
        notificationSettings.like :
        true;

    const body = `${nickname}님이 회원님의 피드를 좋아합니다.`;

    // 1) 알림 문서 저장 (댓글과 동일 패턴)
    const notificationRef = db
      .collection("users")
      .doc(targetUid)
      .collection("notifications")
      .doc();

    await notificationRef.set({
      id: notificationRef.id,
      type: "like",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      feedId,
      senderUid: uid,
      senderNickname: nickname,
      title: "새 좋아요",
      body,
    });

    // 푸시 허용 안 하면 문서만 저장하고 종료
    if (!allowLike) return;

    // 대상 유저의 fcm 토큰 조회
   const targetUserSnap = await db.collection("users").doc(targetUid).get();
   if (!targetUserSnap.exists) return;

   const targetUser = targetUserSnap.data() ?? {};
   const tokens = Array.isArray(targetUser.fcmTokens)
     ? (targetUser.fcmTokens as string[]).filter(
         (token: string) => token.trim().length > 0,
       )
     : [];

   if (tokens.length === 0) return;

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: "새 좋아요",
        body,
      },
      data: {
        type: "like",
        feedId,
        senderUid: uid,
        senderNickname: nickname,
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

   if (invalidTokens.length > 0) {
     await db.collection("users").doc(targetUid).update({
       fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
     });
   }
  });
export const sendChatMessageNotification = functions.firestore
  .document("chatRooms/{roomId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const roomId = context.params.roomId;
    const messageId = context.params.messageId;
    const message = snap.data();

    if (!message) return;

    const authorUid = (message.authorUid as string | undefined) ?? "";
    const type = (message.type as string | undefined) ?? "text";
    const text = (message.text as string | undefined) ?? "";
    const createdAt =
      (message.createdAt as admin.firestore.Timestamp | undefined) ??
      admin.firestore.Timestamp.now();

    if (!authorUid) return;

    const roomRef = db.collection("chatRooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) return;

    const room = roomSnap.data() ?? {};

    const userUids = Array.isArray(room.userUids) ?
      (room.userUids as string[]) :
      [];

    const visibleUids = Array.isArray(room.visibleUids) ?
      (room.visibleUids as string[]) :
      [];

    const activeAtMap =
      (room.activeAtMap as Record<string, admin.firestore.Timestamp> | undefined) ??
      {};

    const chatPushOffMap =
      (room.chatPushOffMap as Record<string, boolean> | undefined) ?? {};

    if (userUids.length === 0) return;

    const receiverUids = userUids.filter((uid) => uid !== authorUid);

    // 작성자 정보 1회 조회
    const authorSnap = await db.collection("users").doc(authorUid).get();
    const author = authorSnap.data() ?? {};
    const authorNickname =
      (author.nickname as string | undefined) ?? "누군가";

    let messagePreview = "";
    if (type === "image") {
      messagePreview = "사진을 보냈습니다.";
    } else if (type === "system") {
      messagePreview = text || "시스템 메시지";
    } else {
      messagePreview = text || "메시지를 보냈습니다.";
    }

    const roomTitle = (() => {
      const explicitTitle = (room.title as string | undefined) ?? "";
      if (explicitTitle.trim().length > 0) return explicitTitle;
      return authorNickname;
    })();

    // 1) 채팅방 메타 업데이트
    const roomUpdates: Record<string, unknown> = {
      lastMessageText: type === "image" ? "사진" : messagePreview,
      lastMessageType: type,
      lastMessageAt: createdAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    for (const targetUid of receiverUids) {
      roomUpdates[`unreadCountMap.${targetUid}`] =
        admin.firestore.FieldValue.increment(1);
    }

    await roomRef.update(roomUpdates);

    // 2) 수신자 users 문서를 한 번에(10개씩) 읽어서 맵으로 만듦
    const targetUserMap: Record<string, FirebaseFirestore.DocumentData> = {};

    const chunkSize = 10;
    for (let i = 0; i < receiverUids.length; i += chunkSize) {
      const chunk = receiverUids.slice(i, i + chunkSize);
      if (chunk.length === 0) continue;

      const userSnap = await db
        .collection("users")
        .where(admin.firestore.FieldPath.documentId(), "in", chunk)
        .get();

      for (const doc of userSnap.docs) {
        targetUserMap[doc.id] = doc.data();
      }
    }

    // 3) 실제 푸시 대상 추리기
    const pushTargets: Array<{
      uid: string;
      tokens: string[];
    }> = [];

    for (const targetUid of receiverUids) {
      if (!visibleUids.includes(targetUid)) continue;

      const targetUser = targetUserMap[targetUid];
      if (!targetUser) continue;

      const notificationSettings =
        (targetUser.notificationSettings as Record<string, unknown> | undefined) ??
        {};

      // 전역 채팅 알림: 없으면 기본 true
      const allowGlobalChat =
        typeof notificationSettings.chat === "boolean" ?
          notificationSettings.chat :
          true;

      if (!allowGlobalChat) continue;

      // 방별 채팅 알림: 없음/true 허용, false 차단
      const allowRoomPush = chatPushOffMap[targetUid] !== false;
      if (!allowRoomPush) continue;

      // 현재 방 보고 있으면 푸시 생략
      const activeAt = activeAtMap[targetUid];
      if (activeAt) {
        const diffMs = createdAt.toMillis() - activeAt.toMillis();
        if (diffMs <= 60 * 1000) continue;
      }

      const tokens = Array.isArray(targetUser.fcmTokens) ?
        (targetUser.fcmTokens as string[]).filter(
          (token: string) => token.trim().length > 0,
        ) :
        [];

      if (tokens.length === 0) continue;

      pushTargets.push({
        uid: targetUid,
        tokens,
      });
    }

    if (pushTargets.length === 0) return;

    // 4) 푸시 발송 (수신자별)
    const pushTitle = roomTitle;
    const pushBody = type === "image" ?
      `${authorNickname}님이 사진을 보냈습니다.` :
      `${authorNickname}: ${messagePreview}`;

    for (const target of pushTargets) {
      const multicastMessage: admin.messaging.MulticastMessage = {
        tokens: target.tokens,
        notification: {
          title: pushTitle,
          body: pushBody,
        },
        data: {
          type: "chat",
          roomId,
          roomType: room.type ?? "dm",
          otherUid: room.type === "dm" ? authorUid : "",
          meetId: room.type === "group" ? (room.meetId ?? "") : "",
          messageId,
          senderUid: authorUid,
          senderNickname: authorNickname,
        },
        android: {
          notification: {
            channelId: "chat",
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

      const response = await messaging.sendEachForMulticast(multicastMessage);

      const invalidTokens: string[] = [];

      response.responses.forEach(
        (r: admin.messaging.SendResponse, index: number) => {
          if (!r.success) {
            const code = r.error?.code ?? "";
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(target.tokens[index]);
            }
          }
        },
      );

      if (invalidTokens.length > 0) {
        await db.collection("users").doc(target.uid).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  });
