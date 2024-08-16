## utils

error_and_exit() {
  local MESSAGE="${1}"
  local HINT="${2}"
  echo ""
  echo "🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥🟥"
  echo ""
  echo "Error \`cloud-run.sh\`"
  echo "===================="
  echo ""
  echo "Message"
  echo "-------"
  echo "$MESSAGE"
  echo ""
  echo "Hint"
  echo "----"
  echo "$HINT"
  echo ""
  echo "/end"
  echo ""
  exit 1
}

## required environment variables

if [[ -z "$GCP_PROJECT_ID" ]]; then
  error_and_exit "\$GCP_PROJECT_ID is not set" "Did you setup a service account?"
fi

if [[ -z "$GCP_SERVICE_ACCOUNT" ]]; then
  error_and_exit "\$GCP_SERVICE_ACCOUNT is not set" "Did you setup a service account?"
fi

if [[ -z "$GCP_SERVICE_ACCOUNT_KEY" ]]; then
  error_and_exit "\$GCP_SERVICE_ACCOUNT_KEY is not set" "Did you setup a service account?"
fi

if [[ -z "$CI_PROJECT_ID" ]]; then
  error_and_exit "\$CI_PROJECT_ID is not set"
fi

if [[ -z "$CI_COMMIT_REF_SLUG" ]]; then
  error_and_exit "\$CI_COMMIT_REF_SLUG is not set"
fi

## optional environment variables

GCP_REGION="${GCP_REGION:-us-central1}"
GCP_CLOUD_RUN_MAX_INSTANCES="${GCP_CLOUD_RUN_MAX_INSTANCES:-100}"
GCP_CLOUD_RUN_MIN_INSTANCES="${GCP_CLOUD_RUN_MIN_INSTANCES:-1}"
GCP_CLOUD_RUN_TIMEOUT="${GCP_CLOUD_RUN_TIMEOUT:-300}"
GCP_CLOUD_RUN_CONCURRENCY="${GCP_CLOUD_RUN_CONCURRENCY:-80}"
GCP_CLOUD_RUN_MEMORY="${GCP_CLOUD_RUN_MEMORY:-512Mi}"
GCP_CLOUD_RUN_CPU="${GCP_CLOUD_RUN_CPU:-1000m}"

## private variables

SERVICE_NAME="gitlab-$CI_PROJECT_ID-$CI_COMMIT_REF_SLUG"
__GCP_SERVICE_ACCOUNT_KEY_PRIVATE_KEY_DATA_FILE_NAME=local-service-account-key-private-key-data.txt
__GCP_SERVICE_ACCOUNT_KEY_FILE_NAME=local-service-account-key-file.json

## cleanup tmp files

rm --force $__GCP_SERVICE_ACCOUNT_KEY_PRIVATE_KEY_DATA_FILE_NAME
rm --force $__GCP_SERVICE_ACCOUNT_KEY_FILE_NAME
rm --force deploy.env
rm --force local-output.log

## extract service account key file

case "$GCP_SERVICE_ACCOUNT_KEY" in
  *privateKeyData*)
    echo "🟩🟩 '.privateKeyData' found"
    echo "$GCP_SERVICE_ACCOUNT_KEY" | jq --raw-output '.privateKeyData' >$__GCP_SERVICE_ACCOUNT_KEY_PRIVATE_KEY_DATA_FILE_NAME
    base64 --decode $__GCP_SERVICE_ACCOUNT_KEY_PRIVATE_KEY_DATA_FILE_NAME >$__GCP_SERVICE_ACCOUNT_KEY_FILE_NAME
    ;;
  *private_key_data*)
    echo "🟩🟩 '.private_key_data' found"
    echo "$GCP_SERVICE_ACCOUNT_KEY" | jq --raw-output '.private_key_data' >$__GCP_SERVICE_ACCOUNT_KEY_FILE_NAME
    ;;
  *)
    error_and_exit "Failed to extract service account key file" "Did you setup a service account?"
    ;;
esac

## gcloud auth and configure

gcloud auth activate-service-account --key-file $__GCP_SERVICE_ACCOUNT_KEY_FILE_NAME || error_and_exit "Failed to activate service account"
gcloud config set project "$GCP_PROJECT_ID" || error_and_exit "Failed to set GCP project"

## gcloud run deploy

gcloud run deploy "$SERVICE_NAME" --quiet --source=. --region="$GCP_REGION" \
  --max-instances="$GCP_CLOUD_RUN_MAX_INSTANCES" --min-instances="$GCP_CLOUD_RUN_MIN_INSTANCES" \
  --timeout="$GCP_CLOUD_RUN_TIMEOUT" \
  --concurrency="$GCP_CLOUD_RUN_CONCURRENCY" \
  --memory="$GCP_CLOUD_RUN_MEMORY" \
  --cpu="$GCP_CLOUD_RUN_CPU" \
  --allow-unauthenticated --format 'value(status.url)' >>local-output.log || error_and_exit "Failed to deploy service"

## generate deploy.env

echo "DYNAMIC_URL=$(cat local-output.log)" >>deploy.env || error_and_exit "Failed to decode service account key"
