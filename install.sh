#!/bin/bash

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Necessário executar com sudo"
    exit 1
fi

# Verificar sistema operacional
verificar_sistema() {
    local SISTEMA=$(grep -oP '(?<=^ID=).*' /etc/os-release | tr -d '"')
    local DISTRIBUICAO=$(grep -oP '(?<=^PRETTY_NAME=).*' /etc/os-release | tr -d '"')

    case "$SISTEMA" in
        debian|crunchbangplusplus)
            echo "✅ Sistema compatível: $DISTRIBUICAO"
            ;;
        *)
            echo "❌ Sistema não suportado: $DISTRIBUICAO"
            exit 1
            ;;
    esac
}

# Diretórios
INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Instalar dependências
instalar_dependencias() {
    echo "🔧 Instalando dependências..."
    apt-get update
    apt-get install -y \
        ntfs-3g \
        hfsprogs \
        exfat-fuse \
        dosfstools \
        btrfs-progs \
        apfs-fuse \
        fuse
    
    # Verificar instalação de dependências
    local DEPENDENCIAS=(
        "mount.ntfs-3g"
        "fsck.hfsplus"
        "mount.exfat-fuse"
        "apfs-fuse"
    )

    for dep in "${DEPENDENCIAS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "⚠️ Dependência não encontrada: $dep"
        fi
    done
}

# Instalar scripts
instalar_scripts() {
    local scripts=(
        "adao.sh:adao"
        "calcular-consumo.sh:calcular-consumo"
    )

    for script in "${scripts[@]}"; do
        local source_name=$(echo "$script" | cut -d: -f1)
        local target_name=$(echo "$script" | cut -d: -f2)
        local source_paths=(
            "$SCRIPT_DIR/$source_name"
            "$HOME/$source_name"
            "/Users/jonasrafael/$source_name"
        )

        local found=false
        for path in "${source_paths[@]}"; do
            if [ -f "$path" ]; then
                cp "$path" "$INSTALL_DIR/$target_name"
                chmod +x "$INSTALL_DIR/$target_name"
                echo "✅ Instalado: $target_name de $path"
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            echo "❌ Script $source_name não encontrado"
        fi
    done
}

# Configurações adicionais
configuracoes_sistema() {
    echo "🔒 Configurando montagem de sistemas de arquivos..."
    
    # Ajustar configurações de montagem
    sed -i 's/^MOUNTOPTIONS=.*/MOUNTOPTIONS="user,exec,utf8,uid=1000,gid=1000"/' /etc/adduser.conf
    
    # Adicionar suporte FUSE para usuários não-root
    if ! grep -q "user_allow_other" /etc/fuse.conf; then
        echo "user_allow_other" >> /etc/fuse.conf
    fi
}

# Executar instalação
main() {
    verificar_sistema
    instalar_dependencias
    instalar_scripts
    configuracoes_sistema
    
    echo "🎉 Instalação do Adão concluída no CrunchBang++!"
}

# Iniciar instalação
main
exit 0
