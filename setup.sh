#!/bin/bash

# Função para verificar e instalar dependências
install_dependencies() {
    echo "Instalando dependências necessárias..."

    # Atualizar o sistema e instalar dependências
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl jq iptables ufw

    echo "Dependências instaladas!"
}

# Função para buscar o arquivo proxy.txt mais recente
fetch_proxies() {
    # URL base do repositório GitHub
    REPO_URL="https://raw.githubusercontent.com/macbservices/proxy-automation/main"

    # Arquivos de proxies disponíveis no GitHub
    PROXY_LISTS=("proxy_list_1.txt" "proxy_list_2.txt" "proxy_list_3.txt" "proxy_list_4.txt" "proxy_list_5.txt")

    # Verificar se já temos os proxies baixados
    if [[ ! -f "downloaded_lists.json" ]]; then
        touch downloaded_lists.json
    fi

    # Baixar uma nova lista se houver menos de 2 proxies no sistema
    num_proxies=$(ls -1 *.txt 2>/dev/null | wc -l)

    if [[ $num_proxies -le 2 ]]; then
        echo "Menos de 2 proxies disponíveis. Buscando novas listas do GitHub..."

        # Recuperar listas novas do GitHub
        for proxy_file in "${PROXY_LISTS[@]}"; do
            # Verificar se já baixamos esta lista
            if ! grep -q "$proxy_file" downloaded_lists.json; then
                echo "Baixando a lista de proxies: $proxy_file"
                
                # Baixar o arquivo do repositório GitHub diretamente para o diretório local
                curl -sSL "$REPO_URL/$proxy_file" -o "$proxy_file"

                # Marcar que esta lista foi baixada
                echo "$proxy_file" >> downloaded_lists.json
            fi
        done
    else
        echo "Já há proxies suficientes no sistema."
    fi
}

# Função para configurar o servidor de proxy
configure_proxy_server() {
    echo "Configurando o servidor de proxy..."

    # Defina a porta e IP público do servidor (modifique conforme necessário)
    PUBLIC_IP="170.254.135.110"
    GATEWAY="100.102.90.1"
    INTERNAL_INTERFACE="ens18"

    # Configuração do UFW (Firewall)
    sudo ufw allow ssh
    sudo ufw allow 22
    sudo ufw allow 8080
    sudo ufw allow 8006
    sudo ufw allow 3389
    sudo ufw enable

    echo "Servidor de proxy configurado!"
}

# Função para configurar o proxy para cada VPS
configure_vps_proxy() {
    echo "Configurando proxies para VPS..."

    # Identificar IPs privados na rede (adapte conforme necessário)
    private_ips=$(ip -o -f inet addr show ens18 | awk '{print $4}' | cut -d/ -f1)

    # Para cada IP privado, perguntar ao usuário qual porta liberar
    for ip in $private_ips; do
        echo "VPS com IP privado $ip detectado."
        read -p "Digite a porta que deseja liberar para este IP (ex: 22, 8080, 3389): " port

        # Verificar se a porta já está liberada
        if ! sudo ufw status | grep -q "$port"; then
            echo "Liberando a porta $port para o IP $ip..."
            sudo ufw allow from $ip to any port $port
        else
            echo "Porta $port já liberada."
        fi
    done

    # Associar proxies às VPS
    for proxy_file in *.txt; do
        while IFS=":" read -r IP PORT USER PASS; do
            # Aqui você pode adicionar as configurações do proxy para cada VPS
            # Exemplo de configuração de proxy para uma VPS:
            echo "Configurando proxy $IP:$PORT com usuário $USER e senha $PASS para a VPS com IP privado"

            # Aqui, você pode adicionar a lógica de associar um proxy à VPS
            # Exemplo: Atualizar a configuração de rede da VPS com o proxy
            # ou modificar iptables para direcionar o tráfego da VPS através do proxy
        done < "$proxy_file"
    done

    echo "Proxies configurados para as VPS!"
}

# Função principal de execução
main() {
    install_dependencies
    fetch_proxies
    configure_proxy_server
    configure_vps_proxy

    echo "Instalação e configuração concluídas!"
}

# Chama a função principal
main
