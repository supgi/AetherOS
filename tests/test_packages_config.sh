#!/usr/bin/env bash
# ==============================================================================
# Aether OS - Teste Automatizado do Parser de Pacotes Customizados
# Valida a leitura de configs/custom-packages.conf, tratamento de comentários e espaços.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=installer/env.sh
source "${ROOT_DIR}/installer/env.sh"
# shellcheck source=installer/ui.sh
source "${ROOT_DIR}/installer/ui.sh"
# shellcheck source=installer/packages.sh
source "${ROOT_DIR}/installer/packages.sh"

echo "➜ [TEST] Testando parser de pacotes customizados (custom-packages.conf)..."

# 1. Testa a leitura do arquivo real padrão do projeto
real_config="${AETHER_CONFIGS_DIR}/custom-packages.conf"
if [[ ! -f "${real_config}" ]]; then
    echo "✖ [FAIL] Arquivo ${real_config} não encontrado."
    exit 1
fi

pkgs=($(load_custom_package_list "${real_config}"))
if [[ ${#pkgs[@]} -gt 0 && -n "${pkgs[0]}" ]]; then
    echo "✔ [PASS] Leitura do arquivo real bem-sucedida (Detectado: ${pkgs[*]}): OK"
else
    echo "✖ [FAIL] Falha ao carregar pacotes do arquivo padrão: ${pkgs[*]}"
    exit 1
fi

# 2. Testa comportamento com arquivo temporário com formatos variados
temp_conf="$(mktemp)"
trap 'rm -f "${temp_conf}"' EXIT

cat << 'EOF' > "${temp_conf}"
# Comentário no início
firefox # Comentário inline
   visual-studio-code-bin   

# Linha vazia acima e abaixo

discord spotify
# mpv comentado
   # linha apenas com comentário indentado
btop
EOF

parsed_pkgs=($(load_custom_package_list "${temp_conf}"))
expected_count=5 # firefox, visual-studio-code-bin, discord, spotify, btop

if [[ ${#parsed_pkgs[@]} -eq "${expected_count}" ]]; then
    echo "✔ [PASS] Contagem de pacotes tratados (${#parsed_pkgs[@]}/${expected_count}): OK"
else
    echo "✖ [FAIL] Contagem incorreta de pacotes: esperado ${expected_count}, obtido ${#parsed_pkgs[@]} (${parsed_pkgs[*]})"
    exit 1
fi

# Verifica se os pacotes esperados estão na lista
expected_list=("firefox" "visual-studio-code-bin" "discord" "spotify" "btop")
for expected in "${expected_list[@]}"; do
    found=false
    for p in "${parsed_pkgs[@]}"; do
        if [[ "${p}" == "${expected}" ]]; then
            found=true
            break
        fi
    done
    if [[ "${found}" == "true" ]]; then
        echo "✔ [PASS] Pacote parseado corretamente: ${expected}"
    else
        echo "✖ [FAIL] Pacote esperado não encontrado: ${expected}"
        exit 1
    fi
done

# 3. Testa filtragem por seção ([common], [hyprland], [plasma])
sections_conf="$(mktemp)"
cat << 'EOF' > "${sections_conf}"
[common]
vivaldi
discord

[hyprland]
nwg-look
wlogout

[plasma]
kdeconnect
kcalc
EOF

# Testa Hyprland: deve conter vivaldi, discord, nwg-look, wlogout (NÃO kdeconnect, kcalc)
hypr_pkgs=($(load_custom_package_list "${sections_conf}" "Aether-Hyprland"))
if [[ " ${hypr_pkgs[*]} " =~ " vivaldi " && " ${hypr_pkgs[*]} " =~ " nwg-look " && ! " ${hypr_pkgs[*]} " =~ " kdeconnect " ]]; then
    echo "✔ [PASS] Filtragem de seção Hyprland exclusiva: OK"
else
    echo "✖ [FAIL] Falha na filtragem Hyprland: ${hypr_pkgs[*]}"
    exit 1
fi

# Testa Plasma: deve conter vivaldi, discord, kdeconnect, kcalc (NÃO nwg-look, wlogout)
plasma_pkgs=($(load_custom_package_list "${sections_conf}" "Aether-Plasma"))
if [[ " ${plasma_pkgs[*]} " =~ " vivaldi " && " ${plasma_pkgs[*]} " =~ " kdeconnect " && ! " ${plasma_pkgs[*]} " =~ " nwg-look " ]]; then
    echo "✔ [PASS] Filtragem de seção Plasma exclusiva: OK"
else
    echo "✖ [FAIL] Falha na filtragem Plasma: ${plasma_pkgs[*]}"
    exit 1
fi

# Testa 'all': deve conter todos os pacotes das seções
all_pkgs=($(load_custom_package_list "${sections_conf}" "all"))
if [[ ${#all_pkgs[@]} -eq 6 ]]; then
    echo "✔ [PASS] Escopo global 'all' reuniu todos os pacotes das seções (6/6): OK"
else
    echo "✖ [FAIL] Falha no escopo 'all': ${all_pkgs[*]}"
    exit 1
fi
rm -f "${sections_conf}"

# 4. Testa comportamento com arquivo inexistente (deve retornar vazio sem erro)
non_existent="/tmp/non_existent_custom_packages_test.conf"
empty_res="$(load_custom_package_list "${non_existent}")"
if [[ -z "${empty_res}" ]]; then
    echo "✔ [PASS] Tratamento gracioso de arquivo inexistente: OK"
else
    echo "✖ [FAIL] Deveria retornar vazio para arquivo inexistente."
    exit 1
fi

echo "✔ [SUCCESS] Todos os testes do parser de pacotes foram aprovados!"
