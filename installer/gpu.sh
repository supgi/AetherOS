#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Detecção e Configuração de Placas Gráficas (GPU)
# Detecção automática (Intel, AMD, NVIDIA, VMs), Early KMS e parâmetros de boot.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

# Detecta os fabricantes de GPU presentes no sistema
detect_gpu_vendors() {
    local -a detected=()

    # 1. Checagem de ambiente virtualizado
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt_type
        virt_type="$(systemd-detect-virt 2>/dev/null || true)"
        if [[ -n "${virt_type}" && "${virt_type}" != "none" ]]; then
            detected+=("vm")
        fi
    fi

    # 2. Varredura via sysfs (/sys/bus/pci/devices)
    if [[ -d "/sys/bus/pci/devices" ]]; then
        for dev in /sys/bus/pci/devices/*; do
            if [[ -f "${dev}/class" && -f "${dev}/vendor" ]]; then
                local class_id vendor_id
                class_id="$(cat "${dev}/class" 2>/dev/null || true)"
                vendor_id="$(cat "${dev}/vendor" 2>/dev/null || true)"

                # Classes PCI de vídeo: 0x030000 (VGA), 0x030200 (3D), 0x038000 (Display)
                if [[ "${class_id}" =~ ^0x03 ]]; then
                    case "${vendor_id}" in
                        0x8086) detected+=("intel") ;;
                        0x1002) detected+=("amd") ;;
                        0x10de) detected+=("nvidia") ;;
                        0x15ad|0x1af4|0x1b36|0x1234|0x80ee) detected+=("vm") ;;
                    esac
                fi
            fi
        done
    fi

    # 3. Fallback via comando lspci caso disponível
    if command -v lspci >/dev/null 2>&1; then
        local lspci_output
        lspci_output="$(lspci -nn 2>/dev/null || true)"

        if echo "${lspci_output}" | grep -Ei "VGA|3D|Display" | grep -q "10de:"; then
            detected+=("nvidia")
        fi
        if echo "${lspci_output}" | grep -Ei "VGA|3D|Display" | grep -q "1002:"; then
            detected+=("amd")
        fi
        if echo "${lspci_output}" | grep -Ei "VGA|3D|Display" | grep -q "8086:"; then
            detected+=("intel")
        fi
        if echo "${lspci_output}" | grep -Ei "VGA|3D|Display" | grep -Eiq "VMware|VirtualBox|QEMU|Red Hat|Virtio"; then
            detected+=("vm")
        fi
    fi

    # Deduplicação mantendo a ordem
    local -a unique=()
    for v in "${detected[@]:-}"; do
        local already_has=false
        for u in "${unique[@]:-}"; do
            if [[ "${u}" == "${v}" ]]; then
                already_has=true
                break
            fi
        done
        if [[ "${already_has}" == "false" && -n "${v}" ]]; then
            unique+=("${v}")
        fi
    done

    # Fallback para mesa genérico caso nenhum fabricante específico seja encontrado
    if [[ ${#unique[@]} -eq 0 ]]; then
        unique=("generic")
    fi

    echo "${unique[@]}"
}

# Retorna a lista de pacotes de drivers recomendados para as GPUs detectadas
get_gpu_packages() {
    local -a vendors=("$@")
    local -a packages=()

    # Pacote Mesa básico essencial para aceleração 3D Wayland
    packages+=(mesa)

    for vendor in "${vendors[@]}"; do
        case "${vendor}" in
            "intel")
                packages+=(vulkan-intel intel-media-driver)
                ;;
            "amd")
                packages+=(vulkan-radeon libva-mesa-driver)
                ;;
            "nvidia")
                packages+=(nvidia-dkms nvidia-utils lib32-nvidia-utils)
                ;;
            "vm")
                packages+=(qemu-guest-agent spice-vdagent virtualbox-guest-utils)
                ;;
            "generic")
                # Mesa já incluído
                ;;
        esac
    done

    # Deduplicação dos pacotes
    local -a unique_pkgs=()
    for p in "${packages[@]}"; do
        local found=false
        for u in "${unique_pkgs[@]:-}"; do
            if [[ "${u}" == "${p}" ]]; then
                found=true
                break
            fi
        done
        if [[ "${found}" == "false" ]]; then
            unique_pkgs+=("${p}")
        fi
    done

    echo "${unique_pkgs[@]}"
}

# Configura Early KMS (Kernel Mode Setting) no /etc/mkinitcpio.conf
configure_early_kms() {
    local mount_point="${1:-/mnt}"
    shift
    local -a vendors=("$@")
    local mkinitcpio_conf="${mount_point}/etc/mkinitcpio.conf"

    if [[ ! -f "${mkinitcpio_conf}" ]]; then
        render_warning "Arquivo ${mkinitcpio_conf} não encontrado. Pulando Early KMS."
        return 0
    fi

    render_step "Configurando Early KMS no initramfs para inicialização gráfica imediata..."

    local -a kms_modules=()
    for vendor in "${vendors[@]}"; do
        case "${vendor}" in
            "intel")
                kms_modules+=(i915)
                ;;
            "amd")
                kms_modules+=(amdgpu)
                ;;
            "nvidia")
                kms_modules+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
                ;;
        esac
    done

    if [[ ${#kms_modules[@]} -gt 0 ]]; then
        local module_str="${kms_modules[*]}"
        # Substitui a linha MODULES=(...) mantendo módulos pré-existentes
        if grep -q "^MODULES=(" "${mkinitcpio_conf}"; then
            sed -i -E "s/^MODULES=\((.*)\)/MODULES=(\1 ${module_str})/" "${mkinitcpio_conf}"
            # Limpa espaços duplos
            sed -i -E "s/MODULES=\([[:space:]]+/MODULES=(/" "${mkinitcpio_conf}"
            sed -i -E "s/[[:space:]]+\)/)/" "${mkinitcpio_conf}"
        fi
        render_success "Módulos DRM injetados no mkinitcpio.conf: ${module_str}"
    fi
}

# Configura parâmetros de kernel específicos para NVIDIA no GRUB e modprobe
configure_nvidia_settings() {
    local mount_point="${1:-/mnt}"
    local grub_default="${mount_point}/etc/default/grub"

    render_step "Configurando parâmetros específicos de kernel e modprobe para NVIDIA..."

    # 1. Habilita DRM Modeset no modprobe
    mkdir -p "${mount_point}/etc/modprobe.d"
    cat <<EOF > "${mount_point}/etc/modprobe.d/nvidia.conf"
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
EOF

    # 2. Injeta nvidia-drm.modeset=1 no GRUB_CMDLINE_LINUX_DEFAULT
    if [[ -f "${grub_default}" ]]; then
        if ! grep -q "nvidia_drm.modeset=1" "${grub_default}" && ! grep -q "nvidia-drm.modeset=1" "${grub_default}"; then
            sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' "${grub_default}"
            sed -i 's/  */ /g' "${grub_default}"
            render_success "Parâmetro nvidia-drm.modeset=1 adicionado ao GRUB."
        fi
    fi
}

