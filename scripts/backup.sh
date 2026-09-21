#!/bin/bash

set -euo pipefail
backup_dir=/mnt/backups
dbname=appdb
timestamp=$(date +%Y%m%d-%H%M%S)
filename=appdb-${timestamp}.sql.gz

cd /tmp

sudo -u postgres pg_dump ${dbname} | gzip > ${backup_dir}/${filename}

ls -lh ${backup_dir}/${filename}

find ${backup_dir} -name "*.sql.gz" -mtime +7 -delete


