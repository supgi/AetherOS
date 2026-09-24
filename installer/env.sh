#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Ambiente e Configurações Globais
# Define caminhos, cores, tokens do Gum e detecção de contexto de execução.
# ==============================================================================

set -euo pipefail

# Diretório raiz do projeto Aether OS
# Recalcula dinamicamente pelo caminho deste arquivo, garantindo resolução correta dentro e fora de chroots
AETHER_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AETHER_ROOT_DIR
export AETHER_INSTALLER_DIR="${AETHER_ROOT_DIR}/installer"
export AETHER_CONFIGS_DIR="${AETHER_ROOT_DIR}/configs"
export AETHER_BIN_DIR="${AETHER_ROOT_DIR}/bin"
export AETHER_LOG_FILE="${AETHER_ROOT_DIR}/aether-install.log"

# Garante que o diretório de logs e o arquivo existam com permissão de escrita
mkdir -p "$(dirname "${AETHER_LOG_FILE}")"
touch "${AETHER_LOG_FILE}" 2>/dev/null || true
chmod 666 "${AETHER_LOG_FILE}" 2>/dev/null || true

# Tokens de cores do Aether Design System (conforme INFO.md)
export COLOR_PRIMARY="39"      # Ice Blue (#00afff)
export COLOR_SECONDARY="31"    # Deep Cyan (#0087af)
export COLOR_ACCENT="75"       # Frost Blue (#5fafff)
export COLOR_MUTED="242"       # Slate Gray (#6c6c6c)
export COLOR_SUCCESS="48"      # Neon Mint (#00ff87)
export COLOR_WARNING="214"     # Amber Glow (#ffaf00)
export COLOR_DANGER="196"      # Crimson (#ff0055)
export COLOR_BG_CARD="235"     # Dark Charcoal (#262626)

# Detecção de usuário alvo e permissões
detect_execution_context() {
    # Determina o usuário alvo da instalação (evita executar Stow ou AUR como root puro)
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        export TARGET_USER="${SUDO_USER}"
    elif [[ "${USER:-}" != "root" && -n "${USER:-}" ]]; then
        export TARGET_USER="${USER}"
    else
        export TARGET_USER="root"
    fi

    # Determina o diretório HOME correspondente ao usuário alvo
    if [[ "${TARGET_USER}" == "root" ]]; then
        export TARGET_HOME="/root"
    else
        export TARGET_HOME=$(getent passwd "${TARGET_USER}" | cut -d: -f6)
        if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
            export TARGET_HOME="/home/${TARGET_USER}"
        fi
    fi

    # Identifica se o ambiente é uma mídia Live (Live ISO do Arch Linux)
    if grep -q "archiso" /proc/cmdline 2>/dev/null || [[ -d "/run/archiso" ]]; then
        export IS_LIVE_ENVIRONMENT=true
    else
        export IS_LIVE_ENVIRONMENT=false
    fi
}

# Inicializa o contexto imediatamente ao carregar o módulo
detect_execution_context
