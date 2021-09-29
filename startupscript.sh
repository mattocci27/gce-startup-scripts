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

  # R
  sudo apt install -y dirmngr \
    gnupg \
    apt-transport-https \
    ca-certificates \
    software-properties-common

  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

  sudo add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/'

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
  sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      lsb-release

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io

  sudo usermod -aG docker $USER


  # Git
  sudo -i -u "${USERNAME}" git config --global user.name "Masatoshi Katabuchi"
  sudo -i -u "${USERNAME}" git config --global user.email "mattocci27@gmail.com"

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

  ## after simlinks -- this shuld be done $HOME

  # rust 
  #curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  #cargo install exa ripgrep
 
  #pip install poetry
# 
#  # nvim
#  curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
#      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
#  nvim +PlugInstall +qall
# 
#  # zplug
#  curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
#
#  # tmux
#  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
#
#  # swap
#  fallocate -l 4G /swapfile
#  chmod 600 /swapfile
#  mkswap /swapfile
#  swapon /swapfile
#  echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
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
