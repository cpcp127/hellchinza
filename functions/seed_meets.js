const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

function shuffle(arr) {
  const copied = [...arr];
  for (let i = copied.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copied[i], copied[j]] = [copied[j], copied[i]];
  }
  return copied;
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

async function seedMeets() {
  const usersSnap = await db.collection("users").get();

  if (usersSnap.empty) {
    throw new Error("users 컬렉션에 유저가 없습니다.");
  }

  const users = usersSnap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      uid: typeof d.uid === "string" && d.uid.trim() ? d.uid : doc.id,
      nickname:
        typeof d.nickname === "string" && d.nickname.trim()
          ? d.nickname.trim()
          : "회원",
    };
  });

  if (users.length < 3) {
    throw new Error("최소 3명 이상의 users 데이터가 필요합니다.");
  }

  const regionPool = [
    { code: "1150010100", fullName: "서울특별시 강서구 염창동" },
    { code: "1150010900", fullName: "서울특별시 강서구 등촌동" },
    { code: "1147010100", fullName: "서울특별시 양천구 신정동" },
    { code: "1168010100", fullName: "서울특별시 강남구 역삼동" },
    { code: "1171010100", fullName: "서울특별시 송파구 잠실동" },
    { code: "1135010200", fullName: "서울특별시 노원구 상계동" },
  ];

  const templates = [
    {
      title: "강서 같이 헬스하실 분",
      intro: "평일 저녁에 같이 운동하고 친목도 쌓아요.",
      category: "헬스",
    },
    {
      title: "주말 한강 러닝 모임",
      intro: "가볍게 5km 정도 함께 뛰실 분 환영해요.",
      category: "러닝",
    },
    {
      title: "초보 클라이밍 같이 가요",
      intro: "처음 오시는 분도 편하게 즐길 수 있어요.",
      category: "클라이밍",
    },
    {
      title: "퇴근 후 볼링 한 게임",
      intro: "실력 상관 없이 재밌게 치실 분 구해요.",
      category: "볼링",
    },
    {
      title: "배드민턴 같이 치실 분",
      intro: "가볍게 꾸준히 운동할 멤버 모집해요.",
      category: "배드민턴",
    },
    {
      title: "아침 운동 습관 만들기",
      intro: "혼자 하면 미루게 돼서 같이 운동 루틴 만들어봐요.",
      category: "헬스",
    },
    {
      title: "러닝 크루 모집",
      intro: "천천히 뛰어도 괜찮아요. 꾸준히 하실 분!",
      category: "러닝",
    },
    {
      title: "실내 클라이밍 번개 모집",
      intro: "서로 응원하면서 재밌게 climbing 해요.",
      category: "클라이밍",
    },
    {
      title: "주말 볼링 멤버 구합니다",
      intro: "초보 환영! 같이 치면서 친해져요.",
      category: "볼링",
    },
    {
      title: "동네 배드민턴 정기 모임",
      intro: "주 1~2회 가볍게 운동할 분들 환영합니다.",
      category: "배드민턴",
    },
  ];

  const existingSeedSnap = await db
    .collection("meets")
    .where("isSeed", "==", true)
    .limit(1)
    .get();

  if (!existingSeedSnap.empty) {
    throw new Error("이미 isSeed=true 인 모임 데이터가 있습니다. 중복 생성을 막기 위해 중단합니다.");
  }

  const createdMeetIds = [];

  for (let i = 0; i < 10; i++) {
    const template = templates[i];
    const meetRef = db.collection("meets").doc();
    const meetId = meetRef.id;

    const author = users[i % users.length];
    const region = pickRandom(regionPool);

    const maxMembers = randomInt(6, 20);
    const participantCount = Math.min(
      randomInt(3, Math.min(6, users.length)),
      maxMembers,
    );

    const shuffledUsers = shuffle(users).filter((u) => u.uid !== author.uid);
    const participants = [author, ...shuffledUsers.slice(0, participantCount - 1)];

    const now = Date.now();
    const createdAt = admin.firestore.Timestamp.fromMillis(
      now - randomInt(0, 1000 * 60 * 60 * 24 * 14),
    );

    const batch = db.batch();

    batch.set(meetRef, {
      id: meetId,
      authorUid: author.uid,
      title: template.title,
      intro: template.intro,
      category: template.category,
      regions: [region],
      maxMembers,
      needApproval: Math.random() < 0.4,
      status: "open",
      imageUrls: [],
      chatRoomId: meetId,
      createdAt,
      updatedAt: createdAt,
      isSeed: true,
      seedVersion: 1,
    });

    for (const user of participants) {
      const memberRef = meetRef.collection("members").doc(user.uid);

      batch.set(memberRef, {
        uid: user.uid,
        role: user.uid === author.uid ? "host" : "member",
        status: "approved",
        joinedAt: createdAt,
        createdAt,
        updatedAt: createdAt,
      });
    }

    const roomRef = db.collection("chatRooms").doc(meetId);
    const firstMsgRef = roomRef.collection("messages").doc();

    const userUids = participants.map((u) => u.uid);
    const unreadCountMap = {};
    const activeAtMap = {};

    for (const uid of userUids) {
      unreadCountMap[uid] = 0;
      activeAtMap[uid] = createdAt;
    }

    batch.set(roomRef, {
      type: "group",
      meetId,
      title: template.title,
      allowMessages: true,
      userUids,
      visibleUids: userUids,
      unreadCountMap,
      activeAtMap,
      lastMessageAt: createdAt,
      lastMessageText: "모임 채팅이 생성되었어요 🎉",
      lastMessageType: "system",
      createdAt,
      updatedAt: createdAt,
      isSeed: true,
      seedVersion: 1,
    });

    batch.set(firstMsgRef, {
      id: firstMsgRef.id,
      type: "system",
      text: "모임 채팅이 생성되었어요 🎉",
      authorUid: "system",
      createdAt,
    });

    await batch.commit();

    createdMeetIds.push(meetId);
    console.log(`[${i + 1}/10] created meet: ${meetId} / ${template.title}`);
  }

  console.log("완료:", createdMeetIds.length, "개 생성");
  console.log(createdMeetIds);
}

seedMeets()
  .then(() => {
    console.log("seed_meets finished");
    process.exit(0);
  })
  .catch((err) => {
    console.error("seed_meets failed:", err);
    process.exit(1);
  });
