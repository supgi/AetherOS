# ==============================================================================
# Aether OS - Auto-Login e Boas-Vindas da Mídia Live (Bash)
# ==============================================================================

if [[ -f "/root/.zlogin" ]]; then
    # shellcheck disable=SC1091
    source "/root/.zlogin"
fi
