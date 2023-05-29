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
echo "{ \"default-address-pools\": [ {\"base\":\"${DOCKER_NETWORK_RANGE:-10.7.0.0/16}\",\"size\":24} ] }" > /etc/docker/daemon.json

## Install Docker
apt-get remove docker docker-engine docker.io containerd runc
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
host_details="$(uname -s)-$(uname -m)"
if [[ -z $DOCKER_COMPOSE_VERSION ]]; then
    docker_compose_version=`curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4`
else
    docker_compose_version="v$DOCKER_COMPOSE_VERSION"
fi
curl -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-${host_details,,}" -o /usr/local/bin/docker-compose
chmod -v +x /usr/local/bin/docker-compose

mkdir -vp ./docker-vol/{etc-pihole,etc-dnsmasq.d}

# create self signed certificate
mkdir -p proxy/certs
openssl req -newkey rsa:2048 -x509 -nodes -sha256 -keyout proxy/certs/private-key.pem -out proxy/certs/public-key.crt -subj "/CN=home.local/O=Home/C=US"

## start services
docker-compose up -d

## cron jobs to update server and containers
cat << EOF > /tmp/update_jobs
0 3 * * 6    export DEBIAN_FRONTEND=noninteractive && apt update && apt -o Dpkg::Options::="--force-confold" upgrade -q -y && apt -o Dpkg::Options::="--force-confold" dist-upgrade -q -y && apt autoremove -q -y
0 4 * * 6    cd /opt/pihole-terraform/ && docker-compose pull pihole && docker-compose up --force-recreate --build -d && docker image prune -f
EOF

cp /tmp/update_jobs /etc/cron.d/update_jobs
cat /etc/cron.d/update_jobs | crontab -
