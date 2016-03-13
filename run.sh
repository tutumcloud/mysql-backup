#!/bin/bash

if [ "${MYSQL_ENV_MYSQL_PASS}" == "**Random**" ]; then
        unset MYSQL_ENV_MYSQL_PASS
fi

MYSQL_HOST=${MYSQL_PORT_3306_TCP_ADDR:-${MYSQL_HOST}}
MYSQL_HOST=${MYSQL_PORT_1_3306_TCP_ADDR:-${MYSQL_HOST}}
MYSQL_PORT=${MYSQL_PORT_3306_TCP_PORT:-${MYSQL_PORT}}
MYSQL_PORT=${MYSQL_PORT_1_3306_TCP_PORT:-${MYSQL_PORT}}
MYSQL_USER=${MYSQL_USER:-${MYSQL_ENV_MYSQL_USER}}
MYSQL_PASS=${MYSQL_PASS:-${MYSQL_ENV_MYSQL_PASS}}

[ -z "${MYSQL_HOST}" ] && { echo "=> MYSQL_HOST cannot be empty" && exit 1; }
[ -z "${MYSQL_PORT}" ] && { echo "=> MYSQL_PORT cannot be empty" && exit 1; }
[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
[ -z "${MYSQL_PASS}" ] && { echo "=> MYSQL_PASS cannot be empty" && exit 1; }

BACKUP_CMD="mysqldump -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASS} ${EXTRA_OPTS} ${MYSQL_DB} > /backup/"'${BACKUP_SQL_NAME}'

echo "=> Creating backup script"
rm -f /backup_mysql.sh
cat <<EOF >> /backup_mysql.sh
#!/bin/bash

BACKUP_SQL_NAME=\$(date +\%Y.\%m.\%d.\%H\%M\%S).sql

echo "=> Backup started: \${BACKUP_SQL_NAME}"
if ${BACKUP_CMD} ;then
    echo "   MySQL Backup succeeded"
    echo "   Pushing to AWS"
    /backup.sh
else
    echo "   Backup failed"
fi

rm -f /backup/*

echo "=> Backup done"
EOF
chmod +x /backup_mysql.sh

echo "=> Creating restore script"
rm -f /restore_mysql.sh
cat <<EOF >> /restore_mysql.sh
#!/bin/bash
echo "=> Restore database from \$1"
if mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASS} < \$1 ;then
    echo "   Restore succeeded"
else
    echo "   Restore failed"
fi
echo "=> Done"
EOF
chmod +x /restore_mysql.sh

touch /mysql_backup.log
tail -F /mysql_backup.log &

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup_mysql.sh
elif [ -n "${INIT_RESTORE_LATEST}" ]; then
    /restore_latest.sh
fi

echo "${CRON_TIME} /backup_mysql.sh >> /mysql_backup.log 2>&1" > /crontab.conf
env | grep 'AWS\|BACKUP_NAME\|PATHS_TO_BACKUP\|S3_BUCKET_NAME' | cat - /crontab.conf > temp && mv temp /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f
