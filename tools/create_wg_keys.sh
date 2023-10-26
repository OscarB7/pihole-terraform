#!/bin/sh

out_file_pub='keys_pub.out'
out_file_priv='keys_priv.out'
separator_str='_SEPARATOR_'

# ----- input -----

n_clients_default=1
cidr_clients=32
ip_server_default='10.6.0.1/24'

n_clients=$1
ip_server=$2

# ----- functions -----

create_key() { # i:$1
    host_id=`echo "${first_host_id} + ${1}" | bc`
    ip_address="${network_id}.${host_id}/${cidr}"

    priv_key=`wg genkey`
    pub_key=`echo "$priv_key" | wg pubkey`

    if [[ $1 == '0' ]]; then
        ip_address=$ip_server
        wg_server_private_key=`echo $line | awk '{print $4}'`
        echo "${1}${separator_str}${ip_address}${separator_str}${pub_key}${separator_str}${priv_key}" >> $out_file_pub
    else
        echo "${1}${separator_str}${ip_address}${separator_str}${pub_key}" >> $out_file_pub
    fi
    echo "${1}${separator_str}${ip_address}${separator_str}${pub_key}${separator_str}${priv_key}" >> $out_file_priv
}

# ----- main -----

echo "${separator_str}" > $out_file_pub
echo "${separator_str}" > $out_file_priv

if [[ -z $n_clients ]]; then
    n_clients=$n_clients_default
    echo "n_clients is empty. Using default value: ${n_clients}"
fi

if [[ -z $ip_server ]]; then
    ip_server=$ip_server_default
    echo "ip_server is empty. Using default value: ${ip_server}"
else
    echo "ip_server=${ip_server}"
fi

# get network part of the IP
network_id=`echo $ip_server | sed "s|\.[0-9]*/[0-9]*$||"`
# get number of first IP client
first_host_id=`echo $ip_server | sed "s|${network_id}.||" | sed "s|/[0-9]*$||"`
cidr=`echo $ip_server | sed "s|${network_id}.${first_host_id}/||"`

# recreate ip_server
ip_server_recreated="${network_id}.${first_host_id}/${cidr}"
cidr=$cidr_clients


if [[ "$ip_server_recreated" == "$ip_server" ]]; then
    echo "ip_server parsed correctly."
else
    ip_server=$ip_server_default
    echo "ip_server not parsed correctly. Using default value: ${ip_server}"
fi

echo "creating keys for $n_clients clients"

for i in $(seq 0 $n_clients); do
    create_key $i

    if [[ $i == '0' ]]; then
        wg_server_public_key=$pub_key
        continue
    fi
done

echo
echo "- wg_keys_base64: base64 string with server keys and clients public keys"
base64 keys_pub.out -w 0; echo

echo
echo "- base64 string with all keys"
base64 keys_priv.out -w 0; echo
