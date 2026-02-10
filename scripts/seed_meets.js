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
function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = randInt(0, i);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/* =======================
 *  공통 풀
 * ======================= */

const CATEGORY_POOL = [
  "헬스","클라이밍","볼링","테니스","스쿼시","배드민턴","런닝","사이클","풋살/축구","수영",
  "다이어트","골프","필라테스","요가","탁구","당구","복싱","주짓수","보드","기타",
];

const LEVEL_POOL = ["입문", "초보", "중급", "고급", "상관없음"];

const TITLE_POOL = [
  "퇴근 후 러닝 같이해요",
  "주말 헬스 루틴 공유",
  "클라이밍 초보 환영",
  "한강 러닝 크루 모집",
  "풋살 한 판 뛰실 분",
  "다이어트 동기부여 모임",
  "아침 수영 같이 하실래요?",
  "요가로 스트레칭해요",
  "테니스 입문자 모임",
  "주말 배드민턴 번개",
];

const INTRO_POOL = [
  "혼자 운동하기 힘들어서 같이 하실 분 찾고 있어요!",
  "부담 없이 즐겁게 운동해요 🙌",
  "초보도 환영합니다 🙂",
  "운동 꾸준히 하실 분이면 좋아요",
  "분위기 좋은 모임으로 만들고 싶어요",
];

// ⚠️ FeedPlace.toJson() 구조가 다르면 여기만 수정
const PLACE_POOL = [
  { title: "한강공원 반포지구", address: "서울 서초구 반포동", lat: 37.5089, lng: 126.9956 },
  { title: "잠실종합운동장", address: "서울 송파구 올림픽로 25", lat: 37.5159, lng: 127.0728 },
  { title: "올림픽공원", address: "서울 송파구 올림픽로 424", lat: 37.5163, lng: 127.1218 },
  { title: "남산공원", address: "서울 중구 삼일대로 231", lat: 37.5512, lng: 126.9882 },
];

function makePlace() {
  const p = pickOne(PLACE_POOL);
  return { title: p.title, address: p.address, lat: p.lat, lng: p.lng };
}

function picsum(seed, w = 1000, h = 700) {
  return `https://picsum.photos/seed/${seed}/${w}/${h}`;
}

/* =======================
 *  테스트 유저 불러오기
 * ======================= */
async function listTestUsers() {
  const out = [];
  let nextPageToken;

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

/**
 * ✅ maxMembers를 넘지 않는 선에서 랜덤 참가자 구성
 * - authorUid는 무조건 포함
 * - targetCount: 1 ~ maxMembers 중 "적당한" 숫자
 */
function buildMemberUids({ allUids, authorUid, maxMembers }) {
  // 최소 1명(방장) ~ 최대 maxMembers
  // "적당하게" 보이도록: maxMembers의 30%~90% 사이로 랜덤 (상황 따라 조절)
  const minTarget = Math.max(1, Math.floor(maxMembers * 0.3));
  const maxTarget = Math.max(1, Math.floor(maxMembers * 0.9));
  const targetCount = randInt(minTarget, Math.min(maxTarget, maxMembers));

  // author 제외 후보
  const candidates = allUids.filter((u) => u !== authorUid);
  const shuffled = shuffle(candidates);

  const picked = shuffled.slice(0, Math.max(0, targetCount - 1)); // 방장 제외한 나머지
  return [authorUid, ...picked];
}

async function main() {
  const users = await listTestUsers();
  if (users.length === 0) {
    console.log("❌ 테스트 유저가 없습니다. seed_users 먼저 실행하세요.");
    return;
  }

  const allUids = users.map((u) => u.uid);

  const totalMeets = 12; // 원하는 개수로 조절
  console.log(`✅ creating meets = ${totalMeets}, users=${allUids.length}`);

  for (let i = 0; i < totalMeets; i++) {
    const author = pickOne(users);
    const meetRef = db.collection("meets").doc();
    const meetId = meetRef.id;

    // 모임 날짜: 앞으로 1~21일 사이
    const daysLater = randInt(1, 21);
    const hoursLater = randInt(6, 21);
    const dateTime = new Date();
    dateTime.setDate(dateTime.getDate() + daysLater);
    dateTime.setHours(hoursLater, 0, 0, 0);

    const maxMembers = randInt(4, 20);

    // ✅ 참가자 랜덤 채우기 (maxMembers 넘지 않음)
    const memberUids = buildMemberUids({
      allUids,
      authorUid: author.uid,
      maxMembers,
    });

    const currentMemberCount = memberUids.length;

    const withImage = Math.random() < 0.6;
    const imageUrls = withImage ? [picsum(`meet_${meetId}`)] : [];

    const data = {
      id: meetId,
      authorUid: author.uid,
      title: pickOne(TITLE_POOL),
      intro: pickOne(INTRO_POOL),
      category: pickOne(CATEGORY_POOL),
      level: pickOne(LEVEL_POOL),
      dateTime: admin.firestore.Timestamp.fromDate(dateTime),
      maxMembers: maxMembers,
      isPrivate: Math.random() < 0.2,
      needApproval: Math.random() < 0.3,
      place: makePlace(),
      imageUrls: imageUrls,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),

      // ✅ 너가 쓰는 참가자 필드
      currentMemberCount: currentMemberCount,
      memberUids: memberUids,
      status: "open",
    };

    await meetRef.set(data);
    console.log(`+ meet ${i + 1}/${totalMeets} id=${meetId} members=${currentMemberCount}/${maxMembers}`);
  }

  console.log("🎉 DONE: meets seeded with random members");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
