#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Gerenciamento de Serviços Systemd
# Habilitação dos daemons essenciais de rede, bluetooth, display manager e firewall.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

# Lista de serviços essenciais a serem habilitados no systemd
SYSTEMD_SERVICES=(
    NetworkManager.service
    bluetooth.service
    sddm.service
    firewalld.service
)

# Habilita os serviços no sistema
enable_core_services() {
    render_step "Configurando e ativando serviços do sistema (systemd)..."

    for service in "${SYSTEMD_SERVICES[@]}"; do
        if systemctl list-unit-files "${service}" >/dev/null 2>&1; then
            systemctl enable "${service}" >> "${AETHER_LOG_FILE}" 2>&1 || {
                render_warning "Não foi possível habilitar ${service}. Detalhes registrados no log."
                continue
            }
            render_success "Serviço ativado: ${service}"
        else
            render_warning "Serviço não encontrado no sistema: ${service} (será pulado)"
        fi
    done

    render_success "Todos os serviços essenciais foram configurados."
}
