#!/bin/bash
set -e

echo "Instalando pré-requisitos..."
apt update && apt install -y curl git python3 python3-pip wireguard socat net-tools

echo "Clonando o projeto..."
git clone https://github.com/macbservices/wireguard-setup.git /opt/proxy-automation

echo "Configurando WireGuard..."
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server_private.key)
EOF
wg-quick up wg0
systemctl enable wg-quick@wg0

echo "Configuração concluída. Execute o gerenciador de proxies manualmente."
