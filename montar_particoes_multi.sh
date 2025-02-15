#!/bin/bash

# Montar Particoes Script for Debian 12
# Autor: Jonas Rafael
# Data: 2025-02-15

# Diretórios de busca de módulos
MODULE_SEARCH_PATHS=(
    "/lib/modules/$(uname -r)/kernel/fs"
    "/lib/modules/$(uname -r)/kernel"
    "/usr/lib/modules/$(uname -r)/kernel/fs"
)

# Função de log com suporte a emojis
log() {
    local nivel="$1"
    local mensagem="$2"
    local emoji=""

    case "$nivel" in
        "INFO")    emoji="🌟" ;;
        "AVISO")   emoji="⚠️" ;;
        "ERRO")    emoji="❌" ;;
        "DEBUG")   emoji="🔍" ;;
        "SUCESSO") emoji="✅" ;;
        *)         emoji="ℹ️" ;;
    esac

    echo "$emoji [$nivel] $mensagem"
}

# Função para encontrar módulo com suporte a compressão
descobrir_modulo() {
    local nome_modulo="$1"
    
    log "DEBUG" "🔎 Iniciando busca por módulo: $nome_modulo"
    log "DEBUG" "🖥️ Kernel atual: $(uname -r)"

    for path in "${MODULE_SEARCH_PATHS[@]}"; do
        log "DEBUG" "🔍 Verificando caminho: $path"
        
        # Buscar módulos compactados e não compactados
        local modulo_encontrado=$(find "$path" \( -name "$nome_modulo.ko" -o -name "$nome_modulo.ko.xz" \) 2>/dev/null | head -n 1)
        
        if [ -n "$modulo_encontrado" ]; then
            log "INFO" "🧩 Módulo $nome_modulo encontrado em: $modulo_encontrado"
            echo "$modulo_encontrado"
            return 0
        fi
    done
    
    log "ERRO" "❌ Módulo $nome_modulo não encontrado em nenhum caminho de busca"
    return 1
}

# Função para verificar módulo
verificar_modulo() {
    local modulo_path="$1"
    local nome_modulo=$(basename "$modulo_path" .ko*)

    log "DEBUG" "🔬 Verificando módulo detalhadamente: $nome_modulo"

    # Verificar existência
    if [ ! -f "$modulo_path" ]; then
        log "ERRO" "❌ Arquivo de módulo não encontrado em $modulo_path"
        return 1
    fi

    # Verificar permissões de leitura
    if [ ! -r "$modulo_path" ]; then
        log "ERRO" "❌ Sem permissão de leitura para $modulo_path"
        return 1
    fi

    # Verificar integridade do módulo
    if [[ "$modulo_path" == *.xz ]]; then
        # Para módulos compactados, usar xz para verificar
        xz -t "$modulo_path" &>/dev/null
        if [ $? -ne 0 ]; then
            log "ERRO" "❌ Módulo $nome_modulo compactado parece estar corrompido"
            return 1
        fi
    else
        # Para módulos não compactados, usar modinfo
        modinfo "$modulo_path" &>/dev/null
        if [ $? -ne 0 ]; then
            log "ERRO" "❌ Módulo $nome_modulo parece estar corrompido"
            return 1
        fi
    fi

    log "SUCESSO" "✅ Módulo $nome_modulo verificado com sucesso"
    return 0
}

# Função para carregar módulo
carregar_modulo() {
    local modulo_path="$1"
    local nome_modulo=$(basename "$modulo_path" .ko*)

    log "INFO" "🚀 Tentando carregar módulo: $nome_modulo"

    # Verificar se o módulo já está carregado
    if lsmod | grep -q "^$nome_modulo "; then
        log "INFO" "ℹ️ Módulo $nome_modulo já está carregado"
        return 0
    fi

    # Se for um módulo compactado, descompactar primeiro
    if [[ "$modulo_path" == *.xz ]]; then
        local temp_dir=$(mktemp -d)
        local modulo_base=$(basename "$modulo_path")
        local modulo_descompactado="$temp_dir/${modulo_base%.xz}"

        log "DEBUG" "📦 Descompactando módulo para: $modulo_descompactado"
        xz -dk "$modulo_path" -c > "$modulo_descompactado"

        # Tentar carregar módulo descompactado
        if insmod "$modulo_descompactado"; then
            log "SUCESSO" "✅ Módulo $nome_modulo carregado com sucesso via insmod"
            rm -rf "$temp_dir"
            return 0
        else
            log "ERRO" "❌ Falha ao carregar módulo descompactado via insmod"
            
            # Tentar com modprobe
            if modprobe "$nome_modulo"; then
                log "SUCESSO" "✅ Módulo $nome_modulo carregado com sucesso via modprobe"
                rm -rf "$temp_dir"
                return 0
            else
                log "ERRO" "❌ Falha ao carregar módulo $nome_modulo via modprobe"
                rm -rf "$temp_dir"
                return 1
            fi
        fi
    fi

    # Tentar carregar módulo diretamente
    if modprobe "$nome_modulo"; then
        log "SUCESSO" "✅ Módulo $nome_modulo carregado com sucesso via modprobe"
        return 0
    else
        log "ERRO" "❌ Falha ao carregar módulo $nome_modulo"
        return 1
    fi
}

