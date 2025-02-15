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

# Pacotes de dependência para compilação
BUILD_DEPENDENCIES=(
    "git"
    "cmake"
    "build-essential"
    "libfuse-dev"
    "libssl-dev"
    "libz-dev"
    "linux-headers-$(uname -r)"
)

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
    "e2fsprogs"
    "fuse"
)

# Instalar pacotes de dependência
log "INFO" "Instalando pacotes de dependência..."
apt install -y "${BUILD_DEPENDENCIES[@]}"

# Instalar pacotes base
log "INFO" "Instalando pacotes base..."
apt install -y "${BASE_PACKAGES[@]}"

# Instalar pacotes de sistemas de arquivos
log "INFO" "Instalando suporte a sistemas de arquivos..."
apt install -y "${FS_PACKAGES[@]}"

# Criar diretório de trabalho para APFS-FUSE
WORK_DIR="/opt/apfs-fuse"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clonar repositório APFS-FUSE
log "INFO" "Clonando repositório APFS-FUSE..."
git clone https://github.com/sgan81/apfs-fuse.git .
git submodule update --init --recursive

# Compilar APFS-FUSE
log "INFO" "Compilando APFS-FUSE..."
mkdir build
cd build
cmake ..
make
make install

# Criar link simbólico para facilitar uso
ln -s "$WORK_DIR/build/apfs-fuse" /usr/local/bin/apfs-fuse

# Criar diretório de montagem
log "INFO" "Criando diretório de montagem..."
mkdir -p /home/jonasrafael/discos
chown jonasrafael:jonasrafael /home/jonasrafael/discos
chmod 755 /home/jonasrafael/discos

# Função para instalar e carregar módulo do kernel
instalar_modulo_kernel() {
    local modulo="$1"
    
    # Tentar carregar o módulo
    modprobe "$modulo" 2>/dev/null
    
    # Se falhar, tentar recompilar
    if [ $? -ne 0 ]; then
        log "AVISO" "Módulo $modulo não encontrado. Tentando recompilar..."
        
        # Instalar pacotes de desenvolvimento do kernel
        apt install -y "linux-headers-$(uname -r)"
        
        # Tentar compilar módulo DKMS se disponível
        if command -v dkms &>/dev/null; then
            log "INFO" "Usando DKMS para instalar módulo $modulo"
            dkms autoinstall
        fi
        
        # Tentar carregar novamente
        modprobe "$modulo"
        
        if [ $? -eq 0 ]; then
            log "SUCESSO" "Módulo $modulo carregado com sucesso"
        else
            log "ERRO" "Falha ao carregar módulo $modulo"
        fi
    else
        log "SUCESSO" "Módulo $modulo já carregado"
    fi
}

# Módulos a serem verificados e carregados
KERNEL_MODULES=(
    "hfsplus"
    "ntfs"
    "ext4"
)

# Verificar e carregar módulos
for modulo in "${KERNEL_MODULES[@]}"; do
    instalar_modulo_kernel "$modulo"
done

# Verificar instalação do APFS-FUSE
if command -v apfs-fuse &>/dev/null; then
    log "SUCESSO" "APFS-FUSE instalado com sucesso!"
    apfs-fuse --version
else
    log "ERRO" "Falha na instalação do APFS-FUSE"
    exit 1
fi

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
