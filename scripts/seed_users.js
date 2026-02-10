const admin = require("firebase-admin");
const path = require("path");

// 🔥 서비스 계정 키 경로
const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db = admin.firestore();

function pad(n) {
  return String(n).padStart(2, "0");
}

// 테스트용 카테고리 풀
const CATEGORY_POOL = [
 '헬스',
   '클라이밍',
   '볼링',
   '테니스',
   '스쿼시',
   '배드민턴',
   '런닝',
   '사이클',
   '풋살/축구',
   '수영',
   '다이어트',
   '골프',
   '필라테스',
   '요가',
   '탁구',
   '당구',
   '복싱',
   '주짓수',
   '보드',
   '기타',
];
const NICKNAME_POOL = [
  '땀나는하루',
  '운동중독자',
  '러닝러버',
  '헬스하는민수',
  '요가하는수진',
  '클라임덕후',
  '운동이취미',
  '주말운동러',
  '근손실싫어',
  '오늘도운동',
];
const DESCRIPTION_POOL = [
  '퇴근 후 운동으로 하루를 마무리해요 💪',
  '땀 흘리는 게 제일 스트레스 해소예요',
  '혼자보다 같이 운동하는 걸 좋아해요',
  '주 3~4회 꾸준히 운동 중입니다',
  '운동은 못해도 즐겁게 하고 싶어요',
  '러닝이랑 헬스 병행하고 있어요',
  '요즘은 체력 키우는 게 목표예요',
  '다이어트 겸 운동 친구 찾고 있어요',
  '운동으로 일상 루틴 만들고 싶어요',
  '무리하지 않고 오래 운동하고 싶어요',
];

function pickCategories() {
  const shuffled = [...CATEGORY_POOL].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, Math.floor(Math.random() * 3) + 1);
}
function pickNickname(i) {
  // 혹시 중복 피하고 싶으면 index 섞어서 사용
  return NICKNAME_POOL[i - 1] ?? `운동유저${i}`;
}
function pickDescription(i) {
  return DESCRIPTION_POOL[i - 1] ?? '운동을 즐기는 운친입니다';
}

function getProfilePhotoUrl(seed) {
  return `https://picsum.photos/seed/${seed}/500/500`;
}

async function main() {
  const count = 10;
  const now = admin.firestore.Timestamp.now();

  const createdUsers = [];

  for (let i = 1; i <= count; i++) {
    const email = `test${pad(i)}@unchin.dev`;
    const password = "Test1234!";
    const nickname = pickNickname(i);


    try {
      // 1️⃣ Firebase Auth 생성
      const user = await auth.createUser({
        email,
        password,
        displayName: nickname,
      });

      const uid = user.uid;

      // 2️⃣ Firestore users/{uid} 생성 (UserModel 100% 반영)
      await db.collection("users").doc(uid).set({
        uid: uid,
        email: email,
        nickname: nickname,
        photoUrl: getProfilePhotoUrl(`unchin_user_${i}`),
        description: pickDescription(i),
        category: pickCategories(),    // 랜덤 운동 카테고리
        profileCompleted: true,        // 테스트용은 true
        createdAt: now,
        updatedAt: now,
      });

      createdUsers.push({
        email,
        password,
        nickname,
        uid,
      });

      console.log(`✅ created: ${email}`);
    } catch (e) {
      console.error(`❌ failed: ${email}`, e.message);
    }
  }

  console.log("\n🎉 SEED COMPLETE");
  console.table(createdUsers);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
