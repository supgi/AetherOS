#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Teste Automatizado de Lógica de Discos e Particionamento
# Testa funções de nomenclatura de partições e detecção de boot UEFI/BIOS.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=installer/env.sh
source "${ROOT_DIR}/installer/env.sh"
# shellcheck source=installer/disk.sh
source "${ROOT_DIR}/installer/disk.sh"

echo "➜ [TEST] Testando funções utilitárias de disco..."

# 1. Teste de nomenclatura de partição para disco SATA/SCSI (ex: /dev/sda)
p1="$(get_partition_path "/dev/sda" 1)"
p2="$(get_partition_path "/dev/sda" 2)"
if [[ "${p1}" != "/dev/sda1" || "${p2}" != "/dev/sda2" ]]; then
    echo "✖ [FAIL] Nomenclatura incorreta para /dev/sda: ${p1}, ${p2}"
    exit 1
fi
echo "✔ [PASS] Nomenclatura para disco padrão (/dev/sda -> /dev/sda1): OK"

# 2. Teste de nomenclatura de partição para disco NVMe (ex: /dev/nvme0n1)
nvme_p1="$(get_partition_path "/dev/nvme0n1" 1)"
nvme_p2="$(get_partition_path "/dev/nvme0n1" 2)"
if [[ "${nvme_p1}" != "/dev/nvme0n1p1" || "${nvme_p2}" != "/dev/nvme0n1p2" ]]; then
    echo "✖ [FAIL] Nomenclatura incorreta para /dev/nvme0n1: ${nvme_p1}, ${nvme_p2}"
    exit 1
fi
echo "✔ [PASS] Nomenclatura para disco NVMe (/dev/nvme0n1 -> /dev/nvme0n1p1): OK"

# 3. Teste de nomenclatura de partição para disco /home dedicado (/dev/sdb)
home_p1="$(get_partition_path "/dev/sdb" 1)"
if [[ "${home_p1}" != "/dev/sdb1" ]]; then
    echo "✖ [FAIL] Nomenclatura incorreta para partição de /home: ${home_p1}"
    exit 1
fi
echo "✔ [PASS] Nomenclatura para partição /home dedicada (/dev/sdb -> /dev/sdb1): OK"

# 4. Teste de detecção de UEFI/BIOS sem erros
if is_uefi_system; then
    echo "✔ [PASS] Detecção de firmware do sistema: UEFI"
else
    echo "✔ [PASS] Detecção de firmware do sistema: BIOS Legado"
fi

# 5. Validação das variáveis de disco de /home
if [[ -z "${TARGET_HOME_DISK+x}" || -z "${HAS_SEPARATE_HOME+x}" ]]; then
    echo "✖ [FAIL] Variáveis TARGET_HOME_DISK ou HAS_SEPARATE_HOME não declaradas."
    exit 1
fi
echo "✔ [PASS] Variáveis de controle de /home separada inicializadas corretamente: OK"

echo "✔ [SUCCESS] Todos os testes de lógica de disco foram aprovados!"
exit 0
