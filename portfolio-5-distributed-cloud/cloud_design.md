# Cloud design — St. Stephen USMS on a managed PostgreSQL service

**Student:** Sharon Chibuzor Mbionwu — 2026/A/MIT/0060 — MIT, Miva Open University

This note sketches how the `ststephen` PostgreSQL 16 workload would run
on a managed relational database service (Amazon RDS for PostgreSQL or
Azure Database for PostgreSQL — Flexible Server) so that the
University's Student Management System stays available across an
availability-zone outage, can scale read-only reporting, and recovers
from disaster without losing more than a few minutes of data.

## 1. Workload summary

The `registration` table is the hot one — ~60k rows after the bulk load
in `portfolio-1-database-design/04_bulk_data.sql`, growing by a few
thousand rows per semester, with a burst of writes during registration
week and a steady read load from the registrar, lecturers and the
bursar. Result rows (~30k) are written in batches after each exam. The
advisory-lock fix from Portfolio 3 means registration writes serialise
per offering; the rest of the workload is read-mostly.

## 2. Architecture

| Component | Configuration |
| --- | --- |
| **Primary** | Multi-AZ deployment: one primary instance in AZ-a, one synchronous standby in AZ-b (RDS Multi-AZ, or Azure Zone-redundant high availability). Automatic failover to the standby if the primary is lost. |
| **Read replicas** | One or two asynchronous read replicas in the same region (and, if the University opens a campus in another Nigerian city, one cross-region replica). All read-only reports from Portfolio 2 and the partitioned reporting queries from Portfolio 5 run against replicas, leaving the primary for OLTP writes. |
| **Connection routing** | PgBouncer (transaction pooling) in front of the primary; the read endpoint of the managed service in front of the replicas. Application reads use the reader endpoint, writes use the writer endpoint. |
| **Storage** | Provisioned IOPS SSD. Storage autoscaling enabled with a hard cap so a runaway bulk load does not silently fill the disk. |
| **Networking** | Private subnet only; the database has no public IP. The application runs in the same VPC/VNet and reaches the database over the Unix socket equivalent (private TCP within the VPC). |
| **Backups** | Automated daily snapshots with a 7-day retention, plus point-in-time-recovery (PITR) with at least a 7-day transaction-log window. Weekly logical `pg_dump` to a separate object-storage bucket as a defence against a snapshot bucket compromise. |

## 3. Replication: synchronous vs asynchronous

| Mode | How it works | Trade-off | Where we use it |
| --- | --- | --- | --- |
| **Synchronous (sync)** | `synchronous_commit = on`; `synchronous_standby_names` requires the standby to acknowledge every WAL record before the primary commits. RDS Multi-AZ and Azure zone-redundant HA use this for the in-region standby. | Zero data loss on primary failure; write latency increases by one network round-trip per commit. | The primary-to-standby link in the same region. Every `INSERT`/`UPDATE`/`DELETE` in `registration`, `result` and `fee_payment` is durable on both AZs before the application sees `COMMIT`. |
| **Asynchronous (async)** | `synchronous_commit = off` (or `local`); the standby pulls WAL as it arrives. The primary does not wait. | Lower write latency; small window (typically seconds) where a primary failure can lose un-replicated transactions. | Read replicas — both in-region and cross-region. They exist to absorb read load, not to be authoritative. Failover to a replica is a deliberate, human-triggered operation, not an automatic one. |

For the race-condition scenario in Portfolio 3, the advisory-lock fix
is what guarantees correctness; replication mode is independent. Sync
replication protects against data *loss*, not against concurrent
write *races*.

## 4. Backups and disaster recovery

- **RPO** (recovery point objective): with sync replication in-region,
  RPO = 0 for an AZ failure. With PITR, RPO ≤ 5 minutes for a logical
  error (e.g. someone runs `DELETE FROM registration;` by mistake).
- **RTO** (recovery time objective): automatic failover to the
  in-region standby typically completes in 60–120 seconds. Restoring
  from a snapshot to a new instance takes 15–30 minutes depending on
  database size.
- **DR drills**: the bursar's office should run a restore-from-snapshot
  drill once a term and a PITR-to-timestamp drill once a year.
- **Long-term retention**: term-end snapshots (one per term) are kept
  for the duration of a student's enrolment plus seven years, to
  satisfy audit and statutory retention expectations.

## 5. Cloud region choice

As of November 2026, **no major hyperscaler offers a cloud region
physically located in Nigeria**. The closest available regions are:

- **AWS** `af-south-1` (Cape Town, South Africa).
- **Azure** `South Africa North` (Johannesburg) and `South Africa West`
  (Cape Town).
- **Google Cloud** `africa-south1` (Johannesburg).

For St. Stephen, the primary deployment should sit in one of these
South-Africa regions. Latency from Enugu to Johannesburg is on the
order of 60–80 ms over a stable Internet path, which is acceptable for
a registrar's OLTP screen. For lower latency to staff on campus, a
read replica on a self-hosted PostgreSQL 16 box in the Enugu data
centre, fed asynchronously from the managed primary, is a reasonable
hybrid pattern (read-only queries hit the local replica; writes go to
the managed primary).

