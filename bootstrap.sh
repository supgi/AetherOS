#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Script Bootstrap para Execução Direta / Live ISO / Archinstall
# Permite iniciar a instalação com apenas um comando curl/wget no terminal do Arch.
# ==============================================================================

set -euo pipefail

# Garante privilégios de superusuário
if [[ "${EUID}" -ne 0 ]]; then
    echo "✖ [ERRO] O bootstrap do Aether OS deve ser executado como root (ou com sudo)."
    exit 1
fi

REPO_URL="${AETHER_REPO_URL:-https://github.com/giovannipds/AetherOS.git}"
TARGET_CLONE_DIR="/tmp/aether-os-installer"

echo "➜ [AETHER OS] Preparando ambiente de instalação..."

# Instala dependências mínimas necessárias para clonar e rodar o assistente
echo "➜ Sincronizando repositórios e instalando dependências base (git, gum)..."
pacman -Sy --needed --noconfirm git gum >> /tmp/aether-bootstrap.log 2>&1 || {
    # Se o gum não estiver no repositório oficial primário, instala git e curl
    pacman -Sy --needed --noconfirm git curl >> /tmp/aether-bootstrap.log 2>&1
}

# Clona ou atualiza o repositório temporário
if [[ -d "${TARGET_CLONE_DIR}" ]]; then
    echo "➜ Atualizando repositório existente..."
    git -C "${TARGET_CLONE_DIR}" pull --quiet || true
else
    echo "➜ Clonando o framework Aether OS..."
    git clone --depth 1 "${REPO_URL}" "${TARGET_CLONE_DIR}" --quiet
fi

# Concede permissões e executa o instalador mestre
chmod +x "${TARGET_CLONE_DIR}/install.sh" "${TARGET_CLONE_DIR}/bin/aether-cli"
cd "${TARGET_CLONE_DIR}"

exec ./install.sh "$@"
