#!/bin/bash

# Verificar sistema operacional
SISTEMA=$(cat /etc/os-release | grep "^ID=" | cut -d= -f2 | tr -d '"')
VERSAO=$(cat /etc/os-release | grep "^VERSION_ID=" | cut -d= -f2 | tr -d '"')

# Título do script
echo " Calculadora de Consumo de Energia - Adão Energy Tracker"
echo " Sistema: $SISTEMA $VERSAO"

# Função de log colorido
log() {
    local color="\033[0;34m"  # Azul
    local reset="\033[0m"
    local message="$1"
    # Usar redirecionamento para evitar problemas de sintaxe
    {
        printf "${color}[ENERGIA]${reset} %s\n" "$message"
    } >&2
}

# Função para obter custo preciso do kWh
obter_custo_kwh() {
    local custo_padrao=0.87  # Custo padrão no Paraná
    local custo_usuario
    local config_file="$HOME/.adao_energia_config"
    
    # Verificar se já existe um arquivo de configuração
    if [ -f "$config_file" ]; then
        custo_usuario=$(grep "CUSTO_KWH=" "$config_file" | cut -d= -f2)
    fi

    # Se não tiver configuração, iniciar fluxo interativo
    if [ -z "$custo_usuario" ]; then
        {
            echo " Você sabe o valor do kWh?"
            echo "   [1] Sim"
            echo "   [2] Não"
            read -p "Escolha uma opção (1/2): " conhece_valor
        } >&2

        case "$conhece_valor" in
            1)
                # Conhece o valor
                {
                    read -p "Qual é o valor do kWh? R$ " custo_usuario
                } >&2
                ;;
            2)
                # Quer ajuda para calcular
                {
                    echo "Vamos calcular o custo do kWh juntos."
                    read -p "Qual foi o valor total da sua última fatura de energia? R$ " valor_fatura
                    read -p "Quantos kWh foram faturados? " total_kwh
                } >&2

                # Calcular custo do kWh
                custo_usuario=$(echo "scale=2; $valor_fatura / $total_kwh" | bc)
                ;;
            *)
                # Opção padrão
                custo_usuario=$custo_padrao
                ;;
        esac

        # Validar entrada
        if [[ -z "$custo_usuario" || "$custo_usuario" == "0" ]]; then
            custo_usuario=$custo_padrao
        fi

        # Salvar configuração
        mkdir -p "$(dirname "$config_file")"
        echo "CUSTO_KWH=$custo_usuario" > "$config_file"
    fi

    echo "$custo_usuario"
}

