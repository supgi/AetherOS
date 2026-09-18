#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Verificações de Sistema e Gerenciamento de Usuários
# Pré-checagens (internet, arquitetura, privilégios) e criação de usuário não-root.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

# Valida conexão com a internet
check_internet_connection() {
    render_step "Verificando conectividade com a internet..."

    if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || curl -s --head --connect-timeout 3 https://archlinux.org >/dev/null 2>&1; then
        render_success "Conexão com a internet confirmada."
    else
        render_error "Falha de conectividade. Verifique sua conexão de rede antes de prosseguir." \
                     "Network ping/curl failed to reach external hosts"
        return 1
    fi
}

# Valida a arquitetura do sistema operacional (x86_64 obrigatório)
check_system_architecture() {
    render_step "Verificando arquitetura do processador..."

    local arch
    arch="$(uname -m)"
    if [[ "${arch}" == "x86_64" ]]; then
        render_success "Arquitetura suportada detectada: ${arch}"
    else
        render_error "O Aether OS requer arquitetura x86_64. Arquitetura atual: ${arch}" \
                     "Unsupported CPU architecture: ${arch}"
        return 1
    fi
}

# Garante que o instalador possui permissões administrativas
check_root_privileges() {
    if [[ "${EUID}" -ne 0 ]]; then
        render_error "Este instalador precisa de privilégios de superusuário para configurar o sistema." \
                     "Script executed without EUID 0 (root)"
        echo -e "\nPor favor, execute o script com: \033[1;33msudo ./install.sh\033[0m\n"
        exit 1
    fi
}

# Configura ou cria uma conta de usuário não-root
setup_target_user() {
    render_step "Validando configurações de usuário do sistema..."

    # Se estivermos executando como root puro (ex: Live ISO ou chroot de instalação)
    if [[ "${TARGET_USER}" == "root" ]]; then
        render_warning "Nenhum usuário não-root foi detectado."
        
        if prompt_confirm "Deseja criar um novo usuário comum com privilégios sudo?"; then
            local new_username
            new_username="$(prompt_input "Nome do novo usuário" "ex: aether")"

            if [[ -z "${new_username}" ]]; then
                render_error "Nome de usuário inválido." "Empty username provided"
                return 1
            fi

            local new_password
            new_password="$(prompt_input "Senha para ${new_username}" "" true)"

            # Cria o usuário com grupo wheel e shell padrão zsh
            local default_shell="/bin/bash"
            if command -v zsh >/dev/null 2>&1; then
                default_shell="/bin/zsh"
            fi

            useradd -m -G wheel -s "${default_shell}" "${new_username}"
            echo "${new_username}:${new_password}" | chpasswd

            # Concede privilégios de sudo ao grupo wheel
            echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel-sudo
            chmod 0440 /etc/sudoers.d/10-wheel-sudo

            export TARGET_USER="${new_username}"
            export TARGET_HOME="/home/${new_username}"
            render_success "Usuário ${new_username} criado e adicionado ao grupo wheel (sudo)."
        fi
    else
        render_success "Instalação direcionada para o usuário existente: ${TARGET_USER} (${TARGET_HOME})"
    fi

    # Define o Zsh como shell padrão do usuário alvo caso instalado
    if command -v zsh >/dev/null 2>&1 && id "${TARGET_USER}" >/dev/null 2>&1; then
        local zsh_path
        zsh_path="$(command -v zsh)"
        chsh -s "${zsh_path}" "${TARGET_USER}" 2>/dev/null || true
        render_success "Shell padrão definido como Zsh para ${TARGET_USER}."
    fi
}
