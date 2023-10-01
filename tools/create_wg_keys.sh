#!/bin/sh

ip_first_client_default='10.5.0.2/32'
out_file='keys.out'
separator_str='SEPARATOR'

# ----- input -----

n_clients=$1
ip_first_client=$2

# ----- functions -----

create_key() { # i:$1
    host_id=`echo "${first_host_id} + ${1} - 1" | bc`
    ip_address="${network_id}.${host_id}/${cidr}"

    priv_key=`wg genkey`
    pub_key=`echo "$priv_key" | wg pubkey`

    echo "ip_address: $ip_address"
    echo "priv_key: $priv_key"
    echo "pub_key: $pub_key"

    # echo "${1}${separator_str}${ip_address}${separator_str}${priv_key}${separator_str}${pub_key}" >> $out_file
    echo "${1}${separator_str}${ip_address}${separator_str}${pub_key}" >> $out_file
}

# ----- main -----
echo "${separator_str}" > $out_file


if [[ -z $ip_first_client ]]; then
    ip_first_client=$ip_first_client_default
    echo "ip_first_client is empty. Using default value: ${ip_first_client}"
else
    echo "ip_first_client=${ip_first_client}"
fi

# get network part of the IP
network_id=`echo $ip_first_client | sed "s|\.[0-9]*/[0-9]*$||"`
# get number of first IP client
first_host_id=`echo $ip_first_client | sed "s|${network_id}.||" | sed "s|/[0-9]*$||"`
cidr=`echo $ip_first_client | sed "s|${network_id}.${first_host_id}/||"`

# recreate ip_first_client
ip_first_client_recreated="${network_id}.${first_host_id}/${cidr}"


if [[ "$ip_first_client_recreated" == "$ip_first_client" ]]; then
    echo "ip_first_client parsed correctly."
else
    ip_first_client=$ip_first_client_default
    echo "ip_first_client not parsed correctly. Using default value: ${ip_first_client}"
fi


echo
echo "- creating key for server"
create_key 0

echo
echo "- creating keys for $n_clients clients"

for i in $(seq $n_clients); do
    echo "i: $i"
    create_key $i
    # echo "priv_key: $priv_key"
    # echo "pub_key: $pub_key"
done

echo
echo "- base64 string with all keys"

base64 keys.out -w 0; echo
