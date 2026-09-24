#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Teste Automatizado de Sintaxe Bash
# Valida a sintaxe de todos os scripts bash utilizando 'bash -n'.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "➜ [TEST] Iniciando verificação de sintaxe de scripts Bash..."

scripts_to_check=(
    "${ROOT_DIR}/install.sh"
    "${ROOT_DIR}/bootstrap.sh"
    "${ROOT_DIR}/test_ui.sh"
    "${ROOT_DIR}/bin/aether-cli"
    "${ROOT_DIR}/installer/env.sh"
    "${ROOT_DIR}/installer/ui.sh"
    "${ROOT_DIR}/installer/packages.sh"
    "${ROOT_DIR}/installer/services.sh"
    "${ROOT_DIR}/installer/stow.sh"
    "${ROOT_DIR}/installer/user.sh"
    "${ROOT_DIR}/installer/disk.sh"
    "${ROOT_DIR}/installer/bootstrap_system.sh"
    "${ROOT_DIR}/installer/chroot_exec.sh"
    "${ROOT_DIR}/installer/options.sh"
    "${ROOT_DIR}/installer/gpu.sh"
    "${ROOT_DIR}/scripts/build_iso.sh"
    "${ROOT_DIR}/archiso/profiledef.sh"
    "${ROOT_DIR}/archiso/airootfs/usr/local/bin/aether-install"
    "${ROOT_DIR}/tests/test_disk_logic.sh"
    "${ROOT_DIR}/tests/test_packages_config.sh"
    "${ROOT_DIR}/tests/test_gpu_and_options.sh"
)

failure_count=0

for script in "${scripts_to_check[@]}"; do
    if [[ ! -f "${script}" ]]; then
        echo "✖ [FAIL] Arquivo não encontrado: ${script}"
        failure_count=$((failure_count + 1))
        continue
    fi

    if bash -n "${script}"; then
        echo "✔ [PASS] Sintaxe válida: $(basename "${script}")"
    else
        echo "✖ [FAIL] Erro de sintaxe detectado em: ${script}"
        failure_count=$((failure_count + 1))
    fi
done

if [[ "${failure_count}" -eq 0 ]]; then
    echo "✔ [SUCCESS] Todos os scripts passaram na verificação de sintaxe!"
    exit 0
else
    echo "✖ [ERROR] Falha em ${failure_count} script(s)."
    exit 1
fi
