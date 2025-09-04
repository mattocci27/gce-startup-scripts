#!/bin/sh

# Enable logging but don't exit on error immediately (we handle errors explicitly)
set +e

USERNAME="mattocci"
DNS_ZONE_NAME="mattocci-dev"
ZONE="mattocci.dev"
#DNS_ZONE_NAME=$(gcloud compute project-info describe --format "value(dnsZoneName)")
#ZONE=$(gcloud dns record-sets list --zone ${DNS_ZONE_NAME} --limit 1 --format "value(name)")

INITIALIZED_FLAG=".startup_script_initialized"
LOG_FILE="/var/log/startup-script.log"

# Logging function
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  # Try to write to log file, fallback to syslog if permission denied
  if ! echo "$msg" >> "$LOG_FILE" 2>/dev/null; then
    logger -t startup-script "$*"
  fi
}

# Error handling function
handle_error() {
  local exit_code=$?
  log "ERROR: Command failed with exit code $exit_code at line $1"
  exit $exit_code
}

# Set up error trap
trap 'handle_error $LINENO' ERR

main()
{
  log "Starting startup script execution"
  log "Initial working directory: $(pwd)"
  log "Script running as user: $(whoami)"
  log "Root filesystem check: $(ls -la / | head -3)"

  if test -e "$INITIALIZED_FLAG"
  then
    # Startup Scripts
    log "Instance already initialized, running update tasks"
    tell_my_ip_address_to_dns
    update
  else
    # Only first time
    log "First-time setup starting"
    sudo apt-get update || { log "Failed to update package lists"; exit 1; }
    sudo apt-get install -y dnsutils || { log "Failed to install dnsutils"; exit 1; }
    tell_my_ip_address_to_dns
    setup
    touch "$INITIALIZED_FLAG"
    log "First-time setup completed"
  fi

  log "Startup script execution completed successfully"
}

