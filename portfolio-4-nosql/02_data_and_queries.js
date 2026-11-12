// 02_data_and_queries.js
// Seeds course_catalogue with a handful of Nigerian course syllabi and
// exam_attempts with a small set of attempt logs, then runs three
// aggregation pipelines:
//   Q1  Pass rate per exam_type (group + count + avg).
//   Q2  Top-5 courses by number of attempts (group + sort + limit).
//   Q3  Average score per student, with a $match stage that filters
//       attempts to the FINAL exam type and a $lookup that enriches each
//       student with their course catalogue entry.
//
// Numbers are inserted with Int32() / Double() so they match the
// $jsonSchema validators declared in 01_setup.js.
//
// Run with:  mongosh --file 02_data_and_queries.js
//            (after:  mongosh --file 01_setup.js)

db = db.getSiblingDB("ststephen");

// =====================================================================
// 1. Seed course_catalogue (one document per faculty variant).
// =====================================================================
db.course_catalogue.deleteMany({});

db.course_catalogue.insertMany([
  {
    _id: ObjectId(),
    course_code:  "CSC301",
    faculty:      "SCI",
    title:        "Database Systems",
    credit_units: Int32(3),
    status:       "ACTIVE",
    academic_year: "2025/2026",
    lab_hours:     Int32(2),
    syllabus: {
      topics: [
        "Relational model and SQL",
        "Normalisation and functional dependencies",
        "Transactions and isolation levels",
        "Indexes and query optimisation"
      ],
      textbooks: [
        "Silberschatz, Korth, Sudarshan — Database System Concepts (7e)",
        "PostgreSQL 16 Documentation"
      ]
    }
  },
  {
    _id: ObjectId(),
    course_code:  "CIV101",
    faculty:      "ENG",
    title:        "Engineering Mechanics",
    credit_units: Int32(3),
    status:       "ACTIVE",
    academic_year: "2025/2026",
    design_project: true,
    syllabus: {
      topics: ["Statics", "Friction", "Virtual work", "Beam analysis"],
      textbooks: ["Hibbeler — Engineering Mechanics: Statics"]
    }
  },
  {
    _id: ObjectId(),
    course_code:  "MCO101",
    faculty:      "ART",
    title:        "Introduction to Mass Media",
    credit_units: Int32(3),
    status:       "ACTIVE",
    academic_year: "2025/2026",
    essay_required: true,
    syllabus: {
      topics: ["Print media", "Broadcast media", "Digital media ethics"],
      textbooks: ["Baran — Introduction to Mass Communication"]
    }
  },
  {
    _id: ObjectId(),
    course_code:  "BUS101",
    faculty:      "MGT",
    title:        "Principles of Management",
    credit_units: Int32(2),
    status:       "ACTIVE",
    academic_year: "2025/2026",
    syllabus: {
      topics: ["Planning", "Organising", "Leading", "Controlling"],
      textbooks: ["Robbins & Coulter — Management"]
    }
  }
]);

// =====================================================================
// 2. Seed exam_attempts (small set; 03_bulk_and_index_demo.js loads 40k).
// =====================================================================
db.exam_attempts.deleteMany({});

var attemptDocs = [];
var examTypes   = ["CA", "MIDSEM", "FINAL", "RESIT"];
var courseCodes = ["CSC301", "CIV101", "MCO101", "BUS101"];
var attemptSeq  = Int32(1);

for (var s = 1; s <= 20; s++) {                       // 20 students
  for (var c = 0; c < courseCodes.length; c++) {       // 4 courses
    for (var t = 0; t < examTypes.length; t++) {       // 4 exam types
      var score   = Double(20 + (Math.random() * 80)); // 20..100
      var passed  = score >= 40;
      var maxScore = Int32(100);
      attemptDocs.push({
        _id:              ObjectId(),
        attempt_id:       attemptSeq,
        student_id:       Int32(s),
        course_code:      courseCodes[c],
        exam_type:        examTypes[t],
        score:            score,
        max_score:        maxScore,
        attempted_at:     new Date(Date.now() - Math.floor(Math.random() * 86400000 * 30)),
        duration_minutes: Int32(30 + Math.floor(Math.random() * 90)),
        device:           "DESKTOP",
        passed:           passed
      });
      attemptSeq = Int32(attemptSeq + 1);
    }
  }
}
db.exam_attempts.insertMany(attemptDocs);

