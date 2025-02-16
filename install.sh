#!/bin/bash

# Script de Instalação para Debian 12 - Adão

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Necessário executar com sudo"
    exit 1
fi

# Verificar Debian 12
if ! grep -q 'Debian GNU/Linux 12' /etc/os-release; then
    echo "❌ Este script é para Debian 12"
    exit 1
fi

# Instalar dependências
instalar_dependencias() {
    echo "🔧 Instalando dependências..."
    apt-get update
    apt-get install -y \
        ntfs-3g \
        hfsprogs \
        exfat-fuse \
        exfat-utils \
        dosfstools \
        btrfs-progs
}

# Instalar scripts
instalar_scripts() {
    local INSTALL_DIR="/usr/local/bin"
    
    # Copiar scripts
    cp adao.sh "$INSTALL_DIR/adao"
    cp calcular_consumo_energia.sh "$INSTALL_DIR/calcular-consumo"
    
    # Permissões
    chmod +x "$INSTALL_DIR/adao"
    chmod +x "$INSTALL_DIR/calcular-consumo"
    
    echo "✅ Scripts instalados em $INSTALL_DIR"
}

# Configurações adicionais
configuracoes_sistema() {
    # Ajustar montagem de sistemas de arquivos
    echo "🔒 Configurando montagem de sistemas de arquivos..."
    
    # Adicionar suporte a montagem para usuários normais
    sed -i 's/^MOUNTOPTIONS=.*/MOUNTOPTIONS="user,exec,utf8,uid=1000,gid=1000"/' /etc/adduser.conf
}

# Executar instalação
main() {
    instalar_dependencias
    instalar_scripts
    configuracoes_sistema
    
    echo "🎉 Instalação do Adão concluída no Debian 12!"
}

# Iniciar instalação
main
exit 0
