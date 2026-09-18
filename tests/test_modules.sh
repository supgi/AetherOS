#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Teste Automatizado de Módulos e Funções
# Valida importação, variáveis de ambiente e estrutura dos dotfiles.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "➜ [TEST] Iniciando testes unitários e de integração de módulos..."

# 1. Teste de carregamento do módulo de ambiente
# shellcheck source=installer/env.sh
source "${ROOT_DIR}/installer/env.sh"

if [[ -z "${COLOR_PRIMARY:-}" || -z "${COLOR_SECONDARY:-}" ]]; then
    echo "✖ [FAIL] Variáveis de cores não foram definidas corretamente em env.sh"
    exit 1
fi
echo "✔ [PASS] Módulo installer/env.sh carregado com sucesso."

# 2. Teste de carregamento do módulo de UI
# shellcheck source=installer/ui.sh
source "${ROOT_DIR}/installer/ui.sh"

if ! declare -f render_banner >/dev/null || ! declare -f render_step >/dev/null; then
    echo "✖ [FAIL] Funções essenciais do módulo installer/ui.sh não encontradas."
    exit 1
fi
echo "✔ [PASS] Módulo installer/ui.sh carregado com funções declaradas."

# 3. Teste de existência da estrutura de módulos do GNU Stow
expected_stow_modules=(kitty starship nvim zsh hyprland plasma)
for mod in "${expected_stow_modules[@]}"; do
    if [[ ! -d "${ROOT_DIR}/configs/${mod}" ]]; then
        echo "✖ [FAIL] Diretório de configuração do Stow ausente: configs/${mod}"
        exit 1
    fi
    echo "✔ [PASS] Módulo de dotfiles validado: configs/${mod}"
done

# 4. Teste de simulação de execução do aether-cli (ajuda e versão)
if ! bash "${ROOT_DIR}/bin/aether-cli" --version >/dev/null 2>&1; then
    echo "✖ [FAIL] Falha ao executar 'aether-cli --version'"
    exit 1
fi
echo "✔ [PASS] Utilitário bin/aether-cli respondeu com sucesso ao comando --version."

echo "✔ [SUCCESS] Todos os testes de módulos foram aprovados!"
exit 0
