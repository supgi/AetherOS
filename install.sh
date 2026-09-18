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

    # 3. Compilação do AUR Helper (Paru)
    install_aur_helper

    # 4. Instalação do Grupo de Pacotes do Perfil
    install_profile_packages "${profile}"

    # 5. Implantação de Dotfiles via GNU Stow
    deploy_dotfiles "${profile}"

    # 6. Habilitação de Serviços Essenciais (systemctl)
    enable_core_services

    # 7. Configuração do aether-cli no PATH
    cp "${AETHER_BIN_DIR}/aether-cli" /usr/local/bin/aether-cli
    chmod +x /usr/local/bin/aether-cli
    render_success "Utilitário /usr/local/bin/aether-cli configurado."
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

    # 2. Seleção de disco rígido
    local target_disk
    target_disk="$(select_target_disk)"

    # 3. Confirmação explícita de formatação destrutiva
    confirm_disk_wipe "${target_disk}"

    # 4. Parâmetros de identificação e usuário
    render_step "Configurações de Identificação e Acesso do Sistema"

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

    # 5. Seleção de Perfil de Interface Gráfica
    render_step "Escolha o Perfil de Interface do Aether OS:"
    local selected_profile
    selected_profile="$(prompt_choice "Selecione a interface desejada" \
        "Aether-Hyprland (Wayland dinâmico focado em teclado)" \
        "Aether-Plasma (KDE Plasma customizado minimal/dark)")"

    local profile_key="Aether-Hyprland"
    if [[ "${selected_profile}" == *"Aether-Plasma"* ]]; then
        profile_key="Aether-Plasma"
    fi

    # 6. Resumo e confirmação final
    render_banner
    render_step "Resumo da Instalação Bare-Metal:"
    echo "  • Disco Alvo: ${target_disk}"
    echo "  • Modo de Inicialização: $(is_uefi_system && echo 'UEFI (GPT)' || echo 'BIOS Legado (MBR)')"
    echo "  • Hostname: ${hostname}"
    echo "  • Usuário: ${username}"
    echo "  • Perfil Gráfico: ${profile_key}"
    echo ""

    if ! prompt_confirm "Deseja iniciar a gravação do Aether OS agora?"; then
        render_warning "Instalação abortada pelo usuário."
        exit 0
    fi

    local mount_point="/mnt"

    # Etapa A: Particionamento, formatação e montagem
    partition_target_disk "${target_disk}"
    format_target_partitions "${target_disk}"
    mount_target_partitions "${target_disk}" "${mount_point}"

    # Etapa B: Bootstrap do sistema base e fstab
    install_base_system "${mount_point}"
    generate_fstab "${mount_point}"

    # Etapa C: Localização, teclado e bootloader GRUB
    configure_system_localization "${mount_point}" "America/Sao_Paulo" "${hostname}" "br-abnt2"
    install_bootloader "${mount_point}" "${target_disk}"

    # Etapa D: Provisionamento de usuários e transição para o ambiente Aether
    setup_chroot_payload "${mount_point}"
    provision_user_in_chroot "${mount_point}" "${username}" "${user_password}"
    execute_aether_desktop_phase "${mount_point}" "${profile_key}" "${username}"

    # Etapa E: Desmontagem limpa
    cleanup_and_unmount "${mount_point}"

    # Etapa F: Conclusão
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
            "Disco: ${target_disk} | Perfil: ${profile_key}" \
            "Usuário: ${username} | Hostname: ${hostname}" \
            "" \
            "O sistema base, bootloader e ambiente gráfico estão prontos." \
            "Remova o pendrive de instalação e reinicie o computador."
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
    local profile="Aether-Hyprland"
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
                "Aether-Hyprland (Wayland dinâmico focado em teclado)" \
                "Aether-Plasma (KDE Plasma customizado minimal/dark)")"

            local profile_key="Aether-Hyprland"
            if [[ "${selected_profile}" == *"Aether-Plasma"* ]]; then
                profile_key="Aether-Plasma"
            fi

            run_desktop_setup_flow "${profile_key}" "${TARGET_USER}"
            render_success "Aether OS configurado com sucesso no sistema atual!"
        fi
    fi
}

main "$@"
