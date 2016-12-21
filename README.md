# mysql-backup

This image runs mysqldump to backup data using cronjob to folder `/backup`

## Usage:

    docker run -d \
        --env MYSQL_HOST=mysql.host \
        --env MYSQL_PORT=27017 \
        --env MYSQL_USER=admin \
        --env MYSQL_PASS=password \
        --volume host.folder:/backup \
        --name tutum-backup \
        tutum/mysql-backup

Moreover, if you link `tutum/mysql-backup` to a mysql container(e.g. `tutum/mysql`) with an alias named mysql, this image will try to auto load the `host`, `port`, `user`, `pass` if possible.

    docker run -d -p 27017:27017 -p 28017:28017 -e MYSQL_PASS="mypass" --name mysql tutum/mysql
    docker run -d --link mysql:mysql -v host.folder:/backup tutum/mysql-backup

## Parameters

    TIMEZONE        e.g. Europe/Moscow
    MYSQL_HOST      the host/ip of your mysql database
    MYSQL_PORT      the port number of your mysql database
    MYSQL_USER      the username of your mysql database
    MYSQL_PASS      the password of your mysql database
    MYSQL_DB        the database name to dump. Default: `--all-databases`
    EXTRA_OPTS      the extra options to pass to mysqldump command
    CRON_TIME       the interval of cron job to run mysqldump. `0 0 * * *` by default, which is every day at 00:00
    MAX_BACKUPS     the number of backups to keep. When reaching the limit, the old backup will be discarded. No limit by default
    INIT_BACKUP     if set, create a backup when the container starts
    INIT_RESTORE_LATEST if set, restores latest backup

## Duplicity over sftp parameters

	SFTP_USER                        user to connect over sftp
	SFTP_HOST                        host to connect to by sftp
	SFTP_PORT                        port to connect to by sftp
	SFTP_DIR                         remote directory to place files over sftp
	DUPLICITY_EXTRA_OPTS             usefull value: --full-if-older-than 1M --allow-source-mismatch
	DUPLICITY_ENCRYPT_PASSPHRASE     the encryption passphrase. keep it in a secret

## Usage with duplicity over sftp

    mkdir -p /root/.cache/duplicity
    docker run -d \
        --env MYSQL_HOST=mysql.host \
        --env MYSQL_PORT=27017 \
        --env MYSQL_USER=admin \
        --env MYSQL_PASS=password \
        --env MYSQL_DB=mydatabase \
        --env EXTRA_OPTS=--skip-lock-tables --single-transaction --flush-logs --hex-blob --master-data=2 \
        --env CRON_TIME=0 6 * * * \
        --env INIT_BACKUP=1 \
        --env MAX_BACKUPS=30 \
        --env TIMEZONE=Europe/Moscow \
        --env SFTP_USER=username \
        --env SFTP_HOST=12.34.56.78 \
        --env SFTP_PORT=22 \
        --env SFTP_DIR=backup/ \
        --env DUPLICITY_EXTRA_OPTS=--full-if-older-than 1M --allow-source-mismatch \
        --env DUPLICITY_ENCRYPT_PASSPHRASE=12345676543212345676543234567654 \
        --volume /backup:/backup \
        --volume /restore:/restore \
        --volume /root/.ssh:/root/.ssh \
        --volume /root/.cache/duplicity:/root/.cache/duplicity \
        --name tutum-backup \
        tutum/mysql-backup

You need to connect to the backup server at least once from your host system in order to have a valid record for it in the known_hosts file.

On your host machine run this command and press Enter for all questions:

    ssh-keygen

It would generate `/root/.ssh/id_rsa` and `/root/.ssh/id_rsa.pub` files.

Then copy this pub key to the backup server. Be sure to allow password access first.

    cd /root/.ssh
    ssh-copy-id -p 22 -i id_rsa.pub username@12.34.56.78

> Not forget to disallow password authentication on the backup server after pub key copying.

It would ask for your username's password. if this command complete, try to connect:

    sftp -P 22 username@12.34.56.78

If this command succeeds and have not asked you for password, then you can be sure this image would function too.

Use this [Guide](www.jscape.com/blog/setting-up-sftp-public-key-authentication-caommand-line) if you need more details about sftp configuration.

## Restore from a backup

See the list of backups, you can run:

    docker exec tutum-backup ls /backup
    
> Note that `tutum-backup` is a docker container name assigned previously with `--name` option.

To restore database from a certain backup, simply run:

    docker exec tutum-backup /restore.sh /backup/2015.08.06.171901

## Restore from a backup if using duplicity

To restore database from a yesterday backup, simply run:

    docker exec tutum-backup /restore.sh 1D

If you want restore only sql dump file without replacing actual database state, do it with:

    docker exec tutum-backup /restore-file-only.sh 1D

if you have used same options for backup container startup as in the example above, 
after executing it you would find file named /restore/mydatabase-1D.sql restored.

Instead of 1D you can use 1h for hours, 15m for minutes, 1W for weeks or 1Y for years.
You can use an exact date in a format like YYYY/MM/DD. See the full list of formats there:
[Duplicity Time Formats](http://duplicity.nongnu.org/duplicity.1.html#sect8)

If you have used your backup server for backup from several servers, e.g. `master` and `slave`, and defined the environment variable `SFTP_DIR` as `backup/1d` on `master` and to `backup/15m` on `slave`, you can use this comand to restore master backup on a slave:

     docker exec tutum-backup /bin/bash -c "export SFTP_DIR=backup/1d && export MYSQL_USER=root && export MYSQL_PASS=123456 && /restore.sh 1D"
