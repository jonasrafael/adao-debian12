#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                               ADÃO SCRIPT                                ║
# ║ "Porque ele comeu a maçã e pulou a janela" - Montagem Inteligente de     ║
# ║                        Dispositivos de Armazenamento                     ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║ Versão:           1.2.0                                                  ║
# ║ Autor:           Jonas Rafael                                            ║
# ║ Última Atualização: 16 de Fevereiro de 2025                              ║
# ║ Licença:         MIT                                                     ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║ Changelog v1.2.0:                                                        ║
# ║ - Adicionado método de proteção do sistema de arquivos raiz              ║
# ║ - Implementadas verificações de segurança para dispositivos externos     ║
# ║ - Melhorada a recuperação de boot com proteções adicionais               ║
# ║ - Suporte aprimorado para diferentes tipos de filesystem                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Variáveis globais de configuração e versão
SCRIPT_NOME="Adao"
SCRIPT_VERSAO="1.2.0"
SCRIPT_DATA_ATUALIZACAO="2025-02-16"

# Verificações de segurança e configurações iniciais
set -o errexit   # Sair imediatamente se um comando falhar
set -o nounset   # Tratar variáveis não definidas como erro
set -o pipefail  # Retornar valor de erro em pipelines

# Montar Particoes Script for Debian 12
# Autor: Jonas Rafael
# Data: 2025-02-15

# Diretórios de busca de módulos
MODULE_SEARCH_PATHS=(
    "/lib/modules/$(uname -r)/kernel/fs"
    "/lib/modules/$(uname -r)/kernel"
    "/usr/lib/modules/$(uname -r)/kernel/fs"
)

# Configurações padrão
DIRETORIO_PADRAO="/home/jonasrafael/discos"

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

# Função para limpar nome do dispositivo
limpar_nome_dispositivo() {
    local dispositivo="$1"
    # Remove caracteres especiais e espaços
    local dispositivo_limpo=$(echo "$dispositivo" | sed -E 's/[└─]//g' | xargs)
    
    # Adiciona prefixo /dev/ se não existir
    if [[ ! "$dispositivo_limpo" =~ ^/dev/ ]]; then
        dispositivo_limpo="/dev/$dispositivo_limpo"
    fi
    
    echo "$dispositivo_limpo"
}

