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

# Função para carregar módulos do kernel
carregar_modulos_kernel() {
    local MODULOS=(
        "ntfs"
        "apfs"
        "hfsplus"
        "ext4"
    )

    echo "🔌 Carregando módulos do kernel..."

    # Verificar versão do kernel
    local KERNEL_VERSION=$(uname -r)
    local KERNEL_MODULES_DIR="/lib/modules/${KERNEL_VERSION}"

    # Criar diretório de módulos se não existir
    mkdir -p "$KERNEL_MODULES_DIR/kernel/fs"

    for modulo in "${MODULOS[@]}"; do
        # Tratamento específico para cada módulo
        case "$modulo" in
            "ntfs")
                # Usar ntfs-3g como alternativa
                if ! modprobe ntfs 2>/dev/null; then
                    echo "⚠️ Módulo NTFS não encontrado. Usando ntfs-3g..."
                    apt-get install -y ntfs-3g
                    # Criar link simbólico para módulo
                    ln -sf /usr/bin/ntfs-3g "$KERNEL_MODULES_DIR/kernel/fs/ntfs.ko" 2>/dev/null
                fi
                ;;
            
            "apfs")
                # Usar apfs-fuse como alternativa
                echo "ℹ️ Suporte a APFS será instalado via apfs-fuse"
                ;;
            
            "hfsplus")
                if ! modprobe hfsplus 2>/dev/null; then
                    echo "⚠️ Módulo HFS+ não encontrado. Instalando hfsprogs..."
                    apt-get install -y hfsprogs
                fi
                ;;
            
            "ext4")
                # Módulo ext4 geralmente já está no kernel
                modprobe ext4 || true
                ;;
        esac
    done

    # Atualizar mapa de módulos
    depmod -a
}

# Função para configurar ambiente de localização
configurar_localizacao() {
    echo "🌐 Configurando ambiente de localização..."
    
    # Verificar e gerar locales
    if ! locale -a | grep -q "en_US.UTF-8"; then
        echo "Gerando locale en_US.UTF-8..."
        locale-gen en_US.UTF-8
    fi

    # Configurar variáveis de ambiente
    export LANGUAGE=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8

    # Atualizar configurações de localização
    update-locale LANG=en_US.UTF-8
}

# Função para instalar e configurar FUSE e apfs-fuse
instalar_fuse_apfs() {
    echo "🔧 Instalando FUSE e preparando apfs-fuse..."

    # Atualizar repositórios
    apt-get update

    # Instalar dependências necessárias
    apt-get install -y \
        fuse \
        libfuse3-dev \
        bzip2 \
        libbz2-dev \
        cmake \
        gcc \
        git \
        libattr1-dev \
        zlib1g-dev \
        build-essential \
        libssl-dev

    # Criar diretório temporário para compilação
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Clonar repositório apfs-fuse
    if ! git clone https://github.com/sgan81/apfs-fuse.git; then
        echo "❌ Falha ao clonar repositório apfs-fuse"
        return 1
    fi

    # Entrar no diretório do projeto
    cd apfs-fuse

    # Inicializar e atualizar submódulos
    git submodule init
    git submodule update

    # Preparar compilação
    mkdir -p build
    cd build

    # Configurar com CMake
    if ! cmake ..; then
        echo "❌ Falha na configuração do CMake"
        return 1
    fi

    # Compilar
    if ! make; then
        echo "❌ Falha na compilação do apfs-fuse"
        return 1
    fi

    # Instalar
    if ! make install; then
        echo "❌ Falha na instalação do apfs-fuse"
        return 1
    fi

    # Limpar diretório temporário
    cd /
    rm -rf "$temp_dir"

    # Verificar instalação
    if ! command -v apfs-fuse &> /dev/null; then
        echo "❌ Instalação do apfs-fuse não encontrada"
        return 1
    fi

    echo "✅ FUSE e apfs-fuse instalados com sucesso!"
    return 0
}

# Função para resolver conflitos de pacotes FUSE
resolver_conflitos_fuse() {
    echo "🔧 Resolvendo conflitos de pacotes FUSE para CrunchBang++..."

    # Configuração de locales
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LANGUAGE=en_US.UTF-8

    # Atualizar configurações de locales
    sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    locale-gen en_US.UTF-8 > /dev/null 2>&1
    update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 > /dev/null 2>&1

    # Limpar e atualizar repositórios
    apt-get clean
    apt-get update -qq

    # Desinstalar pacotes conflitantes
    apt-get remove -y --purge \
        fuse \
        fuse3 \
        libfuse2 \
        libfuse-dev \
        libfuse3-3 \
        libfuse3-dev \
        ntfs-3g \
        exfat-fuse \
        || true

    # Instalar FUSE e apfs-fuse
    if ! instalar_fuse_apfs; then
        echo "❌ Falha na instalação de FUSE e apfs-fuse"
        return 1
    fi

    # Configurar alternativas de montagem
    if [ -f "/usr/bin/fusermount3" ]; then
        update-alternatives --install /usr/bin/fusermount fusermount /usr/bin/fusermount3 100
        update-alternatives --set fusermount /usr/bin/fusermount3
    fi

    # Adicionar suporte a sistemas de arquivos
    modprobe fuse || true
    modprobe ntfs3 || true

    echo "✅ Conflitos de FUSE resolvidos com sucesso"
    return 0
}

