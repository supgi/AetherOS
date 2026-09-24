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
    rofi
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

# Instalação e compilação do AUR Helper (Yay)
install_aur_helper() {
    render_step "Verificando AUR Helper (Yay)..."

    if command -v yay >/dev/null 2>&1; then
        render_success "Yay já está instalado no sistema."
        return 0
    elif command -v paru >/dev/null 2>&1; then
        render_success "Paru já está instalado no sistema."
        return 0
    fi

    render_warning "Yay não detectado. Iniciando instalação a partir do AUR (yay-bin)..."

    # O makepkg NÃO pode ser executado como root puro por segurança
    local build_user="${TARGET_USER}"
    if [[ "${build_user}" == "root" ]]; then
        render_error "Não é permitido compilar pacotes do AUR diretamente como usuário root." \
                     "Target user is root during makepkg execution"
        return 1
    fi

    local temp_build_dir
    temp_build_dir="/tmp/aether-yay-build"
    rm -rf "${temp_build_dir}"
    mkdir -p "${temp_build_dir}"
    chown -R "${build_user}:${build_user}" "${temp_build_dir}"

    # Clona yay-bin (empacotamento rápido pré-compilado oficial) como o usuário regular
    su - "${build_user}" -c "git clone https://aur.archlinux.org/yay-bin.git '${temp_build_dir}'" >> "${AETHER_LOG_FILE}" 2>&1
    
    # Executa makepkg para compilar e instalar o Yay
    if (
        cd "${temp_build_dir}"
        su - "${build_user}" -c "cd '${temp_build_dir}' && makepkg -si --noconfirm" >> "${AETHER_LOG_FILE}" 2>&1
    ); then
        render_success "Yay instalado com sucesso."
        rm -rf "${temp_build_dir}" 2>/dev/null || true
        return 0
    fi

    # Fallback preventivo: tenta paru-bin caso yay-bin encontre alguma instabilidade
    render_warning "Tentando instalar Paru como alternativa de AUR helper..."
    rm -rf "${temp_build_dir}"
    mkdir -p "${temp_build_dir}"
    chown -R "${build_user}:${build_user}" "${temp_build_dir}"

    if su - "${build_user}" -c "git clone https://aur.archlinux.org/paru-bin.git '${temp_build_dir}'" >> "${AETHER_LOG_FILE}" 2>&1 && \
       (cd "${temp_build_dir}" && su - "${build_user}" -c "cd '${temp_build_dir}' && makepkg -si --noconfirm" >> "${AETHER_LOG_FILE}" 2>&1); then
        render_success "Paru instalado com sucesso como AUR helper."
    else
        render_warning "Não foi possível compilar um AUR Helper automaticamente. O sistema continuará com os pacotes oficiais."
    fi

    rm -rf "${temp_build_dir}" 2>/dev/null || true
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

# Lê a lista de pacotes customizados do arquivo de configuração (ignorando comentários e linhas em branco)
load_custom_package_list() {
    local config_file="${1:-${AETHER_CONFIGS_DIR}/custom-packages.conf}"
    local -a pkgs=()

    if [[ ! -f "${config_file}" ]]; then
        return 0
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="$(echo "${line}" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [[ -n "${line}" ]]; then
            for p in ${line}; do
                pkgs+=("${p}")
            done
        fi
    done < "${config_file}"

    echo "${pkgs[@]}"
}

# Instala aplicativos e plugins adicionais definidos pelo usuário em custom-packages.conf
install_custom_packages() {
    local config_file="${AETHER_CONFIGS_DIR}/custom-packages.conf"

    if [[ ! -f "${config_file}" ]]; then
        render_warning "Arquivo de pacotes customizados não encontrado: ${config_file} (pulando etapa)."
        return 0
    fi

    local -a custom_pkgs=($(load_custom_package_list "${config_file}"))

    if [[ ${#custom_pkgs[@]} -eq 0 ]]; then
        render_step "Nenhum aplicativo customizado ativo em custom-packages.conf (etapa concluída)."
        return 0
    fi

    render_step "Instalando aplicativos e ferramentas adicionais (${#custom_pkgs[@]} pacote(s) em custom-packages.conf)..."

    local build_user="${TARGET_USER}"
    local aur_helper=""
    if command -v yay >/dev/null 2>&1 && [[ "${build_user}" != "root" ]]; then
        aur_helper="yay"
    elif command -v paru >/dev/null 2>&1 && [[ "${build_user}" != "root" ]]; then
        aur_helper="paru"
    fi

    for pkg in "${custom_pkgs[@]}"; do
        if pacman -Q "${pkg}" >/dev/null 2>&1; then
            render_success "Aplicativo já instalado: ${pkg}"
            continue
        fi

        local install_cmd
        local is_aur=false

        if pacman -Si "${pkg}" >/dev/null 2>&1; then
            # Pacote oficial disponível nos repositórios Arch Linux
            install_cmd="pacman -S --needed --noconfirm '${pkg}' >> '${AETHER_LOG_FILE}' 2>&1"
        elif [[ -n "${aur_helper}" ]]; then
            # Pacote do AUR (Arch User Repository)
            is_aur=true
            if [[ "${aur_helper}" == "yay" ]]; then
                install_cmd="su - '${build_user}' -c \"yay -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None --answerupgrade None '${pkg}'\" >> '${AETHER_LOG_FILE}' 2>&1"
            else
                install_cmd="su - '${build_user}' -c \"paru -S --needed --noconfirm '${pkg}'\" >> '${AETHER_LOG_FILE}' 2>&1"
            fi
        else
            install_cmd="false"
        fi

        local spinner_label="Instalando aplicativo: ${pkg}"
        if [[ "${is_aur}" == "true" ]]; then
            spinner_label="Instalando do AUR (${aur_helper}): ${pkg}"
        fi

        if render_spinner "${spinner_label}" bash -c "${install_cmd}"; then
            render_success "Aplicativo instalado com sucesso: ${pkg}"
        else
            render_warning "Não foi possível encontrar ou instalar '${pkg}' (Pacman/AUR). Continuando..."
        fi
    done

    render_success "Instalação de aplicativos e pacotes customizados finalizada."
}

