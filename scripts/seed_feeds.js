const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const auth = admin.auth();

function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}
function pickOne(arr) {
  return arr[randInt(0, arr.length - 1)];
}
function pickSome(arr, n) {
  const copy = [...arr];
  const out = [];
  for (let i = 0; i < n && copy.length; i++) {
    out.push(copy.splice(randInt(0, copy.length - 1), 1)[0]);
  }
  return out;
}

const SUBTYPE_POOL = [
  "헬스",
  "클라이밍",
  "볼링",
  "테니스",
  "스쿼시",
  "배드민턴",
  "런닝",
  "사이클",
  "풋살/축구",
  "수영",
  "다이어트",
  "골프",
  "필라테스",
  "요가",
  "탁구",
  "당구",
  "복싱",
  "주짓수",
  "보드",
  "기타",
];

const MAIN_TYPES = ["오운완", "식단", "질문", "후기"];

const CONTENTS = {
  오운완: [
    "오운완! 오늘은 하체 제대로 조졌습니다 💪",
    "러닝 5km 완료 ✅ 꾸준함이 답!",
    "클라이밍 다녀왔는데 손가락이… 😭",
    "수영 30분 하고 개운하게 마무리!",
    "오늘은 가볍게 스트레칭 + 코어 운동!",
  ],
  식단: [
    "아침: 오트밀 + 바나나 🍌",
    "점심: 닭가슴살 샐러드 🥗",
    "저녁: 두부 + 계란 + 야채볶음",
    "간식: 그릭요거트 + 견과류",
    "오늘은 치팅데이… 내일 다시 화이팅",
  ],
  질문: [
    "운동 초보 루틴 어떻게 시작하는 게 좋을까요?",
    "다이어트 중인데 유산소랑 근력 비중이 고민이에요",
    "러닝화 추천 부탁해요! 발볼 넓은 편",
    "헬스 PT 없이도 괜찮을까요?",
    "운동할 때 식단은 어떻게 맞추는 게 좋아요?",
  ],
  후기: [
    "한강 러닝 후기! 바람이 좋아서 달리기 딱이었어요 🏃",
    "헬스장 바꿨는데 기구가 많아서 만족!",
    "클라이밍 처음 갔는데 너무 재밌었어요",
    "필라테스 후기: 자세 교정에 진짜 도움됨",
    "풋살 뛰고 왔는데 팀플레이가 역시 재밌네요",
  ],
};

// ✅ FeedPlace 스키마는 너 프로젝트에 맞춰야 함
// 일단 예시: {title, address, lat, lng}
const PLACE_POOL = [
  { title: "한강공원 반포지구", address: "서울 서초구 반포동", lat: 37.5089, lng: 126.9956 },
  { title: "잠실종합운동장", address: "서울 송파구 올림픽로 25", lat: 37.5159, lng: 127.0728 },
  { title: "올림픽공원", address: "서울 송파구 올림픽로 424", lat: 37.5163, lng: 127.1218 },
  { title: "남산공원", address: "서울 중구 삼일대로 231", lat: 37.5512, lng: 126.9882 },
];

function makeFeedPlace() {
  const p = pickOne(PLACE_POOL);
  return {
    title: p.title,
    address: p.address,
    lat: p.lat,
    lng: p.lng,
  };
}

// Storage 업로드 없이도 이미지 피드처럼 보이게 (테스트용)
function picsum(seed, w = 1000, h = 1000) {
  return `https://picsum.photos/seed/${seed}/${w}/${h}`;
}

// ✅ PollModel 형태(가정): { question, options: [{ text, voterUids: [] }] }
function makePoll(allUids, authorUid) {
  const question = pickOne([
    "오늘 운동 뭐가 좋을까요?",
    "유산소 vs 근력, 뭐부터 할까요?",
    "주말 운동 시간대 추천해주세요",
  ]);

  const optionSets = [
    ["러닝", "헬스", "스트레칭"],
    ["상체", "하체", "유산소"],
    ["아침", "저녁", "상관없음"],
  ];

  const optionsText = pickOne(optionSets);

  const options = optionsText.map((text, index) => ({
    id: `option_${index}`,   // ✅ 추가됨
    text: text,
    voterUids: [],
  }));

  // 랜덤 투표자 0~4명
  const voters = pickSome(
    allUids.filter((u) => u !== authorUid),
    randInt(0, 4),
  );

  for (const v of voters) {
    const idx = randInt(0, options.length - 1);
    options[idx].voterUids.push(v);
  }

  return {
    question,
    options,
  };
}


