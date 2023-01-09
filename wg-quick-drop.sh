#!/bin/bash

SERVER_IP=$1
WG_PORT=$2
SERVER_IFACE=$3

# Install Wireguard
apt update
apt install -y wireguard

# Create server keys
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)

# Create server config
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.66.66.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -o $SERVER_IFACE -j ACCEPT; iptables -A FORWARD -i $SERVER_IFACE -o wg0 -m state --state ESTABLISHED,RELATED -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o $SERVER_IFACE -j ACCEPT; iptables -D FORWARD -i $SERVER_IFACE -o wg0 -m state --state ESTABLISHED,RELATED -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_IFACE -j MASQUERADE
ListenPort = $WG_PORT
PrivateKey = ${SERVER_PRIVATE_KEY}
EOF

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Enable Wireguard
wg-quick up wg0

# Add 5 clients
for i in {1..5}
do
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
    CLIENT_IP="10.66.66.2$i/32"
    cat > /home/ubuntu/Z$i.conf <<EOF
[Interface]
Address = $CLIENT_IP
PrivateKey = $CLIENT_PRIVATE_KEY
[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = 10.33.33.0/24, 10.66.66.0/24
Endpoint = $SERVER_IP:$WG_PORT
PersistentKeepalive = 25
EOF
    wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP
done
