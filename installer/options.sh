#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo Centralizador de Opções de Instalação e Menus
# Fornece arrays de opções padronizadas e parsers para install.sh e test_ui.sh.
# ==============================================================================

set -euo pipefail

# Opções de Layout de Teclado (Keymap)
AETHER_KEYMAP_OPTIONS=(
    "br-abnt2 (Português Brasil ABNT2 - Padrão)"
    "us (Inglês Internacional / US)"
    "es (Espanhol)"
    "de-latin1 (Alemão)"
    "fr (Francês)"
)

# Identifica o código do keymap a partir da seleção do usuário
get_keymap_value() {
    local raw_selection="$1"
    if [[ "${raw_selection}" == *"us "* || "${raw_selection}" == "us" ]]; then
        echo "us"
    elif [[ "${raw_selection}" == *"es "* || "${raw_selection}" == "es" ]]; then
        echo "es"
    elif [[ "${raw_selection}" == *"de-latin1"* ]]; then
        echo "de-latin1"
    elif [[ "${raw_selection}" == *"fr "* || "${raw_selection}" == "fr" ]]; then
        echo "fr"
    else
        echo "br-abnt2"
    fi
}

# Opções de Kernel Linux
AETHER_KERNEL_OPTIONS=(
    "linux-zen (Kernel Zen - Otimizado para Desktop, Baixa Latência e Jogos - Recomendado)"
    "linux (Kernel Padrão Estável do Arch Linux)"
    "linux-lts (Kernel LTS - Maior Estabilidade e Longo Suporte)"
    "linux-hardened (Kernel Hardened - Foco em Segurança Avançada)"
)

# Identifica o pacote do kernel a partir da seleção do usuário
get_kernel_value() {
    local raw_selection="$1"
    if [[ "${raw_selection}" == *"linux-lts"* ]]; then
        echo "linux-lts"
    elif [[ "${raw_selection}" == *"linux-hardened"* ]]; then
        echo "linux-hardened"
    elif [[ "${raw_selection}" == "linux "* || "${raw_selection}" == *"linux (Kernel"* ]]; then
        echo "linux"
    else
        echo "linux-zen"
    fi
}

# Opções de Fuso Horário (Timezone)
AETHER_TIMEZONE_OPTIONS=(
    "America/Sao_Paulo (Horário de Brasília - DF, SP, RJ, MG, Sul, GO)"
    "America/Manaus (Amazonas)"
    "America/Cuiaba (Mato Grosso)"
    "America/Fortaleza (Ceará, RN, PB, PI, MA)"
    "America/Recife (Pernambuco, AL, SE)"
    "America/Bahia (Bahia)"
    "America/Belem (Pará, AP)"
    "America/Porto_Velho (Rondônia)"
    "America/Rio_Branco (Acre)"
    "America/Boa_Vista (Roraima)"
    "UTC (Tempo Universal Coordenado)"
)

# Identifica a timezone válida a partir da seleção do usuário
get_timezone_value() {
    local raw_selection="$1"
    echo "${raw_selection}" | awk '{print $1}'
}

# Opções de Memória Swap
AETHER_SWAP_OPTIONS=(
    "ZRAM (Recomendado - Swap comprimido em RAM, ultra rápido)"
    "Swapfile de 4 GB"
    "Swapfile de 8 GB"
    "Sem Swap"
)

# Normaliza a opção de swap
get_swap_value() {
    local raw_selection="$1"
    if [[ "${raw_selection}" == *"ZRAM"* ]]; then
        echo "ZRAM"
    elif [[ "${raw_selection}" == *"4 GB"* ]]; then
        echo "Swapfile de 4 GB"
    elif [[ "${raw_selection}" == *"8 GB"* ]]; then
        echo "Swapfile de 8 GB"
    else
        echo "Sem Swap"
    fi
}

# Opções de Perfil de Interface Gráfica
AETHER_PROFILE_OPTIONS=(
    "Aether-Plasma (KDE Plasma customizado minimal/dark)"
    "Aether-Hyprland (Wayland dinâmico focado em teclado e produtividade)"
)

# Identifica o perfil de desktop selecionado
get_profile_value() {
    local raw_selection="$1"
    if [[ "${raw_selection}" == *"Hyprland"* ]]; then
        echo "Aether-Hyprland"
    else
        echo "Aether-Plasma"
    fi
}