# Installation and settings
setup(){
  log "Starting package installation and system setup"

  # Ensure we're in root directory to avoid any path confusion
  cd / || { log "Warning: Failed to change to root directory"; }
  log "Setup working directory: $(pwd)"

  # Fundamental tools
  log "Updating package lists and upgrading system"
  sudo apt-get update || { log "Failed to update package lists"; exit 1; }
  sudo apt-get upgrade -y || { log "Failed to upgrade system packages"; exit 1; }
  log "Installing essential development tools"
  sudo apt-get install -y xsel \
    ca-certificates \
    build-essential \
    golang-go \
    neovim \
    peco \
    fzf \
    zsh \
    tmux \
    tree \
    make \
    curl \
    wget \
    cargo \
    neofetch \
    ripgrep \
    libopenblas-dev \
    snapd \
    nodejs \
    stow \
    bat \
    eza \
    openssh-server \
    pipx || { log "Failed to install essential packages"; exit 1; }

  # Akamai CLI installation
  log "Installing Akamai CLI"
  ARCH=$(dpkg --print-architecture)
  log "Detected architecture: $ARCH"

  # Check if binary is available for this architecture
  # Note: Akamai CLI only provides Linux binaries for AMD64, not ARM64
  if test "$ARCH" = "amd64"; then
    CLI_ARCH="linuxamd64"
    log "Using Akamai CLI binary: akamai-v2.0.2-${CLI_ARCH}"
    
    # Try binary download for AMD64
    if curl -fsSL "https://github.com/akamai/cli/releases/download/v2.0.2/akamai-v2.0.2-${CLI_ARCH}" -o /tmp/akamai; then
      log "Successfully downloaded Akamai CLI binary"
      sudo chmod +x /tmp/akamai
      sudo mv /tmp/akamai /usr/local/bin/akamai
      log "Akamai CLI binary installation completed"

      # Verify installation
      if /usr/local/bin/akamai --version >/dev/null 2>&1; then
        AKAMAI_VERSION=$(/usr/local/bin/akamai --version 2>/dev/null || echo "unknown")
        log "Akamai CLI verified successfully - Version: $AKAMAI_VERSION"
      else
        log "Warning: Akamai CLI verification failed"
      fi
    else
      log "Warning: Failed to download Akamai CLI binary for AMD64"
    fi
  fi
  
  # For ARM64 or if AMD64 binary download failed, try source compilation
  if ! command -v akamai >/dev/null 2>&1; then
    log "Akamai CLI not found, attempting source compilation"
    if command -v go >/dev/null 2>&1; then
      log "Go compiler found, compiling Akamai CLI from source"
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR" || { log "Warning: Failed to create temp directory"; cd /; return; }

      if git clone https://github.com/akamai/cli.git; then
        log "Successfully cloned Akamai CLI repository"
        cd cli || { log "Warning: Failed to enter cli directory"; cd / && rm -rf "$TEMP_DIR"; return; }

        log "Building Akamai CLI from source for architecture: $ARCH"
        # Map architecture for Go build
        GO_ARCH="$ARCH"
        if test "$ARCH" = "arm64"; then
          GO_ARCH="arm64"
        elif test "$ARCH" = "amd64"; then
          GO_ARCH="amd64"
        fi
        
        if GOOS=linux GOARCH="$GO_ARCH" CGO_ENABLED=0 \
           go build -trimpath -ldflags "-s -w" -o akamai ./cli; then
          log "Successfully built Akamai CLI from source"
          sudo install -m755 akamai /usr/local/bin/akamai
          log "Akamai CLI source installation completed"

          if /usr/local/bin/akamai --version >/dev/null 2>&1; then
            AKAMAI_VERSION=$(/usr/local/bin/akamai --version 2>/dev/null || echo "unknown")
            log "Akamai CLI verified successfully - Version: $AKAMAI_VERSION"
          else
            log "Warning: Akamai CLI verification failed after source build"
          fi
        else
          log "Warning: Failed to build Akamai CLI from source"
        fi
      else
        log "Warning: Failed to clone Akamai CLI repository"
      fi

      # Clean up temp directory
      cd / && rm -rf "$TEMP_DIR"
    else
      log "Warning: Go compiler not available, Akamai CLI installation skipped"
    fi
  fi

  log "Installing Docker"
  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl || { log "Failed to install Docker prerequisites"; exit 1; }
  sudo install -m 0755 -d /etc/apt/keyrings

  if sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { log "Failed to install Docker"; exit 1; }
    sudo usermod -aG docker "$USER"
    log "Docker installation completed"
  else
    log "Warning: Failed to download Docker GPG key"
  fi

  log "Installing Poetry"
  # Install poetry using the official installer
  if curl -sSL https://install.python-poetry.org | python3 -; then
    # Add poetry to PATH for all users
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/environment
    log "Poetry installation completed"
  else
    log "Warning: Failed to install Poetry"
  fi

  # Install dotfiles
  log "Installing dotfiles"
  log "Current working directory: $(pwd)"
  log "USERNAME: $USERNAME"
  log "Home directory exists: $(test -d /home/$USERNAME && echo 'yes' || echo 'no')"
  log "Home directory contents: $(ls -la /home/$USERNAME 2>/dev/null | head -5 || echo 'failed to list')"

  # Ensure we're in the correct directory
  if test -d "/home/$USERNAME"; then
    if sudo -u "$USERNAME" sh -c "cd /home/$USERNAME && pwd && git clone https://github.com/mattocci27/dotfiles.git 2>/dev/null || true"; then
      if sudo -u "$USERNAME" sh -c "cd /home/$USERNAME/dotfiles && ./install.sh 2>/dev/null || true"; then
        log "Dotfiles installation completed"
      else
        log "Warning: Failed to install dotfiles"
      fi
    else
      log "Warning: Failed to clone dotfiles repository"
    fi
  else
    log "Warning: User home directory /home/$USERNAME does not exist"
  fi

  log "Setup completed successfully"
}

