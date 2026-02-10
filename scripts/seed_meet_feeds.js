const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}
function pickOne(arr) {
  return arr[randInt(0, arr.length - 1)];
}
function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = randInt(0, i);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const SUBTYPE_POOL = [
  "헬스","클라이밍","볼링","테니스","스쿼시","배드민턴","런닝","사이클","풋살/축구","수영",
  "다이어트","골프","필라테스","요가","탁구","당구","복싱","주짓수","보드","기타",
];

const MAIN_TYPES = ["오운완", "식단", "질문", "후기"];

const CONTENTS = {
  오운완: [
    "오운완! 오늘 루틴 완료 ✅",
    "퇴근하고 운동 다녀왔어요 💪",
    "오늘은 유산소+코어로 마무리!",
    "힘들어도 꾸준히…",
    "운친 덕분에 운동 루틴 유지 중",
  ],
  식단: [
    "아침: 오트밀 + 바나나 🍌",
    "점심: 닭가슴살 샐러드 🥗",
    "저녁: 두부 + 계란 + 야채볶음",
    "간식: 그릭요거트 + 견과류",
    "오늘은 치팅데이… 내일부터 다시!",
  ],
  질문: [
    "운동 초보 루틴 추천 부탁해요!",
    "유산소 vs 근력, 뭐부터 하는 게 좋아요?",
    "식단 어떻게 맞추는 게 좋을까요?",
    "러닝화 추천 부탁해요(발볼 넓음)",
    "운동할 때 단백질 섭취 타이밍 궁금해요",
  ],
  후기: [
    "모임 후기! 분위기 좋아서 다음에 또 하고 싶어요 🙌",
    "오늘 모임 덕분에 운동 제대로 했습니다",
    "처음 참여했는데 생각보다 재밌었어요",
    "다음 모임은 더 많은 분들이 오면 좋겠네요!",
    "운동 끝나고 너무 개운합니다",
  ],
};

// Storage 업로드 없이도 사진 있는 피드처럼 보이게
function picsum(seed, w = 1000, h = 1000) {
  return `https://picsum.photos/seed/${seed}/${w}/${h}`;
}

// PollModel: { question, options: [{ id, text, voterUids: [] }] }
function makePoll(allVoterUids, authorUid) {
  const question = pickOne([
    "다음 모임은 뭐 할까요?",
    "운동 끝나고 뭐 먹을까요?",
    "주말 모임 시간대 언제가 좋아요?",
  ]);

  const optionSets = [
    ["러닝", "헬스", "스트레칭"],
    ["샐러드", "단백질", "치팅"],
    ["아침", "오후", "저녁"],
  ];

  const optionsText = pickOne(optionSets);

  const options = optionsText.map((text, index) => ({
    id: `option_${index}`,          // ✅ 필수
    text,
    voterUids: [],
  }));

  // 랜덤 투표자 0~4명 (author 제외)
  const voters = shuffle(allVoterUids.filter((u) => u !== authorUid)).slice(0, randInt(0, 4));
  for (const v of voters) {
    const idx = randInt(0, options.length - 1);
    options[idx].voterUids.push(v);
  }

  return { question, options };
}