# Função para verificar e instalar dependências
verificar_dependencias() {
    local dependencias=(
        "bc"
        "pciutils"   # Contém lspci
        "dmidecode"
    )
    local faltantes=()

    for dep in "${dependencias[@]}"; do
        if ! dpkg -s "$dep" &> /dev/null; then
            faltantes+=("$dep")
        fi
    done

    if [ ${#faltantes[@]} -gt 0 ]; then
        log " Dependências faltantes detectadas. Instalando..."
        sudo apt-get update
        sudo apt-get install -y "${faltantes[@]}"
    fi
}

# Função para calcular consumo de CPU com mais precisão
calcular_consumo_cpu() {
    # Informações detalhadas da CPU
    local modelo=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
    local nucleos=$(nproc)
    local threads=$(grep -c "processor" /proc/cpuinfo)
    
    # Definir base de consumo específico para Core 2 Duo
    local consumo_base=40  # Base para E7300
    local fator_consumo=1.0

    # Coletar uso de CPU com múltiplas medições
    local uso_cpu1=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    local uso_cpu2=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    local uso_cpu3=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

    # Calcular média de uso
    local uso_medio=$(echo "($uso_cpu1 + $uso_cpu2 + $uso_cpu3) / 3" | bc -l)

    # Ajuste de consumo baseado em uso médio
    local consumo_dinamico=$consumo_base
    if (( $(echo "$uso_medio > 70" | bc -l) )); then
        consumo_dinamico=$(echo "$consumo_base * 1.2" | bc -l)  # Alta carga
    elif (( $(echo "$uso_medio > 40" | bc -l) )); then
        consumo_dinamico=$(echo "$consumo_base * 1.1" | bc -l)  # Carga média
    elif (( $(echo "$uso_medio < 10" | bc -l) )); then
        consumo_dinamico=$(echo "$consumo_base * 0.8" | bc -l)  # Baixa carga
    fi

    # Considerar número de núcleos e threads
    local consumo_total=$(echo "$consumo_dinamico * $threads / ($nucleos * 2)" | bc -l)
    consumo_total=$(printf "%.0f" "$consumo_total")

    # Log de diagnóstico
    {
        log " Diagnóstico de CPU:"
        printf "   Modelo:       %s\n" "$modelo"
        printf "   Núcleos:      %d\n" "$nucleos"
        printf "   Threads:      %d\n" "$threads"
        printf "   Uso CPU 1:    %.2f%%\n" "$uso_cpu1"
        printf "   Uso CPU 2:    %.2f%%\n" "$uso_cpu2"
        printf "   Uso CPU 3:    %.2f%%\n" "$uso_cpu3"
        printf "   Uso Médio:    %.2f%%\n" "$uso_medio"
        printf "   Consumo Base: %dW\n" "$consumo_base"
        printf "   Consumo Est.: %dW\n" "$consumo_total"
    } >&2

    echo $consumo_total
}

# Função para calcular consumo de HDs
calcular_consumo_hds() {
    local hds
    local total_hds=0
    local consumo_total=0

    # Usar readarray para evitar problemas de sintaxe
    readarray -t hds < <(lsblk -d -o NAME,TYPE | grep disk | awk '{print $1}')

    # Usar redirecionamento para log
    {
        log " Dispositivos de Armazenamento Detectados:"
        for hd in "${hds[@]}"; do
            local modelo=$(cat "/sys/block/$hd/device/model" 2>/dev/null || echo "Modelo não identificado")
            local tipo=$(lsblk -d -o NAME,TRAN | grep "$hd" | awk '{print $2}')
            local consumo_hd=0
            
            # Ajuste de consumo para diferentes tipos de armazenamento
            case "$tipo" in
                "sata"|"ata")
                    # HDs tradicionais
                    consumo_hd=12
                    ;;
                "usb")
                    # Dispositivos USB
                    consumo_hd=5
                    ;;
                "nvme")
                    # SSDs NVMe
                    consumo_hd=3
                    ;;
                *)
                    # Outros tipos
                    consumo_hd=10
                    ;;
            esac

            printf " - %s: %s (Tipo: %s, Consumo: %dW)\n" "$hd" "$modelo" "$tipo" "$consumo_hd"
            ((total_hds++))
            ((consumo_total+=consumo_hd))
        done
    } >&2

    echo $consumo_total
}

# Função para calcular consumo de RAM
calcular_consumo_ram() {
    local total_ram=$(free -m | grep Mem: | awk '{print $2}')
    local ram_usada=$(free -m | grep Mem: | awk '{print $3}')
    local consumo_ram=$((total_ram / 4096 * 10 + 10))  # ~10W para cada 4GB

    # Ajuste baseado no uso de RAM
    local uso_ram=$((ram_usada * 100 / total_ram))
    consumo_ram=$((consumo_ram * uso_ram / 100))

    # Ajuste para sistemas CrunchBang++ com menos RAM
    if [[ "$SISTEMA" == "crunchbangplusplus" && "$total_ram" -lt 4096 ]]; then
        consumo_ram=$((consumo_ram - 5))
    fi

    echo $consumo_ram
}