## 6. Nigerian data-protection notes

The University processes personal data of identifiable Nigerian
students (names, matric numbers, gender, department, email, examination
scores, Naira-denominated fee records). The relevant legal regime is:

### 6.1 Nigeria Data Protection Act 2023 (NDPA 2023)

The NDPA 2023 — signed into law on 12 June 2023 — is the primary
Nigerian data-protection statute. It is administered by the Nigeria
Data Protection Commission (NDPC). The Act's principal obligations
that bear directly on this design are:

- **Lawful basis and purpose limitation.** Every column in `student`,
  `lecturer`, `result` and `fee_payment` must be justifiable by the
  University's educational and statutory mandate; no "nice-to-have"
  columns.
- **Data minimisation.** The partial UNIQUE index on `registration`
  and the partial indexes in `02_indexes.sql` exist to make the
  minimum necessary data queryable; bulk rows are not copied into
  free-form "notes" tables.
- **Storage limitation.** The graduation status (`student.status =
  'GRADUATED'`) and the term-end snapshot retention policy in §4
  together implement a defensible retention schedule.
- **Security safeguards.** Encryption in transit (TLS between the
  application and the managed database) and encryption at rest
  (managed-service default, with a customer-managed key in AWS KMS /
  Azure Key Vault) are mandatory.
- **Data subject rights.** A student's right of access maps to the
  transcript query in Portfolio 2 (Q1); the right to rectification
  maps to an UPDATE workflow on `student` and `result`; the right to
  erasure is tempered by the statutory retention duty on examination
  records, so a "graduated" student is logically archived rather than
  hard-deleted.
- **Breach notification.** A confirmed personal-data breach is
  reported to the NDPC and to affected data subjects within the
  statutory window; the managed-service's security event notifications
  feed this pipeline.
- **Cross-border transfer.** Because the cloud region is in South
  Africa (not Nigeria), the transfer of personal data outside Nigeria
  falls under the NDPA 2023's cross-border transfer regime. The
  University must ensure the recipient is bound by adequate safeguards
  (e.g. the cloud provider's standard contractual clauses, an
  adequacy determination, or the managed-service's data-protection
  addendum), and must record the transfer in its data-protection
  register.
- **Data Protection Impact Assessment.** A new processing activity
  such as tuition processing tied to biometric or behaviour tracking
  would trigger a DPIA under the NDPA 2023; this baseline design does
  not include biometric data, so a DPIA is not strictly required for
  the launch scope, but is recommended before adding any
  attendance-tracking or CCTV processing.
- **Registration with the NDPC.** Data controllers processing the
  personal data of more than a threshold number of data subjects must
  register with the NDPC and pay the prescribed annual fee. A
  university with thousands of students is above the threshold, so
  St. Stephen must register.

### 6.2 Central Bank of Nigeria (CBN) rules

The `fee_payment` table records Naira-denominated tuition payments
made by CARD, BANK_TRANSFER, USSD or CASH. The CBN rules that apply
indirectly are:

- The **CBN Consumer Protection Regulations** (2016, as amended) and
  the **CBN Risk-Based Cybersecurity Guidelines** (2021) place
  obligations on the payment service providers (e.g. Paystack,
  Flutterwave, the merchant's bank) that process the actual card and
  USSD transactions. The University, as the merchant of record, must
  ensure its payment integrators are licensed CBN-regulated entities
  and that no raw PAN or card CVV is stored in `fee_payment` — only
  the masked last-four and a payment reference.
- The **Banks and Other Financial Institutions Act** (BOFIA) 2020
  underpins the CBN's consumer-protection rule-making authority.
- **Record retention for financial data**: CBN regulations generally
  require financial transaction records to be retained for at least
  five years. The seven-year retention policy in §4 covers this.

### 6.3 Practical configuration choices that flow from the above

| Configuration choice | Reason |
| --- | --- |
| Database has no public IP; reachable only from the application VPC. | NDPA 2023 security-safeguards duty. |
| TLS required for every connection (`rds.force_ssl=1` or equivalent). | NDPA 2023 security-safeguards duty. |
| Encryption at rest with a customer-managed key. | NDPA 2023 security-safeguards duty; CBN cybersecurity guidance. |
| `fee_payment.method` is the only payment field stored — no card numbers, no CVVs. | CBN rules on payment data. |
| Term-end snapshots retained for seven years. | NDPA 2023 storage-limitation duty combined with CBN five-year financial-records retention. |
| Cross-border transfer to the South-Africa region documented in the NDPC register. | NDPA 2023 cross-border transfer regime. |
| Read replicas in the same region as the primary; cross-region replica only if a second campus opens. | Minimise unnecessary cross-border copies of personal data. |

## 7. Honesty note

This document is a design sketch for a coursework portfolio; it is not
an architectural sign-off for a production deployment. The student has
not run a real cross-region replication test against an actual managed
PostgreSQL service, and the row counts in §1 are the bulk-load counts
from `04_bulk_data.sql`, not measured production traffic.
