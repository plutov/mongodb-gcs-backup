FROM mongo:xenial

RUN apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y curl && \
  apt-get install -y python-pip && \
  pip install gsutil

ADD ./backup.sh /mongodb-gcs-backup/backup.sh
WORKDIR /mongodb-gcs-backup

RUN chmod +x /mongodb-gcs-backup/backup.sh

ENTRYPOINT ["/mongodb-gcs-backup/backup.sh"]
