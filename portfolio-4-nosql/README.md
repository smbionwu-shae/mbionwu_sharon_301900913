# Portfolio 4 — NoSQL (MongoDB 7+)

**Student:** Sharon Chibuzor Mbionwu — 2026/A/MIT/0060 — MIT, Miva Open University

## Files

| File | Purpose |
| --- | --- |
| `01_setup.js` | Creates the `ststephen` MongoDB database with two collections that have `$jsonSchema` validators: `course_catalogue` (flexible syllabus documents whose shape varies per faculty, modelled with `oneOf`) and `exam_attempts` (high-volume student activity log). Uses `db = db.getSiblingDB("ststephen")`, `enum` (with one value where a single value is fixed), `oneOf`, no `if/then/else`, `additionalProperties:false` with every field listed, and `Int32()`/`Double()` for numbers. |
| `02_data_and_queries.js` | Seeds a small realistic Nigerian dataset (4 course syllabi, 20 students × 4 courses × 4 exam types ≈ 320 attempts), then runs three aggregation pipelines: pass rate per exam type, top-5 courses by attempts, and average FINAL score per student enriched with the course title via `$lookup`. |
| `03_bulk_and_index_demo.js` | Inserts 40,000 documents into `exam_attempts` in batches of 1,000 with `insertMany`, then runs `explain("executionStats")` BEFORE (with `hint({$natural:1})` forcing a COLLSCAN) and AFTER (compound index `(student_id, exam_type)`). `dropIndex` is wrapped in `try/catch`. Prints Stage / Docs / Time ms for both phases. |

## Run

```
mongosh --file 01_setup.js
mongosh --file 02_data_and_queries.js
mongosh --file 03_bulk_and_index_demo.js
```

Connect via the local Unix socket as the non-root user (GitHub Codespaces default). No TCP, no credentials.

## What the validator enforces

### `course_catalogue`

- `faculty` is one of `["SCI","ENG","MGT","ART"]`.
- `status` is fixed to `"ACTIVE"` via a single-element `enum` (not `const`).
- `oneOf` requires `lab_hours` for SCI courses, `design_project` for ENG courses, `essay_required` for ART courses, and no extra field for MGT courses.
- `additionalProperties: false` at the top level and inside `syllabus`; every allowed field is listed explicitly.

### `exam_attempts`

- `exam_type` is one of `["CA","MIDSEM","FINAL","RESIT"]`.
- `device` is fixed to `"DESKTOP"` via a single-element `enum` (not `const`).
- `oneOf` requires `passed` to be `true` when `score >= 40` and `false` when `score <= 39.99` — the score range and the `passed` boolean must agree.
- `additionalProperties: false`; every field including `_id` is listed.

## Sample output

```text
[paste real output here]
```
