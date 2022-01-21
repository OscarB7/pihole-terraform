#!/bin/sh

# get server wg keys
if [[ -z ${WG_SERVER_PRIVATE_KEY} ]]; then
    umask 077; wg genkey | tee server.privatekey | wg pubkey > server.publickey
else
    umask 077; echo "$WG_SERVER_PRIVATE_KEY" | tee server.privatekey | wg pubkey > server.publickey
fi
wg_server_public_key=`cat server.publickey`

# get client wg keys
if [[ -z ${WG_CLIENT_PUBLIC_KEY} ]]; then
    umask 077; wg genkey | tee client.privatekey | wg pubkey > client.publickey
    wg_client_private_key=`cat client.privatekey`
    wg_client_public_key=`cat client.publickey`
else
    wg_client_private_key='CLIENT_WIREGUARD_PRIVATE_KEY'
    wg_client_public_key=${WG_CLIENT_PUBLIC_KEY};\
fi

# create wg server configuration
echo "[Interface]" >>wg0.conf
echo "PrivateKey = `cat server.privatekey`" >>wg0.conf
echo "ListenPort = ${WG_SERVER_PORT}" >>wg0.conf
echo "[Peer]" >>wg0.conf
echo "PublicKey = ${wg_client_public_key}" >>wg0.conf
echo "AllowedIPs = ${WG_CLIENT_IP}" >>wg0.conf

# create network interface
ip link add wg0 type wireguard
ip addr add ${WG_SERVER_IP} dev wg0
ip link set wg0 up

# configure and start wg server
wg setconf wg0 wg0.conf
wg

# skip this section if pihole_ip has a value already
if [[ -z $pihole_ip ]]; then
    # get Pi-hole IP address
    while [[ -z $pihole_ip ]]; do
        if timeout 5 ping -c 1 -W 2 ${DNS_CONTAINER_NAME} &>/dev/null; then
            pihole_ip=`ping -c 1 -W 2 ${DNS_CONTAINER_NAME} | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | head -n 1`
        fi
        echo "cannot resolve '${DNS_CONTAINER_NAME}' yet..."
        sleep 1
    done
    echo "Pi-hole IP: $pihole_ip"
fi

# get the name of the docker network interface
docker_net_if=`ip r | grep -o "dev [^ ]*" | cut -d ' ' -f 2 | sort -u | grep -v wg0`

# add iptables rules to forward traffic to Pi-hole
iptables -t nat -A PREROUTING -d ${pihole_ip} -j ACCEPT -m comment --comment "Accept inbound traffic for Pi-hole"
iptables -t nat -A POSTROUTING -o ${docker_net_if} -j MASQUERADE -m comment --comment "Allow outbound traffic to the docker network"

# get public IP of the wg server
server_public_ip=`timeout 2 wget -q -O - https://ifconfig.co/ip`

# print client wg configuration
echo -e "\nclient WG configuration file:"
echo "----- START -----"
echo "[Interface]"
echo "PrivateKey = ${wg_client_private_key}"
echo "Address = ${WG_CLIENT_IP}"
echo "DNS = ${pihole_ip}"
echo ""
echo "[Peer]"
echo "PublicKey = ${wg_server_public_key}"
echo "AllowedIPs = ${WG_SERVER_IP}, ${pihole_ip}/24"
echo "Endpoint = ${server_public_ip}:${WG_SERVER_PORT}"
echo "----- END -----"
echo "Note: endpoint port ${WG_SERVER_PORT} may be different. Check the value of WG_PORT env variable."


sleep infinity
