#!/bin/sh

# Exit on any error
set -e

# Settings
PROJECT_NAME="silver-spark-121023"
DNS_ZONE_NAME="mattocci-dev"
ZONE="asia-east1-a"
STARTUP_SCRIPT_URL="https://raw.githubusercontent.com/mattocci27/gce-startup-scripts/master/startupscript.sh"
DEFAULT_MACHINE_TYPE="e2-small"
BOOT_DISK_SIZE="60"

# Arguments
INSTANCE_NAME="$1"
MACHINE_TYPE="${2:-$DEFAULT_MACHINE_TYPE}"

# Validation
if test "$INSTANCE_NAME" = ""
then
  echo "[Error] Instance name required." 1>&2
  echo "Usage: $0 <instance-name> [machine-type]" 1>&2
  exit 1
fi

# Check required tools
for tool in gcloud curl; do
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "[Error] Required tool '$tool' not found." 1>&2
    exit 1
  fi
done

# Validate machine type format (basic check)
if ! echo "$MACHINE_TYPE" | grep -qE '^[a-z][0-9]?-[a-z0-9-]+$'; then
  echo "[Warning] Machine type '$MACHINE_TYPE' may not be valid." 1>&2
fi

# Download startup script
TEMP=$(mktemp)
trap 'rm -f "$TEMP"' EXIT

echo "Downloading startup script..."
if ! curl -fsSL "${STARTUP_SCRIPT_URL}" > "${TEMP}"; then
  echo "[Error] Failed to download startup script from ${STARTUP_SCRIPT_URL}" 1>&2
  exit 1
fi

# Verify script was downloaded
if test ! -s "$TEMP"; then
  echo "[Error] Downloaded startup script is empty." 1>&2
  exit 1
fi

# Get Service Account information
echo "Getting service account information..."
SERVICE_ACCOUNT=$(gcloud iam --project "${PROJECT_NAME}" \
  service-accounts list \
  --limit 1 \
  --format "value(email)")

if test "$SERVICE_ACCOUNT" = ""; then
  echo "[Error] No service account found for project ${PROJECT_NAME}." 1>&2
  exit 1
fi

echo "Using service account: $SERVICE_ACCOUNT"

# Create instance
echo "Creating instance '${INSTANCE_NAME}' with machine type '${MACHINE_TYPE}'..."

if ! gcloud compute --project "${PROJECT_NAME}" \
  instances create "${INSTANCE_NAME}" \
  --zone "${ZONE}" \
  --machine-type "${MACHINE_TYPE}" \
  --maintenance-policy "MIGRATE" \
  --service-account "${SERVICE_ACCOUNT}" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --min-cpu-platform "Automatic" \
  --image-project ubuntu-os-cloud \
  --image-family ubuntu-2404-lts \
  --boot-disk-size "${BOOT_DISK_SIZE}" \
  --boot-disk-type "pd-balanced" \
  --boot-disk-device-name "${INSTANCE_NAME}" \
  --metadata "dnsZoneName=${DNS_ZONE_NAME},startup-script-url=${STARTUP_SCRIPT_URL}" \
  --tags "http-server"; then
  echo "[Error] Failed to create instance." 1>&2
  exit 1
fi

echo "Instance '${INSTANCE_NAME}' created successfully in zone '${ZONE}'."
echo "You can SSH to it with: gcloud compute ssh --project=${PROJECT_NAME} --zone=${ZONE} ${INSTANCE_NAME}"
