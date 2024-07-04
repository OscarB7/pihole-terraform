#!/bin/sh

wg_clients_conf_file='wg_clients.conf'
wg_client_keys_file='wg_client_keys.txt'

# ----- input -----

wg_server_port='51820'
pihole_ip='10.7.107.101'
vpn_dns='pihole'
vpn_traffic='dns'
cloudflare_dns_ip='1.1.1.1'
out_format='text'
client_n='all'

while true; do
    case "$1" in
        --server-public-ip)
            server_public_ip=$2
            shift 2
        ;;
        --wg-server-port)
            wg_server_port=$2
            shift 2
        ;;
        --pihole-ip)
            pihole_ip=$2
            shift 2
        ;;
        --wg-keys-base64)
            wg_keys_base64=$2
            shift 2
        ;;
        --vpn-dns)
            vpn_dns=$2
            shift 2
        ;;
        --vpn-traffic)
            vpn_traffic=$2
            shift 2
        ;;
        --out-format)
            out_format=$2
            shift 2
        ;;
        --client-n)
            client_n=$2
            shift 2
        ;;
        *)
            if [ -n "$1" ]; then
                echo "Argument not valid: '$1'"
            fi
            shift 1 || break
        ;;
    esac
done

echo "server_public_ip: $server_public_ip"
echo "wg_server_port: $wg_server_port"
echo "pihole_ip: $pihole_ip"
echo "wg_keys_base64: `echo $wg_keys_base64 | cut -c 0-50`..."
echo "vpn_dns: $vpn_dns"
echo "vpn_traffic: $vpn_traffic"

# ----- main -----

# install qrencode
if [ $out_format == 'qr' ] || [ $out_format == 'all' ]; then
    # apk update
    which qrencode &>/dev/null || apk add libqrencode 1>/dev/null && echo "Installed qrencode"
fi

echo "$wg_keys_base64" | base64 -d > $wg_client_keys_file

# get string separator from wg_client_keys_file
separator_str=`sed -i -e '1 w /dev/stdout' -e '1d' $wg_client_keys_file`
echo "separator string: $separator_str"
echo

if [ "$vpn_dns" == 'cloudflare' ]; then
    dns_ip=$cloudflare_dns_ip
else
    dns_ip=$pihole_ip
fi

if [ "$vpn_traffic" == 'all' ]; then
    client_allowed_ips='0.0.0.0/0'
else
    client_allowed_ips="${dns_ip}/32"
fi

# read list of clients (each one with pubkey and ip)
while read -r line; do
    # read line
    line=`echo $line | sed "s|$separator_str| |g"`
    wg_client_i=`echo $line | awk '{print $1}'`
    wg_client_ip_address=`echo $line | awk '{print $2}'`
    wg_client_public_key=`echo $line | awk '{print $3}'`
    wg_client_private_key=`echo $line | awk '{print $4}'`

    if [[ $wg_client_i == 0 ]]; then
        # get server info
        echo "wg_client_i: $wg_client_i"
        wg_server_public_key=$wg_client_public_key
        echo "wg_server_public_key=$wg_server_public_key"
        wg_server_ip_address=$wg_client_ip_address
        echo "wg_server_ip_address=$wg_server_ip_address"
        echo -e "\n\n"
        continue
    fi

    if [[ $client_n != 'all' ]] && [[ $wg_client_i != $client_n ]]; then
        continue
    fi

    # write wireguard client configuration
    echo
    echo "# wg_client_i: $wg_client_i" > $wg_clients_conf_file
    echo "[Interface]" >> $wg_clients_conf_file
    echo "PrivateKey = ${wg_client_private_key}" >> $wg_clients_conf_file
    echo "Address = ${wg_client_ip_address}" >> $wg_clients_conf_file
    echo "DNS = ${dns_ip}" >> $wg_clients_conf_file
    echo "" >> $wg_clients_conf_file
    echo "[Peer]" >> $wg_clients_conf_file
    echo "PublicKey = ${wg_server_public_key}" >> $wg_clients_conf_file
    echo "AllowedIPs = ${client_allowed_ips}" >> $wg_clients_conf_file
    echo "Endpoint = ${server_public_ip}:${wg_server_port}" >> $wg_clients_conf_file

    if [ $out_format == 'text' ] || [ $out_format == 'all' ]; then
        # print client wg config
        echo "wg_client_i: $wg_client_i"
        echo "----- START -----"
        cat $wg_clients_conf_file
        echo "----- END -----"
    fi


    if [ $out_format == 'qr' ] || [ $out_format == 'all' ]; then
        # print wireguard QR code for 
        qrencode -t ansiutf8 < $wg_clients_conf_file
        echo -e "\n\n"
    fi
done < $wg_client_keys_file
