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
   - A compilação de pacotes do AUR (`makepkg`/`yay`) e a implantação de links simbólicos de dotfiles (`stow`) são executadas estritamente sob a identidade do usuário não-root.
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
│   ├── custom-packages.conf          # Lista unificada com seções [common], [hyprland], [plasma]
│   ├── custom-packages-hyprland.conf # Pacotes adicionais exclusivos para Hyprland
│   ├── custom-packages-plasma.conf   # Pacotes adicionais exclusivos para KDE Plasma
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

O **Aether OS** possui suporte a instalação **100% autônoma** que substitui o `archinstall` e instala todo o sistema operacional bare-metal com facilidade.

### Opção 1 (Recomendada): Usando a Imagem .ISO Oficial do Aether OS
A mídia Live oficial já contém todo o instalador embutido em `/opt/aether-os`, eliminando a necessidade de digitar comandos longos com `curl`.

1. **Grave a ISO do Aether OS** no pendrive (com Ventoy, BalenaEtcher ou `dd`).
2. **Inicie o computador pelo pendrive** (modo UEFI ou BIOS).
3. O instalador **iniciará automaticamente** na tela de boas-vindas. Caso prefira iniciar manualmente a qualquer momento, basta digitar:
   ```bash
   aether-install
   ```

---

### Opção 2: Usando a ISO Padrão do Arch Linux (Bootstrap via Web)
Se estiver utilizando a ISO genérica original do Arch Linux:

1. Inicie o computador pela mídia oficial do Arch Linux e conecte-se à internet.
2. Execute o instalador com um único comando:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/supgi/AetherOS/main/bootstrap.sh | bash
   ```
   *(Ou via process substitution)*:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/supgi/AetherOS/main/bootstrap.sh)
   ```

---

### 💿 Como Compilar a sua Própria Imagem .ISO (Archiso)

Você pode compilar a imagem ISO oficial do Aether OS diretamente no seu computador em um único comando:

```bash
# Constrói a ISO gerando os arquivos prontos em ./out/
sudo ./scripts/build_iso.sh --clean
```

O script cuidará de verificar o pacote `archiso`, sincronizar os arquivos atualizados do instalador para o sistema de arquivos da mídia (`airootfs`) e gerar os arquivos `.iso` e `.iso.sha256` na pasta `out/`.

> **Dica CI/CD:** O repositório também conta com o workflow automatizado do **GitHub Actions** (`.github/workflows/build-iso.yml`), compilando a ISO diretamente na nuvem a cada Release/Tag.

---

### 🧭 O que o Assistente Visual Configura:
O assistente visual **Charm Gum** guiará você passo a passo:
- **Seleção de Discos:** Escolha da unidade principal e, em múltiplos discos (SSD/HD), opção de usar um **disco dedicado exclusivamente para `/home`**.
- **Hardware & GPU:** Detecção automática de processador (microcódigo Intel/AMD) e aceleração 3D (Intel, AMD, NVIDIA com Early KMS).
- **Layout de Teclado, Kernel, Fuso Horário e Swap:** Personalização completa (`br-abnt2`, `linux-zen` recomendado, ZRAM, etc.).
- **Contas e Rede:** Hostname, usuário e senha, preservando automaticamente o Wi-Fi configurado na Live ISO.
- **Perfil de Interface:** Escolha entre **Aether-Plasma** (KDE Plasma 6 robusto) ou **Aether-Hyprland** (Wayland dinâmico por teclado).

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

## 📦 Lista de Aplicativos Customizados (`configs/custom-packages.conf`)

Você pode escolher exatamente quais navegadores, ferramentas, editores e plugins deseja ter no sistema logo após a instalação, configurando pacotes **compartilhados** ou **exclusivos para cada perfil**:

### Método 1: Seções no arquivo unificado `configs/custom-packages.conf`

```ini
# Pacotes instalados em AMBOS os perfis (Plasma e Hyprland)
[common]
vivaldi
visual-studio-code-bin
discord
obs-studio

# Pacotes instalados EXCLUSIVAMENTE quando escolher o perfil Aether-Hyprland
[hyprland]
# wlogout
# nwg-look
# grimblast-git

# Pacotes instalados EXCLUSIVAMENTE quando escolher o perfil Aether-Plasma
[plasma]
# kdeconnect
# kcalc
# partitionmanager
```

### Método 2: Arquivos dedicados por versão
Se preferir separar por arquivos, o instalador também carrega automaticamente:
* `configs/custom-packages-hyprland.conf`: Programas exclusivos para a versão Hyprland.
* `configs/custom-packages-plasma.conf`: Programas exclusivos para a versão KDE Plasma.

* **Suporte Nativo a AUR e Repositórios Oficiais**: O instalador verifica se o pacote está nos repositórios oficiais do Arch (`pacman`) ou no AUR, compilando e instalando automaticamente com o `yay` (ou `paru`).
* **Instalação Imediata**: Os programas listados são baixados e configurados automaticamente na fase final da instalação do sistema operacional.
* **Sincronização Pós-Instalação**: A qualquer momento, após adicionar novos programas aos arquivos, você pode rodar `aether apps` para sincronizá-los e instalá-los de uma vez.

---

## 🎛 Perfis Disponíveis

* **Aether-Hyprland:** Foco total em produtividade por teclado em ambiente Wayland dinâmico (*tiling*), equipado com `hyprland`, `waybar`, `rofi`, `swaync` e integrações completas de captura de tela e áudio Pipewire.
* **Aether-Plasma:** Experiência desktop completa baseada em KDE Plasma com sessão Wayland, pré-configurada no esquema escuro minimalista Breeze Dark e terminal Kitty integrado.

---

## 🛠 Utilitário de Gerenciamento (`aether-cli`)

Após a instalação, o utilitário `aether-cli` estará disponível no seu terminal através do comando `aether`:

```bash
# Atualização completa de repositórios oficiais e AUR + limpeza de cache:
aether update

# Instalar ou sincronizar os aplicativos definidos em custom-packages.conf:
aether apps

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
