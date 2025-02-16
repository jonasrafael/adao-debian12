# 👨 Adão: Multipartition Mounting Script for Debian 12

## 🏃‍♂️🪟 Sobre o Projeto

`Adão` é um script shell avançado e inteligente para montagem de partições em Debian 12, projetado para entusiastas de TI, administradores de sistemas e usuários que precisam gerenciar múltiplos dispositivos de armazenamento com diferentes sistemas de arquivos.

![Adão Script Demo](https://img.shields.io/badge/version-1.4.0-blue)
![Debian Support](https://img.shields.io/badge/Debian-12-red)
![Bash](https://img.shields.io/badge/Bash-4.4+-green)

## 🐧✨ Características Principais

### 🌐 Suporte Multiplataforma
- 📁 Sistemas de Arquivos Suportados:
  * NTFS (Windows)
  * HFS+ (macOS)
  * APFS (macOS)
  * Ext4 (Linux)
  * FAT32/exFAT
  * E muito mais!

### 🔒 Segurança em Primeiro Lugar
- Verificações de privilégios de root
- Prevenção de montagens duplicadas
- Proteção contra modificações no sistema de arquivos raiz
- Logs detalhados com rastreamento de eventos

### 🤖 Recursos Inteligentes
- Descoberta automática de dispositivos
- Verificação dinâmica de módulos do kernel
- Suporte a módulos compactados
- Tratamento robusto de erros

## 🛠 Instalação Rápida

```bash
# Baixar o script
wget https://github.com/jonasrafael/adao-script/raw/main/montar_particoes_multi.sh

# Dar permissões de execução
chmod +x montar_particoes_multi.sh

# Instalar dependências (opcional, mas recomendado)
sudo ./montar_particoes_multi.sh verificar_dependencias

# Mover para diretório do sistema
sudo mv montar_particoes_multi.sh /usr/local/bin/adao
```

## 💻 Modos de Uso

### Modo Padrão
```bash
# Montagem automática de todas as partições
sudo adao
```

### Modos Experimentais
```bash
# Integração com systemd
sudo adao systemd_integration

# Detecção avançada de filesystem
sudo adao advanced_detect
```

## 🔧 Personalização

Edite o script para configurar:
- Diretórios de montagem personalizados
- Opções de montagem específicas
- Logs e níveis de verbosidade

## 📋 Requisitos

- 🐧 Debian 12 (Bookworm)
- 🔑 Privilégios de root
- 🧩 Kernel Linux 5.10+ com suporte a módulos

## ⚠️ Avisos e Precauções

- 💾 Sempre faça backup de seus dados
- 🚧 Teste em um ambiente controlado antes de usar em produção
- 🔍 Verifique a compatibilidade com seu hardware específico

## 🤝 Contribuições

Contribuições são bem-vindas! 

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## 📄 Licença

Distribuído sob a Licença MIT. Veja `LICENSE` para mais informações.

## 👨‍💻 Autor

**Jonas Rafael**
- GitHub: [@jonasrafael](https://github.com/jonasrafael)
- Email: contato@jonasrafael.com

## 🌟 Apoie o Projeto

## 🌍 Sustentabilidade Digital: Transformando HDs Antigos em Recursos

### 🔋 Contra o Lixo Eletrônico

Cada HD que você reaproveita é um passo contra o descarte prematuro de eletrônicos. O `Adão` não é apenas um script, é uma filosofia de preservação digital.

#### Por que Reaproveitar?
- 💚 Reduz resíduos eletrônicos
- 💰 Economiza recursos de fabricação
- 🌱 Menor impacto ambiental
- 🖥️ Prolonga a vida útil do hardware
- 📂 Garante integridade de dado

### 🗃️ Ideias de Reaproveitamento

1. **Servidor de Backup Doméstico**
   - Centralize fotos, documentos e vídeos
   - Acesso remoto seguro
   - Backup automático de múltiplos dispositivos

2. **Biblioteca de Mídia Pessoal**
   - Armazene filmes, séries, músicas
   - Compartilhe via Plex ou Samba
   - Suporte a diferentes sistemas de arquivos

3. **Nuvem Pessoal Privada**
   - Alternativa ao Google Drive
   - Controle total dos seus dados
   - Criptografia opcional

4. **Servidor de Jogos**
   - Armazene bibliotecas de jogos
   - Compartilhe entre diferentes computadores
   - Suporte a sistemas Windows e Linux

### 🛠️ Como o Adão Ajuda
- Monta HDs de diferentes idades e sistemas
- Verifica integridade dos dispositivos
- Configura pontos de montagem seguros
- Log detalhado para diagnóstico

**Lembre-se**: Cada HD reaproveitado é uma vitória para o planeta! 🌎♻️

Se este script foi útil para você, considere:
- ⭐ Dar uma estrela no GitHub
- 💖 Fazer uma doação
- 📣 Compartilhar com a comunidade

---

**Feito com ❤️ para a comunidade Linux**
