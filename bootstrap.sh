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

REPO_TARBALL="https://github.com/supgi/AetherOS/archive/refs/heads/main.tar.gz"
TARGET_CLONE_DIR="/tmp/aether-os-installer"

echo "➜ [AETHER OS] Preparando ambiente de instalação..."

# Instala o gum em memória se possível (para a TUI)
echo "➜ Sincronizando dependências visuais..."
pacman -Sy --needed --noconfirm gum >> /tmp/aether-bootstrap.log 2>&1 || true

# Baixa e extrai diretamente o código do Aether OS sem precisar de conta no GitHub
echo "➜ Baixando o framework Aether OS diretamente do GitHub..."
rm -rf "${TARGET_CLONE_DIR}" /tmp/AetherOS-main
curl -fsSL "${REPO_TARBALL}" | tar -xz -C /tmp
mv /tmp/AetherOS-main "${TARGET_CLONE_DIR}"

# Concede permissões e executa o instalador mestre
chmod +x "${TARGET_CLONE_DIR}/install.sh" "${TARGET_CLONE_DIR}/bin/aether-cli"
cd "${TARGET_CLONE_DIR}"

exec ./install.sh "$@"
