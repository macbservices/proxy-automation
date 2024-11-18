#!/bin/bash

# Diretórios e arquivos do projeto
PROJECT_DIR="/opt/proxy-automation"
PROXY_LIST_DIR="$PROJECT_DIR/proxy_lists"
DOWNLOADED_LISTS="$PROJECT_DIR/downloaded_lists.json"
GITHUB_REPO_URL="https://raw.githubusercontent.com/macbservices/proxy-automation/refs/heads/main"

# Função para baixar uma lista de proxies específica do GitHub
download_proxy_list() {
    local list_url="$GITHUB_REPO_URL/proxy_lists/$1"
    
    echo "Baixando a lista de proxies: $1"
    curl -s -o "$PROXY_LIST_DIR/$1" "$list_url"
}

# Função para verificar se a lista de proxies precisa ser baixada
is_new_list() {
    local list_name="$1"
    if jq -e ".lists[\"$list_name\"]" "$DOWNLOADED_LISTS" > /dev/null; then
        echo "A lista $list_name já foi baixada."
        return 1
    else
        return 0
    fi
}

# Função para registrar que uma lista de proxies foi baixada
mark_list_as_downloaded() {
    local list_name="$1"
    jq --arg list_name "$list_name" '.lists[$list_name] = true' "$DOWNLOADED_LISTS" > "$DOWNLOADED_LISTS.tmp" && mv "$DOWNLOADED_LISTS.tmp" "$DOWNLOADED_LISTS"
}

# Função para verificar se o arquivo de proxies está vazio
is_proxy_list_empty() {
    local proxy_count=$(wc -l < "$PROXY_LIST_DIR/proxy_list.txt")
    if [ "$proxy_count" -le 2 ]; then
        return 0
    else
        return 1
    fi
}

# Função de configuração inicial
setup_initial() {
    # Criar o diretório do projeto, se não existir
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "Criando o diretório do projeto..."
        mkdir -p "$PROJECT_DIR"
    fi

    # Criar o diretório de listas de proxies, se não existir
    if [ ! -d "$PROXY_LIST_DIR" ]; then
        echo "Criando o diretório de listas de proxies..."
        mkdir -p "$PROXY_LIST_DIR"
    fi

    # Criar o arquivo de controle (downloaded_lists.json), se não existir
    if [ ! -f "$DOWNLOADED_LISTS" ]; then
        touch "$DOWNLOADED_LISTS"
        chmod 600 "$DOWNLOADED_LISTS"
        echo '{"lists": {}}' > "$DOWNLOADED_LISTS"
    fi

    # Criar o arquivo de proxies se não existir
    if [ ! -f "$PROXY_LIST_DIR/proxy_list.txt" ]; then
        touch "$PROXY_LIST_DIR/proxy_list.txt"
    fi
}

# Função principal de execução
main() {
    setup_initial

    # Verificar se a lista de proxies precisa ser baixada
    if is_proxy_list_empty; then
        # Buscar todas as listas de proxies no repositório
        echo "Proxies estão abaixo de 2, vamos buscar novas listas."
        
        # Obter a lista de arquivos no diretório 'proxy_lists'
        proxy_files=$(curl -s "https://api.github.com/repos/macbservices/proxy-automation/contents/proxy_lists" | jq -r '.[].name')

        for proxy_file in $proxy_files; do
            if is_new_list "$proxy_file"; then
                download_proxy_list "$proxy_file"
                mark_list_as_downloaded "$proxy_file"
                echo "Lista $proxy_file baixada e registrada."
            else
                echo "A lista $proxy_file já foi baixada anteriormente."
            fi
        done

    else
        echo "Há proxies suficientes no arquivo (mais de 2). Nenhuma nova lista será baixada."
    fi

    echo "Configuração e verificação de proxies concluídas!"
}

# Executar o processo principal
main
