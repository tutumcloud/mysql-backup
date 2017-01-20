FROM ubuntu:trusty
MAINTAINER Stephen Pope <spope@projectricochet.com>

RUN apt-get update && \
    apt-get install -y --no-install-recommends mysql-client && \
    apt-get install -y python-pip && pip install awscli && \
    mkdir /backup

ENV RESTORE=false

ADD run.sh /run.sh
ADD backup.sh /backup.sh
ADD restore.sh /restore.sh
ADD restore_latest.sh /restore_latest.sh

RUN chmod +x *.sh

HEALTHCHECK --interval=5s --timeout=3s CMD pgrep cron || exit 1

CMD ["/run.sh"]
