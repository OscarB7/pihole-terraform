#!/bin/sh

# ----- default values -----
wg_conf_file='wg0.conf'

wg_client_keys_file='wg_client_keys.txt'
separator_str='_SEPARATOR_'

wg_server_ip_address=$WG_SERVER_IP
wg_server_private_key=$WG_SERVER_PRIVATE_KEY

# ----- get wg keys -----
wg_client_private_key='CLIENT_WIREGUARD_PRIVATE_KEY'
if [[ -n ${WG_KEYS_BASE64} ]]; then
    # save decoded WG_KEYS_BASE64 to wg_client_keys_file
    echo "$WG_KEYS_BASE64" | base64 -d > $wg_client_keys_file
else
    # if WG_KEYS_BASE64 is empty, get keys from specific variables
    if [[ -z ${WG_SERVER_PRIVATE_KEY} ]]; then
        umask 077; wg genkey | tee server.privatekey | wg pubkey > server.publickey
        wg_server_private_key=`cat server.privatekey`
    else
        wg_server_private_key=$WG_SERVER_PRIVATE_KEY
        umask 077; echo "$wg_server_private_key" | tee server.privatekey | wg pubkey > server.publickey
    fi
    wg_server_public_key=`cat server.publickey`

    if [[ -z ${WG_CLIENT_PUBLIC_KEY} ]]; then
        # create wg keys since is WG_CLIENT_PUBLIC_KEY empty
        umask 077; wg genkey | tee client.privatekey | wg pubkey > client.publickey
        wg_client_private_key=`cat client.privatekey`
        wg_client_public_key=`cat client.publickey`
    else
        wg_client_public_key=$WG_CLIENT_PUBLIC_KEY
    fi

    # save wg server and client keys and ip to wg_client_keys_file
    echo "${separator_str}" > $wg_client_keys_file
    echo "0${separator_str}${wg_server_ip_address}${separator_str}${wg_server_public_key}${separator_str}${wg_server_private_key}" >> $wg_client_keys_file
    echo "1${separator_str}${WG_CLIENT_IP}${separator_str}${wg_client_public_key}" >> $wg_client_keys_file
fi


# ----- initial configuration -----

# get public IP of the wg server
server_public_ip=`timeout 2 wget -q -O - https://ifconfig.co/ip`

# # skip this section if pihole_ip has a value already
# if [[ -z $pihole_ip ]]; then
#     # get Pi-hole IP address
#     while [[ -z $pihole_ip ]]; do
#         if timeout 5 ping -c 1 -W 2 ${DNS_CONTAINER_NAME} &>/dev/null; then
#             pihole_ip=`ping -c 1 -W 2 ${DNS_CONTAINER_NAME} | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | head -n 1`
#         fi
#         echo "cannot resolve '${DNS_CONTAINER_NAME}' yet..."
#         sleep 1
#     done
#     echo "Pi-hole IP: $pihole_ip"
# fi


# ----- set up wg config files -----

# get string separator from wg_client_keys_file
separator_str=`sed -i -e '1 w /dev/stdout' -e '1d' $wg_client_keys_file`
echo "separator string: $separator_str"

# read list of clients (each one with pubkey and ip) 
while read -r line; do
    # read line
    line=`echo $line | sed "s|$separator_str| |g"`
    wg_client_i=`echo $line | awk '{print $1}'`
    wg_client_ip_address=`echo $line | awk '{print $2}'`
    wg_client_public_key=`echo $line | awk '{print $3}'`
    if [[ $wg_client_i == 0 ]]; then
        wg_server_ip_address=$wg_client_ip_address
        wg_server_public_key=$wg_client_public_key
        wg_server_private_key=`echo $line | awk '{print $4}'`

        # initialize wg server configuration: wg_conf_file
        echo "[Interface]" > $wg_conf_file
        echo "PrivateKey = ${wg_server_private_key}" >> $wg_conf_file
        echo "ListenPort = ${WG_SERVER_PORT}" >> $wg_conf_file
        continue
    fi

    # add client to wg config file: wg_conf_file
    echo "# wg_client_i: $wg_client_i" >> $wg_conf_file
    echo "[Peer]" >> $wg_conf_file
    echo "PublicKey = ${wg_client_public_key}" >> $wg_conf_file
    echo "AllowedIPs = ${wg_client_ip_address}" >> $wg_conf_file
done < $wg_client_keys_file

# ----- create network interface -----
ip link add wg0 type wireguard
ip addr add ${wg_server_ip_address} dev wg0
ip link set wg0 up
ip route add ${wg_server_ip_address} dev wg0

# ----- set up iptables -----

# get the name of the docker network interface
docker_net_if=`ip r | grep -o "dev [^ ]*" | cut -d ' ' -f 2 | sort -u | grep -v wg0`

# add iptables rules to forward traffic to Pi-hole
# iptables -A FORWARD -i wg0 -j ACCEPT
# iptables -A FORWARD -o wg0 -j ACCEPT
# iptables -t nat -I PREROUTING -d ${pihole_ip} -j ACCEPT
iptables -t nat -I POSTROUTING -o ${docker_net_if} -j MASQUERADE

# ----- configure and start wg server -----
wg setconf wg0 $wg_conf_file
wg

sleep infinity
