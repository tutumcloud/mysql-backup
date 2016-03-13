FROM ubuntu:trusty
MAINTAINER Stephen Pope <spope@projectricochet.com>

RUN apt-get update && \
    apt-get install -y --no-install-recommends mysql-client && \
    apt-get install -y python-pip && pip install awscli && \
    mkdir /backup

ENV MAX_BACKUPS=1 \
    PATHS_TO_BACKUP=/backup \
    CRON_TIME="0 0 * * *" \
    MYSQL_DB="--all-databases" \
    RESTORE=false

ADD run.sh /run.sh
ADD backup.sh /backup.sh
ADD restore.sh /restore.sh
ADD restore_latest.sh /restore_latest.sh

RUN chmod +x *.sh

#VOLUME ["/backup"]

CMD ["/run.sh"]
