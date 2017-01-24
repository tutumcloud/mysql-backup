#!/bin/bash

# Get timestamp
: ${BACKUP_SUFFIX:=.$(date +"%Y-%m-%d-%H-%M-%S")}
readonly tarball=$BACKUP_NAME$BACKUP_SUFFIX.tar.gz

# Create a gzip compressed tarball with the volume(s)
tar czf $tarball $BACKUP_TAR_OPTION /backup

# Create bucket, if it doesn't already exist
BUCKET_EXIST=$(/usr/local/bin/aws s3 ls | grep $S3_BUCKET_NAME | wc -l)
if [ $BUCKET_EXIST -eq 0 ]; 
then
  /usr/local/bin/aws s3 mb s3://$S3_BUCKET_NAME
fi

# Upload the backup to S3 with timestamp
/usr/local/bin/aws s3 --region $AWS_DEFAULT_REGION cp $tarball s3://$S3_BUCKET_NAME/$tarball