# Função para verificar se o dispositivo já está montado
verificar_montagem_existente() {
    local dispositivo="$1"
    local tipo_fs="$2"
    
    # Verificar se o dispositivo já está montado em qualquer lugar
    local ponto_montagem_atual=$(mount | grep "$dispositivo" | awk '{print $3}')
    if [ -n "$ponto_montagem_atual" ]; then
        log "AVISO" "⚠️ Dispositivo $dispositivo já montado em $ponto_montagem_atual"
        return 1
    fi

    # Verificar se já existe um ponto de montagem para este dispositivo em /home/jonasrafael/discos/
    local ponto_montagem_padrao="/home/jonasrafael/discos/${tipo_fs}_$(basename "$dispositivo")"
    
    if mountpoint -q "$ponto_montagem_padrao"; then
        log "ERRO" "❌ Já existe um ponto de montagem em $ponto_montagem_padrao"
        return 1
    fi

    # Verificar se o diretório de montagem já contém algo
    if [ "$(ls -A "$ponto_montagem_padrao" 2>/dev/null)" ]; then
        log "ERRO" "❌ Diretório de montagem $ponto_montagem_padrao não está vazio"
        return 1
    fi

    echo "$ponto_montagem_padrao"
    return 0
}

# Função para montar partições com verificações detalhadas
montar_particao() {
    local dispositivo="$1"
    local tipo_fs="$2"

    # Verificar montagem existente
    local ponto_montagem
    ponto_montagem=$(verificar_montagem_existente "$dispositivo" "$tipo_fs")
    if [ $? -ne 0 ]; then
        return 1
    fi

    log "INFO" "🔌 Preparando montagem de partição: $dispositivo (tipo: $tipo_fs)"

    # Encontrar módulo do sistema de arquivos
    local modulo_fs_path
    case "$tipo_fs" in
        "ext4")
            modulo_fs_path=$(descobrir_modulo "ext4") || return 1
            ;;
        "ntfs")
            modulo_fs_path=$(descobrir_modulo "ntfs") || return 1
            ;;
        "hfsplus")
            modulo_fs_path=$(descobrir_modulo "hfsplus") || return 1
            ;;
        "apfs")
            modulo_fs_path=$(descobrir_modulo "apfs") || return 1
            ;;
        *)
            log "ERRO" "❌ Sistema de arquivos $tipo_fs não suportado"
            return 1
            ;;
    esac

    # Verificar módulo em detalhes
    verificar_modulo "$modulo_fs_path" || return 1

    # Carregar módulo
    carregar_modulo "$modulo_fs_path" || return 1

    # Preparar ponto de montagem
    mkdir -p "$ponto_montagem"

    # Verificar permissões de escrita no ponto de montagem
    if [ ! -w "$ponto_montagem" ]; then
        log "ERRO" "❌ Sem permissão de escrita no ponto de montagem $ponto_montagem"
        return 1
    fi

    # Montar partição com opções de leitura e escrita
    mount -t "$tipo_fs" -o rw "$dispositivo" "$ponto_montagem"
    
    if [ $? -eq 0 ]; then
        log "SUCESSO" "✅ Partição $dispositivo montada em $ponto_montagem (modo leitura-escrita)"
        
        # Verificar se realmente está montado com permissão de escrita
        touch "$ponto_montagem/.write_test" 2>/dev/null
        if [ $? -eq 0 ]; then
            rm "$ponto_montagem/.write_test"
            log "SUCESSO" "✅ Confirmado: Partição montada com sucesso em modo leitura-escrita"
        else
            log "AVISO" "⚠️ Montagem pode estar em modo somente leitura"
            return 1
        fi
    else
        log "ERRO" "❌ Falha ao montar $dispositivo em $ponto_montagem"
        return 1
    fi
}

# Função para escanear partições
escanear_particoes() {
    local tipo_fs="$1"
    local particoes_encontradas=()

    log "INFO" "🔍 Escaneando partições $tipo_fs..."

    # Usar lsblk para encontrar partições do tipo especificado
    while read -r linha; do
        if [ -n "$linha" ]; then
            local dispositivo=$(echo "$linha" | awk '{print $1}')
            local uuid=$(echo "$linha" | awk '{print $3}')
            particoes_encontradas+=("/dev/$dispositivo")
        fi
    done < <(lsblk -f | grep "$tipo_fs")

    # Reportar status das partições encontradas
    if [ ${#particoes_encontradas[@]} -eq 0 ]; then
        log "AVISO" "⚠️ Nenhuma partição $tipo_fs encontrada"
        return 1
    else
        log "INFO" "🎉 Encontradas ${#particoes_encontradas[@]} partição(ões) $tipo_fs"
        
        # Listar partições encontradas
        for particao in "${particoes_encontradas[@]}"; do
            log "INFO" "📁 Partição encontrada: $particao"
        done

        # Tentar montar cada partição encontrada
        local sucesso=0
        local falha=0
        for particao in "${particoes_encontradas[@]}"; do
            if montar_particao "$particao" "$tipo_fs"; then
                ((sucesso++))
            else
                ((falha++))
            fi
        done

        # Resumo de montagem
        log "INFO" "📊 Resumo de montagem $tipo_fs:"
        log "INFO" "✅ Partições montadas com sucesso: $sucesso"
        log "INFO" "❌ Partições com falha de montagem: $falha"

        return 0
    fi
}

# Função principal
main() {
    log "INFO" "🚀 Iniciando script de montagem de partições"
    
    # Verificar se o script está sendo executado com privilégios de root
    if [[ $EUID -ne 0 ]]; then
        log "ERRO" "❌ Este script deve ser executado com privilégios de root (sudo)"
        exit 1
    fi

    # Montar partições HFS+
    log "INFO" "🍏 Iniciando varredura de partições HFS+"
    escanear_particoes "hfsplus"

    # Montar partições NTFS
    log "INFO" "💾 Iniciando varredura de partições NTFS"
    escanear_particoes "ntfs"

    # Montar partições APFS
    log "INFO" "🍎 Iniciando varredura de partições APFS"
    escanear_particoes "apfs"

    log "SUCESSO" "✨ Script de montagem concluído"
}

# Executar main apenas se o script for executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
