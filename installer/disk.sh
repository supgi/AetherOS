#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Gerenciamento de Discos e Particionamento
# Detecção de hardware, suporte a UEFI/BIOS, particionamento, formatação e /home separada.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

# Variáveis globais de discos selecionados
export TARGET_DISK=""
export TARGET_HOME_DISK=""
export HAS_SEPARATE_HOME=false

# Detecta se a máquina iniciou em modo UEFI ou BIOS legado
is_uefi_system() {
    if [[ -d "/sys/firmware/efi" ]]; then
        return 0
    else
        return 1
    fi
}

# Retorna a lista de discos físicos disponíveis no sistema
list_available_disks() {
    # Lista discos excluindo partições, loops e mídias óticas
    lsblk -d -n -o NAME,SIZE,TYPE,MODEL | awk '$3 == "disk" {print "/dev/" $1 " (" $2 " - " $4 ")"}'
}

# Solicita ao usuário a seleção do disco raiz e opcionalmente disco dedicado para /home
select_target_disk() {
    render_step "Detectando unidades de armazenamento disponíveis..."

    local disk_list=()
    while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            disk_list+=("${line}")
        fi
    done < <(list_available_disks)

    if [[ ${#disk_list[@]} -eq 0 ]]; then
        render_error "Nenhum disco físico de instalação foi detectado no sistema." \
                     "No physical block devices found via lsblk"
        return 1
    fi

    # 1. Seleção do disco do sistema (Raiz / Boot)
    local selected_entry
    selected_entry="$(prompt_choice "Selecione o disco principal (Sistema Raiz e Boot)" "${disk_list[@]}")"

    TARGET_DISK="$(echo "${selected_entry}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"
    export TARGET_DISK

    # 2. Se houver mais de uma unidade de disco, oferece opção de /home separada
    if [[ ${#disk_list[@]} -gt 1 ]]; then
        render_step "Configuração de Armazenamento Avançado (/home):"
        local separate_home_choice
        separate_home_choice="$(prompt_choice \
            "Detectamos múltiplas unidades de disco. Deseja utilizar um disco separado para a pasta /home?" \
            "Não (Instalar sistema operacional e /home no mesmo disco)" \
            "Sim (Selecionar um segundo disco dedicado para os arquivos dos usuários em /home)")"

        if [[ "${separate_home_choice}" == *"Sim"* ]]; then
            local home_disk_list=()
            for d in "${disk_list[@]}"; do
                local dev_name
                dev_name="$(echo "${d}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"
                if [[ "${dev_name}" != "${TARGET_DISK}" ]]; then
                    home_disk_list+=("${d}")
                fi
            done

            if [[ ${#home_disk_list[@]} -gt 0 ]]; then
                local selected_home_entry
                selected_home_entry="$(prompt_choice "Selecione o disco dedicado exclusivamente para a partição /home" "${home_disk_list[@]}")"
                TARGET_HOME_DISK="$(echo "${selected_home_entry}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"
                export TARGET_HOME_DISK
                export HAS_SEPARATE_HOME=true
                render_success "Disco selecionado para /home: ${TARGET_HOME_DISK}"
            fi
        else
            export TARGET_HOME_DISK=""
            export HAS_SEPARATE_HOME=false
        fi
    else
        export TARGET_HOME_DISK=""
        export HAS_SEPARATE_HOME=false
    fi
}

# Confirmação visual rigorosa para prevenir perda acidental de dados
confirm_disk_wipe() {
    local target_disk="${1:-${TARGET_DISK}}"
    target_disk="$(echo "${target_disk}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"

    local disks_msg="O disco ${target_disk} será completamente formatado."
    if [[ "${HAS_SEPARATE_HOME}" == "true" && -n "${TARGET_HOME_DISK}" ]]; then
        disks_msg="Os discos ${target_disk} (Raiz) e ${TARGET_HOME_DISK} (/home) serão completamente formatados."
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
            "ATENÇÃO: OPERAÇÃO DESTRUTIVA DE DISCO!" \
            "" \
            "${disks_msg}" \
            "Todos os dados, partições e arquivos existentes serão apagados permanentemente." >&2
    else
        echo -e "\n\033[1;31mATENÇÃO: ${disks_msg} Todos os dados serão perdidos!\033[0m\n" >&2
    fi

    if ! prompt_confirm "Tem certeza absoluta de que deseja formatar e particionar a(s) unidade(s)?"; then
        render_warning "Operação cancelada pelo usuário. Nenhuma alteração foi feita no disco."
        exit 0
    fi
}

# Obtém a nomenclatura correta das partições (ex: /dev/sda1 vs /dev/nvme0n1p1)
get_partition_path() {
    local disk="$1"
    local part_number="$2"
    disk="$(echo "${disk}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"

    if [[ "${disk}" =~ [0-9]$ ]]; then
        echo "${disk}p${part_number}"
    else
        echo "${disk}${part_number}"
    fi
}

# Executa o particionamento do disco conforme o modo de boot (UEFI vs BIOS)
partition_target_disk() {
    local target_disk="${1:-${TARGET_DISK}}"
    target_disk="$(echo "${target_disk}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"

    if [[ -z "${target_disk}" || ! -b "${target_disk}" ]]; then
        render_error "Dispositivo de bloco inválido ou inexistente: ${target_disk}" "Block device does not exist: ${target_disk}"
        return 1
    fi

    render_step "Gravando nova tabela de partições no disco principal ${target_disk}..."

    # Desmonta qualquer partição do disco que esteja montada
    umount -q "${target_disk}"* 2>/dev/null || true

    # Zera o início do disco para limpar assinaturas antigas
    dd if=/dev/zero of="${target_disk}" bs=1M count=10 status=none 2>/dev/null || true

    if is_uefi_system; then
        render_step "Sistema em modo UEFI detectado. Criando tabela GPT..."
        parted -s "${target_disk}" mklabel gpt
        parted -s "${target_disk}" mkpart "ESP" fat32 1MiB 1025MiB
        parted -s "${target_disk}" set 1 esp on
        parted -s "${target_disk}" mkpart "AetherRoot" ext4 1025MiB 100%
    else
        render_step "Sistema em modo BIOS Legado detectado. Criando tabela MBR..."
        parted -s "${target_disk}" mklabel msdos
        parted -s "${target_disk}" mkpart primary ext4 1MiB 100%
        parted -s "${target_disk}" set 1 boot on
    fi

    # Força a re-leitura da tabela de partições pelo kernel e sincronização de udev
    partprobe "${target_disk}" 2>/dev/null || true
    udevadm settle 2>/dev/null || true
    sleep 2

    render_success "Particionamento do disco ${target_disk} concluído com sucesso."

    # Particionamento do disco secundário dedicado para /home (se configurado)
    if [[ "${HAS_SEPARATE_HOME}" == "true" && -n "${TARGET_HOME_DISK}" ]]; then
        local target_home_disk="${TARGET_HOME_DISK}"
        render_step "Gravando nova tabela de partições no disco de dados /home (${target_home_disk})..."

        umount -q "${target_home_disk}"* 2>/dev/null || true
        dd if=/dev/zero of="${target_home_disk}" bs=1M count=10 status=none 2>/dev/null || true

        if is_uefi_system; then
            parted -s "${target_home_disk}" mklabel gpt
            parted -s "${target_home_disk}" mkpart "AetherHome" ext4 1MiB 100%
        else
            parted -s "${target_home_disk}" mklabel msdos
            parted -s "${target_home_disk}" mkpart primary ext4 1MiB 100%
        fi

        partprobe "${target_home_disk}" 2>/dev/null || true
        udevadm settle 2>/dev/null || true
        sleep 2

        render_success "Particionamento do disco /home (${target_home_disk}) concluído com sucesso."
    fi
}

# Formata as partições criadas
format_target_partitions() {
    local target_disk="${1:-${TARGET_DISK}}"
    target_disk="$(echo "${target_disk}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"

    render_step "Formatando sistemas de arquivos no disco principal ${target_disk}..."

    # Garante que os dispositivos de bloco estejam prontos
    udevadm settle 2>/dev/null || true
    sleep 1

    if is_uefi_system; then
        local boot_part
        local root_part
        boot_part="$(get_partition_path "${target_disk}" 1)"
        root_part="$(get_partition_path "${target_disk}" 2)"

        render_spinner "Formatando partição EFI (FAT32) em ${boot_part}" \
            mkfs.fat -F32 "${boot_part}"

        render_spinner "Formatando partição Raiz (EXT4) em ${root_part}" \
            mkfs.ext4 -F -L "AetherRoot" "${root_part}"
    else
        local root_part
        root_part="$(get_partition_path "${target_disk}" 1)"

        render_spinner "Formatando partição Raiz (EXT4) em ${root_part}" \
            mkfs.ext4 -F -L "AetherRoot" "${root_part}"
    fi

    # Formatação da partição /home no segundo disco (se aplicável)
    if [[ "${HAS_SEPARATE_HOME}" == "true" && -n "${TARGET_HOME_DISK}" ]]; then
        local home_part
        home_part="$(get_partition_path "${TARGET_HOME_DISK}" 1)"

        render_spinner "Formatando partição Home dedicada (EXT4) em ${home_part}" \
            mkfs.ext4 -F -L "AetherHome" "${home_part}"
    fi

    render_success "Formatação das partições finalizada com sucesso."
}

# Monta as partições no diretório de destino (/mnt)
mount_target_partitions() {
    local target_disk="${1:-${TARGET_DISK}}"
    local mount_point="${2:-/mnt}"
    target_disk="$(echo "${target_disk}" | grep -oE '/dev/[a-zA-Z0-9_]+' | head -n 1)"

    render_step "Montando partições em ${mount_point}..."

    mkdir -p "${mount_point}"

    if is_uefi_system; then
        local boot_part
        local root_part
        boot_part="$(get_partition_path "${target_disk}" 1)"
        root_part="$(get_partition_path "${target_disk}" 2)"

        mount "${root_part}" "${mount_point}"
        mkdir -p "${mount_point}/boot"
        mount "${boot_part}" "${mount_point}/boot"
    else
        local root_part
        root_part="$(get_partition_path "${target_disk}" 1)"

        mount "${root_part}" "${mount_point}"
    fi

    # Monta a partição /home separada (se configurada)
    if [[ "${HAS_SEPARATE_HOME}" == "true" && -n "${TARGET_HOME_DISK}" ]]; then
        local home_part
        home_part="$(get_partition_path "${TARGET_HOME_DISK}" 1)"
        mkdir -p "${mount_point}/home"
        mount "${home_part}" "${mount_point}/home"
        render_success "Partição dedicada /home montada em ${mount_point}/home."
    fi

    render_success "Todas as partições foram montadas e preparadas para instalação."
}
