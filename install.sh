#!/bin/bash

# Verificar requisitos de sistema
verificar_requisitos() {
    local FALHA=0

    # Verificar versão do bash
    if [[ -z "$BASH_VERSION" ]]; then
        echo "❌ Bash não encontrado"
        FALHA=1
    else
        # Comparar versão do bash
        bash_major=$(echo "$BASH_VERSION" | cut -d. -f1)
        bash_minor=$(echo "$BASH_VERSION" | cut -d. -f2)
        
        if [[ $bash_major -lt 5 ]]; then
            echo "❌ Versão do Bash muito antiga. Requer 5.0+, atual: $BASH_VERSION"
            FALHA=1
        fi
    fi

    # Verificar pacotes essenciais
    local PACOTES_NECESSARIOS=(
        "mount"
        "umount"
        "lsblk"
        "find"
        "grep"
        "awk"
        "xz"
        "kmod"
    )

    for pacote in "${PACOTES_NECESSARIOS[@]}"; do
        if ! command -v "$pacote" &> /dev/null; then
            echo "❌ Pacote necessário não encontrado: $pacote"
            FALHA=1
        fi
    done

    # Verificar módulos do kernel
    local MODULOS_NECESSARIOS=(
        "hfsplus"
        "ntfs"
        "apfs"
        "ext4"
    )

    for modulo in "${MODULOS_NECESSARIOS[@]}"; do
        if ! modinfo "$modulo" &> /dev/null; then
            echo "⚠️ Módulo de kernel não encontrado: $modulo"
        fi
    done

    # Verificar privilégios de root
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Este script requer privilégios de root/sudo"
        FALHA=1
    fi

    # Verificar sistema operacional
    local SISTEMA=$(grep -oP '(?<=^ID=).*' /etc/os-release | tr -d '"')
    local VERSAO=$(grep -oP '(?<=^VERSION_ID=).*' /etc/os-release | tr -d '"')

    if [[ "$SISTEMA" != "debian" && "$SISTEMA" != "crunchbangplusplus" ]]; then
        echo "❌ Sistema operacional não suportado: $SISTEMA $VERSAO"
        FALHA=1
    fi

    # Verificar dependências específicas
    local DEPENDENCIAS_ESPECIFICAS=(
        "ntfs-3g"
        "hfsprogs"
        "apfs-fuse"
    )

    for dep in "${DEPENDENCIAS_ESPECIFICAS[@]}"; do
        if ! dpkg -s "$dep" &> /dev/null; then
            echo "⚠️ Dependência específica não instalada: $dep"
        fi
    done

    # Verificar espaço em disco
    local espaco_minimo=1024  # 1 GB
    local espaco_disponivel=$(df -m / | awk 'NR==2 {print $4}')

    if [[ $espaco_disponivel -lt $espaco_minimo ]]; then
        echo "❌ Espaço em disco insuficiente. Requer pelo menos $espaco_minimo MB, disponível: $espaco_disponivel MB"
        FALHA=1
    fi

    # Resultado final
    if [[ $FALHA -eq 1 ]]; then
        echo "❌ Alguns requisitos não foram atendidos. Por favor, corrija os problemas acima."
        return 1
    else
        echo "✅ Todos os requisitos de sistema verificados com sucesso!"
        return 0
    fi
}

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

# Instalar dependências de compilação
instalar_dependencias_compilacao() {
    echo "🛠️ Instalando dependências de compilação..."
    apt-get update
    apt-get install -y \
        git \
        cmake \
        build-essential \
        libfuse-dev \
        libssl-dev \
        libz-dev \
        libbz2-dev
}

