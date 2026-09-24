#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Executor Central da Suite de Testes (DoD)
# Executa todos os testes automatizados do projeto e reporta o resultado final.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo "         AETHER OS - SUITE DE TESTES AUTOMATIZADOS"
echo "============================================================"

# Executa teste de sintaxe
echo ""
bash "${SCRIPT_DIR}/test_syntax.sh"

# Executa teste de módulos e variáveis
echo ""
bash "${SCRIPT_DIR}/test_modules.sh"

# Executa teste de lógica de disco
echo ""
bash "${SCRIPT_DIR}/test_disk_logic.sh"

# Executa teste de parser de pacotes customizados
echo ""
bash "${SCRIPT_DIR}/test_packages_config.sh"

echo ""
echo "============================================================"
echo "✔ [DOD APROVADO] Todos os testes passaram com sucesso!"
echo "============================================================"
