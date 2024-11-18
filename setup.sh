#!/bin/bash

# Configuração básica
PROJECT_DIR="/opt/proxy-automation"
CONFIG_FILE="$PROJECT_DIR/proxies.json"
PROXY_LIST="/root/proxies.txt"

# Funções principais

install_dependencies() {
    echo "Atualizando pacotes e instalando dependências..."
    apt update && apt upgrade -y
    apt install -y python3 python3-pip iptables-persistent curl
}

create_project_structure() {
    echo "Criando estrutura do projeto..."
    mkdir -p "$PROJECT_DIR"
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

enable_packet_forwarding() {
    echo "Ativando redirecionamento de pacotes..."
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
}

configure_firewall() {
    echo "Configurando firewall com iptables..."
    iptables -A INPUT -p tcp --dport 1:65535 -j ACCEPT
    iptables -A OUTPUT -p tcp --sport 1:65535 -j ACCEPT
    iptables -A FORWARD -p tcp --dport 1:65535 -j ACCEPT
    iptables -A FORWARD -p tcp --sport 1:65535 -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
}

install_python_script() {
    echo "Instalando script Python..."
    cat <<EOF >"$PROJECT_DIR/proxy_manager.py"
import os
import subprocess
import json

CONFIG_FILE = "$CONFIG_FILE"
PROXY_LIST = "$PROXY_LIST"

def load_proxies():
    if not os.path.exists(PROXY_LIST):
        print(f"Arquivo de proxies não encontrado: {PROXY_LIST}")
        return []
    with open(PROXY_LIST, "r") as file:
        return [line.strip() for line in file if line.strip()]

def assign_proxy(ip_private):
    proxies = load_proxies()
    if not proxies:
        print("Nenhum proxy disponível.")
        return
    
    proxy = proxies.pop(0)
    proxy_parts = proxy.split(':')
    ip, port, user, password = proxy_parts

    print(f"Atribuindo proxy {ip}:{port} para {ip_private}")
    
    # Configuração de NAT para o IP privado
    command_nat = f"iptables -t nat -A POSTROUTING -s {ip_private} -j SNAT --to-source {ip}"
    subprocess.run(command_nat, shell=True)

    # Configuração de encaminhamento para o IP privado
    command_forward = f"iptables -A FORWARD -s {ip_private} -j ACCEPT"
    subprocess.run(command_forward, shell=True)
    command_forward_back = f"iptables -A FORWARD -d {ip_private} -j ACCEPT"
    subprocess.run(command_forward_back, shell=True)

    # Salvar configuração no arquivo JSON
    with open(CONFIG_FILE, 'r+') as file:
        data = json.load(file) if os.stat(CONFIG_FILE).st_size != 0 else {}
        data[ip_private] = proxy
        file.seek(0)
        json.dump(data, file)
        file.truncate()

    print(f"Proxy {ip}:{port} atribuído ao IP privado {ip_private}.")

def list_assigned_proxies():
    if not os.path.exists(CONFIG_FILE) or os.stat(CONFIG_FILE).st_size == 0:
        print("Nenhuma configuração encontrada.")
        return
    with open(CONFIG_FILE, 'r') as file:
        data = json.load(file)
        for ip_private, proxy in data.items():
            print(f"IP Privado: {ip_private} -> Proxy: {proxy}")

if __name__ == "__main__":
    print("Gerenciador de Proxies")
    print("1. Atribuir proxy a um IP privado")
    print("2. Listar atribuições")
    choice = input("Escolha uma opção: ")
    
    if choice == "1":
        ip_private = input("Digite o IP privado da VPS: ")
        assign_proxy(ip_private)
    elif choice == "2":
        list_assigned_proxies()
    else:
        print("Opção inválida.")
EOF

    chmod +x "$PROJECT_DIR/proxy_manager.py"
}

setup_complete() {
    echo "Configuração concluída!"
    echo "Para gerenciar proxies, execute:"
    echo "  python3 $PROJECT_DIR/proxy_manager.py"
}

# Execução das funções
install_dependencies
create_project_structure
enable_packet_forwarding
configure_firewall
install_python_script
setup_complete