# Função para instalar dependências específicas
instalar_dependencias_especificas() {
    echo "🛠️ Instalando dependências específicas..."

    # Atualizar lista de pacotes
    apt-get update

    # Pacotes a serem instalados
    local PACOTES=(
        "ntfs-3g"
        "hfsprogs"
        "exfat-fuse"
    )

    # Substituir pacotes obsoletos
    for pacote in "${PACOTES[@]}"; do
        apt-get install -y "$pacote" || {
            echo "❌ Falha ao instalar $pacote"
            
            # Tratamentos específicos
            case "$pacote" in
                "exfat-utils")
                    echo "🔍 Usando exfat-fuse como alternativa"
                    apt-get install -y exfat-fuse
                    ;;
            esac
        }
    done

    # Instalar dependências FUSE
    if ! instalar_fuse_apfs; then
        echo "❌ Falha na instalação das dependências FUSE"
        return 1
    fi

    # Instalar apfs-fuse se não estiver presente
    if ! command -v apfs-fuse &> /dev/null; then
        echo "🍎 Instalando apfs-fuse..."
        instalar_fuse_apfs || {
            echo "❌ Falha na instalação do APFS-FUSE"
            return 1
        }
    fi

    return 0
}

# Função para compilar e instalar APFS-FUSE
compilar_apfs_fuse() {
    echo "🍎 Compilando APFS-FUSE a partir do código-fonte..."
    
    # Criar diretório temporário
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Clonar repositório
    if ! git clone --recursive https://github.com/sgan81/apfs-fuse.git; then
        echo "❌ Falha ao clonar repositório do APFS-FUSE"
        return 1
    fi
    
    cd apfs-fuse
    
    # Preparar compilação
    mkdir -p build
    cd build
    
    # Configurar CMake com flags adicionais
    local FUSE_INCLUDE_DIRS=$(pkg-config --cflags fuse3)
    
    if ! cmake -DCMAKE_BUILD_TYPE=Release \
               -DCMAKE_INSTALL_PREFIX=/usr/local \
               -DBUILD_SHARED_LIBS=ON \
               -DCMAKE_C_FLAGS="-Wno-sign-compare" \
               -DCMAKE_CXX_FLAGS="-Wno-sign-compare" \
               -DFUSE_INCLUDE_DIRS=/usr/include/fuse3 \
               ..; then
        echo "❌ Falha na configuração do CMake para APFS-FUSE"
        return 1
    fi
    
    # Modificar código-fonte para corrigir warnings
    sed -i 's/for (int i = 0; i < table_size; i++)/for (size_t i = 0; i < table_size; i++)/g' \
        ../3rdparty/lzfse/src/lzfse_fse.h
    
    # Compilar
    if ! make -j$(nproc); then
        echo "❌ Falha na compilação do APFS-FUSE"
        
        # Identificar dependências faltantes
        local missing_headers=$(find . -type f -name "*.cpp" -exec grep -l "#include" {} \; | xargs grep -l "No such file or directory")
        echo "🔍 Cabeçalhos ausentes: $missing_headers"
        
        return 1
    fi
    
    # Instalar
    if ! make install; then
        echo "❌ Falha na instalação do APFS-FUSE"
        return 1
    fi
    
    # Adicionar biblioteca ao sistema
    ldconfig
    
    # Verificar instalação
    if ! command -v apfs-fuse &> /dev/null; then
        echo "❌ Comando apfs-fuse não encontrado após instalação"
        return 1
    fi
    
    echo "✅ APFS-FUSE instalado com sucesso!"
    return 0
}

# Função para instalar dependências de compilação
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