# Update on each startup except the first time
update()
{
  log "Running system updates"
  sudo apt-get update || log "Warning: apt update failed"
  sudo apt-get upgrade -y || log "Warning: apt upgrade failed"

  # Only run kr upgrade if kr is installed
  if command -v kr > /dev/null 2>&1; then
    kr upgrade || log "Warning: kr upgrade failed"
  else
    log "Warning: kr command not found, skipping kr upgrade"
  fi

  log "System updates completed"
}

tell_my_ip_address_to_dns()
{
  log "Updating DNS records"

  # Get the hostname of the instance
  HOSTNAME=$(hostname)
  log "Instance hostname: $HOSTNAME"

  # Get the ip address which is used last time
  LAST_PUBLIC_ADDRESS=$(host "${HOSTNAME}.e.${ZONE}" 2>/dev/null | sed -rn 's@^.* has address @@p' || true)
  LAST_PRIVATE_ADDRESS=$(host "${HOSTNAME}.i.${ZONE}" 2>/dev/null | sed -rn 's@^.* has address @@p' || true)

  # Get the current public ip address via Metadata API
  METADATA_SERVER="http://metadata.google.internal/computeMetadata/v1"
  QUERY="instance/network-interfaces/0/access-configs/0/external-ip"
  PUBLIC_ADDRESS=$(curl -s "${METADATA_SERVER}/${QUERY}" -H "Metadata-Flavor: Google" || { log "Warning: Failed to get public IP"; echo ""; })

  # Get the current local ip address
  PRIVATE_ADDRESS=$(hostname -i 2>/dev/null || { log "Warning: Failed to get private IP"; echo ""; })

  log "Current public IP: $PUBLIC_ADDRESS"
  log "Current private IP: $PRIVATE_ADDRESS"

  # Update Cloud DNS only if we have valid IP addresses
  if test -n "$PUBLIC_ADDRESS" && test -n "$PRIVATE_ADDRESS"; then
    TEMP=$(mktemp)
    trap 'rm -f "$TEMP"' EXIT

    if gcloud dns record-sets transaction start -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" 2>/dev/null; then
      # Remove old public address record if it exists
      if test -n "$LAST_PUBLIC_ADDRESS" && test "$LAST_PUBLIC_ADDRESS" != "$PUBLIC_ADDRESS"; then
        gcloud dns record-sets transaction remove -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
          --name "${HOSTNAME}.e.${ZONE}" --ttl 300 --type A "$LAST_PUBLIC_ADDRESS" 2>/dev/null || true
      fi

      # Add new public address record
      gcloud dns record-sets transaction add -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
        --name "${HOSTNAME}.e.${ZONE}" --ttl 300 --type A "$PUBLIC_ADDRESS" 2>/dev/null || true

      # Remove old private address record if it exists
      if test -n "$LAST_PRIVATE_ADDRESS" && test "$LAST_PRIVATE_ADDRESS" != "$PRIVATE_ADDRESS"; then
        gcloud dns record-sets transaction remove -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
          --name "${HOSTNAME}.i.${ZONE}" --ttl 300 --type A "$LAST_PRIVATE_ADDRESS" 2>/dev/null || true
      fi

      # Add new private address record
      gcloud dns record-sets transaction add -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
        --name "${HOSTNAME}.i.${ZONE}" --ttl 300 --type A "$PRIVATE_ADDRESS" 2>/dev/null || true

      # Execute the transaction
      if gcloud dns record-sets transaction execute -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" 2>/dev/null; then
        log "DNS records updated successfully"
      else
        log "Warning: Failed to execute DNS transaction"
        gcloud dns record-sets transaction abort -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" 2>/dev/null || true
      fi
    else
      log "Warning: Failed to start DNS transaction"
    fi
  else
    log "Warning: Could not determine IP addresses, skipping DNS update"
  fi
}

main
