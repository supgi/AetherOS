# ==============================================================================
# Aether OS - Auto-Login e Boas-Vindas da Mídia Live
# ==============================================================================

# Se a sessão não for interativa, não executa o prompt
[[ -o interactive ]] || [ -n "${BASH_VERSION:-}" ] || return 0 2>/dev/null || true

clear

# Banner Visual Oficial Aether OS (Paleta Ice Blue e Deep Cyan conforme INFO.md)
echo -e "\033[38;5;39m"
cat << 'EOF'
     /\        _   _               ____   _____ 
    /  \   ___| |_| |__   ___ _ __/ __ \ / ____|
   / /\ \ / _ \ __| '_ \ / _ \ '__| |  | | (___  
  / ____ \  __/ |_| | | |  __/ |  | |__| |\___ \ 
 /_/    \_\___|\__|_| |_|\___|_|   \____(_)_____/ 
EOF
echo -e "\033[38;5;75m  Framework e Distribuição Arch Linux Terminal-First\033[0m"
echo -e "\033[38;5;244m  Mídia Live de Instalação Oficial • Base Bare-Metal\033[0m\n"

echo -e "\033[1;37mComandos úteis da sessão Live:\033[0m"
echo -e "  • \033[38;5;39maether-install\033[0m : Inicia o instalador gráfico e modular"
echo -e "  • \033[38;5;39mnmtui\033[0m          : Gerenciador interativo de Wi-Fi e rede"
echo -e "  • \033[38;5;39mpacman -Sy\033[0m     : Sincroniza a base de pacotes se necessário\n"

# Prompt de Inicialização Rápida
read -r -p "$(echo -e "\033[38;5;39m➜ Deseja iniciar a instalação do Aether OS agora? [S/n]: \033[0m")" user_choice
user_choice="${user_choice:-s}"

if [[ "${user_choice}" =~ ^[sSyY]$ ]]; then
    echo -e "\n\033[32mIniciando o instalador...\033[0m\n"
    /usr/local/bin/aether-install
fi