# Função para solicitar ponto de montagem
solicitar_ponto_montagem() {
    local tipo_fs="$1"
    local dispositivo="$2"
    local ponto_montagem_padrao="$DIRETORIO_PADRAO/${tipo_fs}_$(basename "$dispositivo")"
    
    # Pergunta ao usuário se quer usar o ponto de montagem padrão
    read -p "🤔 Usar ponto de montagem padrão $ponto_montagem_padrao? (S/n): " usar_padrao
    
    if [[ -z "$usar_padrao" || "$usar_padrao" =~ ^[Ss]([Ii][Mm])?$ ]]; then
        # Usa o ponto de montagem padrão
        echo "$ponto_montagem_padrao"
    else
        # Solicita ponto de montagem personalizado
        while true; do
            read -p "📂 Digite o caminho completo para o ponto de montagem: " ponto_montagem_custom
            
            # Expande caminho do usuário (resolve ~, variáveis de ambiente)
            ponto_montagem_custom=$(eval echo "$ponto_montagem_custom")
            
            # Verifica se o caminho é absoluto
            if [[ "$ponto_montagem_custom" == /* ]]; then
                # Cria diretório se não existir
                mkdir -p "$ponto_montagem_custom"
                
                # Verifica permissões de escrita
                if [ -w "$ponto_montagem_custom" ]; then
                    echo "$ponto_montagem_custom"
                    break
                else
                    log "ERRO" "❌ Sem permissões de escrita em $ponto_montagem_custom"
                fi
            else
                log "ERRO" "❌ Por favor, forneça um caminho absoluto (começando com /)"
            fi
        done
    fi
}

# Função para tentar montar partição APFS
montar_particao_apfs() {
    local dispositivo="$1"
    local ponto_montagem="$2"

    # Verificar se apfs-fuse está instalado
    if command -v apfs-fuse &>/dev/null; then
        log "INFO" "🍎 Tentando montar com apfs-fuse..."
        local mount_output=""
        local mount_status=1

        # Tentar montar com apfs-fuse
        mount_output=$(apfs-fuse "$dispositivo" "$ponto_montagem" 2>&1)
        mount_status=$?

        if [ $mount_status -eq 0 ]; then
            log "SUCESSO" "✅ Partição $dispositivo montada com apfs-fuse"
            return 0
        else
            log "AVISO" "⚠️ Falha ao montar com apfs-fuse"
            log "ERRO" "$mount_output"
        fi
    fi

    # Tentar módulo de kernel APFS como fallback
    local modulo_fs_path=$(descobrir_modulo "apfs")
    if [ -n "$modulo_fs_path" ]; then
        log "INFO" "🔧 Tentando montar com módulo de kernel APFS..."
        
        # Carregar módulo
        if carregar_modulo "$modulo_fs_path"; then
            # Tentar montar com mount
            local mount_output=""
            local mount_status=1
            mount_output=$(mount -t apfs -o rw,noatime "$dispositivo" "$ponto_montagem" 2>&1)
            mount_status=$?

            if [ $mount_status -eq 0 ]; then
                log "SUCESSO" "✅ Partição $dispositivo montada com módulo de kernel"
                return 0
            else
                log "ERRO" "❌ Falha ao montar com módulo de kernel APFS"
                log "ERRO" "$mount_output"
            fi
        fi
    fi

    # Todas as tentativas falharam
    log "ERRO" "❌ Não foi possível montar a partição APFS: $dispositivo"
    return 1
}

# Função para montar partições com verificações detalhadas
montar_particao() {
    local dispositivo="$1"
    local tipo_fs="$2"
    
    # Validações iniciais
    if [ -z "$dispositivo" ] || [ -z "$tipo_fs" ]; then
        log "ERRO" "❌ Dispositivo ou tipo de sistema de arquivos não especificado"
        return 1
    fi

    # Verificar se o dispositivo existe
    if [ ! -b "$dispositivo" ]; then
        log "ERRO" "❌ Dispositivo $dispositivo não existe ou não é um dispositivo de bloco"
        return 1
    fi

    # Tratamento especial para APFS
    if [ "$tipo_fs" == "apfs" ]; then
        # Solicitar ponto de montagem
        local ponto_montagem
        ponto_montagem=$(solicitar_ponto_montagem "$tipo_fs" "$dispositivo")

        # Criar ponto de montagem se não existir
        mkdir -p "$ponto_montagem"

        # Verificar permissões de escrita no ponto de montagem
        if [ ! -w "$ponto_montagem" ]; then
            log "ERRO" "❌ Sem permissões de escrita em $ponto_montagem"
            return 1
        fi

        # Montar usando função específica para APFS
        montar_particao_apfs "$dispositivo" "$ponto_montagem"
        return $?
    fi

    # Identificar módulo do sistema de arquivos
    local modulo_fs_path=""
    case "$tipo_fs" in
        "ntfs")
            modulo_fs_path=$(descobrir_modulo "ntfs")
            ;;
        "hfsplus")
            modulo_fs_path=$(descobrir_modulo "hfsplus")
            ;;
        "ext4")
            modulo_fs_path=$(descobrir_modulo "ext4")
            ;;
        "exfat")
            instalar_pacotes_exfat || return 1
            ;;
        *)
            log "ERRO" "❌ Tipo de sistema de arquivos não suportado: $tipo_fs"
            return 1
            ;;
    esac

    # Verificar módulo para sistemas de arquivos que não são APFS ou exFAT
    if [[ "$tipo_fs" != "apfs" && "$tipo_fs" != "exfat" ]] && [ -z "$modulo_fs_path" ]; then
        log "ERRO" "❌ Módulo para $tipo_fs não encontrado"
        return 1
    fi

    # Carregar módulo para sistemas de arquivos que não são APFS ou exFAT
    if [[ "$tipo_fs" != "apfs" && "$tipo_fs" != "exfat" ]]; then
        carregar_modulo "$modulo_fs_path" || return 1
    fi

    # Solicitar ponto de montagem
    local ponto_montagem
    ponto_montagem=$(solicitar_ponto_montagem "$tipo_fs" "$dispositivo")

    # Criar ponto de montagem se não existir
    mkdir -p "$ponto_montagem"

    # Verificar permissões de escrita no ponto de montagem
    if [ ! -w "$ponto_montagem" ]; then
        log "ERRO" "❌ Sem permissões de escrita em $ponto_montagem"
        return 1
    fi

    # Verificar se já está montado
    if mount | grep -q "$dispositivo"; then
        log "AVISO" "⚠️ $dispositivo já está montado"
        return 1
    fi

    # Opções de montagem
    local mount_options="rw,noatime,utf8"
    
    # Tentar montar com diferentes métodos
    local mount_output=""
    local mount_status=1

    # Método de montagem específico para cada tipo de sistema de arquivos
    case "$tipo_fs" in
        "ntfs")
            # Método 1: Montagem padrão
            mount_output=$(mount -t "$tipo_fs" -o "$mount_options" "$dispositivo" "$ponto_montagem" 2>&1)
            mount_status=$?

            # Método 2: NTFS específico
            if [ $mount_status -ne 0 ]; then
                log "AVISO" "🔧 Tentando montagem NTFS alternativa..."
                mount_output=$(mount -t ntfs-3g -o "$mount_options" "$dispositivo" "$ponto_montagem" 2>&1)
                mount_status=$?
            fi
            ;;
        
        "exfat")
            # Montagem usando mount.exfat-fuse ou mount.exfat
            if command -v mount.exfat-fuse &>/dev/null; then
                mount_output=$(mount.exfat-fuse -o "$mount_options" "$dispositivo" "$ponto_montagem" 2>&1)
            elif command -v mount.exfat &>/dev/null; then
                mount_output=$(mount.exfat -o "$mount_options" "$dispositivo" "$ponto_montagem" 2>&1)
            else
                log "ERRO" "❌ Nenhum comando de montagem exFAT encontrado"
                return 1
            fi
            mount_status=$?
            ;;
        
        *)
            # Montagem padrão para outros sistemas de arquivos
            mount_output=$(mount -t "$tipo_fs" -o "$mount_options" "$dispositivo" "$ponto_montagem" 2>&1)
            mount_status=$?
            ;;
    esac

    # Verificar resultado da montagem
    if [ $mount_status -eq 0 ]; then
        log "SUCESSO" "✅ Partição $dispositivo montada em $ponto_montagem"
        return 0
    else
        # Log detalhado de erro
        log "ERRO" "❌ Falha ao montar $dispositivo"
        log "ERRO" "📝 Detalhes do erro:"
        log "ERRO" "$mount_output"

        # Verificar possíveis causas comuns
        if [ ! -b "$dispositivo" ]; then
            log "ERRO" "🚫 O dispositivo não existe ou não é um dispositivo de bloco"
        elif [ ! -r "$dispositivo" ]; then
            log "ERRO" "🔒 Sem permissões de leitura para o dispositivo"
        fi

        # Verificar sistema de arquivos
        local fs_type
        fs_type=$(blkid -o value -s TYPE "$dispositivo")
        if [ -z "$fs_type" ]; then
            log "ERRO" "❓ Não foi possível determinar o tipo de sistema de arquivos"
        elif [ "$fs_type" != "$tipo_fs" ]; then
            log "AVISO" "⚠️ Tipo de sistema de arquivos detectado: $fs_type (esperado: $tipo_fs)"
        fi

        return 1
    fi
}

# Função para escanear partições
escanear_particoes() {
    local tipo_fs="$1"
    local particoes_encontradas=()

    log "INFO" "🔍 Escaneando partições $tipo_fs..."

    # Usar blkid para encontrar partições do tipo especificado
    while read -r dispositivo; do
        if [ -n "$dispositivo" ]; then
            # Limpar nome do dispositivo
            local dispositivo_limpo=$(limpar_nome_dispositivo "$dispositivo")
            
            # Verificar se o dispositivo existe
            if [ -b "$dispositivo_limpo" ]; then
                particoes_encontradas+=("$dispositivo_limpo")
            fi
        fi
    done < <(blkid -t TYPE="$tipo_fs" -o device)

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
            # Montar partição
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

        # Retorna sucesso se pelo menos uma partição foi montada
        [ $sucesso -gt 0 ]
    fi
}

# Função para detectar partições APFS usando apfs-fuse
detectar_particoes_apfs() {
    local particoes_encontradas=()

    log "INFO" "🍎 Detectando partições APFS..."

    # Verificar se apfs-fuse está instalado
    if ! command -v apfs-fuse &>/dev/null; then
        log "ERRO" "❌ apfs-fuse não está instalado"
        return 1
    fi

    # Usar lsblk para encontrar dispositivos de bloco
    while read -r dispositivo; do
        if [ -n "$dispositivo" ]; then
            # Limpar nome do dispositivo
            local dispositivo_limpo=$(limpar_nome_dispositivo "$dispositivo")
            
            # Verificar se o dispositivo existe e é um dispositivo de bloco
            if [ -b "$dispositivo_limpo" ]; then
                # Tentar montar temporariamente para verificar se é APFS
                local ponto_montagem_temp=$(mktemp -d)
                
                # Tentar montar com apfs-fuse
                if apfs-fuse "$dispositivo_limpo" "$ponto_montagem_temp" &>/dev/null; then
                    # Dispositivo é APFS
                    particoes_encontradas+=("$dispositivo_limpo")
                    
                    # Desmontar imediatamente
                    umount "$ponto_montagem_temp" &>/dev/null
                fi
                
                # Remover diretório temporário
                rmdir "$ponto_montagem_temp" &>/dev/null
            fi
        fi
    done < <(lsblk -ndo PATH)

    # Reportar status das partições encontradas
    if [ ${#particoes_encontradas[@]} -eq 0 ]; then
        log "AVISO" "⚠️ Nenhuma partição APFS encontrada"
        return 1
    else
        log "INFO" "🎉 Encontradas ${#particoes_encontradas[@]} partição(ões) APFS"
        
        # Listar partições encontradas
        for particao in "${particoes_encontradas[@]}"; do
            log "INFO" "📁 Partição APFS encontrada: $particao"
        done

        # Tentar montar cada partição encontrada
        local sucesso=0
        local falha=0
        for particao in "${particoes_encontradas[@]}"; do
            # Montar partição
            if montar_particao "$particao" "apfs"; then
                ((sucesso++))
            else
                ((falha++))
            fi
        done

        # Resumo de montagem
        log "INFO" "📊 Resumo de montagem APFS:"
        log "INFO" "✅ Partições montadas com sucesso: $sucesso"
        log "INFO" "❌ Partições com falha de montagem: $falha"

        # Retorna sucesso se pelo menos uma partição foi montada
        [ $sucesso -gt 0 ]
    fi
}

# Função para montar partições HFS+
montar_hfs() {
    log "INFO" "🍏 Iniciando varredura de partições HFS+"
    escanear_particoes "hfsplus"
}

# Função para montar partições NTFS
montar_ntfs() {
    log "INFO" "💾 Iniciando varredura de partições NTFS"
    escanear_particoes "ntfs"
}

# Função para montar partições APFS
montar_apfs() {
    log "INFO" "🍎 Iniciando varredura de partições APFS"
    detectar_particoes_apfs
}

# Função para montar partições exFAT
montar_exfat() {
    log "INFO" "💽 Iniciando varredura de partições exFAT"
    
    # Verificar se o pacote exfat-fuse ou exfat-utils está instalado
    if ! command -v mount.exfat-fuse &>/dev/null && ! command -v mount.exfat &>/dev/null; then
        log "AVISO" "⚠️ Suporte a exFAT não instalado. Instalando..."
        
        # Tentar instalar pacotes de suporte a exFAT
        if command -v apt &>/dev/null; then
            apt update
            apt install -y exfat-fuse exfat-utils
        elif command -v yum &>/dev/null; then
            yum install -y exfat-utils fuse-exfat
        elif command -v dnf &>/dev/null; then
            dnf install -y exfat-utils fuse-exfat
        else
            log "ERRO" "❌ Não foi possível instalar suporte a exFAT"
            return 1
        fi
    fi

    # Usar blkid para encontrar partições exFAT
    local particoes_encontradas=()
    while read -r dispositivo; do
        if [ -n "$dispositivo" ]; then
            # Limpar nome do dispositivo
            local dispositivo_limpo=$(limpar_nome_dispositivo "$dispositivo")
            
            # Verificar se o dispositivo existe
            if [ -b "$dispositivo_limpo" ]; then
                particoes_encontradas+=("$dispositivo_limpo")
            fi
        fi
    done < <(blkid -t TYPE=exfat -o device)

    # Reportar status das partições encontradas
    if [ ${#particoes_encontradas[@]} -eq 0 ]; then
        log "AVISO" "⚠️ Nenhuma partição exFAT encontrada"
        return 1
    else
        log "INFO" "🎉 Encontradas ${#particoes_encontradas[@]} partição(ões) exFAT"
        
        # Listar partições encontradas
        for particao in "${particoes_encontradas[@]}"; do
            log "INFO" "📁 Partição exFAT encontrada: $particao"
        done

        # Tentar montar cada partição encontrada
        local sucesso=0
        local falha=0
        for particao in "${particoes_encontradas[@]}"; do
            # Montar partição
            if montar_particao "$particao" "exfat"; then
                ((sucesso++))
            else
                ((falha++))
            fi
        done

        # Resumo de montagem
        log "INFO" "📊 Resumo de montagem exFAT:"
        log "INFO" "✅ Partições montadas com sucesso: $sucesso"
        log "INFO" "❌ Partições com falha de montagem: $falha"

        # Retorna sucesso se pelo menos uma partição foi montada
        [ $sucesso -gt 0 ]
    fi
}

# Função para atualizar /etc/fstab e recarregar systemd
atualizar_fstab() {
    log "INFO" "🔄 Atualizando configurações do sistema..."
    
    # Verificar se o script está sendo executado com privilégios de root
    if [[ $EUID -ne 0 ]]; then
        log "ERRO" "❌ Esta função requer privilégios de root"
        return 1
    fi

    # Gerar entradas para /etc/fstab
    log "INFO" "📝 Gerando entradas para /etc/fstab..."
    
    # Backup do fstab original
    cp /etc/fstab /etc/fstab.backup_adao_$(date +"%Y%m%d_%H%M%S")
    
    # Diretório base para montagem
    local base_montagem="/home/jonasrafael/discos"
    
    # Dispositivos a serem montados
    local dispositivos=(
        "/dev/sdb1"
        "/dev/sdc1"
    )
    
    # Arquivo temporário para novas entradas
    local temp_fstab=$(mktemp)
    
    # Copiar entradas originais preservando comentários e opções especiais
    grep -E '^[^#]' /etc/fstab | grep -v "$base_montagem" > "$temp_fstab"
    
    # Adicionar novas entradas com opções de montagem seguras
    for dispositivo in "${dispositivos[@]}"; do
        # Verificar se o dispositivo existe
        if [[ ! -b "$dispositivo" ]]; then
            log "AVISO" "⚠️ Dispositivo $dispositivo não encontrado, pulando entrada no fstab"
            continue
        }
        
        # Obter UUID e tipo de filesystem
        local uuid=""
        local tipo_fs=""
        uuid=$(blkid -o value -s UUID "$dispositivo")
        tipo_fs=$(blkid -o value -s TYPE "$dispositivo")
        
        # Definir nome do ponto de montagem
        local nome_disco=""
        case "$dispositivo" in
            "/dev/sdb1") nome_disco="disco1" ;;
            "/dev/sdc1") nome_disco="disco2" ;;
            *) nome_disco="sistema" ;;
        esac
        
        local ponto_montagem="$base_montagem/$nome_disco"
        
        # Opções de montagem seguras e tolerantes a falhas
        local opcoes_montagem="noauto,nofail,x-systemd.automount,x-systemd.idle-timeout=30,x-systemd.device-timeout=5s,uid=1000,gid=1000,utf8"
        
        # Adicionar entrada ao fstab
        if [[ -n "$uuid" && -n "$tipo_fs" ]]; then
            echo "UUID=$uuid $ponto_montagem $tipo_fs $opcoes_montagem 0 2" >> "$temp_fstab"
            log "INFO" "✅ Adicionando entrada para $dispositivo em $ponto_montagem"
        else
            log "AVISO" "⚠️ Não foi possível gerar entrada para $dispositivo"
        fi
    done
    
    # Substituir fstab
    mv "$temp_fstab" /etc/fstab
    chmod 644 /etc/fstab
    
    # Recarregar configurações do systemd
    systemctl daemon-reload
    
    log "SUCESSO" "✨ Configurações do fstab atualizadas com sucesso!"
}

# Função para criar pontos de montagem seguros
criar_pontos_montagem() {
    local base_montagem="/home/jonasrafael/discos"
    
    # Criar diretório base
    mkdir -p "$base_montagem"
    chmod 755 "$base_montagem"
    
    # Nomes dos subdiretórios
    local nomes_discos=("sistema" "disco1" "disco2" "disco3" "disco4" "disco5")
    
    # Criar subdiretórios
    for nome in "${nomes_discos[@]}"; do
        local ponto_montagem="$base_montagem/$nome"
        mkdir -p "$ponto_montagem"
        chmod 777 "$ponto_montagem"
        chown 1000:1000 "$ponto_montagem"
    done
    
    log "SUCESSO" "✅ Pontos de montagem criados em $base_montagem"
}

# Função para montar discos com nomenclatura personalizada
montar_discos_compartilhados() {
    log "INFO" "🔍 Iniciando montagem de discos compartilhados..."
    
    # Instalar pacotes necessários globalmente
    instalar_pacotes_exfat
    apt-get install -y ntfs-3g
    
    # Dispositivos a serem montados
    local dispositivos=(
        "/dev/sdb1"
        "/dev/sdc1"
    )
    
    local total_discos=0
    local discos_montados=0
    local discos_ignorados=0
    
    for dispositivo in "${dispositivos[@]}"; do
        # Verificar se o dispositivo existe
        if [[ ! -b "$dispositivo" ]]; then
            log "AVISO" "⏩ Dispositivo $dispositivo não encontrado"
            ((discos_ignorados++))
            continue
        fi
        
        # Desmontar primeiro
        umount "$dispositivo" 2>/dev/null
        
        # Detectar tipo de filesystem
        local tipo_fs
        tipo_fs=$(blkid -o value -s TYPE "$dispositivo")
        
        # Definir ponto de montagem
        local nome_disco
        case "$dispositivo" in
            "/dev/sdb1") nome_disco="disco1" ;;
            "/dev/sdc1") nome_disco="disco2" ;;
            *) nome_disco="sistema" ;;
        esac
        
        local ponto_montagem="/home/jonasrafael/discos/$nome_disco"
        
        # Tentar montar
        if montar_particao "$dispositivo" "$tipo_fs" "$ponto_montagem"; then
            ((discos_montados++))
        else
            ((discos_ignorados++))
        fi
        
        ((total_discos++))
    done
    
    log "INFO" "📊 Resumo de montagem de discos compartilhados:"
    log "INFO" "🖥️ Total de discos encontrados: $total_discos"
    log "INFO" "✅ Discos montados: $discos_montados"
    log "INFO" "⚠️ Discos ignorados: $discos_ignorados"
}

# Função para desmontar pontos de montagem existentes
desmontar_pontos_montagem_existentes() {
    log "INFO" "🔄 Verificando e desmontando pontos de montagem existentes..."
    
    # Garantir que o diretório base existe
    mkdir -p "/home/jonasrafael/discos"
    
    # Lista de diretórios e dispositivos para desmontar
    local diretorios_para_desmontar=(
        "/mnt/compartilhados"
        "/mnt/compartilhados/sdc"
        "/mnt/compartilhados/sdc1"
        "/home/jonasrafael/discos"
    )

    local dispositivos_para_desmontar=(
        "/dev/sdc1"
        "/dev/sdc"
        "/dev/sdb1"
    )

    # Desmontar diretórios
    for dir in "${diretorios_para_desmontar[@]}"; do
        # Verificar se o diretório está montado
        if mountpoint -q "$dir" || mount | grep -q "$dir"; then
            log "AVISO" "🔌 Tentando desmontar $dir..."
            
            # Sequência de tentativas de desmontagem
            umount "$dir" 2>/dev/null ||
            umount -f "$dir" 2>/dev/null ||
            umount -l "$dir" 2>/dev/null ||
            { 
                log "ERRO" "❌ Falha ao desmontar $dir" 
                fuser -km "$dir" 2>/dev/null  # Forçar desconexão de processos
            }
        fi
    done

    # Desmontar dispositivos específicos
    for dispositivo in "${dispositivos_para_desmontar[@]}"; do
        if mount | grep -q "$dispositivo"; then
            log "AVISO" "🔌 Tentando desmontar dispositivo $dispositivo..."
            
            # Sequência de tentativas de desmontagem
            umount "$dispositivo" 2>/dev/null ||
            umount -f "$dispositivo" 2>/dev/null ||
            umount -l "$dispositivo" 2>/dev/null ||
            { 
                log "ERRO" "❌ Falha ao desmontar $dispositivo" 
                fuser -km "$dispositivo" 2>/dev/null  # Forçar desconexão de processos
            }
        fi
    done

    # Limpar entradas antigas do fstab relacionadas a esses dispositivos
    sed -i '/sdc1/d' /etc/fstab 2>/dev/null
    sed -i '/sdb1/d' /etc/fstab 2>/dev/null

    # Criar subdiretórios para discos
    local disk_names=("sistema" "disco1" "disco2" "disco3" "disco4" "disco5")
    for disk_name in "${disk_names[@]}"; do
        mkdir -p "/home/jonasrafael/discos/$disk_name"
        chmod 777 "/home/jonasrafael/discos/$disk_name"
    done

    # Recarregar tabela de partições
    partprobe 2>/dev/null
}

# Função para recuperar boot
recuperar_boot() {
    log "🔧 Iniciando processo de recuperação de boot..."

    # Verificar privilégios de root
    if [[ $EUID -ne 0 ]]; then
        log "ERRO" "❌ Esta função requer privilégios de root"
        return 1
    fi

    # Obter informações de proteção do sistema raiz
    local root_info=$(proteger_sistema_raiz)
    local root_device=$(echo "$root_info" | cut -d: -f1)
    local root_uuid=$(echo "$root_info" | cut -d: -f2)

    # Montar sistema de arquivos em modo de escrita
    log "📂 Remontando sistema de arquivos em modo de escrita"
    mount -o remount,rw /

    # Backup do fstab original
    log "💾 Criando backup do fstab"
    cp /etc/fstab /etc/fstab.backup_$(date +"%Y%m%d_%H%M%S")

    # Criar diretórios de montagem seguros
    log "📁 Criando diretórios de montagem seguros"
    criar_pontos_montagem

    # Gerar novo fstab com opções seguras
    log "📝 Gerando novo fstab com opções de montagem seguras"
    local temp_fstab=$(mktemp)
    
    # Preservar TODAS as entradas originais do sistema
    grep -E '^(UUID|LABEL|/dev)' /etc/fstab > "$temp_fstab"
    
    # Adicionar entradas para discos externos com opções de montagem seguras
    echo "# Discos externos - Montagem segura" >> "$temp_fstab"
    
    # Encontrar e adicionar dispositivos externos de forma dinâmica
    local dispositivos=()
    while read -r dispositivo; do
        if [[ -n "$dispositivo" && "$dispositivo" =~ ^/dev/(sd[b-z]|nvme[0-9]n[0-9])[0-9]* ]]; then
            # Validar cada dispositivo antes de adicionar
            if validar_dispositivo_externo "$dispositivo"; then
                dispositivos+=("$dispositivo")
            fi
        fi
    done < <(lsblk -npdo PATH,TYPE | grep "part$" | awk '{print $1}')

    # Processar cada dispositivo externo
    for dispositivo in "${dispositivos[@]}"; do
        # Ignorar dispositivo do sistema
        if [[ "$dispositivo" == "$root_device" ]]; then
            continue
        fi

        # Obter UUID e tipo de filesystem
        local uuid=""
        local tipo_fs=""
        uuid=$(blkid -o value -s UUID "$dispositivo")
        tipo_fs=$(blkid -o value -s TYPE "$dispositivo")

        # Definir nome do ponto de montagem
        local nome_disco=""
        case "$dispositivo" in
            "/dev/sdb1") nome_disco="disco1" ;;
            "/dev/sdc1") nome_disco="disco2" ;;
            "/dev/sdd1") nome_disco="disco3" ;;
            *) nome_disco="disco_extra_$(basename "$dispositivo")" ;;
        esac

        # Adicionar entrada ao fstab temporário com opções seguras
        if [[ -n "$uuid" && -n "$tipo_fs" ]]; then
            echo "UUID=$uuid /home/jonasrafael/discos/$nome_disco $tipo_fs noauto,nofail,x-systemd.automount,x-systemd.device-timeout=5s,uid=1000,gid=1000,utf8 0 2" >> "$temp_fstab"
            log "INFO" "✅ Adicionando entrada para $dispositivo em /home/jonasrafael/discos/$nome_disco"
        fi
    done

    # Substituir fstab com proteções
    mv "$temp_fstab" /etc/fstab
    chmod 644 /etc/fstab

    # Recarregar configurações do systemd
    log "🔄 Recarregando configurações do systemd"
    systemctl daemon-reload

    # Verificar sistema de arquivos
    log "🔍 Verificando sistemas de arquivos"
    for dispositivo in "${dispositivos[@]}"; do
        # Verificação extra de segurança
        if [[ "$dispositivo" != "$root_device" ]]; then
            fsck -f "$dispositivo" || true
        fi
    done

    log "✅ Recuperação de boot concluída. Reinicie o sistema."
}

# Função para identificar e proteger o dispositivo raiz do sistema
proteger_sistema_raiz() {
    # Identificar o dispositivo raiz do sistema
    local root_device=""
    local root_uuid=""
    local root_mountpoint="/"

    # Método 1: Obter dispositivo raiz do /proc/mounts
    root_device=$(awk '$2 == "/" {print $1}' /proc/mounts)

    # Método 2: Usar findmnt como backup
    if [[ -z "$root_device" ]]; then
        root_device=$(findmnt -n -o SOURCE /)
    fi

    # Obter UUID do dispositivo raiz
    root_uuid=$(blkid -o value -s UUID "$root_device")

    # Log de diagnóstico
    log "🔒 Proteção do Sistema Raiz:"
    log "   Dispositivo Raiz: $root_device"
    log "   UUID Raiz: $root_uuid"

    # Retornar dispositivo e UUID para uso em outras funções
    echo "$root_device:$root_uuid"
}

# Função de segurança para validar dispositivos externos
validar_dispositivo_externo() {
    local dispositivo="$1"
    local root_info=$(proteger_sistema_raiz)
    local root_device=$(echo "$root_info" | cut -d: -f1)
    local root_uuid=$(echo "$root_info" | cut -d: -f2)

    # Verificações de segurança
    if [[ -z "$dispositivo" ]]; then
        log "ERRO" "❌ Dispositivo inválido"
        return 1
    fi

    # Verificar se o dispositivo é o mesmo do sistema
    if [[ "$dispositivo" == "$root_device" ]]; then
        log "ERRO" "❌ Tentativa de modificar dispositivo do sistema raiz bloqueada"
        return 1
    fi

    # Verificar UUID
    local dispositivo_uuid=$(blkid -o value -s UUID "$dispositivo")
    if [[ "$dispositivo_uuid" == "$root_uuid" ]]; then
        log "ERRO" "❌ UUID do dispositivo coincide com UUID do sistema raiz"
        return 1
    fi

    # Verificar se o dispositivo está em uso pelo sistema
    if mount | grep -q "$dispositivo"; then
        log "AVISO" "⚠️ Dispositivo $dispositivo já está montado por outro ponto do sistema"
        return 1
    fi

    # Verificações adicionais de segurança
    if [[ ! -b "$dispositivo" ]]; then
        log "ERRO" "❌ Dispositivo $dispositivo não é um dispositivo de bloco válido"
        return 1
    fi

    return 0
}

# Adicionar opção de recuperação de boot na linha de comando
if [[ "${1:-}" == "recuperar_boot" ]]; then
    recuperar_boot
    exit 0
fi

# Função principal
main() {
    log "INFO" "🚀 Iniciando script de montagem de partições"

    # Verificar privilégios de root
    if [[ $EUID -ne 0 ]]; then
        log "ERRO" "❌ Este script deve ser executado com sudo ou como root"
        exit 1
    fi

    # Desmontar pontos de montagem existentes antes de começar
    desmontar_pontos_montagem_existentes

    # Montar discos compartilhados
    montar_discos_compartilhados

    # Atualizar fstab e recarregar systemd
    atualizar_fstab

    log "SUCESSO" "✨ Script de montagem concluído"
}

# Executar main apenas se o script for executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