# Instalar apfs-fuse do GitHub
instalar_apfs_fuse() {
    echo "🍎 Instalando apfs-fuse do GitHub..."
    
    # Criar diretório temporário
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Clonar repositório
    if ! git clone https://github.com/sgan81/apfs-fuse.git; then
        echo "❌ Falha ao clonar repositório do apfs-fuse"
        return 1
    fi
    
    cd apfs-fuse
    
    # Atualizar submódulos
    if ! git submodule update --init; then
        echo "❌ Falha ao atualizar submódulos do apfs-fuse"
        return 1
    fi
    
    # Preparar compilação
    mkdir -p build
    cd build
    
    # Configurar com CMake com flags adicionais
    if ! cmake -DCMAKE_BUILD_TYPE=Release \
               -DCMAKE_INSTALL_PREFIX=/usr/local \
               -DBUILD_SHARED_LIBS=ON \
               ..; then
        echo "❌ Falha na configuração do CMake para apfs-fuse"
        return 1
    fi
    
    # Compilar com verificação de erros
    if ! make -j$(nproc); then
        echo "❌ Falha na compilação do apfs-fuse"
        
        # Tentar identificar dependências faltantes
        echo "🔍 Verificando dependências..."
        local missing_deps=$(find /tmp -name "*.h" | grep -E "bzlib.h|lzma.h|zlib.h" | xargs -I {} echo "Faltando: {}")
        
        if [ -n "$missing_deps" ]; then
            echo "$missing_deps"
            echo "🛠️ Tentando instalar dependências adicionais..."
            apt-get update
            apt-get install -y \
                libbz2-dev \
                liblzma-dev \
                zlib1g-dev
        fi
        
        return 1
    fi
    
    # Instalar
    if ! make install; then
        echo "❌ Falha na instalação do apfs-fuse"
        return 1
    fi
    
    # Adicionar biblioteca ao sistema
    if [ -f /usr/local/lib/libapfs.so ]; then
        ldconfig
    fi
    
    # Limpar diretório temporário
    cd /
    rm -rf "$temp_dir"
    
    echo "✅ apfs-fuse instalado com sucesso!"
    return 0
}

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
        fuse \
        hfsutils \
        exfat-utils \
        libfuse2 \
        libfuse3-dev \
        liblzma-dev \
        zlib1g-dev

    # Instalar dependências de compilação
    instalar_dependencias_compilacao

    # Instalar apfs-fuse com tratamento de erro
    if ! instalar_apfs_fuse; then
        echo "⚠️ Falha na instalação do apfs-fuse. Tentando método alternativo..."
        
        # Método alternativo: baixar binário pré-compilado
        local temp_dir=$(mktemp -d)
        cd "$temp_dir"
        
        if wget https://github.com/sgan81/apfs-fuse/releases/latest/download/apfs-fuse-linux-x86_64.tar.gz; then
            tar -xzvf apfs-fuse-linux-x86_64.tar.gz
            cp apfs-fuse /usr/local/bin/
            cp apfs-fuse-static /usr/local/bin/
            chmod +x /usr/local/bin/apfs-fuse*
            echo "✅ Instalação alternativa do apfs-fuse concluída"
        else
            echo "❌ Falha na instalação alternativa do apfs-fuse"
        fi
        
        cd /
        rm -rf "$temp_dir"
    fi
    
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
            # Tentar instalar pacotes alternativos
            case "$dep" in
                "fsck.hfsplus")
                    apt-get install -y hfsprogs hfsutils
                    ;;
                "mount.exfat-fuse")
                    apt-get install -y exfat-fuse exfat-utils
                    ;;
                "apfs-fuse")
                    # Última tentativa de instalação
                    instalar_apfs_fuse || true
                    ;;
            esac
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
    # Verificar requisitos antes de iniciar
    if ! verificar_requisitos; then
        echo "❌ Falha na verificação de requisitos. Não é possível continuar."
        exit 1
    fi

    verificar_sistema
    instalar_dependencias
    instalar_scripts
    configuracoes_sistema
    
    echo "🎉 Instalação do Adão concluída no CrunchBang++!"
}

# Iniciar instalação
main
exit 0
