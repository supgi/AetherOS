#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Instalador Mestre do Sistema Operacional
# Suporta instalação completa Bare-Metal (Live ISO) e modo pós-instalação/chroot.
# ==============================================================================

set -euo pipefail

# Resolução de diretórios do instalador
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="${BASE_DIR}/installer"

# Carregamento dos módulos auxiliares
# shellcheck source=installer/env.sh
source "${INSTALLER_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${INSTALLER_DIR}/ui.sh"
# shellcheck source=installer/user.sh
source "${INSTALLER_DIR}/user.sh"
# shellcheck source=installer/packages.sh
source "${INSTALLER_DIR}/packages.sh"
# shellcheck source=installer/services.sh
source "${INSTALLER_DIR}/services.sh"
# shellcheck source=installer/stow.sh
source "${INSTALLER_DIR}/stow.sh"
# shellcheck source=installer/disk.sh
source "${INSTALLER_DIR}/disk.sh"
# shellcheck source=installer/bootstrap_system.sh
source "${INSTALLER_DIR}/bootstrap_system.sh"
# shellcheck source=installer/chroot_exec.sh
source "${INSTALLER_DIR}/chroot_exec.sh"
# shellcheck source=installer/options.sh
source "${INSTALLER_DIR}/options.sh"
# shellcheck source=installer/gpu.sh
source "${INSTALLER_DIR}/gpu.sh"

# Tratamento global de erros inesperados
trap 'handle_error $? $LINENO' ERR

handle_error() {
    local exit_code="$1"
    local line_no="$2"
    render_error "Ocorreu uma falha crítica na linha ${line_no} (Código: ${exit_code})." \
                 "Unhandled script failure with exit code ${exit_code} at line ${line_no}"
    exit "${exit_code}"
}

# ==============================================================================
# Fluxo 1: Modo Chroot / Configuração de Desktop
# Executado dentro do sistema recém-instalado ou pós-instalação direta
# ==============================================================================
run_desktop_setup_flow() {
    local profile="$1"
    local user_target="$2"

    export TARGET_USER="${user_target}"
    export TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
    if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
        export TARGET_HOME="/home/${TARGET_USER}"
    fi

    # 1. Otimização do Pacman (ParallelDownloads e multilib)
    configure_pacman

    # 2. Instalação do Núcleo Base (Core Packages)
    install_core_packages

    # 3. Instalação e Compilação do AUR Helper (Yay)
    install_aur_helper

    # 4. Instalação do Grupo de Pacotes do Perfil
    install_profile_packages "${profile}"

    # 5. Instalação de Aplicativos e Plugins Customizados (custom-packages.conf)
    install_custom_packages "${profile}"

    # 6. Implantação de Dotfiles via GNU Stow
    deploy_dotfiles "${profile}"

    # 7. Habilitação de Serviços Essenciais (systemctl)
    enable_core_services

    # 8. Configuração do aether-cli no PATH
    cp "${AETHER_BIN_DIR}/aether-cli" /usr/local/bin/aether-cli
    chmod +x /usr/local/bin/aether-cli
    render_success "Utilitário /usr/local/bin/aether-cli configurado."

    # 9. Restaura política de sudo com senha para o usuário comum
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel-sudo
    chmod 0440 /etc/sudoers.d/10-wheel-sudo
}

