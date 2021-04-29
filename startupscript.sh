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
  #sudo apt update
  sudo apt install -y build-essential \
    python-dev \
    git \
    wget \
    peco \
    fzf \
    xsel \
    openvpn \
    zsh \
    tmux \
    exa \
    ripgrep \
    mosh \
    tree \
    ranger \
    neovim \
    curl \
    software-properties-common

  # nodejs
  curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
  sudo apt install -y nodejs
  npm install nodemailer
  npm install request

  # Krypton CLI for key management
  curl -L https://krypt.co/kr | sh

  # docker
  sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

 echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update 
  sudo apt install  docker-ce docker-ce-cli containerd.io


  sudo usermod -aG docker mattocci

  # Git
  sudo -i -u "${USERNAME}" git config --global user.name "Masatoshi Katabuchi"
  sudo -i -u "${USERNAME}" git config --global user.email "mattocci27@gmail.com"

  ### Python packages
  sudo apt -y install python-pip python-virtualenv python-numpy python-matplotlib

  # dotfiles
  sudo -u ${USERNAME} bash -c \
    'git clone git://github.com/mattocci27/dotfiles.git \
    $HOME/dotfiles; \
    cd $HOME/dotfiles; \
    ./link_files.sh mkdir; \
    ./link_files.sh links; \
    cd'
 
  # gotop
  git clone --depth 1 https://github.com/cjbassi/gotop /tmp/gotop
  sudo bash /tmp/gotop/scripts/download.sh
  sudo mv gotop /usr/bin/gotop

  # bat
  wget -O /tmp/bat.deb TEMP_DEB https://github.com/sharkdp/bat/releases/download/v0.12.1/bat_0.12.1_amd64.deb
  sudo dpkg -i /tmp/bat.deb
  sudo rm /tmp/bat.deb
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
