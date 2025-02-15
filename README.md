# 🔌 ADAO - Multipartition Mounting Script for Debian 12

## 📝 Descrição

Adão, comeu a maçã e legalizou para você um script avançado de montagem de partições para Debian 12, projetado para quem quer montar aquele servidor de backup com vários hds velhos para gerenciar múltiplos sistemas de arquivos com robustez, segurança e facilidade de uso. Por ssh você tem acesso a arquivos de qualquer lugar do mundo e pelo samba acesso local para jogar seus jogos preferidos.

## ✨ Recursos Principais

### 🌟 Suporte a Múltiplos Sistemas de Arquivos
- HFS+ (Apple)
- APFS (Apple)
- NTFS (Windows)
- Ext4 (Linux)

### 🔍 Descoberta Dinâmica de Módulos
- Localização automática de módulos do kernel
- Suporte a módulos compactados (.ko.xz)
- Verificação de integridade dos módulos

### 🛡️ Recursos de Segurança
- Verificação de privilégios de root
- Prevenção de montagens duplicadas
- Tratamento de erros detalhado
- Logs informativos com emojis

### 📊 Recursos de Montagem
- Montagem automática de partições descobertas
- Verificação de permissões de leitura/escrita
- Pontos de montagem padronizados
- Resumo detalhado de montagens

## 🚀 Pré-requisitos

- Debian 12
- Privilégios de root
- Kernel Linux com suporte a módulos HFS, NTFS, APFS

## 🛠️ Instalação

```bash
sudo chmod +x montar_particoes_multi.sh
sudo mv montar_particoes_multi.sh /usr/local/bin/
```

## 💻 Uso

```bash
sudo montar_particoes_multi.sh
```

## 🔧 Personalização

Edite o script para modificar:
- Caminhos de busca de módulos
- Diretórios de montagem
- Opções de montagem

## ⚠️ Avisos

- Sempre faça backup de seus dados
- Verifique compatibilidade com seu sistema
- Use com cautela em ambientes de produção

## 📋 Registro de Mudanças

### Versão 1.0
- Suporte inicial a HFS+, NTFS, APFS
- Descoberta dinâmica de módulos
- Logs detalhados
- Prevenção de montagens duplicadas

## 🤝 Contribuições

Contribuições são bem-vindas! Por favor, abra uma issue ou envie um pull request.

## 📄 Licença

[Especificar Licença - por exemplo, MIT]

## 👥 Autor

Jonas Rafael
