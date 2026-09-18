# ==============================================================================
# Aether OS - Zsh Configuration
# ==============================================================================

# Histórico de comandos
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Inicialização do Prompt Starship
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# Aliases padrão do Aether OS
alias aether="aether-cli"
alias v="nvim"
alias vim="nvim"

# Substitutos modernos quando disponíveis
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -la --icons --group-directories-first"
    alias tree="eza --tree --icons"
fi

if command -v bat >/dev/null 2>&1; then
    alias cat="bat --paging=never"
fi

# Variáveis de ambiente úteis
export EDITOR="nvim"
export VISUAL="nvim"
export PATH="${HOME}/.local/bin:${PATH}"
