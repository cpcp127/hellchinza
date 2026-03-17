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
  await deleteSubcollectionByPath(`${meetRef.path}/members`);

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
  functions.logger.info("query meet members start", {uid});

  const memberSnap = await db
    .collectionGroup("members")
    .where("uid", "==", uid)
    .get();

  functions.logger.info("query meet members done", {
    uid,
    count: memberSnap.size,
  });

  if (memberSnap.empty) return;

  for (const memberDoc of memberSnap.docs) {
    const meetRef = memberDoc.ref.parent.parent;
    if (!meetRef) continue;

    const meetSnap = await meetRef.get();
    if (!meetSnap.exists) continue;

    const meetData = meetSnap.data() || {};
    const isHost = meetData.authorUid === uid;

    // 1) 내 member 문서 삭제
    await memberDoc.ref.delete();

    // 2) 남은 멤버 조회
    const remainSnap = await meetRef
      .collection("members")
      .orderBy("joinedAt", "asc")
      .limit(10)
      .get();

    // 3) 마지막 멤버였으면 모임 전체 삭제
    if (remainSnap.empty) {
      await deleteMeetDoc(meetRef);
      continue;
    }

    // 4) 호스트가 나가는 경우 -> 다음 호스트 지정
    if (isHost) {
      const nextHostDoc = remainSnap.docs.find((doc) => {
        const data = doc.data() || {};
        const nextUid = typeof data.uid === "string" ? data.uid : doc.id;
        return nextUid !== uid;
      });

      const nextHostUid = nextHostDoc
        ? (typeof nextHostDoc.data().uid === "string"
            ? nextHostDoc.data().uid
            : nextHostDoc.id)
        : null;

      if (nextHostUid) {
        await meetRef.update({
          authorUid: nextHostUid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 선택: members.role도 같이 맞추고 싶으면
        await meetRef.collection("members").doc(nextHostUid).set(
          {
            role: "host",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
    } else {
      await meetRef.update({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
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
async function cleanupUserScores(uid: string): Promise<void> {
  await deleteSubcollectionByPath(`users/${uid}/scoreEvents`);
  await deleteSubcollectionByPath(`users/${uid}/scoreDaily`);
}

const SCORE = {
  OOW_FEED: 20,
  NORMAL_FEED: 5,
  MEET_CREATE: 20,
  MEET_JOIN: 10,
  LIGHTNING_CREATE: 15,
  LIGHTNING_JOIN: 15,
  COMMENT_WRITE: 2,
  COMMENT_RECEIVED: 2,
  LIKE_RECEIVED: 1,
};

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

function toKstShifted(date: Date): Date {
  return new Date(date.getTime() + KST_OFFSET_MS);
}

function dayKeyFromDate(date: Date): string {
  const shifted = toKstShifted(date);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const d = String(shifted.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function startOfKstWeekUtc(date: Date): Date {
  const shifted = toKstShifted(date);
  const day = shifted.getUTCDay(); // Sun=0
  const diffFromMonday = (day + 6) % 7;
  shifted.setUTCHours(0, 0, 0, 0);
  shifted.setUTCDate(shifted.getUTCDate() - diffFromMonday);
  return new Date(shifted.getTime() - KST_OFFSET_MS);
}

function endOfKstWeekUtc(date: Date): Date {
  return new Date(startOfKstWeekUtc(date).getTime() + 7 * DAY_MS);
}

function weekKeyFromDate(date: Date): string {
  const start = startOfKstWeekUtc(date);
  return dayKeyFromDate(start);
}

async function grantOneTimeScore(params: {
  uid: string;
  eventId: string;
  type: string;
  points: number;
  refId?: string;
  dayKey?: string;
  weekKey?: string;
  extra?: Record<string, unknown>;
}): Promise<boolean> {
  const userRef = db.collection("users").doc(params.uid);
  const eventRef = userRef.collection("scoreEvents").doc(params.eventId);

  return db.runTransaction(async (tx) => {
    const eventSnap = await tx.get(eventRef);
    if (eventSnap.exists) return false;

    tx.set(eventRef, {
      id: params.eventId,
      type: params.type,
      points: params.points,
      refId: params.refId ?? null,
      dayKey: params.dayKey ?? null,
      weekKey: params.weekKey ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(params.extra ?? {}),
    });

    tx.set(
      userRef,
      {
        score: {
          total: admin.firestore.FieldValue.increment(params.points),
          weekly: admin.firestore.FieldValue.increment(params.points),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );

    return true;
  });
}

async function grantDailyLimitedScore(params: {
  uid: string;
  eventId: string;
  type: string;
  points: number;
  dayKey: string;
  dailyField: string;
  dailyMaxCount: number;
  refId?: string;
  weekKey?: string;
  extra?: Record<string, unknown>;
}): Promise<boolean> {
  const userRef = db.collection("users").doc(params.uid);
  const eventRef = userRef.collection("scoreEvents").doc(params.eventId);
  const dailyRef = userRef.collection("scoreDaily").doc(params.dayKey);

  return db.runTransaction(async (tx) => {
    const [eventSnap, dailySnap] = await Promise.all([
      tx.get(eventRef),
      tx.get(dailyRef),
    ]);

    if (eventSnap.exists) return false;

    const dailyData = dailySnap.exists ? (dailySnap.data() ?? {}) : {};
    const currentCount =
      typeof dailyData[params.dailyField] === "number" ?
        (dailyData[params.dailyField] as number) :
        0;

    if (currentCount >= params.dailyMaxCount) return false;

    tx.set(eventRef, {
      id: params.eventId,
      type: params.type,
      points: params.points,
      refId: params.refId ?? null,
      dayKey: params.dayKey,
      weekKey: params.weekKey ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(params.extra ?? {}),
    });

    tx.set(
      dailyRef,
      {
        dayKey: params.dayKey,
        [params.dailyField]: currentCount + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    tx.set(
      userRef,
      {
        score: {
          total: admin.firestore.FieldValue.increment(params.points),
          weekly: admin.firestore.FieldValue.increment(params.points),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );

    return true;
  });
}

async function tryGrantWeeklyGoalBonus(
  uid: string,
  baseDate: Date,
): Promise<boolean> {
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) return false;

  const userData = userSnap.data() ?? {};
  const workoutGoal =
    (userData.workoutGoal as Record<string, unknown> | undefined) ?? {};
  const weeklyTarget =
    typeof workoutGoal.weeklyTarget === "number" ?
      workoutGoal.weeklyTarget :
      0;

  if (weeklyTarget <= 0) return false;

  const weekStart = startOfKstWeekUtc(baseDate);
  const weekEnd = endOfKstWeekUtc(baseDate);
  const weekKey = weekKeyFromDate(baseDate);

  const feedSnap = await db
    .collection("feeds")
    .where("authorUid", "==", uid)
    .where("mainType", "==", "오운완")
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(weekStart))
    .where("createdAt", "<", admin.firestore.Timestamp.fromDate(weekEnd))
    .get();

  const uniqueDayKeys = new Set<string>();

  for (const doc of feedSnap.docs) {
    const data = doc.data() ?? {};
    const ts = data.createdAt;
    if (ts instanceof admin.firestore.Timestamp) {
      uniqueDayKeys.add(dayKeyFromDate(ts.toDate()));
    }
  }

  if (uniqueDayKeys.size < weeklyTarget) return false;

  return grantOneTimeScore({
    uid,
    eventId: `weekly_goal_bonus_${weekKey}`,
    type: "weekly_goal_bonus",
    points: weeklyTarget * 10,
    weekKey,
    extra: {
      weeklyTarget,
      achievedDays: uniqueDayKeys.size,
    },
  });
}


export const deleteUserData = functions
  .region("asia-northeast3")
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
    functions.logger.info("cleanup scores start", {uid});
    await cleanupUserScores(uid);
        functions.logger.info("cleanup scores done", {uid});
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
  .region("asia-northeast3")
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
     const activeAt = activeAtMap[targetUid];

     let isActiveRecently = false;

     if (activeAt instanceof admin.firestore.Timestamp) {
       const diffMs = createdAt.toMillis() - activeAt.toMillis();
       isActiveRecently = diffMs <= 30 * 1000; // 30초 안에 활동 중
     }

     if (!isActiveRecently) {
       roomUpdates[`unreadCountMap.${targetUid}`] =
         admin.firestore.FieldValue.increment(1);
     }
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

   let pushBody = "";

   if (type === "system" || authorUid === "system") {
     pushBody = messagePreview;
   } else if (type === "image") {
     pushBody = `${authorNickname}님이 사진을 보냈습니다.`;
   } else {
     pushBody = `${authorNickname}: ${messagePreview}`;
   }

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

export const sendMeetJoinRequestNotification = functions
  .region("asia-northeast3")
  .firestore
  .document("meets/{meetId}/requests/{requestUid}")
  .onCreate(async (snap, context) => {

    const data = snap.data();
    const meetId = context.params.meetId;
    const requesterUid = data.uid;

    try {

      /// 1️⃣ meet 정보
      const meetSnap = await db.collection("meets").doc(meetId).get();
      if (!meetSnap.exists) return;

      const meet = meetSnap.data()!;
      const hostUid = meet.authorUid;
      const meetTitle = meet.title ?? "모임";

      /// 2️⃣ 신청자 정보
      const requesterSnap = await db.collection("users").doc(requesterUid).get();
      const requester = requesterSnap.data();
      const nickname = requester?.nickname ?? "누군가";

      /// 3️⃣ 알림 내용
      const title = "모임 참가 신청";
      const body = `${nickname}님이 '${meetTitle}' 모임에 참가 신청했어요`;

      /// 4️⃣ notifications 저장
      const notificationRef = db
        .collection("users")
        .doc(hostUid)
        .collection("notifications")
        .doc();

      await notificationRef.set({
        id: notificationRef.id,
        type: "meet",
        meetId: meetId,
        title: title,
        body: body,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });

      /// 5️⃣ host FCM 토큰 조회
      const hostSnap = await db.collection("users").doc(hostUid).get();
      const host = hostSnap.data();

      const tokens: string[] = host?.fcmTokens ?? [];

      if (!tokens.length) return;

      /// 6️⃣ FCM 전송
      await messaging.sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: "meet",
          meetId: meetId,
        },
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });

      functions.logger.info("meet join request push sent", {
        meetId,
        hostUid,
        requesterUid,
      });

    } catch (e) {
      functions.logger.error("meet join request push failed", {
        error: String(e),
        meetId,
      });
    }
  });

export const sendMeetRequestApprovedNotification = functions
  .region("asia-northeast3")
  .https
  .onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
    }

    const hostUid = context.auth.uid;
    const meetId = data.meetId as string | undefined;
    const targetUid = data.targetUid as string | undefined;

    if (!meetId || !targetUid) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "meetId, targetUid가 필요합니다.",
      );
    }

    try {
      const meetSnap = await db.collection("meets").doc(meetId).get();
      if (!meetSnap.exists) {
        throw new functions.https.HttpsError("not-found", "모임이 없어요.");
      }

      const meet = meetSnap.data()!;
      if (meet.authorUid != hostUid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "호스트만 승인 알림을 보낼 수 있어요.",
        );
      }

      const meetTitle = meet.title ?? "모임";

      const targetSnap = await db.collection("users").doc(targetUid).get();
      if (!targetSnap.exists) return;

      const target = targetSnap.data()!;
      const tokens: string[] = Array.isArray(target.fcmTokens)
        ? target.fcmTokens.filter(
            (e: unknown) => typeof e === "string" && e.trim().length > 0,
          )
        : [];

      const title = "모임 참가 승인";
      const body = `'${meetTitle}' 모임 참가가 승인되었어요`;

      const notiRef = db
        .collection("users")
        .doc(targetUid)
        .collection("notifications")
        .doc();

      await notiRef.set({
        id: notiRef.id,
        type: "meet",
        action: "requestApproved",
        meetId,
        title,
        body,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {
            type: "meet",
            action: "requestApproved",
            meetId,
          },
        });
      }

      return {ok: true};
    } catch (e) {
      functions.logger.error("sendMeetRequestApprovedNotification failed", {
        meetId,
        targetUid,
        error: String(e),
      });
      throw new functions.https.HttpsError(
        "internal",
        "승인 알림 전송에 실패했어요.",
      );
    }
  });

export const sendMeetRequestRejectedNotification = functions
  .region("asia-northeast3")
  .https
  .onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
    }

    const hostUid = context.auth.uid;
    const meetId = data.meetId as string | undefined;
    const targetUid = data.targetUid as string | undefined;

    if (!meetId || !targetUid) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "meetId, targetUid가 필요합니다.",
      );
    }

    try {
      const meetSnap = await db.collection("meets").doc(meetId).get();
      if (!meetSnap.exists) {
        throw new functions.https.HttpsError("not-found", "모임이 없어요.");
      }

      const meet = meetSnap.data()!;
      if (meet.authorUid != hostUid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "호스트만 거절 알림을 보낼 수 있어요.",
        );
      }

      const meetTitle = meet.title ?? "모임";

      const targetSnap = await db.collection("users").doc(targetUid).get();
      if (!targetSnap.exists) return;

      const target = targetSnap.data()!;
      const tokens: string[] = Array.isArray(target.fcmTokens)
        ? target.fcmTokens.filter(
            (e: unknown) => typeof e === "string" && e.trim().length > 0,
          )
        : [];

      const title = "모임 참가 거절";
      const body = `'${meetTitle}' 모임 참가 요청이 거절되었어요`;

      const notiRef = db
        .collection("users")
        .doc(targetUid)
        .collection("notifications")
        .doc();

      await notiRef.set({
        id: notiRef.id,
        type: "meet",
        action: "requestRejected",
        meetId,
        title,
        body,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {
            type: "meet",
            action: "requestRejected",
            meetId,
          },
        });
      }

      return {ok: true};
    } catch (e) {
      functions.logger.error("sendMeetRequestRejectedNotification failed", {
        meetId,
        targetUid,
        error: String(e),
      });
      throw new functions.https.HttpsError(
        "internal",
        "거절 알림 전송에 실패했어요.",
      );
    }
  });

