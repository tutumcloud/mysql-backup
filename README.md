# mysql-aws-backup

This image runs mysqldump to backup data using cronjob to Amazon S3, it can also restore data from an S3 backup.

## Usage:

    docker run -d \
        --env MYSQL_HOST=mysql.host \
        --env MYSQL_PORT=27017 \
        --env MYSQL_USER=admin \
        --env MYSQL_PASS=password \
        --env MYSQL_DB=db \
        --env AWS_ACCESS_KEY_ID=key \	
        --env AWS_DEFAULT_REGION=region \		
        --env AWS_SECRET_ACCESS_KEY=access_key \
        --env BACKUP_NAME=name \
        --env CRON_TIME=time \
        --env S3_BUCKET_NAME=bucket_name \
        mysql-aws-backup

Moreover, if you link `mysql-aws-backup` to a mysql container(e.g. `mysql`) with an alias named mysql, this image will try to auto load the `host`, `port`, `user`, `pass` if possible.

## Parameters

    MYSQL_HOST          the host/ip of your mysql database
    MYSQL_PORT          the port number of your mysql database
    MYSQL_USER          the username of your mysql database
    MYSQL_PASS          the password of your mysql database
    MYSQL_DB            the database name to dump. Default: `--all-databases`
    EXTRA_OPTS          the extra options to pass to mysqldump command
    CRON_TIME           the interval of cron job to run mysqldump. `0 0 * * *` by default, which is every day at 00:00
    AWS_ACCESS_KEY_ID	set the AWS access key
    AWS_DEFAULT_REGION	set an aws region to use	
    AWS_SECRET_ACCESS_KEY set your secret access key
    BACKUP_NAME         the name to be used for the backup
    S3_BUCKET_NAME      S3 bucket name
    RESTORE             if set to true, it will restore latest backup

## Restore from a backup

To restore database from a certain backup, simply run:

    docker exec mysql-aws-backup /restore_latest.sh
