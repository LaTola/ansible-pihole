#!/bin/bash
cd /etc/pihole
systemctl stop unbound
systemctl stop pihole-FTL
rm gravity_old.db
sync
for db in $(ls *.db)
do
  # Enable WAL and full optimization
  sqlite3 $db "PRAGMA integrity_check; VACUUM; REINDEX; ANALYZE;"
done
sync
systemctl start unbound
systemctl start pihole-FTL