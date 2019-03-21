#!/bin/bash

set -o pipefail
set -o errexit
set -o errtrace
set -o nounset
# set -o xtrace

BACKUP_DIR=${BACKUP_DIR:-/tmp}
BOTO_CONFIG_PATH=${BOTO_CONFIG_PATH:-/root/.boto}
AWS_BACKUP_ENABLED=${AWS_BACKUP_ENABLED:-}
AWS_ACCESS_KEY=${AWS_ACCESS_KEY:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
AWS_CONFIG_FOLDER=${AWS_CONFIG_FOLDER:-/root/.aws}
AWS_CONFIG_CREDENTIALS_FILE=${AWS_CONFIG_CREDENTIALS_FILE:-/root/.aws/credentials}
AWS_CONFIG_FILE=${AWS_CONFIG_FILE:-/root/.aws/config}
AWS_BUCKET=${AWS_BUCKET:-}
AWS_REGION=${AWS_REGION:-us-east-2}
AWS_OUTPUT_FORMAT=${AWS_OUTPUT_FORMAT:-json}
GCS_BUCKET=${GCS_BUCKET:-}
GCS_KEY_FILE_PATH=${GCS_KEY_FILE_PATH:-}
MONGODB_HOST=${MONGODB_HOST:-localhost}
MONGODB_PORT=${MONGODB_PORT:-27017}
MONGODB_DB=${MONGODB_DB:-}
MONGODB_USER=${MONGODB_USER:-}
MONGODB_PASSWORD=${MONGODB_PASSWORD:-}
MONGODB_OPLOG=${MONGODB_OPLOG:-}
SLACK_ALERTS=${SLACK_ALERTS:-}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-}
SLACK_CHANNEL=${SLACK_CHANNEL:-}
SLACK_USERNAME=${SLACK_USERNAME:-}
SLACK_ICON=${SLACK_ICON:-}

backup() {
  mkdir -p $BACKUP_DIR
  date=$(date "+%Y-%m-%dT%H:%M:%SZ")
  archive_name="backup-$date.tar.gz"

  cmd_auth_part=""
  if [[ ! -z $MONGODB_USER ]] && [[ ! -z $MONGODB_PASSWORD ]]
  then
    cmd_auth_part="--username=\"$MONGODB_USER\" --password=\"$MONGODB_PASSWORD\""
  fi

  cmd_db_part=""
  if [[ ! -z $MONGODB_DB ]]
  then
    cmd_db_part="--db=\"$MONGODB_DB\""
  fi

  cmd_oplog_part=""
  if [[ $MONGODB_OPLOG = "true" ]]
  then
    cmd_oplog_part="--oplog"
  fi

  cmd="mongodump --host=\"$MONGODB_HOST\" --port=\"$MONGODB_PORT\" $cmd_auth_part $cmd_db_part $cmd_oplog_part --gzip --archive=$BACKUP_DIR/$archive_name"
  echo "starting to backup MongoDB host=$MONGODB_HOST port=$MONGODB_PORT"
  eval "$cmd"
}

upload_to_gcs() {
  if [[ $GCS_KEY_FILE_PATH != "" ]]
  then
cat <<EOF > $BOTO_CONFIG_PATH
[Credentials]
gs_service_key_file = $GCS_KEY_FILE_PATH
[Boto]
https_validate_certificates = True
[GoogleCompute]
[GSUtil]
content_language = en
default_api_version = 2
[OAuth2]
EOF
  fi
  echo "uploading backup archive to GCS bucket=$GCS_BUCKET"
  gsutil cp $BACKUP_DIR/$archive_name $GCS_BUCKET
}

upload_to_s3() {
  if [[ $AWS_BACKUP_ENABLED == "true" ]] 
  then 
    mkdir -p $AWS_CONFIG_FOLDER
      if [[ $AWS_ACCESS_KEY != "" ]] && [[ $AWS_SECRET_ACCESS_KEY != "" ]]
      then 
cat <<EOF > $AWS_CONFIG_CREDENTIALS_FILE
  [default]
  aws_access_key_id= $AWS_ACCESS_KEY
  aws_secret_access_key= $AWS_SECRET_ACCESS_KEY
EOF
cat <<EOF > $AWS_CONFIG_FILE
  [default]
  region= $AWS_REGION
  output= $AWS_OUTPUT_FORMAT
EOF
      fi
    echo "uploading backup archive to AWS bucket=$AWS_BUCKET"
    aws s3 cp $BACKUP_DIR/$archive_name ${AWS_BUCKET}
  fi 
}

send_slack_message() {
  local color=${1}
  local title=${2}
  local message=${3}

  echo 'Sending to '${SLACK_CHANNEL}'...'
  curl --silent --data-urlencode \
    "$(printf 'payload={"channel": "%s", "username": "%s", "link_names": "true", "attachments": [{"author_name": "mongodb-gcs-backup", "title": "%s", "text": "%s", "color": "%s"}]}' \
        "${SLACK_CHANNEL}" \
        "${SLACK_USERNAME}" \
        "${title}" \
        "${message}" \
        "${color}" \
    )" \
    ${SLACK_WEBHOOK_URL} || true
  echo
}

err() {
  err_msg="Something went wrong on line $(caller)"
  echo $err_msg >&2
  if [[ $SLACK_ALERTS == "true" ]]
  then
    send_slack_message "danger" "Error while performing mongodb backup" "$err_msg"
  fi
}

cleanup() {
  rm $BACKUP_DIR/$archive_name
}

trap err ERR
backup
upload_to_gcs
upload_to_s3
cleanup
echo "backup done!"
