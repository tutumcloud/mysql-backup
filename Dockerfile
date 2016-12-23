FROM ubuntu:xenial
MAINTAINER Tutum Labs <support@tutum.co>

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN mkdir -p /var/lib/mysql/ \
	&& groupadd -r mysql \
	&& useradd -r -g mysql -d /var/lib/mysql/ mysql \
	&& chown mysql:mysql /var/lib/mysql \
	&& chmod 700 /var/lib/mysql

# add gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove ca-certificates wget

# gpg: key 5072E1F5: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5

ENV MYSQL_MAJOR 5.7
ENV MYSQL_VERSION 5.7.17-1ubuntu16.04

RUN echo "deb http://repo.mysql.com/apt/ubuntu/ xenial mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list

RUN apt-get update \
	&& apt-get install -y \
		mysql-client="${MYSQL_VERSION}" \
		cron \
		openssh-client \
		python-paramiko \
		python-pexpect \
		duplicity \
		python \
	&& rm -rf /var/lib/apt/lists/*

# timezone
ENV TIMEZONE="Etc/UTC"

ENV CRON_TIME="0 0 * * *" \
    MYSQL_DB="--all-databases"
ADD run.sh /run.sh
VOLUME ["/backup"]

CMD ["/run.sh"]
