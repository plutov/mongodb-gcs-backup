# mongodb-gcs-backup

This project aims to provide a simple way to perform a MongoDB server/db backup using `mongo-tools` and to upload it to Google Cloud Storage. It was greatly inspired from [`takemetour/docker-mongodb-gcs-backup`](https://github.com/takemetour/docker-mongodb-gcs-backup).

We provide a kubernetes support thanks to the helm chart located in the `chart` folder of this repository.


### Docker image

You can pull the public image from Docker Hub:

    docker pull pltvs/mongodb-gcs-backup:latest


### Configuration

The following table lists the configurable parameters you can set up.

Environment Variable | Required | Default | Description
---------------------|----------|---------|-------------
`GCS_BUCKET` | Yes |  | The bucket you want to upload the backup archive to.
`MONGODB_HOST` | No | `localhost` | The MongoDB server host.
`MONGODB_PORT` | No | `27017` | The MongoDB port.
`MONGODB_DB` | No |  | The database to backup. By default, a backup of all the databases will be performed.
`SLACK_ALERTS` | No |  | `true` if you want to send Slack alerts in case of failure.
`SLACK_WEBHOOK_URL` | No |  | The Incoming WebHook URL to use to send the alerts.
`SLACK_CHANNEL` | No |  | The channel to send Slack messages to.
`SLACK_USERNAME` | No |  | The user to send Slack messages as.

You must set all of these variables within your `values.yaml` file under the `env` dict key.

### Usage

#### Run within Kubernetes

##### Installing the Chart

To install the chart with the release name my-release within you Kubernetes cluster:

    $ helm install --name my-release chart/mongodb-gcs-backup

The command deploys the chart on the Kubernetes cluster in the default namespace. The configuration section lists the parameters that can be configured during installation.


##### Uninstalling the Chart

To uninstall/delete the my-release deployment:

    $ helm delete my-release

The command removes all the Kubernetes components associated with the chart and deletes the release.


### Authenticate with GCS

#### Using the gcloud CLI

If you are running the script locally, the easiest solution is to sign in to the google account associated with your Google Cloud Storage data:

    gcloud init --console-only

More information on how to setup gsutil locally [here](https://cloud.google.com/storage/docs/gsutil_install).

#### Using a service account within Kubernetes

You can create a [service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts) with the required roles to write to GCS attached.

To use the resulting JSON key file within Kubernetes you can create a secret from it by running the following command:

      kubectl create secret generic mongodb-gcs-backup \
      --from-file=credentials.json=/path/to/your/key.json

Then you will need to specify this secret name via the `--set secretName=<your_secret_name>` argument to the `helm install` command or by specifying it directly in your `values.yaml` file (by default, the secret name is set to `mongodb-gcs-backup`). The key file will be mounted by default under `/secrets/gcp/credentials.json` and the `GCS_KEY_FILE_PATH` variable should point to it.