function buildFeedDoc({
  feedId,
  meetId,
  authorUid,
  meetPlace,
  meetMemberUids,
  createdAt,
}) {
  // mainType 분포를 모임 피드답게 조정(후기/오운완 비중 ↑)
  const mainType = pickOne([
    "오운완","오운완","오운완",
    "후기","후기",
    "식단",
    "질문",
  ]);

  // subType 규칙: 식단이면 null, 그 외는 카테고리 하나
  const subType = mainType === "식단" ? null : pickOne(SUBTYPE_POOL);

  // 좋아요/댓글 랜덤
  const likeUids = shuffle(meetMemberUids.filter((u) => u !== authorUid)).slice(0, randInt(0, 5));
  const commentCount = randInt(0, 12);

  const base = {
    id: feedId,
    authorUid,
    meetId,                 // ✅ 핵심
    mainType,
    subType,
    contents: pickOne(CONTENTS[mainType]) ?? null,

    place: null,
    imageUrls: null,
    poll: null,

    likeUids,
    commentCount,

    createdAt,
    updatedAt: createdAt,
  };

  // ✅ 규칙 반영
  if (mainType === "후기") {
    base.place = meetPlace ?? null; // 모임 장소 재사용 (자연스러움)

    // 후기: 사진 확률 높게
    const withImage = Math.random() < 0.65;
    if (withImage) {
      const count = randInt(1, 3);
      base.imageUrls = Array.from({ length: count }).map((_, i) =>
        picsum(`meetfeed_${meetId}_${feedId}_${i}`)
      );
    } else {
      base.imageUrls = null;
    }
    base.poll = null;
    return base;
  }

  if (mainType === "질문") {
    base.poll = makePoll(meetMemberUids, authorUid);
    base.place = null;
    base.imageUrls = null;
    return base;
  }

  if (mainType === "오운완") {
    base.place = null;
    base.poll = null;

    // 오운완: 사진도 종종
    const withImage = Math.random() < 0.45;
    if (withImage) {
      const count = randInt(1, 2);
      base.imageUrls = Array.from({ length: count }).map((_, i) =>
        picsum(`meetfeed_${meetId}_${feedId}_${i}`)
      );
    } else {
      base.imageUrls = null;
    }
    return base;
  }

  // 식단: subType 없음 + 사진 종종(식단샷)
  if (mainType === "식단") {
    base.place = null;
    base.poll = null;

    const withImage = Math.random() < 0.5;
    if (withImage) {
      base.imageUrls = [picsum(`meal_${meetId}_${feedId}_0`, 1000, 800)];
    } else {
      base.imageUrls = null;
    }
    return base;
  }

  return base;
}

async function main() {
  // ✅ 모임 가져오기 (원하면 limit 조절)
  const meetsSnap = await db.collection("meets").orderBy("createdAt", "desc").limit(30).get();
  if (meetsSnap.empty) {
    console.log("❌ meets가 없습니다. seed_meets 먼저 실행하세요.");
    return;
  }

  // 전체 생성 개수를 컨트롤하고 싶으면 여기서 조절
  const minFeedsPerMeet = 1;
  const maxFeedsPerMeet = 4;

  let totalCreated = 0;

  for (const meetDoc of meetsSnap.docs) {
    const meet = meetDoc.data();
    const meetId = (meet["id"] ?? meetDoc.id).toString();

    const memberUids = Array.isArray(meet["memberUids"])
      ? meet["memberUids"].map((x) => x.toString())
      : [];

    // 멤버가 없으면 authorUid만이라도 넣어 안전 처리
    const authorUid = (meet["authorUid"] ?? "").toString();
    const safeMembers = memberUids.length > 0 ? memberUids : (authorUid ? [authorUid] : []);

    // place 구조: {title,address,lat,lng} (너 meets 구조 그대로 재사용)
    const place = meet["place"] ?? null;

    const feedCount = randInt(minFeedsPerMeet, maxFeedsPerMeet);

    for (let i = 0; i < feedCount; i++) {
      const feedRef = db.collection("feeds").doc();
      const feedId = feedRef.id;

      // 작성자: 해당 모임 멤버 중 랜덤
      const writerUid = pickOne(safeMembers);

      // createdAt 분산: 최근 14일 내
      const daysAgo = randInt(0, 13);
      const minutesAgo = randInt(0, 12 * 60);
      const created = new Date(Date.now() - (daysAgo * 24 * 60 + minutesAgo) * 60 * 1000);
      const createdAt = admin.firestore.Timestamp.fromDate(created);

      const data = buildFeedDoc({
        feedId,
        meetId,
        authorUid: writerUid,
        meetPlace: place,
        meetMemberUids: safeMembers,
        createdAt,
      });

      await feedRef.set(data);
      totalCreated++;

      console.log(`+ feed for meet=${meetId} [${data.mainType}] id=${feedId}`);
    }
  }

  console.log(`🎉 DONE: created ${totalCreated} meet-feeds`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