# ==============================================================================
# Fluxo 2: Modo Bare-Metal Completo (Substituto do archinstall)
# Executado diretamente na mídia de instalação (Live ISO)
# ==============================================================================
run_bare_metal_installation() {
    render_banner

    # 1. Pré-checagens de segurança
    check_root_privileges
    check_system_architecture
    check_internet_connection

    # 2. Seleção de disco rígido (define TARGET_DISK global de forma segura)
    select_target_disk
    local target_disk="${TARGET_DISK}"

    # 3. Confirmação explícita de formatação destrutiva
    confirm_disk_wipe "${target_disk}"

    # 4. Configuração de Teclado (Keymap)
    render_step "Configuração de Layout do Teclado:"
    local raw_keymap
    raw_keymap="$(prompt_choice "Selecione o layout do teclado" "${AETHER_KEYMAP_OPTIONS[@]}")"
    local selected_keymap
    selected_keymap="$(get_keymap_value "${raw_keymap}")"
    loadkeys "${selected_keymap}" 2>/dev/null || true

    # 5. Seleção de Kernel Linux
    render_step "Seleção do Kernel Linux:"
    local raw_kernel
    raw_kernel="$(prompt_choice "Selecione o Kernel Linux desejado" "${AETHER_KERNEL_OPTIONS[@]}")"
    local selected_kernel
    selected_kernel="$(get_kernel_value "${raw_kernel}")"

    # 6. Seleção de Fuso Horário (Timezone)
    render_step "Seleção do Fuso Horário:"
    local raw_timezone
    raw_timezone="$(prompt_choice "Selecione o Fuso Horário do sistema" "${AETHER_TIMEZONE_OPTIONS[@]}")"
    local selected_timezone
    selected_timezone="$(get_timezone_value "${raw_timezone}")"

    # 7. Gerenciamento de Memória Swap
    render_step "Configuração de Memória Swap:"
    local raw_swap
    raw_swap="$(prompt_choice "Selecione a estratégia de Swap (Memória Virtual)" "${AETHER_SWAP_OPTIONS[@]}")"
    local selected_swap
    selected_swap="$(get_swap_value "${raw_swap}")"

    # 8. Parâmetros de identificação e usuário
    render_step "Configurações de Identificação e Acesso:"

    local hostname
    hostname="$(prompt_input "Nome do computador (Hostname)" "aether-os")"
    hostname="${hostname:-aether-os}"

    local username
    username="$(prompt_input "Nome do usuário principal" "aether")"
    username="${username:-aether}"

    local user_password
    user_password="$(prompt_input "Senha de acesso para ${username}" "" true)"
    while [[ -z "${user_password}" ]]; do
        render_warning "A senha não pode ser vazia."
        user_password="$(prompt_input "Digite uma senha para ${username}" "" true)"
    done

    # 9. Seleção de Perfil de Interface Gráfica
    render_step "Escolha o Perfil de Interface do Aether OS:"
    local raw_profile
    raw_profile="$(prompt_choice "Selecione a interface gráfica desejada" "${AETHER_PROFILE_OPTIONS[@]}")"
    local profile_key
    profile_key="$(get_profile_value "${raw_profile}")"

    # 10. Resumo e confirmação final de instalação
    render_banner
    render_step "Resumo Geral da Instalação do Aether OS:"
    echo "  • Disco Raiz (Root): ${target_disk}"
    if [[ "${HAS_SEPARATE_HOME:-false}" == "true" && -n "${TARGET_HOME_DISK:-}" ]]; then
        echo "  • Disco de Usuários (/home): ${TARGET_HOME_DISK} (Dedicado)"
    else
        echo "  • Partição /home: Mesmo disco do sistema (${target_disk})"
    fi
    echo "  • Modo de Boot: $(is_uefi_system && echo 'UEFI (GPT)' || echo 'BIOS Legado (MBR)')"
    echo "  • Layout de Teclado: ${selected_keymap}"
    echo "  • Kernel Linux: ${selected_kernel}"
    echo "  • Fuso Horário: ${selected_timezone}"
    echo "  • Configuração de Swap: ${selected_swap}"
    echo "  • Hostname: ${hostname}"
    echo "  • Usuário Principal: ${username}"
    echo "  • Perfil Gráfico: ${profile_key}"
    local custom_pkgs_count=0
    if [[ -f "${AETHER_CONFIGS_DIR}/custom-packages.conf" ]]; then
        local -a custom_pkgs_list=($(load_custom_package_list "${AETHER_CONFIGS_DIR}/custom-packages.conf" "${profile_key}"))
        custom_pkgs_count=${#custom_pkgs_list[@]}
    fi
    if [[ ${custom_pkgs_count} -gt 0 ]]; then
        echo "  • Aplicativos Adicionais: ${custom_pkgs_count} pacote(s) para o perfil ${profile_key}"
    fi
    echo ""

    if ! prompt_confirm "Deseja iniciar a gravação e instalação do Aether OS agora?"; then
        render_warning "Instalação abortada pelo usuário."
        exit 0
    fi

    local mount_point="/mnt"

    # Execução das etapas automatizadas
    partition_target_disk "${target_disk}"
    format_target_partitions "${target_disk}"
    mount_target_partitions "${target_disk}" "${mount_point}"

    install_base_system "${mount_point}" "${selected_kernel}"
    generate_fstab "${mount_point}"
    setup_swap "${mount_point}" "${selected_swap}"

    configure_system_localization "${mount_point}" "${selected_timezone}" "${hostname}" "${selected_keymap}"
    install_and_configure_gpu "${mount_point}"
    install_bootloader "${mount_point}" "${target_disk}"

    setup_chroot_payload "${mount_point}"
    provision_user_in_chroot "${mount_point}" "${username}" "${user_password}"
    execute_aether_desktop_phase "${mount_point}" "${profile_key}" "${username}"

    cleanup_and_unmount "${mount_point}"

    local disk_summary="${target_disk}"
    if [[ "${HAS_SEPARATE_HOME:-false}" == "true" && -n "${TARGET_HOME_DISK:-}" ]]; then
        disk_summary="${target_disk} (Raiz) + ${TARGET_HOME_DISK} (/home)"
    fi

    # Tela final comemorativa
    render_banner
    if has_gum; then
        gum style \
            --foreground "${COLOR_SUCCESS}" \
            --border "double" \
            --border-foreground "${COLOR_PRIMARY}" \
            --padding "1 4" \
            --margin "1 0" \
            --align center \
            --bold \
            "PARABÉNS! O AETHER OS FOI INSTALADO COM SUCESSO!" \
            "" \
            "Discos: ${disk_summary} | Kernel: ${selected_kernel}" \
            "Perfil: ${profile_key} | Usuário: ${username}" \
            "" \
            "O sistema está 100% pronto para uso." \
            "Remova a mídia de instalação e reinicie o computador."
    else
        echo "============================================================"
        echo "   PARABÉNS! O AETHER OS FOI INSTALADO COM SUCESSO!"
        echo "============================================================"
    fi

    if prompt_confirm "Deseja reiniciar o computador agora para entrar no Aether OS?"; then
        reboot
    fi
}

# ==============================================================================
# Ponto de Entrada Principal
# ==============================================================================
main() {
    local chroot_mode=false
    local profile="Aether-Plasma"
    local target_user="${TARGET_USER}"

    # Processamento de flags de linha de comando
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --chroot-mode)
                chroot_mode=true
                shift
                ;;
            --profile)
                profile="$2"
                shift 2
                ;;
            --target-user)
                target_user="$2"
                shift 2
                ;;
            --dry-run|--test|-t)
                exec "${BASE_DIR}/test_ui.sh" "$@"
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "${chroot_mode}" == "true" ]]; then
        run_desktop_setup_flow "${profile}" "${target_user}"
        return 0
    fi

    # Se estiver em uma mídia Live ou se o usuário optar por instalação completa
    if [[ "${IS_LIVE_ENVIRONMENT}" == "true" ]]; then
        run_bare_metal_installation
    else
        # Se estiver em um sistema já instalado, pergunta o modo desejado
        render_banner
        local install_type
        install_type="$(prompt_choice "Selecione o modo de instalação do Aether OS" \
            "Instalação Bare-Metal Completa (Formatar disco e instalar Arch + Aether OS)" \
            "Aplicar Aether OS neste sistema Arch Linux existente")"

        if [[ "${install_type}" == *"Bare-Metal"* ]]; then
            run_bare_metal_installation
        else
            check_root_privileges
            setup_target_user

            local selected_profile
            selected_profile="$(prompt_choice "Selecione o perfil desejado" \
                "Aether-Plasma (KDE Plasma customizado minimal/dark)" \
                "Aether-Hyprland (Wayland dinâmico focado em teclado)")"

            local profile_key="Aether-Plasma"
            if [[ "${selected_profile}" == *"Aether-Hyprland"* ]]; then
                profile_key="Aether-Hyprland"
            fi

            run_desktop_setup_flow "${profile_key}" "${TARGET_USER}"
            render_success "Aether OS configurado com sucesso no sistema atual!"
        fi
    fi
}

main "$@"
