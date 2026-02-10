/**
 * admin_areas 시드 업로드 스크립트
 *
 * 실행:
 * 1) scripts 폴더에 아래 2개 파일을 넣어줘
 *    - serviceAccountKey.json
 *    - admin_areas_seed.json
 * 2) npm i firebase-admin
 * 3) node seed_admin_areas.js
 */

const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const serviceAccount = require(path.join(__dirname, "..", "serviceAccountKey.json"));
const seed = require(path.join(__dirname, "admin_areas_seed.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const COLLECTION = "admin_areas";
const BATCH_SIZE = 450;

async function main() {
  console.log(`seed count = ${seed.length}`);

  let batch = db.batch();
  let batchCount = 0;
  let total = 0;

  for (let i = 0; i < seed.length; i++) {
    const item = seed[i];

    // 문서 ID는 code를 그대로 사용 (중복 방지)
    const ref = db.collection(COLLECTION).doc(item.code);

    batch.set(ref, item, { merge: true });

    batchCount++;
    total++;

    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      console.log(`+ committed ${total}/${seed.length}`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    console.log(`+ committed ${total}/${seed.length}`);
  }

  console.log("🎉 DONE");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });