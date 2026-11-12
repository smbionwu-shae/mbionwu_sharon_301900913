// 03_bulk_and_index_demo.js
// Inserts 40,000 documents into exam_attempts in batches of 1,000 using
// insertMany, then runs the same selective query twice with
// explain("executionStats"):
//
//   BEFORE  — no index, hint({$natural:1}) forces a COLLSCAN.
//   AFTER   — a compound index on (student_id, exam_type) is created and
//             hinted.
//
// Prints: Stage BEFORE/AFTER, Docs BEFORE/AFTER, Time ms BEFORE/AFTER.
// dropIndex is wrapped in try/catch so the file is re-runnable.
//
// Numbers use Double() and Int32() to satisfy the $jsonSchema validator
// from 01_setup.js.
//
// Run with:  mongosh --file 03_bulk_and_index_demo.js
//            (after:  mongosh --file 01_setup.js)

db = db.getSiblingDB("ststephen");

var TOTAL = 40000;
var BATCH = 1000;

// ---------------------------------------------------------------------
// Clean slate: drop the compound index if it exists (wrapped in
// try/catch per the spec) and clear the collection.
// ---------------------------------------------------------------------
try { db.exam_attempts.dropIndex("idx_student_exam"); }
catch (e) { /* index not created yet: fine */ }

db.exam_attempts.deleteMany({});

// ---------------------------------------------------------------------
// Helper: build one valid exam_attempts document.
// ---------------------------------------------------------------------
function makeAttempt(n) {
  // 2-decimal score in [20.00, 100.00]; passed must match the oneOf branch.
  var score    = Math.round((20 + Math.random() * 80) * 100) / 100;
  var passed   = score >= 40;
  var examType = ["CA", "MIDSEM", "FINAL", "RESIT"][n % 4];
  return {
    _id:              ObjectId(),
    attempt_id:       Int32(n + 1),
    student_id:       Int32((n % 1020) + 1),
    course_code:      "BU" + ((n % 96) + 1).toString().padStart(3, "0"),
    exam_type:        examType,
    score:            Double(score),
    max_score:        Int32(100),
    attempted_at:     new Date(Date.now() - Math.floor(Math.random() * 86400000 * 365)),
    duration_minutes: Int32(30 + Math.floor(Math.random() * 90)),
    device:           "DESKTOP",
    passed:           passed
  };
}

// ---------------------------------------------------------------------
// 1. Bulk insert 40,000 documents in batches of 1,000.
// ---------------------------------------------------------------------
var t0 = Date.now();
for (var b = 0; b < TOTAL / BATCH; b++) {
  var batch = [];
  for (var i = 0; i < BATCH; i++) {
    batch.push(makeAttempt(b * BATCH + i));
  }
  db.exam_attempts.insertMany(batch, { ordered: false });
}
var insertMs = Date.now() - t0;

print("Inserted " + db.exam_attempts.countDocuments() + " docs in "
      + insertMs + " ms (batches of " + BATCH + ")");

// ---------------------------------------------------------------------
// 2. BEFORE — no index, hint({$natural:1}) forces a COLLSCAN.
// ---------------------------------------------------------------------
// Pick the target from real data so the query always returns rows.
var sample = db.exam_attempts.findOne({ student_id: Int32(500) }) || db.exam_attempts.findOne({});
var query = { student_id: sample.student_id, exam_type: sample.exam_type };
print("Query target: student_id=" + sample.student_id + ", exam_type=" + sample.exam_type);

var before = db.exam_attempts.find(query).hint({ $natural: 1 })
                                  .explain("executionStats");

var beforeStage = before.executionStats.executionStages.stage;
var beforeDocs  = before.executionStats.totalDocsExamined;
var beforeTime  = before.executionStats.executionTimeMillis;
var beforeCount = before.executionStats.nReturned;

print("Stage BEFORE: " + beforeStage);
print("Docs  BEFORE: " + beforeDocs   + " examined");
print("Time  BEFORE: " + beforeTime   + " ms");
print("Rows  BEFORE: " + beforeCount  + " returned");

// ---------------------------------------------------------------------
// 3. Create the compound index.
// ---------------------------------------------------------------------
db.exam_attempts.createIndex(
  { student_id: 1, exam_type: 1 },
  { name: "idx_student_exam" }
);
print("Created compound index idx_student_exam on (student_id, exam_type)");

// ---------------------------------------------------------------------
// 4. AFTER — same query, now using the compound index.
// ---------------------------------------------------------------------
var after = db.exam_attempts.find(query).hint("idx_student_exam")
                                 .explain("executionStats");

// When a hint is used, MongoDB wraps the stage inside a "FETCH" + "IXSCAN".
// Walk one level down to find IXSCAN if needed.
function findStage(plan) {
  if (!plan) return "(unknown)";
  if (plan.stage === "IXSCAN" || plan.stage === "COLLSCAN") return plan.stage;
  if (plan.inputStage)  return findStage(plan.inputStage);
  if (plan.inputStages) return findStage(plan.inputStages[0]);
  return plan.stage || "(unknown)";
}

var afterStage = findStage(after.executionStats.executionStages);
var afterDocs  = after.executionStats.totalDocsExamined;
var afterTime  = after.executionStats.executionTimeMillis;
var afterCount = after.executionStats.nReturned;

print("Stage AFTER: " + afterStage);
print("Docs  AFTER: " + afterDocs  + " examined");
print("Time  AFTER: " + afterTime  + " ms");
print("Rows  AFTER: " + afterCount + " returned");

// ---------------------------------------------------------------------
// 5. Summary table.
// ---------------------------------------------------------------------
print("\n================ SUMMARY ================");
print("Stage BEFORE: " + beforeStage
      + "   | Docs BEFORE: " + beforeDocs
      + "   | Time ms BEFORE: " + beforeTime);
print("Stage AFTER : " + afterStage
      + "   | Docs AFTER : " + afterDocs
      + "   | Time ms AFTER : " + afterTime);
print("=========================================");

// Optional: drop the index at the end so the file is re-runnable without
// the try/catch at the top firing.
try { db.exam_attempts.dropIndex("idx_student_exam"); }
catch (e) { print("dropIndex idx_student_exam (post): " + e); }

print("03_bulk_and_index_demo.js finished");
