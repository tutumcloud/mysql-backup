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

echo ${TIMEZONE} > /etc/timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash

# Setting the pass phrase to encrypt the backup files.
export PASSPHRASE=$DUPLICITY_ENCRYPT_PASSPHRASE

MAX_BACKUPS=${MAX_BACKUPS}

BACKUP_NAME_NOEXT=\$(date +\%Y.\%m.\%d.\%H\%M\%S)
BACKUP_GZ_NAME=\${BACKUP_NAME_NOEXT}.gz

SFTP_USER=${SFTP_USER}
SFTP_HOST=${SFTP_HOST}
SFTP_PORT=${SFTP_PORT}
SFTP_DIR="${SFTP_DIR}"
DUPLICITY_EXTRA_OPTS="${DUPLICITY_EXTRA_OPTS}"
DUPLICITY_SCHEME="${DUPLICITY_SCHEME:-sftp}"

MYSQL_HOST=${MYSQL_HOST}
MYSQL_PORT=${MYSQL_PORT}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASS="${MYSQL_PASS}"
MYSQL_DB=${MYSQL_DB}
EXTRA_OPTS="${EXTRA_OPTS}"

if [[ ! -z \${SFTP_USER} && ! -z \${SFTP_HOST} && ! -z \${SFTP_DIR} ]]; then
	echo "=> Backup started: \${MYSQL_DB}.sql"

	# using pexpect+sftp because of a bug in paramiko backend. 
	# @see https://lists.gnu.org/archive/html/duplicity-talk/2016-10/msg00010.html
	if flock -x -n /root/.cache/duplicity/backup.lock -c "/usr/local/bin/gosu mysql mysqldump -h\${MYSQL_HOST} -P\${MYSQL_PORT} -u\${MYSQL_USER} -p\${MYSQL_PASS} \${EXTRA_OPTS} \${MYSQL_DB} > /backup/\${MYSQL_DB}.sql && duplicity --ssh-options=\"-oProtocol=2 -oIdentityFile=/root/.ssh/id_rsa\" \${DUPLICITY_EXTRA_OPTS} /backup \${DUPLICITY_SCHEME}://\${SFTP_USER}@\${SFTP_HOST}:\${SFTP_PORT}/\${SFTP_DIR}" ;then
		echo "   Backup succeeded"
	else
		echo "   Backup failed"
	fi

	if [ -n "\${MAX_BACKUPS}" ]; then
		if flock -x -n /root/.cache/duplicity/backup.lock -c "duplicity remove-older-than \${MAX_BACKUPS} --force --ssh-options=\"-oProtocol=2 -oIdentityFile=/root/.ssh/id_rsa\" \${DUPLICITY_SCHEME}://\${SFTP_USER}@\${SFTP_HOST}:\${SFTP_PORT}/\${SFTP_DIR}" ;then
			echo "   Backup succeeded"
		else
			echo "   Backup failed"
		fi
	fi
else
	echo "=> Backup started: \${BACKUP_GZ_NAME}"

	if flock -x -n /root/.cache/duplicity/backup.lock -c "exec /usr/local/bin/gosu mysql mysqldump -h\${MYSQL_HOST} -P\${MYSQL_PORT} -u\${MYSQL_USER} -p\${MYSQL_PASS} \${EXTRA_OPTS} \${MYSQL_DB} | gzip -c -9 > /backup/\${BACKUP_GZ_NAME}" ;then
		echo "   Backup succeeded"
	else
		echo "   Backup failed"
	fi

	if [ -n "\${MAX_BACKUPS}" ]; then
		while [ \$(ls /backup -N1 | wc -l) -gt \${MAX_BACKUPS} ];
		do
			BACKUP_TO_BE_DELETED=\$(ls /backup -N1 | sort | head -n 1)
			echo "   Backup \${BACKUP_TO_BE_DELETED} is deleted"
			rm -rf /backup/\${BACKUP_TO_BE_DELETED}
		done
	fi
fi

echo "=> Backup done"
EOF
chmod +x /backup.sh

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash

# Setting the pass phrase to encrypt the backup files.
export PASSPHRASE=\$DUPLICITY_ENCRYPT_PASSPHRASE

