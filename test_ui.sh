#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Modo de Teste e Simulação da Interface TUI (Dry-Run)
# Executa todo o fluxo visual do instalador sem tocar em discos ou pacotes.
# Permite desenhar, iterar e validar a experiência do usuário de forma segura.
# ==============================================================================

set -euo pipefail

# Resolução de diretórios
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="${ROOT_DIR}/installer"

# Carregamento dos módulos auxiliares
# shellcheck source=installer/env.sh
source "${INSTALLER_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${INSTALLER_DIR}/ui.sh"
# shellcheck source=installer/options.sh
source "${INSTALLER_DIR}/options.sh"

# Indicador de modo de simulação
export AETHER_TEST_MODE=true

# Lista de discos simulados para desenvolvimento da interface
mock_disk_list=(
    "/dev/nvme0n1 (512G - Samsung SSD 980 Pro)"
    "/dev/sda (1TB - Crucial MX500 SSD)"
    "/dev/sdb (2TB - Seagate Barracuda HDD)"
    "/dev/vda (64G - QEMU/KVM Virtual Disk)"
)

# Fluxo principal de simulação da interface
run_ui_simulation() {
    # 1. Banner Principal de Abertura
    render_banner

    # Aviso explícito de Modo de Teste
    if has_gum; then
        gum style \
            --foreground "${COLOR_WARNING}" \
            --border "rounded" \
            --border-foreground "${COLOR_WARNING}" \
            --padding "0 2" \
            --margin "0 0 1 0" \
            --align center \
            --bold \
            "MODO DE TESTE DA INTERFACE (DRY-RUN)" \
            "Nenhuma alteração real será gravada em disco ou no sistema." >&2
    else
        echo -e "\033[1;33m[ MODO DE TESTE / SIMULAÇÃO ATIVO - NENHUM DISCO SERÁ ALTERADO ]\033[0m\n" >&2
    fi

    # 2. Pré-checagens simuladas
    render_step "Verificações de integridade do ambiente..."
    sleep 0.5
    render_success "Privilégios de execução validados (Modo Teste)."
    render_success "Arquitetura suportada detectada: $(uname -m)"
    render_success "Conexão de rede operacional."

    # 3. Seleção de Unidade de Armazenamento (Simulada)
    render_step "Detectando unidades de armazenamento disponíveis..."
    local selected_disk_entry
    selected_disk_entry="$(prompt_choice "Selecione o disco principal (Sistema Raiz e Boot)" "${mock_disk_list[@]}")"
    local simulated_disk
    simulated_disk="$(echo "${selected_disk_entry}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"

    local simulated_home_disk=""
    local has_simulated_separate_home=false

    # Opção de /home em disco separado quando houver múltiplas unidades
    if [[ ${#mock_disk_list[@]} -gt 1 ]]; then
        render_step "Configuração de Armazenamento Avançado (/home):"
        local separate_home_choice
        separate_home_choice="$(prompt_choice \
            "Detectamos múltiplas unidades de disco. Deseja utilizar um disco separado para a pasta /home?" \
            "Não (Instalar sistema operacional e /home no mesmo disco)" \
            "Sim (Selecionar um segundo disco dedicado para os arquivos dos usuários em /home)")"

        if [[ "${separate_home_choice}" == *"Sim"* ]]; then
            local mock_home_disks=()
            for d in "${mock_disk_list[@]}"; do
                local dev_name
                dev_name="$(echo "${d}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"
                if [[ "${dev_name}" != "${simulated_disk}" ]]; then
                    mock_home_disks+=("${d}")
                fi
            done

            if [[ ${#mock_home_disks[@]} -gt 0 ]]; then
                local selected_home_entry
                selected_home_entry="$(prompt_choice "Selecione o disco dedicado exclusivamente para a partição /home" "${mock_home_disks[@]}")"
                simulated_home_disk="$(echo "${selected_home_entry}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"
                has_simulated_separate_home=true
                render_success "Disco simulado para /home: ${simulated_home_disk}"
            fi
        fi
    fi

    # 4. Alerta de Operação Destrutiva (Teste do Modal de Risco)
    local wipe_info="O disco ${simulated_disk} seria completamente formatado."
    if [[ "${has_simulated_separate_home}" == "true" && -n "${simulated_home_disk}" ]]; then
        wipe_info="Os discos ${simulated_disk} (Raiz) e ${simulated_home_disk} (/home) seriam completamente formatados."
    fi

    if has_gum; then
        gum style \
            --foreground "${COLOR_DANGER}" \
            --border "double" \
            --border-foreground "${COLOR_DANGER}" \
            --padding "1 3" \
            --margin "1 0" \
            --align center \
            --bold \
            "ATENÇÃO: OPERAÇÃO DESTRUTIVA DE DISCO (SIMULAÇÃO)!" \
            "" \
            "${wipe_info}" \
            "Todos os dados e partições existentes seriam apagados permanentemente." >&2
    else
        echo -e "\n\033[1;31mATENÇÃO (SIMULAÇÃO): ${wipe_info}!\033[0m\n" >&2
    fi

    if ! prompt_confirm "Deseja prosseguir com a simulação nas unidades selecionadas?"; then
        render_warning "Simulação cancelada pelo usuário."
        exit 0
    fi

    # 5. Configuração de Teclado (Keymap)
    render_step "Configuração de Layout do Teclado:"
    local raw_keymap
    raw_keymap="$(prompt_choice "Selecione o layout do teclado" "${AETHER_KEYMAP_OPTIONS[@]}")"
    local selected_keymap
    selected_keymap="$(get_keymap_value "${raw_keymap}")"

    # 6. Seleção de Kernel Linux
    render_step "Seleção do Kernel Linux:"
    local raw_kernel
    raw_kernel="$(prompt_choice "Selecione o Kernel Linux desejado" "${AETHER_KERNEL_OPTIONS[@]}")"
    local selected_kernel
    selected_kernel="$(get_kernel_value "${raw_kernel}")"

    # 7. Seleção de Fuso Horário
    render_step "Seleção do Fuso Horário:"
    local raw_timezone
    raw_timezone="$(prompt_choice "Selecione o Fuso Horário do sistema" "${AETHER_TIMEZONE_OPTIONS[@]}")"
    local selected_timezone
    selected_timezone="$(get_timezone_value "${raw_timezone}")"

    # 8. Estratégia de Swap
    render_step "Configuração de Memória Swap:"
    local raw_swap
    raw_swap="$(prompt_choice "Selecione a estratégia de Swap (Memória Virtual)" "${AETHER_SWAP_OPTIONS[@]}")"
    local selected_swap
    selected_swap="$(get_swap_value "${raw_swap}")"

    # 9. Coleta de Identificação e Credenciais
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

    # 10. Seleção de Perfil Gráfico
    render_step "Escolha o Perfil de Interface do Aether OS:"
    local raw_profile
    raw_profile="$(prompt_choice "Selecione a interface gráfica desejada" "${AETHER_PROFILE_OPTIONS[@]}")"
    local profile_key
    profile_key="$(get_profile_value "${raw_profile}")"

    # 11. Resumo Geral Pré-Instalação
    render_banner
    render_step "Resumo Geral da Instalação (Simulação):"
    echo "  • Disco Raiz (Root): ${simulated_disk}"
    if [[ "${has_simulated_separate_home}" == "true" && -n "${simulated_home_disk}" ]]; then
        echo "  • Disco de Usuários (/home): ${simulated_home_disk} (Dedicado)"
    else
        echo "  • Partição /home: Mesmo disco do sistema (${simulated_disk})"
    fi
    echo "  • Modo de Boot: UEFI (GPT)"
    echo "  • Layout de Teclado: ${selected_keymap}"
    echo "  • Kernel Linux: ${selected_kernel}"
    echo "  • Fuso Horário: ${selected_timezone}"
    echo "  • Estratégia de Swap: ${selected_swap}"
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

    if ! prompt_confirm "Deseja iniciar a simulação visual da instalação?"; then
        render_warning "Simulação finalizada pelo usuário."
        exit 0
    fi

    # 12. Simulação dos Spinners e Etapas do Instalador Real
    render_step "Executando procedimentos de instalação simulados..."

    render_spinner "Gravando tabela de partições GPT em ${simulated_disk}" sleep 1
    if [[ "${has_simulated_separate_home}" == "true" && -n "${simulated_home_disk}" ]]; then
        render_spinner "Gravando tabela de partições GPT em ${simulated_home_disk} (/home)" sleep 0.8
    fi
    render_success "Particionamento simulado com sucesso."

    render_spinner "Formatando partição EFI (FAT32) em ${simulated_disk}p1" sleep 0.8
    render_spinner "Formatando partição Raiz (EXT4) em ${simulated_disk}p2" sleep 1
    if [[ "${has_simulated_separate_home}" == "true" && -n "${simulated_home_disk}" ]]; then
        render_spinner "Formatando partição Home dedicada (EXT4) em ${simulated_home_disk}p1" sleep 0.8
    fi
    render_success "Sistemas de arquivos simulados com sucesso."

    render_spinner "Instalando sistema base e kernel ${selected_kernel} (pacstrap)" sleep 1.8
    render_success "Sistema base simulado com sucesso."

    render_spinner "Gerando arquivo persistente /etc/fstab" sleep 0.6
    render_spinner "Configurando regionalização e mapa de teclado (${selected_keymap})" sleep 0.6
    render_spinner "Instalando e configurando bootloader GRUB para UEFI" sleep 1
    render_success "Bootloader configurado com sucesso."

    render_spinner "Configurando swap (${selected_swap})" sleep 0.8
    render_spinner "Provisionando usuário ${username} com privilégios sudo" sleep 0.8
    render_spinner "Instalando AUR Helper (Yay)" sleep 1.2
    render_spinner "Instalando pacotes do perfil ${profile_key}" sleep 1.5
    if [[ ${custom_pkgs_count} -gt 0 ]]; then
        render_spinner "Instalando aplicativos adicionais (${custom_pkgs_count} pacotes de custom-packages.conf)" sleep 1.2
        render_success "Aplicativos customizados simulados com sucesso."
    fi
    render_spinner "Vinculando dotfiles declarativos via GNU Stow" sleep 1
    render_spinner "Ativando serviços systemd (NetworkManager, sddm, firewalld)" sleep 0.8
    render_success "Todos os serviços e dotfiles foram configurados."

    local simulated_disk_summary="${simulated_disk}"
    if [[ "${has_simulated_separate_home}" == "true" && -n "${simulated_home_disk}" ]]; then
        simulated_disk_summary="${simulated_disk} (Raiz) + ${simulated_home_disk} (/home)"
    fi

    # 13. Tela de Sucesso Final
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
            "SIMULAÇÃO DO AETHER OS CONCLUÍDA COM SUCESSO!" \
            "" \
            "Discos: ${simulated_disk_summary} | Kernel: ${selected_kernel}" \
            "Perfil: ${profile_key} | Usuário: ${username}" \
            "" \
            "Esta foi uma simulação 100% segura do instalador TUI." \
            "Todos os componentes visuais foram validados." >&2
    else
        echo "============================================================"
        echo "   SIMULAÇÃO DO AETHER OS CONCLUÍDA COM SUCESSO!"
        echo "============================================================"
    fi

    echo ""
    render_success "Teste da interface TUI finalizado."
}

run_ui_simulation "$@"