export const onFeedCreatedGiveScore = functions
  .region("asia-northeast3")
  .firestore
  .document("feeds/{feedId}")
  .onCreate(async (snap, context) => {
    const feedId = context.params.feedId;
    const data = snap.data() ?? {};

    if (data.isSeed === true) return;

    const authorUid =
      typeof data.authorUid === "string" ? data.authorUid : null;
    if (!authorUid) return;

    const mainType =
      typeof data.mainType === "string" ? data.mainType : "";
    const createdAt =
      data.createdAt instanceof admin.firestore.Timestamp ?
        data.createdAt.toDate() :
        new Date();

    const dayKey = dayKeyFromDate(createdAt);
    const weekKey = weekKeyFromDate(createdAt);

    if (mainType === "오운완") {
      const granted = await grantOneTimeScore({
        uid: authorUid,
        eventId: `oow_${dayKey}`,
        type: "oow_feed",
        points: SCORE.OOW_FEED,
        refId: feedId,
        dayKey,
        weekKey,
      });

      if (granted) {
        await tryGrantWeeklyGoalBonus(authorUid, createdAt);
      }
      return;
    }

    await grantDailyLimitedScore({
      uid: authorUid,
      eventId: `feed_create_${feedId}`,
      type: "feed_create",
      points: SCORE.NORMAL_FEED,
      refId: feedId,
      dayKey,
      weekKey,
      dailyField: "normalFeedCount",
      dailyMaxCount: 3,
    });
  });

