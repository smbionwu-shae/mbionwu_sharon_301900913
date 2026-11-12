# References

Real books and official documentation consulted while building this
portfolio. No fabricated citations.

## PostgreSQL 16

- PostgreSQL 16 Documentation. The PostgreSQL Global Development Group.
  https://www.postgresql.org/docs/16/
  - Chapter 5: Data Definition — tables, constraints, partitions.
  - Chapter 6: Data Manipulation — INSERT, UPDATE, transactions.
  - Chapter 8: Data Types.
  - Chapter 11: Indexes — B-tree, partial indexes, unique indexes.
  - Chapter 13: Performance Tips — `EXPLAIN (ANALYZE, BUFFERS)`.
  - Chapter 14: Monitoring Database Activity.
  - Section 13.2: Statistics Used by the Planner.
  - Section 38.9: Trigger Functions (`CREATE TRIGGER`, `NEW`/`OLD`).
  - Section 9.25.5: Advisory Lock Functions (`pg_advisory_xact_lock`).
  - Section 13.7: `VACUUM` and `ANALYZE` guidance.
- PostgreSQL 16 Release Notes.
  https://www.postgresql.org/docs/16/release-16.html

## MongoDB 7

- MongoDB 7.0 Manual. MongoDB, Inc.
  https://www.mongodb.com/docs/v7.0/
  - `$jsonSchema` operator: https://www.mongodb.com/docs/v7.0/reference/operator/query/jsonSchema/
  - Aggregation pipeline: https://www.mongodb.com/docs/v7.0/core/aggregation-pipeline/
  - `explain("executionStats")`: https://www.mongodb.com/docs/v7.0/reference/method/cursor.explain/
  - `insertMany`: https://www.mongodb.com/docs/v7.0/reference/method/db.collection.insertMany/
  - Compound indexes: https://www.mongodb.com/docs/v7.0/core/index-compound/
  - `Int32()` / `Double()` constructors: https://www.mongodb.com/docs/v7.0/reference/bson-types/

## Books on database systems

- Silberschatz, A., Korth, H. F., & Sudarshan, S. (2019).
  *Database System Concepts* (7th ed.). McGraw-Hill Education.
  — Chapters on relational design (3NF), transaction management,
    concurrency control, and recovery.
- Elmasri, R., & Navathe, S. B. (2015).
  *Fundamentals of Database Systems* (7th ed.). Pearson.
  — ER modelling, normalisation, indexing.
- Kleppmann, M. (2017).
  *Designing Data-Intensive Applications*. O'Reilly Media.
  — Replication (sync vs async), partitioning, isolation levels.
- Gray, J., & Reuter, A. (1993).
  *Transaction Processing: Concepts and Techniques*. Morgan Kaufmann.
  — Classic reference on transactions, locking, deadlocks and 2PC.
- Bernstein, P. A., & Newcomer, E. (2009).
  *Principles of Transaction Processing* (2nd ed.). Morgan Kaufmann.
  — ACID, isolation levels, deadlock handling.
- Hellerstein, J. M., Stonebraker, M., & Hamilton, J. (2007).
  *Architecture of a Database System*. Foundations and Trends in
  Databases, 1(2), 141–259. Now Publishers.
  — Query optimiser internals, process model.

## Concurrency and isolation

- Berenson, H., Bernstein, P., Gray, J., Melton, J., & O'Neil, E. (1995).
  *A Critique of ANSI SQL Isolation Levels*. SIGMOD 1995.
  https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/tr-95-51.pdf
  — Defines the phenomena that READ COMMITTED, REPEATABLE READ and
    SERIALIZABLE do or do not prevent.
- PostgreSQL 16 — Transaction Isolation.
  https://www.postgresql.org/docs/16/transaction-iso.html
  — Documents PostgreSQL's implementation of each isolation level,
    including SSI for SERIALIZABLE.

## Distributed databases and partitioning

- DeWitt, D., & Gray, J. (1992).
  *Parallel Database Systems: The Future of High Performance Database
  Systems*. Communications of the ACM, 35(6), 85–98.
- PostgreSQL 16 — Table Partitioning.
  https://www.postgresql.org/docs/16/ddl-partitioning.html
  — RANGE partitioning, partition pruning, limitations on unique and
    exclusion constraints on partitioned parents.

## Managed PostgreSQL services (consulted for cloud_design.md)

- Amazon RDS for PostgreSQL — Multi-AZ deployments.
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html
- Amazon RDS for PostgreSQL — Read replicas.
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html
- Amazon RDS — Backing up and restoring.
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_CommonTasks.BackupRestore.html
- Microsoft Azure Database for PostgreSQL — Flexible Server: High availability.
  https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-high-availability
- Microsoft Azure — Regions: South Africa North (Johannesburg), South Africa West (Cape Town).
  https://azure.microsoft.com/explore/regions/
- Google Cloud — Regions and zones: `africa-south1` (Johannesburg).
  https://cloud.google.com/compute/docs/regions-zones

## Nigerian law and regulation (consulted for cloud_design.md)

- Nigeria Data Protection Act 2023. Federal Republic of Nigeria.
  Signed into law 12 June 2023. Establishes the Nigeria Data Protection
  Commission (NDPC) and imposes obligations on data controllers and
  data processors processing the personal data of Nigerian residents.
  Official gazette and NDPC guidance:
  https://ndpc.gov.ng/   (Nigeria Data Protection Commission)
- Nigeria Data Protection Regulation (NDPR) 2019. Issued by the
  National Information Technology Development Agency (NITDA).
  https://nitda.gov.ng/   — Superseded in force by the NDPA 2023, but
  still referenced in older compliance documentation.
- Central Bank of Nigeria — Consumer Protection Regulations.
  https://www.cbn.gov.ng/
- Central Bank of Nigeria — Risk-Based Cybersecurity Guidelines
  (2021). Applies to deposit-money banks and payment service providers.
- Banks and Other Financial Institutions Act (BOFIA) 2020. Federal
  Republic of Nigeria.

## Python driver

- psycopg 2 / psycopg 3 documentation.
  https://www.psycopg.org/docs/
  — `psycopg2.connect`, `cursor.execute`, `set_session(isolation_level=…)`,
    `commit`, `rollback`, exception classes (`OperationalError`,
    `Error`) and `pgcode`/`pgerror`.
