#!/bin/bash
set -ueo pipefail

backup_file=$1
testdb=appdb_restore_test
cd /tmp
if [ -z "$backup_file" ]; then
   echo " usage: ./restore.sh <backup-file>"
   exit 1
fi

if [ ! -f "$backup_file" ]; then
   echo "file not found: $backup_file"
   exit 1
fi

sudo -u postgres dropdb --if-exists $testdb
sudo -u postgres createdb $testdb

gunzip -c $backup_file | sudo  -u postgres psql -d $testdb 

restored=$(sudo -u postgres psql -d $testdb -tAc "SELECT COUNT(*) FROM users")
original=$(sudo -u postgres psql -d appdb -tAc "SELECT COUNT(*) FROM users")

if [ "$original" == "$restored" ]; then
    echo "ok backup"
else
    echo "backup fail"
    exit 1
fi

