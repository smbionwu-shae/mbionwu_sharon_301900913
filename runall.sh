#!/usr/bin/env bash
# runall.sh - runs Portfolio 1 to 5 in order, commits after each, then collects results.
# Run from the repo root:  bash runall.sh     (resume from P3:  bash runall.sh 3)
set -uo pipefail
DB=ststephen
START="${1:-1}"
REPO="$PWD"
KIT="$HOME/kit/advanced-database-portfolio"
P1=portfolio-1-database-design
P2=portfolio-2-query-optimisation
P3=portfolio-3-transactions-concurrency
P4=portfolio-4-nosql
P5=portfolio-5-distributed-cloud

# --- kit and services (the Codespace may have slept) ---
if [ ! -d "$KIT" ]; then
  ZIP="$(ls "$REPO"/Mbionwu_Sharon_FIXED.zip 2>/dev/null | head -1)"
  [ -n "$ZIP" ] || { echo "!!! kit missing and no zip in the repo - send Joseph a screenshot"; exit 1; }
  mkdir -p "$HOME/kit" && unzip -o -q "$ZIP" -d "$HOME/kit"
fi
PGV=$(ls /usr/lib/postgresql | sort -n | tail -1)
sudo pg_ctlcluster "$PGV" main start 2>/dev/null || true
pgrep -x mongod >/dev/null || sudo runuser -u mongodb -- mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null 2>&1 || true
for i in 1 2 3 4 5 6 7 8 9 10; do mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1 && break; sleep 1; done
if ! psql -d $DB -c 'SELECT 1' >/dev/null 2>&1; then
  echo "Database missing - running setup.sh first"
  bash "$KIT/setup.sh" || { echo "!!! setup FAILED - send Joseph the screen"; exit 1; }
fi
python3 -c 'import psycopg2' 2>/dev/null || { echo "!!! psycopg2 missing - run: bash $KIT/setup.sh"; exit 1; }

commit_push() { git add -A && git commit -m "$1" >/dev/null 2>&1; git push >/dev/null 2>&1 || echo "(push skipped)"; }
fail() { echo "!!! $1 FAILED - send Joseph the file $2"; exit 1; }
prep() { [ -d "$REPO/$1" ] || cp -r "$KIT/$1" "$REPO/$1"; }

p1() { prep $P1; cd "$REPO/$P1"
  for f in 01_schema 02_indexes 03_seed_data 04_bulk_data 05_constraint_tests; do
    echo "--- $f.sql"; psql -d $DB -v ON_ERROR_STOP=1 -f $f.sql || return 1; done; }
p2() { prep $P2; cd "$REPO/$P2"
  for f in 01_queries 02_explain_analyze; do echo "--- $f.sql"; psql -d $DB -v ON_ERROR_STOP=1 -f $f.sql || return 1; done; }
p3() { prep $P3; cd "$REPO/$P3"
  psql -d $DB -v ON_ERROR_STOP=1 -f 01_transactions.sql || return 1
  python3 race_demos.py 2>&1 | tee race_demos_output.log; [ "${PIPESTATUS[0]}" = 0 ]; }
p4() { prep $P4; cd "$REPO/$P4"
  for f in 01_setup 02_data_and_queries 03_bulk_and_index_demo; do echo "--- $f.js"; mongosh --quiet --file $f.js || return 1; done; }
p5() { prep $P5; cd "$REPO/$P5"
  psql -d $DB -v ON_ERROR_STOP=1 -f 01_partitioning.sql || return 1
  { bash 02_replica_setup.sh && psql -d $DB -f 03_replica_tests.sql; } 2>&1 | tee replication_output.log; [ "${PIPESTATUS[0]}" = 0 ]; }

for N in 1 2 3 4 5; do
  [ "$N" -lt "$START" ] && continue
  case $N in 1) D=$P1;; 2) D=$P2;; 3) D=$P3;; 4) D=$P4;; 5) D=$P5;; esac
  echo; echo "=================== PORTFOLIO $N ==================="
  cd "$REPO"; prep $D
  LOG="$REPO/$D/p${N}_output.log"
  ( set -o pipefail; p$N 2>&1 | tee "$LOG" ) || fail "P$N" "$D/p${N}_output.log"
  cd "$REPO"; commit_push "Portfolio $N: run output"
done

cd "$REPO"
[ -f collect_results.sh ] || cp "$KIT/collect_results.sh" .
bash collect_results.sh
commit_push "Collect results"
echo "ALL DONE. Open my_results.txt, press Ctrl+A, Ctrl+C and paste it to Joseph."
command -v code >/dev/null 2>&1 && code my_results.txt || true
