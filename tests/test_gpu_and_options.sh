#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Testes Automatizados para Módulos de Opções e GPU
# Valida menus centralizados, parsers e lógica de aceleração gráfica / Early KMS.
# ==============================================================================

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"

# Carrega os módulos a serem testados
# shellcheck source=installer/env.sh
source "${ROOT_DIR}/installer/env.sh"
# shellcheck source=installer/ui.sh
source "${ROOT_DIR}/installer/ui.sh"
# shellcheck source=installer/options.sh
source "${ROOT_DIR}/installer/options.sh"
# shellcheck source=installer/gpu.sh
source "${ROOT_DIR}/installer/gpu.sh"

echo "➜ [TEST] Validando arrays e parsers do módulo installer/options.sh..."

# 1. Validação dos arrays de opções
if [[ ${#AETHER_KEYMAP_OPTIONS[@]} -lt 2 ]]; then
    echo "❌ [FAIL] Array AETHER_KEYMAP_OPTIONS não contém opções suficientes."
    exit 1
fi
if [[ ${#AETHER_KERNEL_OPTIONS[@]} -lt 4 ]]; then
    echo "❌ [FAIL] Array AETHER_KERNEL_OPTIONS não contém opções suficientes."
    exit 1
fi
if [[ ${#AETHER_TIMEZONE_OPTIONS[@]} -lt 5 ]]; then
    echo "❌ [FAIL] Array AETHER_TIMEZONE_OPTIONS não contém opções suficientes."
    exit 1
fi
if [[ ${#AETHER_SWAP_OPTIONS[@]} -lt 3 ]]; then
    echo "❌ [FAIL] Array AETHER_SWAP_OPTIONS não contém opções suficientes."
    exit 1
fi
if [[ ${#AETHER_PROFILE_OPTIONS[@]} -ne 2 ]]; then
    echo "❌ [FAIL] Array AETHER_PROFILE_OPTIONS deve conter exatamente 2 perfis."
    exit 1
fi
echo "✔ [PASS] Arrays de opções do instalador validados com sucesso."

# 2. Validação dos parsers de valores
[[ "$(get_keymap_value "br-abnt2 (Padrão)")" == "br-abnt2" ]] || { echo "❌ [FAIL] Keymap br-abnt2 inválido"; exit 1; }
[[ "$(get_keymap_value "us (Inglês)")" == "us" ]] || { echo "❌ [FAIL] Keymap us inválido"; exit 1; }
[[ "$(get_keymap_value "de-latin1")" == "de-latin1" ]] || { echo "❌ [FAIL] Keymap de-latin1 inválido"; exit 1; }

[[ "$(get_kernel_value "linux-zen (Kernel Zen)")" == "linux-zen" ]] || { echo "❌ [FAIL] Kernel zen inválido"; exit 1; }
[[ "$(get_kernel_value "linux (Kernel Padrão)")" == "linux" ]] || { echo "❌ [FAIL] Kernel padrão inválido"; exit 1; }
[[ "$(get_kernel_value "linux-lts")" == "linux-lts" ]] || { echo "❌ [FAIL] Kernel lts inválido"; exit 1; }
[[ "$(get_kernel_value "linux-hardened")" == "linux-hardened" ]] || { echo "❌ [FAIL] Kernel hardened inválido"; exit 1; }

[[ "$(get_timezone_value "America/Sao_Paulo (Brasília)")" == "America/Sao_Paulo" ]] || { echo "❌ [FAIL] Timezone inválida"; exit 1; }
[[ "$(get_timezone_value "UTC (Coordenado)")" == "UTC" ]] || { echo "❌ [FAIL] Timezone UTC inválida"; exit 1; }

[[ "$(get_swap_value "ZRAM (Recomendado)")" == "ZRAM" ]] || { echo "❌ [FAIL] Swap ZRAM inválido"; exit 1; }
[[ "$(get_swap_value "Swapfile de 4 GB")" == "Swapfile de 4 GB" ]] || { echo "❌ [FAIL] Swapfile 4GB inválido"; exit 1; }
[[ "$(get_swap_value "Sem Swap")" == "Sem Swap" ]] || { echo "❌ [FAIL] Sem Swap inválido"; exit 1; }

[[ "$(get_profile_value "Aether-Plasma (KDE)")" == "Aether-Plasma" ]] || { echo "❌ [FAIL] Perfil Plasma inválido"; exit 1; }
[[ "$(get_profile_value "Aether-Hyprland (Wayland)")" == "Aether-Hyprland" ]] || { echo "❌ [FAIL] Perfil Hyprland inválido"; exit 1; }

echo "✔ [PASS] Todos os parsers de menu retornaram valores corretos."

# 3. Teste de pacotes por fabricante de GPU
echo "➜ [TEST] Validando pacotes por fabricante de GPU em installer/gpu.sh..."

intel_pkgs=($(get_gpu_packages "intel"))
[[ " ${intel_pkgs[*]} " =~ " mesa " ]] || { echo "❌ [FAIL] Mesa ausente no perfil Intel"; exit 1; }
[[ " ${intel_pkgs[*]} " =~ " vulkan-intel " ]] || { echo "❌ [FAIL] vulkan-intel ausente no perfil Intel"; exit 1; }

amd_pkgs=($(get_gpu_packages "amd"))
[[ " ${amd_pkgs[*]} " =~ " mesa " ]] || { echo "❌ [FAIL] Mesa ausente no perfil AMD"; exit 1; }
[[ " ${amd_pkgs[*]} " =~ " vulkan-radeon " ]] || { echo "❌ [FAIL] vulkan-radeon ausente no perfil AMD"; exit 1; }

nvidia_pkgs=($(get_gpu_packages "nvidia"))
[[ " ${nvidia_pkgs[*]} " =~ " nvidia-dkms " ]] || { echo "❌ [FAIL] nvidia-dkms ausente no perfil Nvidia"; exit 1; }
[[ " ${nvidia_pkgs[*]} " =~ " nvidia-utils " ]] || { echo "❌ [FAIL] nvidia-utils ausente no perfil Nvidia"; exit 1; }

vm_pkgs=($(get_gpu_packages "vm"))
[[ " ${vm_pkgs[*]} " =~ " qemu-guest-agent " ]] || { echo "❌ [FAIL] qemu-guest-agent ausente no perfil VM"; exit 1; }

echo "✔ [PASS] Seleção de pacotes por fabricante de GPU validada com sucesso."

# 4. Teste de Early KMS em mkinitcpio.conf simulado
echo "➜ [TEST] Validando injeção de Early KMS em mkinitcpio.conf..."
mock_root="$(mktemp -d)"
mkdir -p "${mock_root}/etc"
cat << 'EOF' > "${mock_root}/etc/mkinitcpio.conf"
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)
EOF

configure_early_kms "${mock_root}" "amd"
if ! grep -q "MODULES=(amdgpu)" "${mock_root}/etc/mkinitcpio.conf"; then
    echo "❌ [FAIL] Falha ao injetar amdgpu no mkinitcpio.conf simulado."
    rm -rf "${mock_root}"
    exit 1
fi
echo "✔ [PASS] Early KMS para AMD injetado com sucesso no mkinitcpio.conf."

configure_early_kms "${mock_root}" "nvidia"
if ! grep -q "nvidia" "${mock_root}/etc/mkinitcpio.conf" || ! grep -q "nvidia_drm" "${mock_root}/etc/mkinitcpio.conf"; then
    echo "❌ [FAIL] Falha ao injetar módulos da NVIDIA no mkinitcpio.conf simulado."
    rm -rf "${mock_root}"
    exit 1
fi
echo "✔ [PASS] Early KMS para NVIDIA injetado com sucesso no mkinitcpio.conf."

# 5. Teste de parâmetros do GRUB para NVIDIA
echo "➜ [TEST] Validando injeção de parâmetros no GRUB para NVIDIA..."
mkdir -p "${mock_root}/etc/default"
cat << 'EOF' > "${mock_root}/etc/default/grub"
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="AetherOS"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"
EOF

configure_nvidia_settings "${mock_root}"

if ! grep -q "nvidia-drm.modeset=1" "${mock_root}/etc/default/grub"; then
    echo "❌ [FAIL] Parâmetro nvidia-drm.modeset=1 não encontrado no /etc/default/grub simulado."
    rm -rf "${mock_root}"
    exit 1
fi

if [[ ! -f "${mock_root}/etc/modprobe.d/nvidia.conf" ]] || ! grep -q "NVreg_PreserveVideoMemoryAllocations=1" "${mock_root}/etc/modprobe.d/nvidia.conf"; then
    echo "❌ [FAIL] Arquivo /etc/modprobe.d/nvidia.conf não foi criado corretamente."
    rm -rf "${mock_root}"
    exit 1
fi
echo "✔ [PASS] Configuração de GRUB e modprobe para NVIDIA validada com sucesso."

# Limpeza
rm -rf "${mock_root}"

echo "✔ [SUCCESS] Todos os testes de GPU e Opções foram aprovados!"
exit 0
