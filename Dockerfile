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

COPY setup_wg.sh .

CMD /bin/sh setup_wg.sh