export const onMeetCreatedGiveScore = functions
  .region("asia-northeast3")
  .firestore
  .document("meets/{meetId}")
  .onCreate(async (snap, context) => {
    const meetId = context.params.meetId;
    const data = snap.data() ?? {};

    if (data.isSeed === true) return;

    const authorUid =
      typeof data.authorUid === "string" ? data.authorUid : null;
    if (!authorUid) return;

    const createdAt =
      data.createdAt instanceof admin.firestore.Timestamp ?
        data.createdAt.toDate() :
        new Date();

    await grantOneTimeScore({
      uid: authorUid,
      eventId: `meet_create_${meetId}`,
      type: "meet_create",
      points: SCORE.MEET_CREATE,
      refId: meetId,
      dayKey: dayKeyFromDate(createdAt),
      weekKey: weekKeyFromDate(createdAt),
    });
  });

export const onMeetMemberCreatedGiveScore = functions
  .region("asia-northeast3")
  .firestore
  .document("meets/{meetId}/members/{memberUid}")
  .onCreate(async (snap, context) => {
    const meetId = context.params.meetId;
    const memberUid = context.params.memberUid;

    const meetSnap = await db.collection("meets").doc(meetId).get();
    if (!meetSnap.exists) return;

    const meet = meetSnap.data() ?? {};
    if (meet.isSeed === true) return;

    const hostUid =
      typeof meet.authorUid === "string" ? meet.authorUid : null;

    // 호스트는 생성 점수만 받고 참가 점수는 제외
    if (hostUid && hostUid === memberUid) return;

    const data = snap.data() ?? {};
    const joinedAt =
      data.joinedAt instanceof admin.firestore.Timestamp ?
        data.joinedAt.toDate() :
        new Date();

    await grantOneTimeScore({
      uid: memberUid,
      eventId: `meet_join_${meetId}`,
      type: "meet_join",
      points: SCORE.MEET_JOIN,
      refId: meetId,
      dayKey: dayKeyFromDate(joinedAt),
      weekKey: weekKeyFromDate(joinedAt),
    });
  });

