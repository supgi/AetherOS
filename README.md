# Aether OS 🌌

Framework modular de pós-instalação e assistente de configuração voltado ao **Arch Linux**, projetado para oferecer uma experiência *terminal-first*, minimalista e 100% orientada a **Wayland**.

Construído com automação em Bash, interface TUI moderna alimentada pelo [Charm Gum](https://github.com/charmbracelet/gum) e gerenciamento declarativo de dotfiles via **GNU Stow**.

---

## 📑 Sumário

- [Visão Geral e Arquitetura](#-visão-geral-e-arquitetura)
- [Estrutura do Repositório](#-estrutura-do-repositório)
- [Pré-requisitos](#-pré-requisitos)
- [Como Executar a Instalação](#-como-executar-a-instalação)
- [Perfis Disponíveis](#-perfis-disponíveis)
- [Utilitário de Gerenciamento (`aether-cli`)](#-utilitário-de-gerenciamento-aether-cli)
- [Design System (`INFO.md`)](#-design-system-infomd)
- [Testes Automatizados](#-testes-automatizados)
- [Boas Práticas e Segurança](#-boas-práticas-e-segurança)

---

## 🏛 Visão Geral e Arquitetura

O Aether OS foi concebido sob princípios rigorosos de modularidade e separação de privilégios:

1. **Separação de Privilégios (Root vs. Não-Root):**
   - Tarefas administrativas de sistema (`pacman`, `systemctl`, criação de contas) executam com privilégios `sudo`/`root`.
   - A compilação de pacotes do AUR (`makepkg`/`paru`) e a implantação de links simbólicos de dotfiles (`stow`) são executadas estritamente sob a identidade do usuário não-root.
2. **Interface TUI Terminal-First:**
   - Formulários, seletores e barras de progresso desenhados com o `gum`, exibindo paleta fria e escura (Ice Blue, Cyan, Grafite).
3. **Gerenciamento Declarativo:**
   - Dotfiles organizados de forma independente por aplicação dentro do diretório `configs/`, facilitando adição ou remoção via GNU Stow sem conflitos.

---

## 📂 Estrutura do Repositório

```text
AetherOS/
├── .gitignore               # Exclusões de logs, temporários e credenciais
├── INFO.md                  # Guia de estilos, paleta de cores e componentes TUI Gum
├── README.md                # Documentação técnica e guia de execução
├── install.sh               # Script orquestrador mestre de instalação
├── bin/
│   └── aether-cli           # Utilitário de linha de comando para pós-instalação
├── installer/
│   ├── env.sh               # Variáveis de ambiente, caminhos e detecção de contexto
│   ├── packages.sh          # Otimização do Pacman, Paru e listas de pacotes
│   ├── services.sh          # Gerenciamento e ativação de daemons systemd
│   ├── stow.sh              # Orquestrador de links simbólicos via GNU Stow
│   ├── ui.sh                # Componentes TUI do Gum com fallback resiliente
│   └── user.sh              # Pré-checagens de conectividade, CPU e criação de usuário
├── configs/
│   ├── hyprland/            # Configurações do compositor Wayland Hyprland
│   │   └── .config/hypr/hyprland.conf
│   ├── plasma/              # Configurações do tema escuro/minimalista KDE Plasma
│   │   └── .config/kdeglobals
│   ├── kitty/               # Emulador de terminal minimalista acelerado por GPU
│   │   └── .config/kitty/kitty.conf
│   ├── starship/            # Prompt rápido e responsivo
│   │   └── .config/starship.toml
│   ├── nvim/                # Editor Neovim minimalista terminal-first
│   │   └── .config/nvim/init.lua
│   └── zsh/                 # Configuração de shell Zsh
│       └── .zshrc
└── tests/
    ├── run_tests.sh         # Executor principal da suite de testes
    ├── test_modules.sh      # Testes de importação e funções utilitárias
    └── test_syntax.sh       # Verificação de sintaxe de todos os scripts bash
```

---

## ⚡ Pré-requisitos

- Instalação limpa do **Arch Linux** (arquitetura `x86_64`).
- Conexão ativa com a internet.
- Git instalado para clonagem do repositório:
  ```bash
  sudo pacman -S --needed git
  ```

---

## 🚀 Como Instalar o Aether OS (Instalador Autônomo Bare-Metal)

O **Aether OS** possui um fluxo de instalação **100% autônomo** que substitui o `archinstall` e instala todo o sistema operacional do zero em sua máquina com apenas **um comando**.

### Passo a Passo:

1. **Baixe e grave a ISO oficial do Arch Linux** em um pendrive (utilizando Rufus, BalenaEtcher ou `dd`).
2. **Inicie o computador pelo pendrive** (modo UEFI ou BIOS).
3. Ao ver o terminal da mídia de instalação (`root@archiso ~ #`), verifique se está conectado à internet (via cabo de rede ou `iwctl` para Wi-Fi).
4. **Execute o instalador centralizado do Aether OS com um único comando:**

```bash
curl -fsSL https://raw.githubusercontent.com/supgi/AetherOS/main/bootstrap.sh | bash
```

*(Ou usando bash process substitution):*
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/supgi/AetherOS/main/bootstrap.sh)
```

5. O assistente visual **Charm Gum** iniciará na tela e guiará você por:
   - **Seleção de Disco:** O instalador detecta suas unidades (`/dev/nvme...`, `/dev/sda...`) e permite escolher a unidade alvo.
   - **Confirmação de Segurança:** Aviso duplo para evitar perda acidental de dados.
   - **Contas e Rede:** Definição do Hostname, Usuário principal e Senha.
   - **Perfil de Interface:** Escolha entre **Aether-Hyprland** (Wayland dinâmico por teclado) ou **Aether-Plasma** (KDE Plasma escuro/minimal).

O instalador fará todo o restante de forma 100% automatizada:
- Particionamento inteligente (GPT + ESP para UEFI ou MBR para BIOS).
- Formatação dos sistemas de arquivos (`mkfs.fat` + `mkfs.ext4`).
- Instalação do sistema base (`pacstrap`, kernel Linux, firmware e utilitários de rede).
- Geração automática do `/etc/fstab`.
- Configuração de localização (`pt_BR.UTF-8`, teclado `br-abnt2`, fuso `America/Sao_Paulo`).
- Instalação e configuração do bootloader **GRUB** com entrada do Aether OS.
- Provisionamento de usuário, `sudo` e compilação do AUR Helper (`paru`).
- Implantação declarativa de dotfiles via **GNU Stow**.
- Ativação dos daemons essenciais (`NetworkManager`, `bluetooth`, `sddm`, `firewalld`).

Ao final, basta confirmar o reinício, retirar o pendrive e desfrutar do seu novo sistema!

---

### 🎨 Modo de Teste da Interface (Dry-Run / Simulação)

Você pode testar e aprimorar toda a interface visual do instalador sem precisar formatar discos ou instalar pacotes de verdade. O modo de teste simula todo o fluxo (discos fictícios, seleção de teclado, kernel, fuso, swap, usuários e spinners animados) com 100% de segurança:

```bash
# Executa o simulador direto:
./test_ui.sh

# Ou via flag do instalador:
./install.sh --dry-run
```

---

---

## 🎛 Perfis Disponíveis

* **Aether-Hyprland:** Foco total em produtividade por teclado em ambiente Wayland dinâmico (*tiling*), equipado com `hyprland`, `waybar`, `rofi-wayland`, `swaync` e integrações completas de captura de tela e áudio Pipewire.
* **Aether-Plasma:** Experiência desktop completa baseada em KDE Plasma com sessão Wayland, pré-configurada no esquema escuro minimalista Breeze Dark e terminal Kitty integrado.

---

## 🛠 Utilitário de Gerenciamento (`aether-cli`)

Após a instalação, o utilitário `aether-cli` estará disponível no seu terminal através do comando `aether`:

```bash
# Atualização completa de repositórios oficiais e AUR + limpeza de cache:
aether update

# Alternar ou reaplicar perfis de dotfiles (Hyprland / Plasma / Comum):
aether profile

# Consultar o status da sessão e configurações atuais:
aether status

# Consultar ajuda e comandos disponíveis:
aether help
```

---

## 🎨 Design System (`INFO.md`)

Consulte o arquivo [`INFO.md`](INFO.md) para detalhes sobre as diretrizes visuais, paleta de cores (Cyan, Slate, Grafite, Ice Blue) e padrões de uso dos comandos `gum style`, `gum choose`, `gum confirm`, `gum input` e `gum spin`.

---

## 🧪 Testes Automatizados

O projeto inclui uma suite de testes para garantir o Critério de Conclusão (DoD) e confiabilidade da automação:

```bash
# Executa todos os testes automatizados:
./tests/run_tests.sh
```

Os testes cobrem:
- Validação estrita de sintaxe (`bash -n`) em todos os scripts.
- Teste de importação de módulos e integridade de variáveis.
- Verificação da consistência dos dotfiles para o GNU Stow.

---

## 🔒 Boas Práticas e Segurança

- **Variáveis de Ambiente**: Arquivos `.env` são ignorados no `.gitignore` para prevenir vazamento de credenciais.
- **Log Centralizado**: Falhas e comandos com erro registram mensagens técnicas em inglês no arquivo `aether-install.log`, enquanto o usuário recebe alertas amigáveis e claros em português no terminal.
