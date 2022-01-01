#!/bin/bash

## Stop dns service
sudo systemctl stop systemd-resolved.service
sudo systemctl disable systemd-resolved.service

cp /etc/resolv.conf /etc/resolv.conf.bckup
cat << EOF | sudo tee /etc/resolv.conf 1>/dev/null
search domain.local
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# load environment variables if needed
[[ -e '.env' ]] && source .env

# set docker network ip range
[[ ! -z $DOCKER_NETWORK_RANGE ]] && echo "{ \"default-address-pools\": [ {\"base\":\"$DOCKER_NETWORK_RANGE\",\"size\":24} ] }" > /etc/docker/daemon.json

## Install Docker
apt-get remove docker docker-engine docker.io containerd runc
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
host_details="$(uname -s)-$(uname -m)"
if [[ -z $DOCKER_COMPOSE_VERSION ]]; then
    docker_compose_version=`curl https://github.com/docker/compose/releases/latest 2>1 | grep -o "v[0-9]*\.[0-9]\.[0-9]"`
else
    docker_compose_version="v$DOCKER_COMPOSE_VERSION"
fi
curl -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-${host_details,,}" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

mkdir ./docker-vol/{etc-pihole,etc-dnsmasq.d}

## start services
docker-compose up -d
