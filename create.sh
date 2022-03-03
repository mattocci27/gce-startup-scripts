#!/bin/sh

# Settings
PROJECT_NAME="silver-spark-121023"
DNS_ZONE_NAME="mattocci-dev"
STARTUP_SCRIPT_URL="https://raw.githubusercontent.com/mattocci27/gce-startup-scripts/master/startupscript.sh"

# Arguments
INSTANCE_NAME="$1"
MACHINE_TYPE="$2"

if test "$INSTANCE_NAME" = ""
then
  echo "[Error] Instance name required." 1>&2
  exit 1
fi

# Download startup script
TEMP=$(mktemp -u)
curl "${STARTUP_SCRIPT_URL}" > "${TEMP}"

# Get Service Account information
SERVICE_ACCOUNT=$(\
  gcloud iam --project "${PROJECT_NAME}" \
    service-accounts list \
    --limit 1 \
    --format "value(email)")

# Create a instance
gcloud beta compute --project "${PROJECT_NAME}" \
  instances create "${INSTANCE_NAME}" \
  --zone "us-central1-a" \
  --machine-type "${MACHINE_TYPE}" \
  --maintenance-policy "MIGRATE" \
  --service-account "${SERVICE_ACCOUNT}" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --min-cpu-platform "Automatic" \
  --image-project ubuntu-os-cloud \
  --image-family ubuntu-2004-lts \
  --boot-disk-size "60" \
  --boot-disk-type "pd-standard" \
  --boot-disk-device-name "${INSTANCE_NAME}" \
  --metadata dnsZoneName="${DNS_ZONE_NAME}",startup-script-url="${STARTUP_SCRIPT_URL}" \
  --tags "http-server"
