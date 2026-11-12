#!/usr/bin/env bash
# collect_results.sh - gathers the real output of every portfolio into my_results.txt
cd "$(dirname "${BASH_SOURCE[0]}")"
OUT=my_results.txt
P1=portfolio-1-database-design; P2=portfolio-2-query-optimisation; P3=portfolio-3-transactions-concurrency
P4=portfolio-4-nosql; P5=portfolio-5-distributed-cloud
sec() { echo; echo "######## $1"; }
show() { # file, grep-pattern
  if [ -f "$1" ]; then grep -E "$2" "$1" | cut -c1-200; else echo "(no $1 - this portfolio did not run)"; fi; }
{
  echo "Sharon Chibuzor Mbionwu - 2026/A/MIT/0060 - ststephen - generated $(date)"
  sec "P1 row counts"; [ -f $P1/p1_output.log ] && grep -A14 "table_name" $P1/p1_output.log | tail -14 || echo "(no $P1/p1_output.log)"
  sec "P1 constraint tests"; show $P1/p1_output.log "TEST [0-9]+"
  sec "P2 queries, plans and times"; show $P2/p2_output.log "^---|^PHASE|Execution Time|Seq Scan on (student|registration|result)|Index (Only )?Scan using idx_"
  sec "P3 transactions"; show $P3/p3_output.log "^=== |^[ABC]: "
  sec "P3 race demos"; show $P3/race_demos_output.log "PART|>>>|outcome|Active rows"
  sec "P4 MongoDB"; show $P4/p4_output.log "VALIDATOR|Query target|Stage|Docs|Time|Rows|Inserted"
  sec "P5 partitions"; show $P5/p5_output.log "registration_p_|Subplans Removed|Partition range|Execution Time|default|DEFAULT"
  sec "P5 replica"; show $P5/replication_output.log "===|port|is_replica|ERROR|RPL|streaming|registrations_on|lsn|delay"
} > $OUT
echo "Wrote $OUT ($(wc -l < $OUT) lines)"
