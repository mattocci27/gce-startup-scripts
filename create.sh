#!/bin/sh

# Exit on any error
set -e

# Settings
PROJECT_NAME="silver-spark-121023"
DNS_ZONE_NAME="mattocci-dev"
ZONE="asia-east1-a"
STARTUP_SCRIPT_URL="https://raw.githubusercontent.com/mattocci27/gce-startup-scripts/master/startupscript.sh"
BOOT_DISK_SIZE="60"

# Arguments
INSTANCE_NAME="$1"
ARCHITECTURE="${2:-amd}"
MACHINE_TYPE="$3"

# Set defaults based on architecture
if test "$ARCHITECTURE" = "arm"; then
  DEFAULT_MACHINE_TYPE="c4a-standard-2"
  IMAGE_FAMILY="ubuntu-2404-lts-arm64"
  DISK_TYPE="hyperdisk-balanced"
elif test "$ARCHITECTURE" = "amd"; then
  DEFAULT_MACHINE_TYPE="e2-standard-2"
  IMAGE_FAMILY="ubuntu-2404-lts-amd64"
  DISK_TYPE="pd-balanced"
else
  echo "[Error] Invalid architecture '$ARCHITECTURE'. Use 'arm' or 'amd'." 1>&2
  exit 1
fi

# Set machine type default if not provided
MACHINE_TYPE="${MACHINE_TYPE:-$DEFAULT_MACHINE_TYPE}"

# Validation
if test "$INSTANCE_NAME" = ""
then
  echo "[Error] Instance name required." 1>&2
  echo "Usage: $0 <instance-name> [architecture] [machine-type]" 1>&2
  echo "  architecture: 'arm' or 'amd' (default: amd)" 1>&2
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
echo "Creating instance '${INSTANCE_NAME}' with machine type '${MACHINE_TYPE}' (${ARCHITECTURE} architecture)..."

if ! gcloud compute --project "${PROJECT_NAME}" \
  instances create "${INSTANCE_NAME}" \
  --zone "${ZONE}" \
  --machine-type "${MACHINE_TYPE}" \
  --maintenance-policy "MIGRATE" \
  --service-account "${SERVICE_ACCOUNT}" \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --min-cpu-platform "Automatic" \
  --image-project ubuntu-os-cloud \
  --image-family "${IMAGE_FAMILY}" \
  --boot-disk-size "${BOOT_DISK_SIZE}" \
  --boot-disk-type "${DISK_TYPE}" \
  --boot-disk-device-name "${INSTANCE_NAME}" \
  --metadata "dnsZoneName=${DNS_ZONE_NAME},startup-script-url=${STARTUP_SCRIPT_URL}" \
  --tags "http-server"; then
  echo "[Error] Failed to create instance." 1>&2
  exit 1
fi

echo "Instance '${INSTANCE_NAME}' created successfully in zone '${ZONE}'."
echo "You can SSH to it with: gcloud compute ssh --project=${PROJECT_NAME} --zone=${ZONE} ${INSTANCE_NAME}"