export const onLightningCreatedGiveScore = functions
  .region("asia-northeast3")
  .firestore
  .document("meets/{meetId}/lightnings/{lightningId}")
  .onCreate(async (snap, context) => {
    const lightningId = context.params.lightningId;
    const data = snap.data() ?? {};

    if (data.isSeed === true) return;

    const authorUid =
      typeof data.authorUid === "string" ? data.authorUid : null;
    if (!authorUid) return;

    const createdAt =
      data.createdAt instanceof admin.firestore.Timestamp ?
        data.createdAt.toDate() :
        new Date();

    await grantOneTimeScore({
      uid: authorUid,
      eventId: `lightning_create_${lightningId}`,
      type: "lightning_create",
      points: SCORE.LIGHTNING_CREATE,
      refId: lightningId,
      dayKey: dayKeyFromDate(createdAt),
      weekKey: weekKeyFromDate(createdAt),
    });
  });

export const onLightningUpdatedGiveScore = functions
  .region("asia-northeast3")
  .firestore
  .document("meets/{meetId}/lightnings/{lightningId}")
  .onUpdate(async (change, context) => {
    const lightningId = context.params.lightningId;

    const beforeData = change.before.data() ?? {};
    const afterData = change.after.data() ?? {};

    if (afterData.isSeed === true) return;

    const beforeUids = asStringArray(beforeData.userUids);
    const afterUids = asStringArray(afterData.userUids);

    if (afterUids.length <= beforeUids.length) return;

    const authorUid =
      typeof afterData.authorUid === "string" ? afterData.authorUid : null;

    const addedUids = afterUids.filter((uid) => !beforeUids.includes(uid));

    if (addedUids.length === 0) return;

    const baseDate =
      afterData.updatedAt instanceof admin.firestore.Timestamp ?
        afterData.updatedAt.toDate() :
      afterData.createdAt instanceof admin.firestore.Timestamp ?
        afterData.createdAt.toDate() :
        new Date();

    for (const uid of addedUids) {
      if (authorUid && uid === authorUid) continue;

      await grantOneTimeScore({
        uid,
        eventId: `lightning_join_${lightningId}`,
        type: "lightning_join",
        points: SCORE.LIGHTNING_JOIN,
        refId: lightningId,
        dayKey: dayKeyFromDate(baseDate),
        weekKey: weekKeyFromDate(baseDate),
      });
    }
  });

