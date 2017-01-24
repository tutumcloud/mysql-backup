#!/bin/bash

echo "=> Restore latest backup"
rm -f /backup/*
echo "   Pulling from AWS"
/restore.sh
until nc -z $MYSQL_HOST $MYSQL_PORT
do
    echo "waiting database container..."
    sleep 1
done
ls -d -1 /backup/* | tail -1 | xargs /restore_mysql.sh