print("Seeded course_catalogue: " + db.course_catalogue.countDocuments() + " docs");
print("Seeded exam_attempts:    " + db.exam_attempts.countDocuments()   + " docs");

// =====================================================================
// Q1 — Pass rate per exam_type.
// =====================================================================
print("\n=== Q1 — Pass rate per exam_type ===");
var q1 = db.exam_attempts.aggregate([
  { $group: {
      _id: "$exam_type",
      attempts:   { $sum: 1 },
      passed:     { $sum: { $cond: ["$passed", 1, 0] } },
      avg_score:  { $avg: "$score" }
  }},
  { $project: {
      _id: 1,
      attempts: 1,
      passed:   1,
      pass_rate_pct: { $round: [{ $multiply: [100, { $divide: ["$passed", "$attempts"] }] }, 2] },
      avg_score:     { $round: ["$avg_score", 2] }
  }},
  { $sort: { _id: 1 } }
]);
printjson(q1.toArray());

// =====================================================================
// Q2 — Top-5 courses by number of attempts.
// =====================================================================
print("\n=== Q2 — Top-5 courses by number of attempts ===");
var q2 = db.exam_attempts.aggregate([
  { $group: {
      _id: "$course_code",
      attempts:  { $sum: 1 },
      avg_score: { $avg: "$score" },
      max_score: { $max: "$score" },
      min_score: { $min: "$score" }
  }},
  { $sort: { attempts: -1 } },
  { $limit: 5 },
  { $project: {
      course_code: "$_id",
      attempts: 1,
      avg_score: { $round: ["$avg_score", 2] },
      max_score: { $round: ["$max_score", 2] },
      min_score: { $round: ["$min_score", 2] },
      _id: 0
  }}
]);
printjson(q2.toArray());

// =====================================================================
// Q3 — Average FINAL score per student, enriched with the catalogue title
//      via $lookup.
// =====================================================================
print("\n=== Q3 — Average FINAL score per student (enriched with course title) ===");
var q3 = db.exam_attempts.aggregate([
  { $match: { exam_type: "FINAL" } },
  { $group: {
      _id: { student_id: "$student_id", course_code: "$course_code" },
      avg_score:    { $avg: "$score" },
      attempts:     { $sum: 1 }
  }},
  { $lookup: {
      from:         "course_catalogue",
      localField:   "_id.course_code",
      foreignField: "course_code",
      as:           "course"
  }},
  { $unwind: { path: "$course", preserveNullAndEmptyArrays: true } },
  { $project: {
      _id: 0,
      student_id:   "$_id.student_id",
      course_code:  "$_id.course_code",
      course_title: { $ifNull: ["$course.title", "(unknown)"] },
      faculty:      { $ifNull: ["$course.faculty", "(unknown)"] },
      attempts: 1,
      avg_score: { $round: ["$avg_score", 2] }
  }},
  { $sort: { student_id: 1, course_code: 1 } },
  { $limit: 20 }
]);
printjson(q3.toArray());

print("\n02_data_and_queries.js finished");

// ---------------------------------------------------------------------
// Validator check: two invalid documents that MUST be rejected.
// ---------------------------------------------------------------------
[
  { label: "score above max_score / wrong types", doc: { attempt_id: "x", student_id: "not-a-number" } },
  { label: "unknown extra field",                 doc: { surprise_field: 1 } }
].forEach(function (t) {
  try {
    db.exam_attempts.insertOne(t.doc);
    print("VALIDATOR FAIL: accepted invalid document (" + t.label + ")");
  } catch (e) {
    print("VALIDATOR PASS: rejected invalid document (" + t.label + ") code=" + e.code);
  }
});