# Função para configurar Samba e compartilhamento de discos
configurar_samba_discos() {
    echo "🖥️ Configurando Samba e compartilhamento de discos..."

    # Criar diretório de discos se não existir
    mkdir -p /home/jonas/discos

    # Instalar Samba
    apt-get update -qq
    apt-get install -y samba cifs-utils

    # Configurar permissões do diretório
    chown -R jonas:jonas /home/jonas/discos
    chmod -R 775 /home/jonas/discos

    # Verificar se usuário jonas existe
    if ! id "jonas" &>/dev/null; then
        echo "❌ Usuário jonas não encontrado. Criando usuário..."
        adduser --disabled-password --gecos "" jonas
    fi

    # Configurar Samba para compartilhamento
    local SAMBA_CONFIG="/etc/samba/smb.conf"
    
    # Backup da configuração original
    cp "$SAMBA_CONFIG" "${SAMBA_CONFIG}.bak" 2>/dev/null

    # Limpar configurações anteriores de compartilhamento
    sed -i '/\[discos\]/,/^$/d' "$SAMBA_CONFIG"

    # Adicionar configuração de compartilhamento
    cat << EOF >> "$SAMBA_CONFIG"

[discos]
    path = /home/jonas/discos
    browseable = yes
    read only = no
    writable = yes
    guest ok = no
    valid users = jonas
    create mask = 0775
    directory mask = 0775
    force user = jonas
    force group = jonas
EOF

    # Gerar senha aleatória segura
    local SAMBA_PASS=$(openssl rand -base64 12)
    
    # Adicionar usuário jonas ao Samba com senha segura
    (echo "$SAMBA_PASS"; echo "$SAMBA_PASS") | smbpasswd -a jonas
    
    # Salvar senha em arquivo seguro para referência
    echo "Senha Samba para usuário jonas: $SAMBA_PASS" > /home/jonas/samba_password.txt
    chmod 600 /home/jonas/samba_password.txt
    chown jonas:jonas /home/jonas/samba_password.txt

    # Reiniciar serviço Samba
    systemctl restart smbd
    systemctl enable smbd

    # Configurar firewall para Samba (se UFW estiver ativo)
    if command -v ufw &> /dev/null; then
        ufw allow from any to any port 445 proto tcp comment "Samba"
        ufw allow from any to any port 139 proto tcp comment "Samba"
    fi

    echo "✅ Samba configurado com sucesso para compartilhamento de discos"
    echo "📝 Senha do Samba salva em /home/jonas/samba_password.txt"
    return 0
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

# Função para configurar Samba e compartilhamento de discos
configurar_samba_discos() {
    echo "🖥️ Configurando Samba e compartilhamento de discos..."

    # Criar diretório de discos se não existir
    mkdir -p /home/jonas/discos

    # Instalar Samba
    apt-get update -qq
    apt-get install -y samba cifs-utils

    # Configurar permissões do diretório
    chown -R jonas:jonas /home/jonas/discos
    chmod -R 775 /home/jonas/discos

    # Verificar se usuário jonas existe
    if ! id "jonas" &>/dev/null; then
        echo "❌ Usuário jonas não encontrado. Criando usuário..."
        adduser --disabled-password --gecos "" jonas
    fi

    # Configurar Samba para compartilhamento
    local SAMBA_CONFIG="/etc/samba/smb.conf"
    
    # Backup da configuração original
    cp "$SAMBA_CONFIG" "${SAMBA_CONFIG}.bak" 2>/dev/null

    # Limpar configurações anteriores de compartilhamento
    sed -i '/\[discos\]/,/^$/d' "$SAMBA_CONFIG"

    # Adicionar configuração de compartilhamento
    cat << EOF >> "$SAMBA_CONFIG"

[discos]
    path = /home/jonas/discos
    browseable = yes
    read only = no
    writable = yes
    guest ok = no
    valid users = jonas
    create mask = 0775
    directory mask = 0775
    force user = jonas
    force group = jonas
EOF

    # Gerar senha aleatória segura
    local SAMBA_PASS=$(openssl rand -base64 12)
    
    # Adicionar usuário jonas ao Samba com senha segura
    (echo "$SAMBA_PASS"; echo "$SAMBA_PASS") | smbpasswd -a jonas
    
    # Salvar senha em arquivo seguro para referência
    echo "Senha Samba para usuário jonas: $SAMBA_PASS" > /home/jonas/samba_password.txt
    chmod 600 /home/jonas/samba_password.txt
    chown jonas:jonas /home/jonas/samba_password.txt

    # Reiniciar serviço Samba
    systemctl restart smbd
    systemctl enable smbd

    # Configurar firewall para Samba (se UFW estiver ativo)
    if command -v ufw &> /dev/null; then
        ufw allow from any to any port 445 proto tcp comment "Samba"
        ufw allow from any to any port 139 proto tcp comment "Samba"
    fi

    echo "✅ Samba configurado com sucesso para compartilhamento de discos"
    echo "📝 Senha do Samba salva em /home/jonas/samba_password.txt"
    return 0
}

# Executar instalação
main() {
    # Verificar requisitos antes de iniciar
    if ! verificar_requisitos; then
        echo "❌ Falha na verificação de requisitos. Não é possível continuar."
        exit 1
    fi

    # Carregar módulos do kernel
    carregar_modulos_kernel

    # Instalar dependências específicas
    if ! instalar_dependencias_especificas; then
        echo "❌ Falha na instalação de dependências específicas"
        exit 1
    fi

    verificar_sistema
    instalar_dependencias
    instalar_scripts
    configuracoes_sistema
    configurar_samba_discos
    
    echo "🎉 Instalação do Adão concluída no CrunchBang++!"
}

# Iniciar instalação
main
exit 0
