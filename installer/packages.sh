#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Gerenciamento e Instalação de Pacotes
# Otimização do Pacman, compilação de AUR Helper (Paru) e grupos de pacotes.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

# Pacotes do Núcleo Base (Core)
CORE_PACKAGES=(
    base-devel
    git
    curl
    wget
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    ttf-jetbrains-mono-nerd
    noto-fonts-emoji
    zsh
    starship
    stow
    kitty
    neovim
    ripgrep
    fd
    bat
    eza
    fzf
    gum
    fastfetch
)

# Pacotes de Serviços Essenciais
SERVICES_PACKAGES=(
    networkmanager
    bluez
    bluez-utils
    sddm
    firewalld
)

# Pacotes do Perfil Aether-Hyprland (Terminal-first Wayland)
HYPRLAND_PACKAGES=(
    hyprland
    waybar
    rofi-wayland
    swaync
    hyprpaper
    hyprlock
    hypridle
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    grim
    slurp
    wl-clipboard
    brightnessctl
    polkit-kde-agent
)

# Pacotes do Perfil Aether-Plasma (KDE Plasma Minimal)
PLASMA_PACKAGES=(
    plasma-desktop
    plasma-wayland-session
    dolphin
    ark
    spectacle
    kate
    sddm-kcm
    xdg-desktop-portal-kde
)

# Otimiza o arquivo de configuração do Pacman (/etc/pacman.conf)
configure_pacman() {
    render_step "Otimizando configuração do Pacman (/etc/pacman.conf)..."

    local pacman_conf="/etc/pacman.conf"
    if [[ ! -f "${pacman_conf}" ]]; then
        render_warning "Arquivo ${pacman_conf} não encontrado. Pulando otimização do Pacman."
        return 0
    fi

    # Habilita downloads paralelos (ParallelDownloads = 5)
    if grep -q "^#ParallelDownloads" "${pacman_conf}"; then
        sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' "${pacman_conf}"
    elif grep -q "^ParallelDownloads" "${pacman_conf}"; then
        sed -i 's/^ParallelDownloads.*/ParallelDownloads = 5/' "${pacman_conf}"
    else
        sed -i '/\[options\]/a ParallelDownloads = 5' "${pacman_conf}"
    fi

    # Habilita cores e barra de progresso aprimorada
    sed -i 's/^#Color/Color/' "${pacman_conf}" 2>/dev/null || true

    # Habilita repositório [multilib] se estiver comentado
    if grep -q "^#\[multilib\]" "${pacman_conf}"; then
        sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "${pacman_conf}"
    fi

    # Sincroniza a base de dados do Pacman
    pacman -Sy --noconfirm >> "${AETHER_LOG_FILE}" 2>&1
    render_success "Pacman configurado com downloads paralelos e repositório multilib."
}

# Instalação e compilação do AUR Helper (Paru)
install_aur_helper() {
    render_step "Verificando AUR Helper (Paru)..."

    if command -v paru >/dev/null 2>&1; then
        render_success "Paru já está instalado no sistema."
        return 0
    fi

    render_warning "Paru não detectado. Iniciando compilação a partir do AUR..."

    # O makepkg NÃO pode ser executado como root puro por segurança
    local build_user="${TARGET_USER}"
    if [[ "${build_user}" == "root" ]]; then
        render_error "Não é permitido compilar pacotes do AUR diretamente como usuário root." \
                     "Target user is root during makepkg execution"
        return 1
    fi

    local temp_build_dir
    temp_build_dir="/tmp/aether-paru-build"
    rm -rf "${temp_build_dir}"
    mkdir -p "${temp_build_dir}"
    chown -R "${build_user}:${build_user}" "${temp_build_dir}"

    # Clona paru-bin (compilação rápida pré-empacotada) como o usuário regular
    su - "${build_user}" -c "git clone https://aur.archlinux.org/paru-bin.git '${temp_build_dir}'" >> "${AETHER_LOG_FILE}" 2>&1
    
    # Executa makepkg para compilar e instalar
    (
        cd "${temp_build_dir}"
        su - "${build_user}" -c "cd '${temp_build_dir}' && makepkg -si --noconfirm" >> "${AETHER_LOG_FILE}" 2>&1
    )

    rm -rf "${temp_build_dir}"
    render_success "Paru instalado com sucesso."
}

# Instala os pacotes do núcleo base do Aether OS
install_core_packages() {
    render_step "Instalando ferramentas essenciais e serviços de base..."

    local all_core=("${CORE_PACKAGES[@]}" "${SERVICES_PACKAGES[@]}")
    pacman -S --needed --noconfirm "${all_core[@]}" >> "${AETHER_LOG_FILE}" 2>&1

    render_success "Pacotes base e serviços essenciais instalados com sucesso."
}

# Instala os pacotes correspondentes ao perfil selecionado
install_profile_packages() {
    local profile="$1"
    render_step "Instalando grupo de pacotes do perfil: ${profile}..."

    case "${profile}" in
        "Aether-Hyprland")
            pacman -S --needed --noconfirm "${HYPRLAND_PACKAGES[@]}" >> "${AETHER_LOG_FILE}" 2>&1
            render_success "Componentes do Aether-Hyprland instalados com sucesso."
            ;;
        "Aether-Plasma")
            pacman -S --needed --noconfirm "${PLASMA_PACKAGES[@]}" >> "${AETHER_LOG_FILE}" 2>&1
            render_success "Componentes do Aether-Plasma instalados com sucesso."
            ;;
        *)
            render_error "Perfil desconhecido selecionado: ${profile}" "Unknown profile: ${profile}"
            return 1
            ;;
    esac
}