SFTP_USER=${SFTP_USER}
SFTP_HOST=${SFTP_HOST}
SFTP_PORT=${SFTP_PORT}
SFTP_DIR="${SFTP_DIR}"
DUPLICITY_SCHEME="${DUPLICITY_SCHEME:-sftp}"

MYSQL_HOST=${MYSQL_HOST}
MYSQL_PORT=${MYSQL_PORT}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASS="${MYSQL_PASS}"
MYSQL_DB=${MYSQL_DB}

if [[ ! -z \${SFTP_USER} && ! -z \${SFTP_HOST} && ! -z \${SFTP_DIR} ]]; then
	# using pexpect+sftp because of a bug in paramiko backend. 
	# @see https://lists.gnu.org/archive/html/duplicity-talk/2016-10/msg00010.html
	if duplicity --allow-source-mismatch --ssh-options="-oProtocol=2 -oIdentityFile=/root/.ssh/id_rsa" -t \${1} --file-to-restore \${MYSQL_DB}.sql \${DUPLICITY_SCHEME}://\${SFTP_USER}@\${SFTP_HOST}:\${SFTP_PORT}/\${SFTP_DIR} /restore/\${MYSQL_DB}-\${1}.sql && gosu mysql mysql -h\${MYSQL_HOST} -P\${MYSQL_PORT} -u\${MYSQL_USER} -p\${MYSQL_PASS} < /restore/\${MYSQL_DB}-\${1}.sql ;then
		echo "   Restore succeeded"
	else
		echo "   Restore failed"
	fi
else
	echo "=> Restore database from \$1"
	if gunzip -c \$1 | exec gosu mysql mysql -h\${MYSQL_HOST} -P\${MYSQL_PORT} -u\${MYSQL_USER} -p\${MYSQL_PASS} ;then
		echo "   Restore succeeded"
	else
		echo "   Restore failed"
	fi
fi
echo "=> Done"
EOF
chmod +x /restore.sh

rm -f /restore-file-only.sh
cat <<EOF >> /restore-file-only.sh
#!/bin/bash

# Setting the pass phrase to encrypt the backup files.
export PASSPHRASE=\$DUPLICITY_ENCRYPT_PASSPHRASE

SFTP_USER=${SFTP_USER}
SFTP_HOST=${SFTP_HOST}
SFTP_PORT=${SFTP_PORT}
SFTP_DIR="${SFTP_DIR}"
DUPLICITY_SCHEME="${DUPLICITY_SCHEME:-sftp}"

MYSQL_DB=${MYSQL_DB}

if [[ ! -z \${SFTP_USER} && ! -z \${SFTP_HOST} && ! -z \${SFTP_DIR} ]]; then
	# using pexpect+sftp because of a bug in paramiko backend. 
	# @see https://lists.gnu.org/archive/html/duplicity-talk/2016-10/msg00010.html
	if duplicity --allow-source-mismatch --ssh-options="-oProtocol=2 -oIdentityFile=/root/.ssh/id_rsa" -t \${1} --file-to-restore \${MYSQL_DB}.sql ${DUPLICITY_SCHEME}://\${SFTP_USER}@\${SFTP_HOST}:\${SFTP_PORT}/\${SFTP_DIR} /restore/\${MYSQL_DB}-\${1}.sql ;then
		echo "   Restore succeeded"
	else
		echo "   Restore failed"
	fi
else
	echo "=> Restore database from \$1"
	if gunzip -c \$1 > /restore/\${1}.sql ;then
		echo "   Restore succeeded"
	else
		echo "   Restore failed"
	fi
fi
echo "=> Done"
EOF
chmod +x /restore-file-only.sh

touch /mysql_backup.log
tail -F /mysql_backup.log &

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup.sh
elif [ -n "${INIT_RESTORE_LATEST}" ]; then
    echo "=> Restore lates backup"
    until nc -z $MYSQL_HOST $MYSQL_PORT
    do
        echo "waiting database container..."
        sleep 1
    done
    ls -d -1 /backup/* | tail -1 | xargs /restore.sh
fi

echo "${CRON_TIME} /backup.sh >> /mysql_backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f
