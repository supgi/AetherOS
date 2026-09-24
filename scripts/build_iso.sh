#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Script Automatizado de Construção de Imagem .ISO (Archiso)
# Compila uma imagem Live oficial com o instalador embutido out-of-the-box.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARCHISO_PROFILE_DIR="${ROOT_DIR}/archiso"
OUTPUT_DIR="${ROOT_DIR}/out"
WORK_DIR="/tmp/aetheros-archiso-work"
AIROOTFS_AETHER_DIR="${ARCHISO_PROFILE_DIR}/airootfs/opt/aether-os"

# Cores ANSI
C_BLUE="\033[38;5;39m"
C_CYAN="\033[38;5;31m"
C_GREEN="\033[38;5;82m"
C_YELLOW="\033[38;5;214m"
C_RED="\033[38;5;196m"
C_RESET="\033[0m"

show_help() {
    echo -e "${C_BLUE}============================================================${C_RESET}"
    echo -e "${C_CYAN}         AETHER OS - GERADOR DE IMAGEM .ISO${C_RESET}"
    echo -e "${C_BLUE}============================================================${C_RESET}"
    echo -e "Uso: sudo $0 [OPÇÕES]\n"
    echo -e "Opções:"
    echo -e "  -c, --clean     Limpa o diretório de trabalho temporário antes de compilar"
    echo -e "  -h, --help      Exibe esta mensagem de ajuda"
    echo ""
    exit 0
}

CLEAN_BUILD=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${C_RED}[ERRO] Opção desconhecida: $1${C_RESET}"
            show_help
            ;;
    esac
done

echo -e "${C_BLUE}============================================================${C_RESET}"
echo -e "${C_CYAN}         AETHER OS - CONSTRUÇÃO DA MÍDIA LIVE .ISO${C_RESET}"
echo -e "${C_BLUE}============================================================${C_RESET}"

# 1. Validação de privilégios de superusuário
if [[ $EUID -ne 0 ]]; then
    echo -e "${C_RED}[ERRO] Este script requer privilégios de root para executar o mkarchiso.${C_RESET}" >&2
    echo -e "Por favor, execute novamente com: ${C_YELLOW}sudo $0${C_RESET}" >&2
    exit 1
fi

# 2. Verificação de dependência do mkarchiso
if ! command -v mkarchiso >/dev/null 2>&1; then
    echo -e "${C_YELLOW}[AVISO] O pacote 'archiso' não está instalado no sistema.${C_RESET}"
    read -r -p "Deseja instalar o archiso agora via pacman? [S/n]: " install_archiso
    install_archiso="${install_archiso:-s}"
    if [[ "${install_archiso}" =~ ^[sSyY]$ ]]; then
        pacman -S --needed --noconfirm archiso
    else
        echo -e "${C_RED}[ABORTADO] Instalação do archiso cancelada. Não é possível continuar.${C_RESET}" >&2
        exit 1
    fi
fi

# 3. Limpeza opcional do diretório de trabalho
if [[ "${CLEAN_BUILD}" == "true" ]]; then
    echo -e "${C_BLUE}➜ Limpando diretório de trabalho anterior (${WORK_DIR})...${C_RESET}"
    rm -rf "${WORK_DIR}"
fi

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${WORK_DIR}"

# 4. Sincronização do instalador para o airootfs (/opt/aether-os)
echo -e "${C_BLUE}➜ Sincronizando arquivos do Aether OS para o perfil da ISO...${C_RESET}"
mkdir -p "${AIROOTFS_AETHER_DIR}"

# Copia arquivos excluindo artefatos temporários, git e saídas
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
        --exclude='.git' \
        --exclude='out' \
        --exclude='*.iso' \
        --exclude='*.sha256' \
        --exclude='aether-install.log' \
        --exclude='.qodo' \
        "${ROOT_DIR}/" "${AIROOTFS_AETHER_DIR}/"
else
    # Fallback via cp caso rsync não esteja presente
    rm -rf "${AIROOTFS_AETHER_DIR:?}"/*
    find "${ROOT_DIR}" -mindepth 1 -maxdepth 1 \
        ! -name '.git' \
        ! -name 'out' \
        ! -name 'archiso' \
        ! -name '*.iso' \
        ! -name '*.sha256' \
        ! -name 'aether-install.log' \
        ! -name '.qodo' \
        -exec cp -a {} "${AIROOTFS_AETHER_DIR}/" \;
fi

# Garante permissões de execução dos scripts essenciais no airootfs
chmod +x "${AIROOTFS_AETHER_DIR}"/install.sh 2>/dev/null || true
chmod +x "${AIROOTFS_AETHER_DIR}"/bootstrap.sh 2>/dev/null || true
chmod +x "${AIROOTFS_AETHER_DIR}"/test_ui.sh 2>/dev/null || true
chmod +x "${AIROOTFS_AETHER_DIR}"/bin/aether-cli 2>/dev/null || true
chmod +x "${AIROOTFS_AETHER_DIR}"/tests/*.sh 2>/dev/null || true
chmod +x "${ARCHISO_PROFILE_DIR}/airootfs/usr/local/bin/aether-install" 2>/dev/null || true

echo -e "${C_GREEN}✔ Repositório Aether OS incorporado com sucesso em /opt/aether-os.${C_RESET}"

# 5. Execução do mkarchiso
echo -e "${C_BLUE}➜ Iniciando compilação do mkarchiso (isso pode levar alguns minutos)...${C_RESET}"
mkarchiso -v -w "${WORK_DIR}" -o "${OUTPUT_DIR}" "${ARCHISO_PROFILE_DIR}"

# 6. Geração de checksums para verificação de integridade
echo -e "${C_BLUE}➜ Gerando hashes de integridade SHA256...${C_RESET}"
(
    cd "${OUTPUT_DIR}"
    for iso in *.iso; do
        if [[ -f "${iso}" ]]; then
            sha256sum "${iso}" > "${iso}.sha256"
        fi
    done
)

echo -e "${C_GREEN}============================================================${C_RESET}"
echo -e "${C_GREEN}✔ [SUCESSO] Imagem .ISO do Aether OS gerada com sucesso!${C_RESET}"
echo -e "${C_GREEN}============================================================${C_RESET}"
echo -e "Arquivos disponíveis em: ${C_CYAN}${OUTPUT_DIR}${C_RESET}"
ls -lh "${OUTPUT_DIR}"/*.iso
