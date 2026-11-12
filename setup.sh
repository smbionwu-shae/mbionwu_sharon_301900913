#!/usr/bin/env bash
# setup.sh - one-time setup for Sharon Mbionwu's MIT 8103 portfolio (database: ststephen).
# Run from the root of your GitHub repo:  bash $HOME/kit/advanced-database-portfolio/setup.sh
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$PWD"
DB=ststephen
ME="$(whoami)"

echo "== 1. PostgreSQL and MongoDB =="
sudo rm -f /etc/apt/sources.list.d/yarn.list
if [ "${SKIP_APT:-0}" != "1" ]; then
  if [ ! -x /usr/lib/postgresql/16/bin/psql ] && ! ls /usr/lib/postgresql/*/bin/pg_ctl >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y postgresql postgresql-contrib
  fi
  if ! command -v mongod >/dev/null 2>&1; then
    CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    case "$CODENAME" in jammy|noble) ;; *) CODENAME=jammy ;; esac
    sudo apt-get install -y gnupg curl
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg --yes --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $CODENAME/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y mongodb-org
  fi
fi
PGV=$(ls /usr/lib/postgresql | sort -n | tail -1)
sudo pg_ctlcluster "$PGV" main start 2>/dev/null || true
for i in 1 2 3 4 5 6 7 8 9 10; do pg_isready -q && break; sleep 1; done

echo "== 2. Role and database (Unix socket, no password) =="
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$ME') THEN CREATE ROLE \"$ME\" SUPERUSER LOGIN; END IF; END \$\$;"
if ! sudo runuser -u postgres -- psql -At -c "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -q 1; then
  sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE $DB OWNER \"$ME\""
fi
sudo runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "ALTER DATABASE $DB SET timezone TO 'Africa/Lagos'"

echo "== 3. mongod =="
sudo mkdir -p /data/db /var/log/mongodb
sudo chown -R mongodb:mongodb /data/db /var/log/mongodb 2>/dev/null || true
if ! pgrep -x mongod >/dev/null; then
  sudo runuser -u mongodb -- mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null
fi
for i in 1 2 3 4 5 6 7 8 9 10; do mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1 && break; sleep 1; done
mongosh --quiet --eval 'db.runCommand({ping:1}).ok' | grep -q 1

echo "== 4. Python packages (psycopg2) =="
if ! python3 -c 'import psycopg2' 2>/dev/null; then
  pip install psycopg2-binary 2>/dev/null || pip install --user psycopg2-binary 2>/dev/null \
  || pip install --break-system-packages psycopg2-binary 2>/dev/null \
  || pip install --user --break-system-packages psycopg2-binary 2>/dev/null \
  || sudo apt-get install -y python3-psycopg2
fi
python3 -c 'import psycopg2; print("psycopg2 OK")'

echo "== 5. Copy project files into the repo =="
for f in README.md CHANGES.md setup.sh runall.sh collect_results.sh; do [ -f "$KIT/$f" ] && [ "$KIT" != "$REPO" ] && cp "$KIT/$f" "$REPO/$f" || true; done
[ "$KIT" != "$REPO" ] && cp -r "$KIT/docs" "$REPO/" || true
git add -A
git commit -m "Add setup, run scripts and docs" >/dev/null 2>&1 || true
git push >/dev/null 2>&1 || echo "(git push skipped - push later with: git push)"
echo "SETUP DONE. Now run:  bash runall.sh"
