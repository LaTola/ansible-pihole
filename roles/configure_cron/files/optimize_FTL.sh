#!/bin/bash
cd /etc/pihole
systemctl stop pihole-FTL
rm gravity_old.db
sync
for db in $(ls *.db)
do
  # Full optimization
  sqlite3 $db "PRAGMA integrity_check; VACUUM; REINDEX; ANALYZE;"
done
sync
systemctl start pihole-FTL
