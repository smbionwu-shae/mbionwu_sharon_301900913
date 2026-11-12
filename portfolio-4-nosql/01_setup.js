// 01_setup.js
// Creates the ststephen MongoDB database with two collections that have
// $jsonSchema validators:
//   * course_catalogue  — flexible syllabus documents whose shape varies
//                          per faculty (modelled with oneOf).
//   * exam_attempts     — high-volume student activity log.
//
// Notes on the rules:
//   * db = db.getSiblingDB("ststephen");  (NOT `use ststephen;`)
//   * Numbers use Double() or Int32() constructors when inserted.
//   * Where a single value is fixed, we use `enum: [...]` with ONE value
//     instead of `const`.
//   * No if/then/else is used inside the schema — varying shapes are
//     modelled with oneOf.
//   * additionalProperties:false is used at the top level of each schema
//     AND every nested object; _id and every field are listed explicitly.
//
// Run with:  mongosh --file 01_setup.js
//            (or:  mongosh ststephen --file 01_setup.js)

db = db.getSiblingDB("ststephen");

// Drop the two demo collections so the file is re-runnable. The DB itself
// is NOT dropped (some other artefacts may live here).
try { db.course_catalogue.drop(); } catch (e) { print("drop course_catalogue: " + e); }
try { db.exam_attempts.drop(); }   catch (e) { print("drop exam_attempts: "   + e); }

// =====================================================================
// Collection 1: course_catalogue
//   Flexible syllabus documents whose shape depends on the faculty.
//   SCI courses require lab_hours; ENG courses require design_project;
//   ART courses require essay_required. MGT courses require neither
//   (they match the first oneOf branch which only fixes faculty).
// =====================================================================
db.createCollection("course_catalogue", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      title: "St. Stephen course catalogue document",
      required: [
        "_id", "course_code", "faculty", "title",
        "credit_units", "status", "syllabus", "academic_year"
      ],
      properties: {
        _id:           { bsonType: "objectId" },
        course_code:   { bsonType: "string", minLength: 4, maxLength: 12 },
        faculty:       { enum: ["SCI", "ENG", "MGT", "ART"] },
        title:         { bsonType: "string", minLength: 3, maxLength: 200 },
        credit_units:  { bsonType: "int", minimum: 1, maximum: 6 },
        status:        { enum: ["ACTIVE"] },     // ONE value instead of const
        academic_year: { bsonType: "string", pattern: "^[0-9]{4}/[0-9]{4}$" },
        // Faculty-specific fields (all listed so additionalProperties:false holds).
        lab_hours:       { bsonType: "int", minimum: 0, maximum: 12 },  // SCI
        design_project:  { bsonType: "bool" },                          // ENG
        essay_required:  { bsonType: "bool" },                          // ART
        syllabus: {
          bsonType: "object",
          required: ["topics"],
          properties: {
            topics:    { bsonType: "array",
                         items: { bsonType: "string", minLength: 1 },
                         minItems: 1, maxItems: 50 },
            textbooks: { bsonType: "array",
                         items: { bsonType: "string", minLength: 1 },
                         maxItems: 10 }
          },
          additionalProperties: false
        }
      },
      additionalProperties: false,
      oneOf: [
        {
          title: "Science faculty course — lab_hours required",
          properties: {
            faculty:        { enum: ["SCI"] },
            lab_hours:      { bsonType: "int" }
          },
          required: ["lab_hours"]
        },
        {
          title: "Engineering faculty course — design_project required",
          properties: {
            faculty:         { enum: ["ENG"] },
            design_project:  { bsonType: "bool" }
          },
          required: ["design_project"]
        },
        {
          title: "Arts faculty course — essay_required required",
          properties: {
            faculty:         { enum: ["ART"] },
            essay_required:  { bsonType: "bool" }
          },
          required: ["essay_required"]
        },
        {
          title: "Management faculty course — no extra field required",
          properties: {
            faculty: { enum: ["MGT"] }
          }
        }
      ]
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

// =====================================================================
// Collection 2: exam_attempts
//   High-volume log of every exam attempt by every student. Numbers are
//   Int32 (credit_units, score_int, max_score, duration_minutes) or
//   Double (score). `device` is fixed to "DESKTOP" via a single-element
//   enum (instead of const). `passed` is fixed to true/false via the
//   oneOf — but only ONE enum value is shown as the const-replacement
//   pattern: device.
// =====================================================================
db.createCollection("exam_attempts", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      title: "St. Stephen exam attempt log",
      required: [
        "_id", "attempt_id", "student_id", "course_code", "exam_type",
        "score", "max_score", "attempted_at", "device"
      ],
      properties: {
        _id:               { bsonType: "objectId" },
        attempt_id:        { bsonType: "int", minimum: 1 },
        student_id:        { bsonType: "int", minimum: 1 },
        course_code:       { bsonType: "string", minLength: 4, maxLength: 12 },
        exam_type:         { enum: ["CA", "MIDSEM", "FINAL", "RESIT"] },
        score:             { bsonType: "double", minimum: 0 },
        max_score:         { bsonType: "int", minimum: 1, maximum: 100 },
        attempted_at:      { bsonType: "date" },
        duration_minutes:  { bsonType: "int", minimum: 1, maximum: 240 },
        device:            { enum: ["DESKTOP"] },    // ONE value instead of const
        passed:            { bsonType: "bool" }
      },
      additionalProperties: false,
      oneOf: [
        {
          title: "Passing attempt — score >= 40",
          properties: {
            score:  { bsonType: "double", minimum: 40 },
            passed: { enum: [true] }
          },
          required: ["passed"]
        },
        {
          title: "Failing attempt — score < 40",
          properties: {
            score:  { bsonType: "double", maximum: 39.99 },
            passed: { enum: [false] }
          },
          required: ["passed"]
        }
      ]
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

// Sanity report.
print("01_setup.js loaded OK");
print("Collections in ststephen: " + JSON.stringify(db.getCollectionNames()));
print("course_catalogue count: " + db.course_catalogue.countDocuments());
print("exam_attempts   count: " + db.exam_attempts.countDocuments());
