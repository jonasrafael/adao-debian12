#Por sua conta em risco, your own risk, por tu cuenta boludo!

#!/bin/bash

# Script de Instalação de Requisitos para Montagem de Partições

# Definir cores para saída
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sem cor

# Função de log
log() {
    local tipo="$1"
    local mensagem="$2"
    local cor

    case "$tipo" in
        "INFO")    cor=$GREEN ;;
        "AVISO")   cor=$YELLOW ;;
        "ERRO")    cor=$RED ;;
        *)         cor=$NC ;;
    esac

    echo -e "${cor}[${tipo}]${NC} ${mensagem}"
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
   log "ERRO" "Este script deve ser executado com sudo ou como root"
   exit 1
fi

# Atualizar repositórios
log "INFO" "Atualizando lista de pacotes..."
apt update

# Pacotes base
BASE_PACKAGES=(
    "bash"
    "mount"
    "util-linux"
    "coreutils"
    "findutils"
    "grep"
    "gawk"
    "xz-utils"
    "kmod"
)

# Pacotes de sistemas de arquivos
FS_PACKAGES=(
    "ntfs-3g"
    "hfsprogs"
    "apfs-fuse"
    "e2fsprogs"
)

# Instalar pacotes base
log "INFO" "Instalando pacotes base..."
apt install -y "${BASE_PACKAGES[@]}"

# Instalar pacotes de sistemas de arquivos
log "INFO" "Instalando suporte a sistemas de arquivos..."
apt install -y "${FS_PACKAGES[@]}"

# Criar diretório de montagem
log "INFO" "Criando diretório de montagem..."
mkdir -p /home/jonasrafael/discos
chown jonasrafael:jonasrafael /home/jonasrafael/discos
chmod 755 /home/jonasrafael/discos

# Verificar módulos do kernel
log "INFO" "Verificando módulos do kernel..."
KERNEL_MODULES=("hfsplus" "ntfs" "apfs" "ext4")
for modulo in "${KERNEL_MODULES[@]}"; do
    if modinfo "$modulo" &>/dev/null; then
        log "INFO" "Módulo $modulo encontrado"
    else
        log "AVISO" "Módulo $modulo não encontrado"
    fi
done

# Atualizar initramfs
log "INFO" "Atualizando initramfs..."
update-initramfs -u

# Limpar pacotes
log "INFO" "Limpando pacotes desnecessários..."
apt autoremove -y
apt clean

log "SUCESSO" "Instalação de requisitos concluída com sucesso!"

# Mensagem final
echo -e "\n${GREEN}🚀 Ambiente preparado para montagem de partições! 🚀${NC}"
