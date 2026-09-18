#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Interface TUI (Charm Gum)
# Fornece componentes visuais padronizados conforme o guia INFO.md.
# ==============================================================================

set -euo pipefail

# Garante que as variáveis de ambiente e cores estejam disponíveis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"

# Verifica se o binário do Gum está disponível no sistema
has_gum() {
    command -v gum >/dev/null 2>&1
}

# Renderiza o banner principal de identidade visual do Aether OS
render_banner() {
    clear
    if has_gum; then
        gum style \
            --foreground "${COLOR_PRIMARY}" \
            --border "rounded" \
            --border-foreground "${COLOR_SECONDARY}" \
            --padding "1 4" \
            --margin "1 0" \
            --align center \
            --bold \
            "   /\   ____  _   _   _ _____ ____    ___  ____  " \
            "  /  \ | ____| |_| |_| | ____|  _ \  / _ \/ ___| " \
            " / /\ \|  _| | __|  _  |  _| | |_) || | | \___ \ " \
            "/ ____ \ |___| |_| | | | |___|  _ < | |_| |___) |" \
            "/_/    \_\_____|\__|_| |_|_____|_| \_\ \___/|____/ " \
            "" \
            "A E T H E R   O S  •  W A Y L A N D   E D I T I O N" \
            "Framework Modular e Minimalista para Arch Linux"
    else
        echo "============================================================"
        echo "               A E T H E R   O S"
        echo "   Framework Modular e Minimalista para Arch Linux"
        echo "============================================================"
    fi
}

# Exibe o título de uma etapa ou seção
render_step() {
    local step_title="$1"
    if has_gum; then
        gum style \
            --foreground "${COLOR_ACCENT}" \
            --bold \
            --margin "1 0 0 0" \
            "➜ ${step_title}"
    else
        echo -e "\n\033[1;36m➜ ${step_title}\033[0m"
    fi
}

# Exibe mensagem amigável de sucesso
render_success() {
    local message="$1"
    if has_gum; then
        gum style \
            --foreground "${COLOR_SUCCESS}" \
            --bold \
            "✔ ${message}"
    else
        echo -e "\033[1;32m✔ ${message}\033[0m"
    fi
}

# Exibe aviso com destaque
render_warning() {
    local message="$1"
    if has_gum; then
        gum style \
            --foreground "${COLOR_WARNING}" \
            --bold \
            "▲ ${message}"
    else
        echo -e "\033[1;33m▲ ${message}\033[0m"
    fi
}

# Exibe mensagem de erro amigável ao usuário e registra logs técnicos
render_error() {
    local user_message="$1"
    local technical_log="${2:-Nenhum detalhe técnico fornecido}"

    # Registro técnico no arquivo de log do sistema
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [ERROR] ${technical_log}" >> "${AETHER_LOG_FILE}"

    if has_gum; then
        gum style \
            --foreground "${COLOR_DANGER}" \
            --border "rounded" \
            --border-foreground "${COLOR_DANGER}" \
            --padding "0 2" \
            --margin "1 0" \
            --bold \
            "✖ Ops! ${user_message}" \
            "Detalhes foram registrados em: ${AETHER_LOG_FILE}"
    else
        echo -e "\n\033[1;31m✖ Ops! ${user_message}\033[0m"
        echo -e "\033[0;37mDetalhes registrados em: ${AETHER_LOG_FILE}\033[0m\n"
    fi
}

# Executa um comando com indicador de progresso (spinner)
render_spinner() {
    local title="$1"
    shift

    if has_gum; then
        gum spin \
            --spinner.foreground "${COLOR_PRIMARY}" \
            --title.foreground "${COLOR_ACCENT}" \
            --spinner "dots" \
            --title " ${title}..." \
            -- "$@"
    else
        echo -n "${title}... "
        "$@"
        echo "Concluído."
    fi
}

# Solicita confirmação binária (Sim/Não) ao usuário
prompt_confirm() {
    local prompt_text="$1"
    if has_gum; then
        gum confirm \
            --prompt.foreground "${COLOR_ACCENT}" \
            --selected.background "${COLOR_SECONDARY}" \
            --selected.foreground "255" \
            "${prompt_text}"
    else
        read -r -p "${prompt_text} [s/N]: " response
        [[ "${response}" =~ ^[sSyY]$ ]]
    fi
}

# Menu interativo de seleção única
prompt_choice() {
    local prompt_header="$1"
    shift
    local options=("$@")

    if has_gum; then
        render_step "${prompt_header}"
        gum choose \
            --cursor="› " \
            --cursor.foreground="${COLOR_PRIMARY}" \
            --item.foreground="252" \
            --selected.foreground="${COLOR_PRIMARY}" \
            --limit=1 \
            "${options[@]}"
    else
        echo "${prompt_header}:"
        select opt in "${options[@]}"; do
            if [[ -n "${opt}" ]]; then
                echo "${opt}"
                break
            fi
        done
    fi
}

# Coleta de entrada de texto via terminal
prompt_input() {
    local prompt_text="$1"
    local placeholder="${2:-}"
    local is_password="${3:-false}"

    if has_gum; then
        if [[ "${is_password}" == "true" ]]; then
            gum input \
                --password \
                --prompt="› ${prompt_text}: " \
                --prompt.foreground="${COLOR_PRIMARY}" \
                --placeholder="${placeholder}" \
                --width=50
        else
            gum input \
                --prompt="› ${prompt_text}: " \
                --prompt.foreground="${COLOR_PRIMARY}" \
                --placeholder="${placeholder}" \
                --width=50
        fi
    else
        if [[ "${is_password}" == "true" ]]; then
            read -r -s -p "${prompt_text}: " user_input
            echo ""
        else
            read -r -p "${prompt_text}: " user_input
        fi
        echo "${user_input}"
    fi
}
