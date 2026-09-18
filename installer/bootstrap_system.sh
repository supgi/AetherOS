#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Bootstrap do Sistema Base (Pacstrap, Fstab, Bootloader)
# Instalação bare-metal do núcleo Arch Linux, localização e GRUB.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"
# shellcheck source=installer/disk.sh
source "${SCRIPT_DIR}/disk.sh"

# Pacotes mínimos essenciais para o boot e administração básica do sistema
BASE_SYSTEM_PACKAGES=(
    base
    base-devel
    linux
    linux-firmware
    git
    sudo
    networkmanager
    nano
    vim
    zsh
    grub
    efibootmgr
    dosfstools
    mtools
)

# Executa o pacstrap instalando o núcleo do sistema na partição raiz montada
install_base_system() {
    local mount_point="${1:-/mnt}"
    render_step "Instalando sistema base via pacstrap em ${mount_point}..."

    # Garante que o diretório contenha a assinatura de chaves atualizada
    pacman -Sy --noconfirm archlinux-keyring >> "${AETHER_LOG_FILE}" 2>&1 || true

    pacstrap -K "${mount_point}" "${BASE_SYSTEM_PACKAGES[@]}" >> "${AETHER_LOG_FILE}" 2>&1

    render_success "Sistema base e kernel Linux instalados com sucesso."
}

# Gera o arquivo de pontos de montagem persistentes (/etc/fstab)
generate_fstab() {
    local mount_point="${1:-/mnt}"
    render_step "Gerando arquivo fstab com UUIDs persistentes..."

    genfstab -U "${mount_point}" >> "${mount_point}/etc/fstab"

    render_success "Arquivo /etc/fstab gerado com sucesso."
}

# Configura fuso horário, locales, teclado e identificação de rede
configure_system_localization() {
    local mount_point="${1:-/mnt}"
    local timezone="${2:-America/Sao_Paulo}"
    local hostname="${3:-aether-os}"
    local keymap="${4:-br-abnt2}"

    render_step "Configurando regionalização, fuso horário e hostname..."

    # Fuso horário e relógio do hardware
    ln -sf "/usr/share/zoneinfo/${timezone}" "${mount_point}/etc/localtime"
    arch-chroot "${mount_point}" hwclock --systohc 2>/dev/null || true

    # Hostname e hosts
    echo "${hostname}" > "${mount_point}/etc/hostname"
    cat <<EOF > "${mount_point}/etc/hosts"
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
EOF

    # Configuração de Locales (pt_BR e en_US)
    sed -i 's/^#\(pt_BR.UTF-8 UTF-8\)/\1/' "${mount_point}/etc/locale.gen" 2>/dev/null || \
        echo "pt_BR.UTF-8 UTF-8" >> "${mount_point}/etc/locale.gen"
    sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' "${mount_point}/etc/locale.gen" 2>/dev/null || \
        echo "en_US.UTF-8 UTF-8" >> "${mount_point}/etc/locale.gen"

    arch-chroot "${mount_point}" locale-gen >> "${AETHER_LOG_FILE}" 2>&1

    echo "LANG=pt_BR.UTF-8" > "${mount_point}/etc/locale.conf"
    echo "KEYMAP=${keymap}" > "${mount_point}/etc/vconsole.conf"

    render_success "Localização e rede configuradas (Hostname: ${hostname}, Locale: pt_BR.UTF-8)."
}

# Instala e gera as configurações do bootloader GRUB
install_bootloader() {
    local mount_point="${1:-/mnt}"
    local target_disk="$2"

    render_step "Instalando e configurando o bootloader GRUB para o Aether OS..."

    if is_uefi_system; then
        render_step "Instalando GRUB para UEFI x86_64..."
        arch-chroot "${mount_point}" grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot \
            --bootloader-id=AetherOS \
            --recheck >> "${AETHER_LOG_FILE}" 2>&1
    else
        render_step "Instalando GRUB para BIOS MBR no disco ${target_disk}..."
        arch-chroot "${mount_point}" grub-install \
            --target=i386-pc \
            "${target_disk}" \
            --recheck >> "${AETHER_LOG_FILE}" 2>&1
    fi

    # Gera a configuração do menu do GRUB
    arch-chroot "${mount_point}" grub-mkconfig -o /boot/grub/grub.cfg >> "${AETHER_LOG_FILE}" 2>&1

    render_success "Bootloader GRUB configurado com sucesso."
}
