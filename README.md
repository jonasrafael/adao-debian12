# 🔌 ADAO - Multipartition Mounting Script for Debian 12

## 📝 Descrição

Adão, comeu a maçã e legalizou para você um script avançado de montagem de partições para Debian 12, projetado para quem quer montar aquele servidor de backup com vários hds velhos de diferentes sistemas de arquivos para gerenciar (ler e escrever) com segurança e facilidade de uso. Por ssh você tem acesso a arquivos de qualquer lugar do mundo e pelo samba acesso local para jogar seus jogos preferidos.

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

# Histórico de Versões do Script Adão

## [1.4.0] - 2025-02-16
### Experimental
- Função `integrar_systemd_devices()` para gerenciamento de dispositivos
- Função `detectar_filesystem_avancado()` com detalhamento de dispositivos

### Adicionado
- Suporte a opções de linha de comando para funções experimentais
- Integração opcional com systemd
- Detecção avançada de filesystem

### Modificações
- Mantido comportamento padrão do script
- Funções experimentais não afetam execução principal

## [1.3.0] - 2025-02-16
### Adicionado
- Função `verificar_dependencias()` para checagem e instalação automática de pacotes
- Suporte aprimorado para Debian 12 e Crunchbang++
- Verificação de módulos de filesystem durante inicialização
- Tratamento de pacotes opcionais e necessários

### Segurança
- Função `proteger_sistema_raiz()` para identificação segura do dispositivo raiz
- Função `validar_dispositivo_externo()` com múltiplas camadas de verificação
- Proteção contra modificações acidentais no sistema de arquivos raiz

### Modificações
- Atualizado cabeçalho com informações de versão
- Adicionado log de mudanças no script principal
- Melhorada a robustez da função de recuperação de boot

## [1.2.0] - 2025-02-16
### Adicionado
- Método de proteção do sistema de arquivos raiz
- Verificações de segurança para dispositivos externos
- Função de recuperação de boot com proteções adicionais
- Verificação e instalação automática de dependências

## [1.0.0] - 2025-02-15
### Inicial
- Suporte básico para montagem de dispositivos
- Logging detalhado
- Suporte a múltiplos sistemas de arquivos
- Montagem dinâmica de partições

## Próximas Versões Planejadas
- [ ] Suporte a criptografia de dispositivos
- [ ] Interface de configuração interativa
- [ ] Integração com gerenciamento de dispositivos do systemd
- [ ] Melhorias na detecção de filesystem

## Convenções de Versionamento
- MAJOR.MINOR.PATCH
- MAJOR: Mudanças incompatíveis na API
- MINOR: Novas funcionalidades compatíveis
- PATCH: Correções de bugs e melhorias menores


## 🤝 Contribuições

Contribuições são bem-vindas! Por favor, abra uma issue ou envie um pull request.

## 📄 Licença

[Especificar Licença - por exemplo, MIT]

## 👥 Autor

Jonas Rafael
