// scripts/seed_oow_feeds_7weeks.js
const admin = require("firebase-admin");
const path = require("path");

// ✅ 서비스 계정 키 경로 (네 환경에 맞게 수정)
const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ---------- utils ----------
function startOfWeekMonday(date) {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = d.getDay(); // 0=Sun..6=Sat
  const diff = (weekday + 6) % 7; // Monday=0
  d.setDate(d.getDate() - diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pickOne(arr) {
  return arr[randInt(0, arr.length - 1)];
}

function randomTimeInDay(base) {
  const d = new Date(base);
  d.setHours(randInt(6, 23), randInt(0, 59), randInt(0, 59), 0);
  return d;
}

function pad2(n) {
  return n.toString().padStart(2, "0");
}

function dateKey(d) {
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}`; // YYYYMMDD
}

/**
 * ✅ 주(weekStart) 안에서 "운동한 날짜"를 n개 뽑는다 (중복 없음)
 * 반환: Date[] (각각 00:00 기준)
 */
function pickUniqueDaysInWeek(weekStart, n) {
  const max = 7;
  const target = Math.max(0, Math.min(n, max));

  // 0..6 중에서 중복 없이 target개
  const pool = [0, 1, 2, 3, 4, 5, 6];
  for (let i = pool.length - 1; i > 0; i--) {
    const j = randInt(0, i);
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }

  return pool.slice(0, target).map((off) => {
    const d = addDays(weekStart, off);
    d.setHours(0, 0, 0, 0);
    return d;
  });
}

// ---------- seed config ----------
const WEEKS = 7;

// ✅ 여기서 의미를 바꿈: "주당 피드 개수"가 아니라 "주당 운동한 날짜 수"
const MIN_DAYS_PER_WEEK = 3;
const MAX_DAYS_PER_WEEK = 5;

// ✅ 너가 가진 유저 uid들로 바꿔 넣기
const USER_UIDS = [
  "8ehwMFaqGzfR7JXJW7UJ1Q6fMwq1",
  "GlKiQDGzkjTslwTKcKuxx0R7Rm62",
];

const SUB_TYPES = [
  "헬스",
  "러닝",
  "클라이밍",
  "볼링",
  "배드민턴",
  "요가",
  "필라테스",
  "수영",
  "자전거",
];

const CONTENTS_POOL = [
  "오운완! 오늘도 해냈다 💪",
  "짧게라도 운동해서 뿌듯!",
  "하체 불태웠다…🔥",
  "상체 펌핑 완료 😎",
  "유산소로 땀 쫙!",
  "스트레칭까지 마무리",
  "컨디션 안 좋았는데 그래도 했다",
  "운동 후 단백질 필수 🥛",
  "오늘은 가볍게 회복 운동",
  "목표 채우는 중 ✅",
];

// ✅ batch
const BATCH_LIMIT = 450;

async function commitBatchIfNeeded(ctx) {
  if (ctx.batchCount >= BATCH_LIMIT) {
    await ctx.batch.commit();
    ctx.batch = db.batch();
    ctx.batchCount = 0;
    console.log(`committed... created=${ctx.created}`);
  }
}

async function run() {
  if (!USER_UIDS.length) {
    throw new Error("USER_UIDS가 비어있어. scripts/seed_oow_feeds_7weeks.js에 uid 넣어줘!");
  }

  const now = new Date();
  const thisWeekStart = startOfWeekMonday(now);

  console.log("Seeding OOW feeds (1 user / 1 day = max 1 feed)...");
  console.log(`weeks=${WEEKS}, daysPerWeek=${MIN_DAYS_PER_WEEK}~${MAX_DAYS_PER_WEEK}`);
  console.log(`users=${USER_UIDS.length}`);

  const ctx = {
    batch: db.batch(),
    batchCount: 0,
    created: 0,
  };

  // ✅ 중복 방지: "userUid + dayKey"를 기록해서 하루 1개만 만들기
  const usedUserDay = new Set();

  // ✅ 로그 계획 (주별/유저별 운동한 날짜 수)
  const plan = [];

  for (let w = 0; w < WEEKS; w++) {
    const weekStart = addDays(thisWeekStart, -7 * w);

    // 유저별로 "운동한 날짜"를 랜덤으로 뽑아준다.
    const perUserDays = [];

    for (const authorUid of USER_UIDS) {
      const daysThisWeek = randInt(MIN_DAYS_PER_WEEK, MAX_DAYS_PER_WEEK);
      const pickedDays = pickUniqueDaysInWeek(weekStart, daysThisWeek);

      perUserDays.push({
        uid: authorUid,
        weekStart: weekStart.toISOString().slice(0, 10),
        days: pickedDays.map((d) => d.toISOString().slice(0, 10)),
      });

      for (const day of pickedDays) {
        const dKey = dateKey(day);
        const key = `${authorUid}_${dKey}`;

        // ✅ 혹시라도 겹치면 스킵(원칙상 안겹치지만 안전)
        if (usedUserDay.has(key)) continue;
        usedUserDay.add(key);

        const createdAt = randomTimeInDay(day);
        const subType = pickOne(SUB_TYPES);
        const contents = pickOne(CONTENTS_POOL);

        const ref = db.collection("feeds").doc();
        const feedId = ref.id;

        // ✅ 너 feeds 스키마에 맞춰 최소 필드만 안전하게 채움
        ctx.batch.set(
          ref,
          {
            id: feedId,
            authorUid,
            mainType: "오운완",
            subType,
            contents,
            imageUrls: [],
            meetId: null, // 일반 피드
            likeCount: 0,
            likeUids: [],
            commentCount: 0,
            createdAt: admin.firestore.Timestamp.fromDate(createdAt),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        ctx.batchCount += 1;
        ctx.created += 1;

        await commitBatchIfNeeded(ctx);
      }
    }

    plan.push(...perUserDays);
  }

  if (ctx.batchCount > 0) {
    await ctx.batch.commit();
  }

  console.log("✅ Done!");
  console.log(`Total created: ${ctx.created}`);
  console.log("Plan (per user):", plan);


}

run()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ seed failed:", e);
    process.exit(1);
  });