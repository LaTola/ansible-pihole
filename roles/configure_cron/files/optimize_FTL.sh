#!/bin/bash
set -e
cd /etc/pihole
systemctl stop pihole-FTL
sync
for db in $(ls *.db | grep -v "old")
do
  # Full optimization
  sqlite3 $db "PRAGMA integrity_check; VACUUM; REINDEX; ANALYZE;"
done
sync
systemctl start pihole-FTL
