#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Definição do Perfil de Construção Archiso
# Configura metadados da imagem ISO, bootmodes e permissões do airootfs.
# ==============================================================================
# shellcheck disable=SC2034

iso_name="aetheros"
iso_label="AETHER_$(date +%Y%m)"
iso_publisher="Aether OS <https://github.com/supgi/AetherOS>"
iso_application="Aether OS Live/Installation Media"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux'
    'uefi.systemd-boot'
)
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd')

# Mapeamento de permissões de arquivos no airootfs (UID:GID:MODO)
file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/root"]="0:0:750"
    ["/usr/local/bin/aether-install"]="0:0:755"
    ["/opt/aether-os/install.sh"]="0:0:755"
    ["/opt/aether-os/bootstrap.sh"]="0:0:755"
    ["/opt/aether-os/test_ui.sh"]="0:0:755"
    ["/opt/aether-os/bin/aether-cli"]="0:0:755"
)
