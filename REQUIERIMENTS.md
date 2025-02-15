# Requisitos de Sistema para Script de Montagem de Partições

## Sistemas Operacionais
- Debian 12 (Bookworm)
- Sistemas Linux baseados em Debian

## Pacotes do Sistema
- bash (versão 5.0+)
- mount
- umount
- lsblk
- find
- grep
- awk
- xz-utils
- kmod

## Módulos do Kernel
- Suporte a módulos de sistemas de arquivos:
  * hfsplus
  * ntfs
  * apfs
  * ext4

## Privilégios
- Acesso root/sudo

## Dependências Específicas
- ntfs-3g (para montagem de partições NTFS)
- hfsprogs (para suporte a HFS+)
- apfs-fuse (para suporte a APFS)

## Recomendações
- Kernel Linux 6.x+
- Espaço em /home/jonasrafael/discos/ para pontos de montagem
- Permissões de escrita no diretório de montagem