export const onCommentCreatedGiveScore = functions
  .region("asia-northeast3")
  .firestore
  .document("feeds/{feedId}/comments/{commentId}")
  .onCreate(async (snap, context) => {
    const feedId = context.params.feedId;
    const commentId = context.params.commentId;
    const comment = snap.data() ?? {};

    const authorUid =
      typeof comment.authorUid === "string" ? comment.authorUid : null;
    if (!authorUid) return;

    const feedSnap = await db.collection("feeds").doc(feedId).get();
    if (!feedSnap.exists) return;

    const feed = feedSnap.data() ?? {};
    if (feed.isSeed === true) return;

    const feedAuthorUid =
      typeof feed.authorUid === "string" ? feed.authorUid : null;
    if (!feedAuthorUid) return;

    // 내 피드에 내가 댓글 달면 점수 없음
    if (feedAuthorUid === authorUid) return;

    const createdAt =
      comment.createdAt instanceof admin.firestore.Timestamp ?
        comment.createdAt.toDate() :
        new Date();

    await grantDailyLimitedScore({
      uid: authorUid,
      eventId: `comment_write_${commentId}`,
      type: "comment_write",
      points: SCORE.COMMENT_WRITE,
      refId: commentId,
      dayKey: dayKeyFromDate(createdAt),
      weekKey: weekKeyFromDate(createdAt),
      dailyField: "commentWriteCount",
      dailyMaxCount: 10,
    });

    // 댓글 받은 사람 점수: 피드당 최대 20회
    const ownerEventRef = db
      .collection("users")
      .doc(feedAuthorUid)
      .collection("scoreEvents")
      .doc(`comment_received_${commentId}`);

    await db.runTransaction(async (tx) => {
      const [ownerEventSnap, latestFeedSnap] = await Promise.all([
        tx.get(ownerEventRef),
        tx.get(db.collection("feeds").doc(feedId)),
      ]);

      if (ownerEventSnap.exists) return;
      if (!latestFeedSnap.exists) return;

      const latestFeed = latestFeedSnap.data() ?? {};
      const currentCount =
        typeof latestFeed.scoreCommentPointCount === "number" ?
          latestFeed.scoreCommentPointCount :
          0;

      if (currentCount >= 20) return;

      tx.set(ownerEventRef, {
        id: `comment_received_${commentId}`,
        type: "comment_received",
        points: SCORE.COMMENT_RECEIVED,
        refId: feedId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(
        db.collection("users").doc(feedAuthorUid),
        {
          score: {
            total: admin.firestore.FieldValue.increment(SCORE.COMMENT_RECEIVED),
            weekly: admin.firestore.FieldValue.increment(SCORE.COMMENT_RECEIVED),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );

      tx.update(db.collection("feeds").doc(feedId), {
        scoreCommentPointCount: admin.firestore.FieldValue.increment(1),
      });
    });
  });

export const onLikeCreatedGiveScore = functions
  .region("asia-northeast3")
  .firestore
  .document("feeds/{feedId}/likes/{uid}")
  .onCreate(async (snap, context) => {
    const feedId = context.params.feedId;
    const actorUid = context.params.uid;

    const feedRef = db.collection("feeds").doc(feedId);
    const feedSnap = await feedRef.get();
    if (!feedSnap.exists) return;

    const feed = feedSnap.data() ?? {};
    if (feed.isSeed === true) return;

    const targetUid =
      typeof feed.authorUid === "string" ? feed.authorUid : null;
    if (!targetUid) return;

    // 내 피드에 내가 좋아요 = 점수 없음
    if (targetUid === actorUid) return;

    const eventRef = db
      .collection("users")
      .doc(targetUid)
      .collection("scoreEvents")
      .doc(`like_received_${feedId}_${actorUid}`);

    await db.runTransaction(async (tx) => {
      const [eventSnap, latestFeedSnap] = await Promise.all([
        tx.get(eventRef),
        tx.get(feedRef),
      ]);

      if (eventSnap.exists) return;
      if (!latestFeedSnap.exists) return;

      const latestFeed = latestFeedSnap.data() ?? {};
      const currentCount =
        typeof latestFeed.scoreLikePointCount === "number" ?
          latestFeed.scoreLikePointCount :
          0;

      if (currentCount >= 20) return;

      tx.set(eventRef, {
        id: `like_received_${feedId}_${actorUid}`,
        type: "like_received",
        points: SCORE.LIKE_RECEIVED,
        refId: feedId,
        actorUid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(
        db.collection("users").doc(targetUid),
        {
          score: {
            total: admin.firestore.FieldValue.increment(SCORE.LIKE_RECEIVED),
            weekly: admin.firestore.FieldValue.increment(SCORE.LIKE_RECEIVED),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );

      tx.update(feedRef, {
        scoreLikePointCount: admin.firestore.FieldValue.increment(1),
      });
    });
  });

export const resetWeeklyScores = functions
  .region("asia-northeast3")
  .pubsub
  .schedule("5 0 * * 1")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const pageSize = 300;

    while (true) {
      const snap = await db
        .collection("users")
        .where("score.weekly", ">", 0)
        .limit(pageSize)
        .get();

      if (snap.empty) break;

      const batch = db.batch();
      for (const doc of snap.docs) {
        batch.set(doc.ref, {
          score: {
            weekly: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        }, {merge: true});
      }
      await batch.commit();

      if (snap.size < pageSize) break;
    }

    return null;
  });

export const seedUserScores = functions
  .region("asia-northeast3")
  .https
  .onCall(async (_, context) => {
    // 🔥 관리자만 실행 (선택)
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
    }

    try {
      const snap = await db
        .collection("users")
        .where("profileCompleted", "==", true)
        .get();

      if (snap.empty) {
        return {ok: true, count: 0};
      }

      let count = 0;

      for (const doc of snap.docs) {
        // 랜덤 점수 생성
        const weekly = Math.floor(Math.random() * 120); // 0~120
        const total = weekly + Math.floor(Math.random() * 2000);

        await doc.ref.update({
          score: {
            weekly,
            total,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        });

        count++;
      }

      return {
        ok: true,
        count,
      };
    } catch (e) {
      throw new functions.https.HttpsError(
        "internal",
        "점수 시드 실패",
      );
    }
  });
