#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo Orquestrador de Execução em Chroot
# Transfere o framework para o sistema recém-instalado e executa a fase desktop.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

# Copia os arquivos do Aether OS para dentro da partição raiz montada
setup_chroot_payload() {
    local mount_point="${1:-/mnt}"
    local source_dir="${AETHER_ROOT_DIR}"
    local destination_dir="${mount_point}/opt/aether-os"

    render_step "Copiando instalador do Aether OS para o sistema destino (${destination_dir})..."

    mkdir -p "${destination_dir}"
    cp -a "${source_dir}/." "${destination_dir}/"

    render_success "Arquivos do Aether OS provisionados no ambiente de destino."
}

# Cria a conta de usuário e credenciais no novo sistema
provision_user_in_chroot() {
    local mount_point="${1:-/mnt}"
    local username="$2"
    local password="$3"

    # Sanitiza rigorosamente username e password para garantir linha única
    username="$(echo -n "${username}" | tr -d '[:space:]')"
    password="$(echo -n "${password}" | tr -d '\r\n')"

    render_step "Provisionando conta de usuário comum e permissões sudo..."

    # Garante que a senha não esteja vazia
    if [[ -z "${password}" ]]; then
        render_error "A senha informada para o usuário está vazia." "Empty password in provision_user_in_chroot"
        return 1
    fi

    # Define a senha do root com printf em linha única estrita
    printf "%s:%s\n" "root" "${password}" | arch-chroot "${mount_point}" chpasswd

    # Cria o usuário com zsh e grupo administrativo wheel (se ainda não existir)
    if ! arch-chroot "${mount_point}" id "${username}" >/dev/null 2>&1; then
        arch-chroot "${mount_point}" useradd -m -G wheel -s /bin/zsh "${username}"
    fi

    # Define a senha do usuário com printf em linha única estrita
    printf "%s:%s\n" "${username}" "${password}" | arch-chroot "${mount_point}" chpasswd

    # Concede privilégios administrativos sudo (NOPASSWD temporário para compilação do paru)
    mkdir -p "${mount_point}/etc/sudoers.d"
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "${mount_point}/etc/sudoers.d/10-wheel-sudo"
    chmod 0440 "${mount_point}/etc/sudoers.d/10-wheel-sudo"

    render_success "Usuário ${username} provisionado com privilégios administrativos."
}

# Executa o instalador dentro do ambiente chroot para configurar a interface desktop
execute_aether_desktop_phase() {
    local mount_point="${1:-/mnt}"
    local profile="$2"
    local target_user="$3"

    render_step "Iniciando instalação da interface desktop (${profile}) via chroot..."

    # Copia o log acumulado na mídia de instalação para o sistema destino
    if [[ -f "${AETHER_LOG_FILE}" ]]; then
        cp "${AETHER_LOG_FILE}" "${mount_point}/opt/aether-os/aether-install.log" 2>/dev/null || true
        chmod 666 "${mount_point}/opt/aether-os/aether-install.log" 2>/dev/null || true
    fi

    # Executa o install.sh no modo chroot diretamente dentro do novo sistema com variáveis limpas
    arch-chroot "${mount_point}" /usr/bin/env \
        HOME="/root" \
        AETHER_ROOT_DIR="/opt/aether-os" \
        AETHER_LOG_FILE="/opt/aether-os/aether-install.log" \
        /bin/bash -c \
        "cd /opt/aether-os && ./install.sh --chroot-mode --profile '${profile}' --target-user '${target_user}'"

    render_success "Configuração da interface Wayland e dotfiles finalizada com sucesso."
}

# Realiza a desmontagem segura de todos os pontos de montagem do novo sistema
cleanup_and_unmount() {
    local mount_point="${1:-/mnt}"
    render_step "Sincronizando dados no disco e desmontando partições de ${mount_point}..."

    sync
    umount -R "${mount_point}" 2>/dev/null || true

    render_success "Todas as partições foram desmontadas com segurança."
}
