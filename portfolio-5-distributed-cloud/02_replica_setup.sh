#!/usr/bin/env bash
# 02_replica_setup.sh - streaming replica of the ststephen primary on this machine.
# Unix sockets only, no TCP, no passwords. Replica listens on port 55432.
# Needs sudo (root only is enough), as in GitHub Codespaces.
set -euo pipefail
PGV=$(ls /usr/lib/postgresql | sort -n | tail -1)
PGBIN=/usr/lib/postgresql/$PGV/bin
RDIR=/var/lib/postgresql/replica_ststephen
SOCK=/var/run/postgresql
RPORT=55432

sudo pg_ctlcluster "$PGV" main start 2>/dev/null || true
for i in 1 2 3 4 5 6 7 8 9 10; do pg_isready -q -h "$SOCK" && break; sleep 1; done

# Re-runnable: remove an old replica first.
if [ -d "$RDIR" ]; then
  sudo runuser -u postgres -- "$PGBIN/pg_ctl" -D "$RDIR" -m fast stop >/dev/null 2>&1 || true
  sudo rm -rf "$RDIR"
fi

echo "== pg_basebackup from the primary (Unix socket) =="
sudo runuser -u postgres -- "$PGBIN/pg_basebackup" -h "$SOCK" -p 5432 -U postgres -D "$RDIR" -X stream -R -c fast

# Ubuntu keeps its config in /etc, so the copy has no config files: add them.
printf '%s\n' "port = $RPORT" "listen_addresses = ''" "unix_socket_directories = '$SOCK'" \
  "hot_standby = on" "max_connections = 100" | sudo tee "$RDIR/postgresql.conf" >/dev/null
sudo cp "/etc/postgresql/$PGV/main/pg_hba.conf" "$RDIR/pg_hba.conf"
sudo cp "/etc/postgresql/$PGV/main/pg_ident.conf" "$RDIR/pg_ident.conf"
sudo chown -R postgres:postgres "$RDIR"
sudo chmod 700 "$RDIR"

echo "== start replica on port $RPORT =="
sudo runuser -u postgres -- "$PGBIN/pg_ctl" -D "$RDIR" -l /tmp/replica_ststephen.log -w start
for i in 1 2 3 4 5 6 7 8 9 10; do pg_isready -q -h "$SOCK" -p "$RPORT" && break; sleep 1; done
pg_isready -h "$SOCK" -p "$RPORT"
echo "Replica is up (port $RPORT). Next: psql -d ststephen -f 03_replica_tests.sql"