async function listTestUsers() {
  const out = [];
  let nextPageToken = undefined;

  while (true) {
    const res = await auth.listUsers(1000, nextPageToken);
    for (const u of res.users) {
      if (u.email && u.email.endsWith("@unchin.dev")) {
        out.push({ uid: u.uid });
      }
    }
    nextPageToken = res.pageToken;
    if (!nextPageToken) break;
  }
  return out;
}

function buildFeedDoc({ feedId, authorUid, mainType, allUids, createdAt }) {
  const likeUids = pickSome(allUids.filter((u) => u !== authorUid), randInt(0, 6));
  const commentCount = randInt(0, 15);

  // ✅ subType 규칙: 식단이면 null, 그 외는 운동 카테고리 하나
  const subType = mainType === "식단" ? null : pickOne(SUBTYPE_POOL);

  const base = {
    id: feedId,
    authorUid,
    mainType,
    subType: subType, // null 가능
    contents: pickOne(CONTENTS[mainType]) ?? null,

    // 조건부 필드 (기본 null)
    place: null,
    imageUrls: null,
    poll: null,

    likeUids,
    commentCount,

    // pagination/정렬 안정용
    createdAt,
    updatedAt: createdAt,
    meetId: null,
  };

  // ✅ 후기: place 존재, poll 없음
  if (mainType === "후기") {
    base.place = makeFeedPlace();

    // 후기: 가끔 이미지도 넣기 (없으면 null)
    const withImage = Math.random() < 0.6;
    if (withImage) {
      const count = randInt(1, 3);
      base.imageUrls = Array.from({ length: count }).map((_, i) =>
        picsum(`feed_${authorUid}_${feedId}_${i}`)
      );
    } else {
      base.imageUrls = null;
    }

    base.poll = null;
    return base;
  }

  // ✅ 질문: poll 존재, place 없음
  if (mainType === "질문") {
    base.poll = makePoll(allUids, authorUid);
    base.place = null;
    base.imageUrls = null; // 질문은 보통 이미지 없이
    return base;
  }

  // ✅ 오운완: place/poll 없음, 이미지 가끔
  if (mainType === "오운완") {
    base.place = null;
    base.poll = null;

    const withImage = Math.random() < 0.65;
    if (withImage) {
      const count = randInt(1, 2);
      base.imageUrls = Array.from({ length: count }).map((_, i) =>
        picsum(`feed_${authorUid}_${feedId}_${i}`)
      );
    } else {
      base.imageUrls = null;
    }
    return base;
  }

  // ✅ 식단: subType 없음 + place/poll 없음, 이미지 가끔
  if (mainType === "식단") {
    base.place = null;
    base.poll = null;

    const withImage = Math.random() < 0.65; // 식단 사진 느낌
    if (withImage) {
      base.imageUrls = [picsum(`meal_${authorUid}_${feedId}_0`, 1000, 800)];
    } else {
      base.imageUrls = null;
    }
    return base;
  }

  return base;
}

async function main() {
  const users = await listTestUsers();
  if (users.length === 0) {
    console.log("❌ @unchin.dev 테스트 유저가 없어요. seed_users 먼저 실행해줘.");
    return;
  }

  const allUids = users.map((u) => u.uid);
  const totalFeeds = 15;

  // ✅ 타입 분포(15개): 오운완 6, 식단 3, 질문 3, 후기 3
  // 페이지네이션 테스트용으로 적당히 다양하게
  const types = [
    ...Array.from({ length: 6 }, () => "오운완"),
    ...Array.from({ length: 3 }, () => "식단"),
    ...Array.from({ length: 3 }, () => "질문"),
    ...Array.from({ length: 3 }, () => "후기"),
  ];

  // 섞기
  types.sort(() => 0.5 - Math.random());

  console.log(`✅ users=${users.length}, creating feeds=${totalFeeds}`);

  for (let i = 0; i < totalFeeds; i++) {
    const authorUid = pickOne(allUids);
    const mainType = types[i];

    const feedRef = db.collection("feeds").doc();
    const feedId = feedRef.id;

    // 최근 10일 내 분산 (pagination/정렬 테스트)
    const daysAgo = randInt(0, 9);
    const minutesAgo = randInt(0, 12 * 60);
    const created = new Date(Date.now() - (daysAgo * 24 * 60 + minutesAgo) * 60 * 1000);
    const createdAt = admin.firestore.Timestamp.fromDate(created);

    const data = buildFeedDoc({
      feedId,
      authorUid,
      mainType,
      allUids,
      createdAt,
    });

    await feedRef.set(data);
    console.log(`+ feed ${i + 1}/${totalFeeds} [${mainType}] author=${authorUid} id=${feedId}`);
  }

  console.log("🎉 DONE: 15 feeds seeded");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
