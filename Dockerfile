FROM alpine:latest
WORKDIR /etc/wireguard

RUN \
    apk update && \
    apk upgrade && \
    apk add wireguard-tools

ENV \
    WG_INT_PRIVATE_KEY='' \
    WG_INT_IP='10.6.0.1/24' \
    WG_INT_PORT='51820' \
    WG_PEER_PUBLIC_KEY='' \
    WG_PEER_IP='10.6.0.2/32' \
    DNS_CONTAINER_NAME='pihole'

CMD \
    # get server wg keys \
    if [[ -z ${WG_INT_PRIVATE_KEY} ]]; then \
        umask 077; wg genkey | tee server.privatekey | wg pubkey > server.publickey; \
    else \
        umask 077; echo "$WG_INT_PRIVATE_KEY" | tee server.privatekey | wg pubkey > server.publickey; \
    fi && \
    wg_int_public_key=`cat server.publickey` && \
    # get peer wg keys \
    if [[ -z ${WG_PEER_PUBLIC_KEY} ]]; then \
        umask 077; wg genkey | tee peer.privatekey | wg pubkey > peer.publickey && \
        wg_peer_private_key=`cat peer.privatekey` && \
        wg_peer_public_key=`cat peer.publickey`; \
    else \
        wg_peer_private_key='CLIENT_WIREGUARD_PRIVATE_KEY' && \
        wg_peer_public_key=${WG_PEER_PUBLIC_KEY};\
    fi && \
    # create wg server configuration \
    echo "[Interface]" >>wg0.conf && \
    echo "PrivateKey = `cat server.privatekey`" >>wg0.conf && \
    echo "ListenPort = ${WG_INT_PORT}" >>wg0.conf && \
    echo "[Peer]" >>wg0.conf && \
    echo "PublicKey = ${wg_peer_public_key}" >>wg0.conf && \
    echo "AllowedIPs = ${WG_PEER_IP}" >>wg0.conf && \
    # create network interface \
    ip link add wg0 type wireguard && \
    ip addr add ${WG_INT_IP} dev wg0 && \
    ip link set wg0 up && \
    # configure and start wg server \
    wg setconf wg0 wg0.conf && \
    wg && \
    # skip this section if pihole_ip has a value already \
    if [[ -z $pihole_ip ]]; then \
        # get Pi-hole IP address \
        while [[ -z $pihole_ip ]]; do \
            if timeout 5 ping -c 1 -W 2 ${DNS_CONTAINER_NAME} &>/dev/null; then \
                pihole_ip=`ping -c 1 -W 2 ${DNS_CONTAINER_NAME} | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | head -n 1`; \
            fi && \
            echo "cannot resolve '${DNS_CONTAINER_NAME}' yet..." && \
            sleep 1; \
        done && \
        echo "Pi-hole IP: $pihole_ip" && \
        # get the name of the docker network interface \
        docker_net_if=`ip r | grep -o "dev [^ ]*" | cut -d ' ' -f 2 | sort -u | grep -v wg0` && \
        # add iptables rules to forward traffic to Pi-hole \
        iptables -t nat -A PREROUTING -d ${pihole_ip} -j ACCEPT -m comment --comment "Accept inbound traffic for Pi-hole" && \
        iptables -t nat -A POSTROUTING -o ${docker_net_if} -j MASQUERADE -m comment --comment "Allow outbound traffic to the docker network" && \
        # iptables -t nat -nvL && \
        # get public IP of the wg server \
        server_public_ip=`timeout 2 wget -q -O - https://ifconfig.co/ip` && \
        # print peer wg configuration \
        echo -e "\nPeer WG configuration file:" && \
        echo "----- START -----" && \
        echo "[Interface]" && \
        echo "PrivateKey = ${wg_peer_private_key}" && \
        echo "Address = ${WG_PEER_IP}" && \
        echo "DNS = ${pihole_ip}" && \
        echo "" && \
        echo "[Peer]" && \
        echo "PublicKey = ${wg_int_public_key}" && \
        echo "AllowedIPs = ${WG_INT_IP}, ${pihole_ip}/24" && \
        echo "Endpoint = ${server_public_ip}:51820" && \
        echo "----- END -----" && \
        echo 'Note: endpoint port 51820 may be different if WG_PORT env variable was modified.'; \
    fi && \
    sleep infinity
