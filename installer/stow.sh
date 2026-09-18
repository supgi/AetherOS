#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Gerenciamento de Dotfiles (GNU Stow)
# Implantação e remoção modular de configurações na HOME do usuário alvo.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

# Módulos comuns a todos os perfis do Aether OS
COMMON_STOW_MODULES=(
    kitty
    starship
    nvim
    zsh
)

# Executa comando como o usuário alvo para preservar permissões corretas
run_as_target_user() {
    local cmd="$1"
    if [[ "${TARGET_USER}" == "root" || "${USER:-}" == "${TARGET_USER}" ]]; then
        bash -c "${cmd}"
    else
        su - "${TARGET_USER}" -c "${cmd}"
    fi
}

# Prepara a estrutura do diretório destino (~/.config)
prepare_target_environment() {
    local target_config_dir="${TARGET_HOME}/.config"
    if [[ ! -d "${target_config_dir}" ]]; then
        mkdir -p "${target_config_dir}"
        if [[ "${TARGET_USER}" != "root" ]]; then
            chown -R "${TARGET_USER}:${TARGET_USER}" "${target_config_dir}"
        fi
    fi
}

# Realiza backup preventivo de arquivos existentes que possam conflitar com o Stow
backup_conflicting_files() {
    local module="$1"
    local module_path="${AETHER_CONFIGS_DIR}/${module}"

    if [[ ! -d "${module_path}" ]]; then
        return 0
    fi

    # Varre os arquivos no módulo para detectar conflitos na $TARGET_HOME
    find "${module_path}" -type f | while read -r src_file; do
        local rel_path="${src_file#"${module_path}/"}"
        local dest_file="${TARGET_HOME}/${rel_path}"

        # Se o arquivo existe e NÃO é um link simbólico, move para backup .aether.bak
        if [[ -f "${dest_file}" && ! -L "${dest_file}" ]]; then
            local backup_file="${dest_file}.aether.bak"
            mv "${dest_file}" "${backup_file}"
            render_warning "Arquivo existente em conflito com ${module}: salvo como ${backup_file}"
        fi
    done
}

# Aplica os dotfiles via GNU Stow
deploy_dotfiles() {
    local profile="$1"
    render_step "Aplicando dotfiles via GNU Stow para o usuário: ${TARGET_USER}..."

    if ! command -v stow >/dev/null 2>&1; then
        render_error "GNU Stow não está instalado no sistema." "GNU Stow binary missing"
        return 1
    fi

    prepare_target_environment

    # Lista de módulos a aplicar
    local modules_to_stow=("${COMMON_STOW_MODULES[@]}")
    case "${profile}" in
        "Aether-Hyprland")
            modules_to_stow+=(hyprland)
            ;;
        "Aether-Plasma")
            modules_to_stow+=(plasma)
            ;;
        *)
            render_warning "Nenhum módulo específico associado ao perfil: ${profile}"
            ;;
    esac

    for module in "${modules_to_stow[@]}"; do
        if [[ -d "${AETHER_CONFIGS_DIR}/${module}" ]]; then
            backup_conflicting_files "${module}"
            render_spinner "Vinculando módulo: ${module}" \
                stow --restow --dir="${AETHER_CONFIGS_DIR}" --target="${TARGET_HOME}" "${module}" >> "${AETHER_LOG_FILE}" 2>&1
            render_success "Módulo aplicado: ${module}"
        else
            render_warning "Diretório de configuração do módulo não encontrado: configs/${module}"
        fi
    done

    # Garante que os links e arquivos tenham as permissões corretas do usuário
    if [[ "${TARGET_USER}" != "root" ]]; then
        chown -hR "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config" 2>/dev/null || true
    fi

    render_success "Dotfiles do Aether OS aplicados com sucesso na pasta pessoal."
}

# Remove os dotfiles vinculados via GNU Stow
undeploy_dotfiles() {
    local profile="$1"
    render_step "Removendo links simbólicos do perfil: ${profile}..."

    local modules_to_unstow=("${COMMON_STOW_MODULES[@]}")
    case "${profile}" in
        "Aether-Hyprland")
            modules_to_unstow+=(hyprland)
            ;;
        "Aether-Plasma")
            modules_to_unstow+=(plasma)
            ;;
    esac

    for module in "${modules_to_unstow[@]}"; do
        if [[ -d "${AETHER_CONFIGS_DIR}/${module}" ]]; then
            stow --delete --dir="${AETHER_CONFIGS_DIR}" --target="${TARGET_HOME}" "${module}" >> "${AETHER_LOG_FILE}" 2>&1 || true
            render_success "Módulo desvinculado: ${module}"
        fi
    done
}
