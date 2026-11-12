-- 03_replica_tests.sql - ONE script that switches between primary (5432) and replica (55432).
-- Run:  psql -d ststephen -f 03_replica_tests.sql
\set ON_ERROR_STOP off
\pset pager off

\echo '=== 1. Who is who: primary on port 5432 ==='
\connect -reuse-previous=off ststephen - /var/run/postgresql 5432
SELECT current_setting('port') AS port, pg_is_in_recovery() AS is_replica;

\echo '=== 2. Who is who: replica on port 55432 ==='
\connect -reuse-previous=off ststephen - /var/run/postgresql 55432
SELECT current_setting('port') AS port, pg_is_in_recovery() AS is_replica;

\echo '=== 3. A write on the replica must be REJECTED (read-only) ==='
INSERT INTO faculty (faculty_code, faculty_name, dean_name) VALUES ('RPL','Replica Test Faculty','Prof. Replica');

\echo '=== 4. Insert on the primary ==='
\connect -reuse-previous=off ststephen - /var/run/postgresql 5432
DELETE FROM faculty WHERE faculty_code = 'RPL';
INSERT INTO faculty (faculty_code, faculty_name, dean_name) VALUES ('RPL','Replica Test Faculty','Prof. Replica');
SELECT faculty_code, faculty_name FROM faculty WHERE faculty_code = 'RPL';
SELECT pg_sleep(1);

\echo '=== 5. The row has arrived on the replica ==='
\connect -reuse-previous=off ststephen - /var/run/postgresql 55432
SELECT faculty_code, faculty_name FROM faculty WHERE faculty_code = 'RPL';
SELECT count(*) AS registrations_on_replica FROM registration;

\echo '=== 6. Replication lag, seen on the replica ==='
SELECT pg_last_wal_receive_lsn() AS received_lsn, pg_last_wal_replay_lsn() AS replayed_lsn,
       now() - pg_last_xact_replay_timestamp() AS replay_delay;

\echo '=== 7. pg_stat_replication, seen on the primary ==='
\connect -reuse-previous=off ststephen - /var/run/postgresql 5432
SELECT state, sync_state, sent_lsn, replay_lsn, replay_lag FROM pg_stat_replication;
SELECT count(*) AS registrations_on_primary FROM registration;

\echo '=== 8. Clean up the test row on the primary ==='
DELETE FROM faculty WHERE faculty_code = 'RPL';
\echo '03_replica_tests.sql finished'
