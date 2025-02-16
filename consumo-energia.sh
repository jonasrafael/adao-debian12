#!/bin/bash

# Título do script
echo "🔌 Calculadora de Consumo de Energia - Adão Energy Tracker"

# Função de log colorido
log() {
    local color="\033[0;34m"  # Azul
    local reset="\033[0m"
    echo -e "${color}[ENERGIA]${reset} $1"
}

# Função para calcular consumo de CPU
calcular_consumo_cpu() {
    local modelo=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
    local consumo_base=80  # Watts base para CPUs antigas

    # Ajuste de consumo baseado em gerações
    if [[ "$modelo" == *"Core 2 Duo"* ]]; then
        consumo_base=100
    elif [[ "$modelo" == *"Core i3"* ]]; then
        consumo_base=65
    elif [[ "$modelo" == *"Core i5"* ]]; then
        consumo_base=95
    fi

    echo $consumo_base
}

# Função para calcular consumo de HDs
calcular_consumo_hds() {
    local hds=$(lsblk -d -o NAME,TYPE | grep disk | awk '{print $1}')
    local total_hds=0
    local consumo_hd=12  # Watts por HD tradicional

    log "🖴 Dispositivos de Armazenamento Detectados:"
    for hd in $hds; do
        local modelo=$(cat /sys/block/$hd/device/model 2>/dev/null)
        echo " - $hd: ${modelo:-Modelo não identificado}"
        ((total_hds++))
    done

    echo $((total_hds * consumo_hd))
}

# Função para calcular consumo de RAM
calcular_consumo_ram() {
    local total_ram=$(free -m | grep Mem: | awk '{print $2}')
    local consumo_ram=$((total_ram / 4096 * 10 + 10))  # ~10W para cada 4GB
    echo $consumo_ram
}

# Função principal de cálculo
calcular_consumo_total() {
    local consumo_cpu=$(calcular_consumo_cpu)
    local consumo_hds=$(calcular_consumo_hds)
    local consumo_ram=$(calcular_consumo_ram)
    local overhead=35  # Overhead de fonte, motherboard, etc

    local consumo_total=$((consumo_cpu + consumo_hds + consumo_ram + overhead))
    local consumo_diario=$((consumo_total * 24))
    local consumo_mensal=$((consumo_diario * 30))
    local custo_mensal=$(echo "scale=2; $consumo_mensal * 0.80 / 1000" | bc)

    log "📊 Resumo de Consumo de Energia:"
    echo "   🖥️  CPU:            ${consumo_cpu}W"
    echo "   💽 HDs:            ${consumo_hds}W"
    echo "   🧮 RAM:            ${consumo_ram}W"
    echo "   🔌 Overhead:       35W"
    echo "   ➡️  Consumo Total:  ${consumo_total}W"
    echo ""
    echo "💡 Estimativas:"
    echo "   🕰️  Consumo Diário:  ${consumo_diario} Wh"
    echo "   📅 Consumo Mensal: ${consumo_mensal} Wh (${consumo_mensal%.*} kWh)"
    echo "   💰 Custo Mensal:   R$ ${custo_mensal}"
}

# Verificar privilégios
if [[ $EUID -ne 0 ]]; then
   log "❌ Este script precisa ser executado com sudo"
   exit 1
fi

# Executar cálculo
calcular_consumo_total

# Dicas de economia
log "🌱 Dicas de Economia de Energia:"
echo "   - Desligue dispositivos não utilizados"
echo "   - Use modo de economia de energia"
echo "   - Considere substituir HDs por SSDs"
