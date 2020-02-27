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
  sudo apt install -y build-essential
  sudo apt install -y python-dev
  sudo apt install -y git
  sudo apt install -y wget
  sudo apt install -y peco
  sudo apt install -y xsel
  sudo apt install -y openvpn
  sudo apt install -y zsh
  sudo apt install -y tmux
  sudo apt install -y exa
  sudo apt install -y ripgrep
  sudo apt install -y mosh
  sudo apt install -y tree
  sudo apt install -y ranger
  sudo apt install -y neovim
  sudo apt install -y curl
  sudo apt install -y software-properties-common

  # nodejs
  curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
  sudo apt install -y nodejs
  npm install nodemailer
  npm install request

  # Krypton CLI for key management
  curl -L https://krypt.co/kr | sh

  # docker
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  sudo apt-key fingerprint 0EBFCD88
  sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/debian \
     $(lsb_release -cs) \
     stable"
  sudo apt update
  sudo apt -y install docker-ce docker-ce-cli containerd.io

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
    sh ./setup_gce.sh; \
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