# Função principal de orquestração do módulo de GPU
install_and_configure_gpu() {
    local mount_point="${1:-/mnt}"
    local -a detected_vendors=($(detect_gpu_vendors))

    render_step "Hardware gráfico detectado: ${detected_vendors[*]}"

    local -a gpu_pkgs=($(get_gpu_packages "${detected_vendors[@]}"))

    render_step "Instalando pacotes de aceleração gráfica: ${gpu_pkgs[*]}..."
    arch-chroot "${mount_point}" pacman -S --needed --noconfirm "${gpu_pkgs[@]}" >> "${AETHER_LOG_FILE}" 2>&1 || {
        render_warning "Alguns drivers de vídeo não puderam ser instalados. Continuando..."
    }

    # Configuração de Early KMS
    configure_early_kms "${mount_point}" "${detected_vendors[@]}"

    # Configurações exclusivas se NVIDIA estiver presente
    local has_nvidia=false
    for v in "${detected_vendors[@]}"; do
        if [[ "${v}" == "nvidia" ]]; then
            has_nvidia=true
            break
        fi
    done

    if [[ "${has_nvidia}" == "true" ]]; then
        configure_nvidia_settings "${mount_point}"
    fi

    # Regenera o initramfs para aplicar o Early KMS
    render_step "Regenerando initramfs (mkinitcpio -P)..."
    arch-chroot "${mount_point}" mkinitcpio -P >> "${AETHER_LOG_FILE}" 2>&1 || true

    render_success "Aceleração gráfica e módulos de vídeo configurados com sucesso."
}
