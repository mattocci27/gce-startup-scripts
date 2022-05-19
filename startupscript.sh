#!/bin/sh

USERNAME="mattocci"
DNS_ZONE_NAME="mattocci-dev"
ZONE="mattocci.dev"
#DNS_ZONE_NAME=$(gcloud compute project-info describe --format "value(dnsZoneName)")
#ZONE=$(gcloud dns record-sets list --zone ${DNS_ZONE_NAME} --limit 1 --format "value(name)")

INITIALIZED_FLAG=".startup_script_initialized"

main()
{

  if test -e $INITIALIZED_FLAG
  then
    # Startup Scripts
    tell_my_ip_address_to_dns
    update
  else
    # Only first time
    sudo apt update
    sudo apt install -y dnsutils
    tell_my_ip_address_to_dns
    setup
    touch $INITIALIZED_FLAG
  fi
}

# Installation and settings
setup(){
  # Foundamental tools
  sudo apt update
  sudo apt upgrade -y
  sudo apt install -y build-essential \
    git \
    wget \
    peco \
    fzf \
    xsel \
    openvpn \
    zsh \
    tmux \
    mosh \
    tree \
    ranger \
    neovim \
    curl \
    cargo \
    stow \
    nodejs \
    npm  \
    software-properties-common

  # nodejs
  npm install nodemailer
  npm install request

  # Krypton CLI for key management
  curl -L https://krypt.co/kr | sh

  # R
  sudo apt install -y dirmngr \
    software-properties-common

  wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc

  sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

  sudo apt update
  sudo apt install -y r-base

  echo "Installing python..."
  sudo apt install -y \
    libpython3-dev \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-virtualenv \
    docker-compose


  echo "Installing docker..."
  # docker 
  sudo apt install -y docker.io

  sudo usermod -aG docker $USER


  # Git
  sudo -i -u "${USERNAME}" git config --global user.name "Masatoshi Katabuchi"
  sudo -i -u "${USERNAME}" git config --global user.email "mattocci27@gmail.com"

  # dotfiles
  sudo -u ${USERNAME} bash -c \
    'git clone git://github.com/mattocci27/dotfiles.git \
    $HOME/dotfiles; \
    cd $HOME/dotfiles; \
    bash scripts/deploy.sh; \
    cd'
 
  # rust 
  cargo install exa ytop bat fd ripgrep gitui

  # poetry
  curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -

  # swap
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
}

# Update on each startup except the first time
update()
{
  sudo apt update
  sudo apt upgrade
  kr upgrade
}

tell_my_ip_address_to_dns()
{
  # Get the hostname of the instance
  HOSTNAME=$(hostname)

  # Get the ip address which is used last time
  LAST_PUBLIC_ADDRESS=$(host "${HOSTNAME}.e.${ZONE}" | sed -rn 's@^.* has address @@p')
  LAST_PRIVATE_ADDRESS=$(host "${HOSTNAME}.i.${ZONE}" | sed -rn 's@^.* has address @@p')

  # Get the current public ip address via Metadata API
  METADATA_SERVER="http://metadata.google.internal/computeMetadata/v1"
  QUERY="instance/network-interfaces/0/access-configs/0/external-ip"
  PUBLIC_ADDRESS=$(curl "${METADATA_SERVER}/${QUERY}" -H "Metadata-Flavor: Google")
  
  # Get the current local ip address
  PRIVATE_ADDRESS=$(hostname -i)

  # Update Cloud DNS
  TEMP=$(mktemp -u)
  gcloud dns record-sets transaction start -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}"
  if test "$LAST_PUBLIC_ADDRESS" != ""
  then
    gcloud dns record-sets transaction remove -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
      --name "${HOSTNAME}.e.${ZONE}" --ttl 300 --type A "$LAST_PUBLIC_ADDRESS"
  fi
  gcloud dns record-sets transaction add -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
    --name "${HOSTNAME}.e.${ZONE}" --ttl 300 --type A "$PUBLIC_ADDRESS"
  
  if test "$LAST_PRIVATE_ADDRESS" != ""
  then
    gcloud dns record-sets transaction remove -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
      --name "${HOSTNAME}.i.${ZONE}" --ttl 300 --type A "$LAST_PRIVATE_ADDRESS"
  fi
  gcloud dns record-sets transaction add -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}" \
    --name "${HOSTNAME}.i.${ZONE}" --ttl 300 --type A "$PRIVATE_ADDRESS"
  gcloud dns record-sets transaction execute -z "${DNS_ZONE_NAME}" --transaction-file="${TEMP}"
}

main
