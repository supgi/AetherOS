#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Módulo de Gerenciamento de Discos e Particionamento
# Detecção de hardware, suporte a UEFI/BIOS, particionamento e formatação.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/env.sh
source "${SCRIPT_DIR}/env.sh"
# shellcheck source=installer/ui.sh
source "${SCRIPT_DIR}/ui.sh"

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

# Solicita ao usuário a seleção do disco para instalação
select_target_disk() {
    render_step "Detectando discos rígidos e unidades de armazenamento..."

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

    local selected_entry
    selected_entry="$(prompt_choice "Selecione o disco alvo para a instalação do Aether OS" "${disk_list[@]}")"

    # Extrai o caminho do dispositivo (ex.: /dev/nvme0n1 ou /dev/sda)
    local target_disk
    target_disk="$(echo "${selected_entry}" | awk '{print $1}')"
    echo "${target_disk}"
}

# Confirmação visual rigorosa para prevenir perda acidental de dados
confirm_disk_wipe() {
    local target_disk="$1"

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
            "O disco ${target_disk} será completamente formatado." \
            "Todos os dados, partições e arquivos existentes serão apagados permanentemente."
    else
        echo -e "\n\033[1;31mATENÇÃO: O disco ${target_disk} será formatado e todos os dados serão perdidos!\033[0m\n"
    fi

    if ! prompt_confirm "Tem certeza absoluta de que deseja formatar o disco ${target_disk}?"; then
        render_warning "Operação cancelada pelo usuário. Nenhuma alteração foi feita no disco."
        exit 0
    fi
}

# Obtém a nomenclatura correta das partições (ex: /dev/sda1 vs /dev/nvme0n1p1)
get_partition_path() {
    local disk="$1"
    local part_number="$2"

    if [[ "${disk}" =~ [0-9]$ ]]; then
        echo "${disk}p${part_number}"
    else
        echo "${disk}${part_number}"
    fi
}

# Executa o particionamento do disco conforme o modo de boot (UEFI vs BIOS)
partition_target_disk() {
    local target_disk="$1"
    render_step "Gravando nova tabela de partições no disco ${target_disk}..."

    # Desmonta qualquer partição do disco que esteja montada
    umount -q "${target_disk}"* 2>/dev/null || true

    # Zera a tabela de partições
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

    # Força a re-leitura da tabela de partições pelo kernel
    partprobe "${target_disk}" 2>/dev/null || true
    sleep 2

    render_success "Particionamento concluído com sucesso."
}

# Formata as partições criadas
format_target_partitions() {
    local target_disk="$1"
    render_step "Formatando partições..."

    if is_uefi_system; then
        local boot_part
        local root_part
        boot_part="$(get_partition_path "${target_disk}" 1)"
        root_part="$(get_partition_path "${target_disk}" 2)"

        render_spinner "Formatando partição EFI (FAT32) em ${boot_part}" \
            mkfs.fat -F32 "${boot_part}" >> "${AETHER_LOG_FILE}" 2>&1

        render_spinner "Formatando partição Raiz (EXT4) em ${root_part}" \
            mkfs.ext4 -F -L "AetherRoot" "${root_part}" >> "${AETHER_LOG_FILE}" 2>&1
    else
        local root_part
        root_part="$(get_partition_path "${target_disk}" 1)"

        render_spinner "Formatando partição Raiz (EXT4) em ${root_part}" \
            mkfs.ext4 -F -L "AetherRoot" "${root_part}" >> "${AETHER_LOG_FILE}" 2>&1
    fi

    render_success "Formatação dos sistemas de arquivos finalizada."
}

# Monta as partições no diretório de destino (/mnt)
mount_target_partitions() {
    local target_disk="$1"
    local mount_point="${2:-/mnt}"

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

    render_success "Partições montadas e prontas para instalação base."
}