# Função para calcular overhead de energia
calcular_overhead() {
    # Verificar se as dependências estão instaladas
    if ! command -v lspci &> /dev/null || ! command -v dmidecode &> /dev/null; then
        log " Algumas ferramentas de diagnóstico não estão disponíveis"
        echo 35  # Valor padrão
        return
    fi

    local placa_mae=""
    local fonte=""
    local video=""
    local consumo_base=35  # Valor base padrão

    # Detectar placa-mãe
    placa_mae=$(dmidecode -t baseboard 2>/dev/null | grep "Product Name" | cut -d: -f2 | xargs)
    
    # Detectar fonte
    fonte=$(dmidecode -t power-supply 2>/dev/null | grep "Power Unit" | cut -d: -f2 | xargs)
    
    # Detectar placa de vídeo
    video=$(lspci | grep -i "vga" | cut -d: -f3 | xargs)

    # Ajustar consumo baseado em componentes
    local fator_ajuste=1.0

    # Placas-mãe específicas
    if [[ "$placa_mae" == "PW-945GCX" ]]; then
        fator_ajuste=1.1  # Placa mais antiga
    fi

    # Calcular consumo final
    local consumo_overhead=$(printf "%.0f" $(echo "$consumo_base * $fator_ajuste" | bc -l))

    # Log de diagnóstico
    {
        log " Diagnóstico de Overhead:"
        printf "   Placa-mãe:      %s\n" "${placa_mae:-Não identificada}"
        printf "   Fonte:          %s\n" "${fonte:-Não identificada}"
        printf "   Placa de Vídeo: %s\n" "${video:-Não identificada}"
        printf "   Fator de Ajuste: %.2f\n" "$fator_ajuste"
        printf "   Consumo Est.:   %dW\n" "$consumo_overhead"
    } >&2

    echo "$consumo_overhead"
}

# Função principal de cálculo
calcular_consumo_total() {
    local consumo_cpu=$(calcular_consumo_cpu)
    local consumo_hds=$(calcular_consumo_hds)
    local consumo_ram=$(calcular_consumo_ram)
    local overhead=$(calcular_overhead "$consumo_cpu" "$consumo_hds" "$consumo_ram")
    
    local consumo_total=$((consumo_cpu + consumo_hds + consumo_ram + overhead))
    local consumo_diario=$((consumo_total * 24))
    local consumo_mensal=$((consumo_diario * 30))
    
    # Obter custo do kWh
    local custo_kwh=$(obter_custo_kwh)
    local custo_mensal=$(echo "scale=2; $consumo_mensal * $custo_kwh / 1000" | bc)

    log " Resumo de Consumo de Energia:"
    printf "   CPU:            %dW\n" "$consumo_cpu"
    printf "   HDs:            %dW\n" "$consumo_hds"
    printf "   RAM:            %dW\n" "$consumo_ram"
    printf "   Overhead:       %dW\n" "$overhead"
    printf "   Consumo Total:  %dW\n" "$consumo_total"
    echo ""
    echo "Estimativas:"
    printf "   Consumo Diário:  %d Wh\n" "$consumo_diario"
    printf "   Consumo Mensal: %d Wh (%d kWh)\n" "$consumo_mensal" "$((consumo_mensal / 1000))"
    printf "   Custo Mensal:   R$ %.2f (kWh: R$ %.2f)\n" "$custo_mensal" "$custo_kwh"

    # Dicas específicas para CrunchBang++
    if [[ "$SISTEMA" == "crunchbangplusplus" ]]; then
        log " Dicas de Economia para CrunchBang++:"
        echo "   - Use gerenciadores de energia leves"
        echo "   - Otimize inicialização do sistema"
        echo "   - Considere desabilitar serviços não essenciais"
    fi
}

# Verificar privilégios
if [[ $EUID -ne 0 ]]; then
   log " Este script precisa ser executado com sudo"
   exit 1
fi

# Executar verificação de dependências no início
verificar_dependencias

# Executar cálculo
calcular_consumo_total

# Dicas gerais de economia
log " Dicas de Economia de Energia:"
echo "   - Desligue dispositivos não utilizados"
echo "   - Use modo de economia de energia"
echo "   - Considere substituir HDs por SSDs"
