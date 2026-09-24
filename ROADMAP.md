# 🗺️ Roadmap Técnico & Plano Estratégico - Aether OS

Este documento apresenta uma análise abrangente da arquitetura do **Aether OS**, mapeando as redundâncias técnicas a serem eliminadas, correções preventivas de estabilidade, blindagem contra falhas conhecidas dos ecossistemas **KDE Plasma 6** e **Hyprland**, melhorias de experiência de usuário e as fases de evolução recomendadas para consolidar o sistema como uma distribuição/framework Arch Linux de referência.

---

## 📊 1. Diagnóstico do Estado Atual

O projeto evoluiu significativamente, tornando-se um instalador autônomo, modular e terminal-first:

| Componente | Estado Atual | Avaliação |
| :--- | :--- | :--- |
| **Instalação Bare-Metal** | Substituição total do `archinstall` (Particionamento UEFI/BIOS, Pacstrap, Fstab, Swap/ZRAM, GRUB) | ✅ Estável e funcional |
| **Interface TUI** | Desenvolvida com Charm Gum seguindo as diretrizes de cores e estilos do `INFO.md` | ✅ Moderna e responsiva |
| **Simulador de Teste** | `test_ui.sh` e flag `--dry-run` para iteração visual sem risco de perda de dados | ✅ Excelente para desenvolvimento |
| **Gestão de Discos** | Suporte a particionamento automático e partição `/home` separada em múltiplos discos | ✅ Validado |
| **Pacotes Customizados** | `custom-packages.conf` com seções `[common]`, `[hyprland]`, `[plasma]` e arquivos dedicados | ✅ Flexível e declarativo |
| **AUR Helper** | Yay configurado como padrão (`yay-bin`) com fallback automático para Paru | ✅ Rápido e não-interativo |
| **Gerenciamento Dotfiles** | GNU Stow modular por aplicação (`kitty`, `nvim`, `zsh`, `starship`, `hyprland`, `plasma`) | ✅ Desacoplado |
| **Testes Automatizados** | Suite em `tests/` com validação de sintaxe, imports e integridade de módulos (DoD) | ✅ 100% de aprovação |

---

## ♻️ 2. Redundâncias Identificadas e Oportunidades de Refatoração

### 2.1 Duplicação de Opções de Menus (`install.sh` vs `test_ui.sh`)
* **Problema:** As opções interativas de teclado (`br-abnt2`, `us`), kernels (`linux-zen`, `linux`), fusos horários, swap e perfis gráficos estão declaradas separadamente em `install.sh` e em `test_ui.sh`. Qualquer alteração de texto ou nova opção adicionada em um precisa ser sincronizada manualmente no outro.
* **Solução Recomendada:** Criar um módulo centralizador (ex.: `installer/options.sh` ou expandir `installer/env.sh`) que declare os arrays de opções reutilizáveis. Dessa forma, tanto o instalador de produção quanto o simulador leem estritamente a mesma fonte da verdade.

### 2.2 Duplicação de Lógica de Provisionamento de Usuário (`user.sh` vs `chroot_exec.sh`)
* **Problema:** A criação de usuários não-root existe em duas implementações: `setup_target_user` em `installer/user.sh` (para sistemas já instalados) e `provision_user_in_chroot` em `installer/chroot_exec.sh` (para a instalação bare-metal). Ambas possuem passos redundantes de definição de shell Zsh, `chpasswd` e configuração do `/etc/sudoers.d/10-wheel-sudo`.
* **Solução Recomendada:** Unificar a lógica de criação de contas em uma função utilitária com parâmetro de raiz de montagem opcional (ex.: `create_user_account [mount_point] [user] [pass]`).

### 2.3 Sobreposição entre `pacstrap` e `CORE_PACKAGES`
* **Problema:** O `pacstrap` em `installer/bootstrap_system.sh` instala pacotes como `git`, `zsh` e `sudo`, enquanto `CORE_PACKAGES` em `installer/packages.sh` reinstala esses mesmos itens no primeiro boot/chroot.
* **Solução Recomendada:** Manter no `pacstrap` estritamente o necessário para inicializar o sistema mínimo e rede; deixar as ferramentas de produtividade e terminal para o estágio de pacotes de desktop.

---

## 🛡️ 3. Correções e Estabilidade de Hardware (Prioridade Alta)

### 3.1 Detecção e Instalação Automática de Microcode (Intel / AMD)
* **Impacto:** Crítico para estabilidade da CPU, mitigação de falhas de segurança de hardware e inicialização confiável com o GRUB.
* **Ação:** Identificar o processador antes da etapa do `pacstrap` e instalar o pacote correspondente:
  ```bash
  if grep -q "AuthenticAMD" /proc/cpuinfo; then
      base_packages+=(amd-ucode)
  elif grep -q "GenuineIntel" /proc/cpuinfo; then
      base_packages+=(intel-ucode)
  fi
  ```

### 3.2 Detecção Automática de Placa Gráfica e Drivers de Vídeo (GPU)
* **Impacto:** Wayland (Hyprland e Plasma Wayland) exige aceleração de hardware 3D (OpenGL/Vulkan) para renderizar a interface sem travamentos.
* **Ação:** Inspecionar `lspci` ou `glxinfo` e instalar os pacotes adequados:
  * **Intel Graphics:** `mesa`, `vulkan-intel`, `intel-media-driver`
  * **AMD Radeon:** `mesa`, `vulkan-radeon`, `libva-mesa-driver`
  * **NVIDIA:** `nvidia-dkms`, `nvidia-utils`, `lib32-nvidia-utils` e adição automática do parâmetro `nvidia_drm.modeset=1` na linha do kernel no GRUB.
  * **Ambientes Virtuais (QEMU / VirtualBox / VMware):** `qemu-guest-agent`, `spice-vdagent`, `virtualbox-guest-utils`.

### 3.3 Preservação de Conexão Wi-Fi da Live ISO
* **Impacto:** Evita que o usuário precise digitar a senha do Wi-Fi novamente após o primeiro boot.
* **Ação:** Copiar os arquivos de rede salvos em `/etc/NetworkManager/system-connections/` da mídia Live para `/mnt/etc/NetworkManager/system-connections/` antes de desmontar.

---

## 🖥️ 4. Matriz de Resiliência dos Ambientes Gráficos: KDE Plasma 6 & Hyprland

Abaixo está o levantamento minucioso do status atual do Aether OS em relação aos cenários críticos de quebra e instabilidade de ambientes gráficos Wayland, com seus respectivos planos de ação preventivos.

### 4.1 KDE Plasma (Plasma 6 / Qt 6)

| # | Problema Mapeado | Situação no Aether OS | Diagnóstico Técnico & Causa Raiz | Ação Corretiva no Roadmap |
| :--- | :--- | :---: | :--- | :--- |
| **P1** | **Tela preta / Segfault no plasmashell** | ⚠️ *Vulnerável* | A lista atual em `PLASMA_PACKAGES` instala apenas `plasma-desktop`, omitindo o metapacote `plasma-workspace` e componentes base do KF6. | Substituir `plasma-desktop` pelo conjunto `plasma-workspace` ou metapacote `plasma` completo no `installer/packages.sh`. |
| **P2** | **Loop de login no SDDM** | ⚠️ *Vulnerável* | O SDDM tenta iniciar a sessão Wayland (`plasma.desktop`), mas os pacotes `qt6-wayland` e `kwayland` não constam na lista de instalação. | Adicionar obrigatoriamente `qt6-wayland`, `qt5-wayland` e `kwayland` aos pacotes base do sistema. |
| **P3** | **SDDM em tela preta ou travando no boot** | ⚠️ *Vulnerável* | O `sddm.service` sobe antes da inicialização dos módulos DRM do kernel (ausência de Early KMS no `mkinitcpio.conf`). | Configurar módulos de vídeo no `MODULES=(...)` do `/etc/mkinitcpio.conf` durante a instalação e rodar `mkinitcpio -P`. Garantir `sddm-kcm`. |
| **P4** | **Falta de gerenciamento de rede e som** | ⚠️ *Vulnerável* | `plasma-nm` (applet de rede) e `plasma-pa` (controle de volume PipeWire na bandeja) não estão listados em `PLASMA_PACKAGES`. | Incluir explicitamente `plasma-nm` e `plasma-pa` no perfil Plasma. |
| **P5** | **Sem aplicativos essenciais de fábrica** | 🟡 *Parcial* | `dolphin` está presente em `PLASMA_PACKAGES`, porém `konsole` estava apenas no `custom-packages.conf` (opcional). | Incluir `konsole` como dependência padrão em `PLASMA_PACKAGES` para garantir terminal nativo do KDE integrado. |
| **P6** | **KWallet solicitando senha a cada boot** | ❌ *Não preparado* | O pacote `kwallet-pam` não está instalado e `/etc/pam.d/sddm` não contém os módulos de desbloqueio automático no login. | Adicionar `kwallet-pam` e configurar `/etc/pam.d/sddm` com `pam_kwallet5.so` / `pam_kwallet6.so` na criação do usuário. |
| **P7** | **Polkit inativo** | 🟡 *Parcial* | O pacote `polkit-kde-agent` foi colocado em `HYPRLAND_PACKAGES`, mas omitido de `PLASMA_PACKAGES` (depende de herança implícita). | Garantir `polkit-kde-agent` como dependência essencial nos dois perfis gráficos. |
| **P8** | **KWin piscando/travando com NVIDIA** | ⚠️ *Mapeado* | Ausência de `nvidia-drm.modeset=1` nos parâmetros de linha de comando do GRUB (`GRUB_CMDLINE_LINUX_DEFAULT`). | Injetar automaticamente `nvidia-drm.modeset=1` no `/etc/default/grub` e regenerar `grub.cfg` ao detectar GPU Nvidia. |
| **P9** | **Desfoque em escalonamento fracionário (Fractional Scaling)** | ❌ *Não preparado* | Janelas XWayland (Steam, Discord, Spotify) ficam borradas ao aplicar escalas 125%/150% sem a configuração de renderização nítida. | Configurar opção do KWin para "Apply scaling themselves" (aplicar escala nativa) e exportar variáveis Wayland para apps Electron. |
| **P10** | **Quebra de extensões legadas (Plasmoids)** | ❌ *Não preparado* | Widgets e temas de terceiros herdados de instalações anteriores ou dotfiles Qt5 causam crash no `plasmashell` do Plasma 6. | Implementar sanitização preventiva em `configs/plasma` garantindo compatibilidade estrita com APIs do Qt6 / KF6. |
| **P11** | **Corrupção de cache/histórico do Klipper** | ❌ *Não preparado* | Corrupção no arquivo de histórico de clipboard (`~/.local/share/klipper/history`) causa loop de crash contínuo no `plasmashell`. | Adicionar rotina de autodiagnóstico no `aether-cli doctor` para limpar/resetar o histórico do Klipper corrompido. |
| **P12** | **Regras de janela inconsistentes no KWin** | ❌ *Não preparado* | Regras genéricas aplicadas a janelas principais propagam erroneamente para caixas de diálogo e pop-ups. | Pré-configurar regras de janela sanitizadas em `configs/plasma/.config/kwinrulesrc` com correspondência estrita por `window-role`. |

---

### 4.2 Hyprland (Wayland Dinâmico)

| # | Problema Mapeado | Situação no Aether OS | Diagnóstico Técnico & Causa Raiz | Ação Corretiva no Roadmap |
| :--- | :--- | :---: | :--- | :--- |
| **H1** | **Tela preta na inicialização (Crash do compositor)** | ⚠️ *Vulnerável* | Hyprland aborta o boot quando os módulos DRM de vídeo não são carregados na inicialização antecipada (Early KMS). | Implementar Early KMS no `/etc/mkinitcpio.conf` e instalar drivers 3D apropriados para a GPU detectada. |
| **H2** | **Cursor invisível (NVIDIA)** | ⚠️ *Vulnerável* | Em hardware Nvidia, o cursor do mouse não renderiza sem `no_hardware_cursors = true` explícito na configuração do Hyprland. | Adicionar `cursor { no_hardware_cursors = true }` e `env = WLR_NO_HARDWARE_CURSORS,1` no `hyprland.conf`. |
| **H3** | **Sintaxe defasada de arquivo de configuração** | 🟡 *Parcial* | Atualizações frequentes do Hyprland invalidam sintaxes antigas (ex: transição de `windowrule` para `windowrulev2`). | Manter o arquivo `configs/hyprland/.config/hypr/hyprland.conf` atualizado com a sintaxe moderna `windowrulev2` e validar na suite de testes. |
| **H4** | **Atraso de 25–30s ao abrir apps (Portal timeout)** | ⚠️ *Vulnerável* | Conflito de múltiplos backends de portal instalados (`xdg-desktop-portal-kde` e `xdg-desktop-portal-hyprland`) travando D-Bus. | Criar `/etc/xdg/xdg-desktop-portal/portals.conf` e `hyprland-portals.conf` definindo explicitamente: `default=hyprland;gtk`. |
| **H5** | **Compartilhamento de tela falhando (OBS/Discord)** | 🟡 *Parcial* | Os pacotes `xdg-desktop-portal-hyprland` e `pipewire` estão listados, mas faltam scripts de inicialização de variáveis D-Bus no boot. | Adicionar rotina no `hyprland.conf` executando `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP`. |
| **H6** | **Ambiente "vazio" no primeiro boot** | ⚠️ *Vulnerável* | `waybar`, `swaync` e `hyprpaper` são chamados via `exec-once`, mas os arquivos de configuração dessas barras e papéis de parede ainda não existem no repositório. | Criar os diretórios e dotfiles oficiais: `configs/waybar/`, `configs/swaync/` e `configs/hyprland/.config/hypr/hyprpaper.conf`. |
| **H7** | **Autenticação gráfica silenciada (Polkit)** | 🟡 *Parcial* | Chamada `exec-once = /usr/lib/polkit-kde-authentication-agent-1` no `hyprland.conf` pode falhar no Plasma 6 devido à mudança de path no Arch. | Criar script wrapper de inicialização do polkit que tenta `/usr/lib/polkit-kde-authentication-agent-1` e `/usr/lib/plasma-polkit-agent`. |
| **H8** | **Teclas de multimídia inoperantes** | ⚠️ *Vulnerável* | `brightnessctl` e `pipewire` estão instalados, porém `hyprland.conf` não possui bindings para as teclas `XF86Audio*` e `XF86MonBrightness*`. | Mapear teclas `XF86AudioRaiseVolume`, `XF86AudioLowerVolume`, `XF86AudioMute`, `XF86MonBrightnessUp` e `Down` no `hyprland.conf`. |
| **H9** | **Distorção e perda de tamanho do cursor** | ⚠️ *Vulnerável* | Ausência de sincronização de cursor entre Wayland e XWayland faz o cursor alterar de tamanho ou tema ao transitar entre janelas. | Exportar `env = XCURSOR_THEME,breeze_cursors`, `env = XCURSOR_SIZE,24` e `exec-once = hyprctl setcursor breeze_cursors 24`. |
| **H10** | **Problemas de suspensão e hibernação (NVIDIA)** | ❌ *Não preparado* | Retorno do estado de sleep causa congelamento ou telas corrompidas se os serviços de gerenciamento de VRAM não estiverem ativos. | Ativar `nvidia-suspend.service`, `nvidia-hibernate.service`, `nvidia-resume.service` e configurar `NVreg_PreserveVideoMemoryAllocations=1`. |
| **H11** | **Perda de variáveis ao usar Display Managers** | 🟡 *Parcial* | O Aether OS utiliza SDDM, mas sessões Wayland podem perder variáveis de ambiente se não propagadas para o systemd/D-Bus. | Incluir exportação explícita de `XDG_SESSION_TYPE=wayland`, `QT_QPA_PLATFORM=wayland` e `GDK_BACKEND=wayland`. |
| **H12** | **Quebra de plugins (Hyprpm)** | ❌ *Não preparado* | Atualizações de versão do Hyprland via pacman tornam plugins do `hyprpm` incompatíveis até serem recompilados. | Criar um Pacman Hook (`/etc/pacman.d/hooks/hyprpm.hook`) ou comando `aether update` que execute `hyprpm update` automaticamente. |
| **H13** | **Erros no bloqueador de tela (hyprlock)** | ❌ *Não preparado* | Falhas de autenticação PAM ou travamento com drivers proprietários ao desbloquear a tela. | Provisionar `/etc/pam.d/hyprlock` padrão funcional apontando para `system-auth` e validar compatibilidade com backend DRM. |
| **H14** | **Bloqueio de captura de entrada (Input Capture)** | ❌ *Não preparado* | Softwares como Input Leap e Synergy falham ao tentar capturar o cursor sem suporte à interface de portal Wayland. | Configurar suporte à interface `input-capture` no compositor e permissões no portal XDG. |

---

## 🚀 5. Novas Funcionalidades e Melhorias de Experiência (UX)

### 5.1 Suporte a Sistema de Arquivos Btrfs com Rollback Automático (Snapper)
* **Objetivo:** Permitir restaurar o sistema instantaneamente pelo GRUB caso uma atualização quebre algum pacote.
* **Arquitetura:**
  * Subvolumes padrão: `@` (raiz), `@home` (dados do usuário), `@snapshots` (pontos de restauração), `@var_log` (logs persistentes), `@swap` (arquivo de troca).
  * Instalação e pré-configuração do `snapper`, `snap-pac` (snapshots automáticos a cada `pacman -S`) e `grub-btrfs`.

### 5.2 Suporte Opcional a Criptografia Completa de Disco (LUKS)
* **Objetivo:** Segurança de dados para laptops contra roubo ou acesso físico não autorizado.
* **Implementação:** Menu interativo opcional solicitando frase secreta para criptografar a partição raiz com `cryptsetup luksFormat`.

### 5.3 Acabamento Visual e Temas Out-of-the-Box
* **Waybar para Hyprland:** Criar uma configuração completa com tema Aether Dark (bateria, controle de volume, status de rede, consumo de RAM e relógio).
* **Hyprpaper Wallpaper:** Incluir um papel de parede oficial minimalista do Aether OS e gerar o arquivo `hyprpaper.conf` automaticamente.
* **Atalhos Multimídia no Hyprland:** Vincular teclas de função (Volume Up/Down/Mute via `wpctl`, Brilho via `brightnessctl` e PrintScreen via `grim`/`slurp`).
* **SDDM Personalizado:** Aplicar um tema escuro e moderno ao Display Manager, combinando com o `INFO.md`.

### 5.4 Gerenciamento Integrado de Flatpak e Flathub
* **Objetivo:** Permitir instalar aplicativos sandboxed de forma transparente.
* **Implementação:** Habilitar automaticamente o repositório oficial do Flathub quando `flatpak` estiver instalado.

### 5.5 Expansão do Utilitário `aether-cli`
* `aether theme [cor]`: Alternar paletas visuais globais (Ice Blue, Neon Mint, Crimson, Frost Blue).
* `aether doctor`: Utilitário de diagnóstico que valida status do áudio Pipewire, serviços do systemd, drivers de vídeo e integridade do fstab.
* `aether backup`: Exportar ou sincronizar dotfiles para um repositório Git pessoal do usuário.

---

## 📅 6. Cronograma Recomendado de Implementação Atualizado

```mermaid
flowchart TD
    subgraph Fase 1 - Estabilidade de Hardware & Base Gráfica
        A1[Detecção Microcode Intel/AMD] --> A2[Detecção Drivers de Vídeo Nvidia/AMD/Intel]
        A2 --> A3[Early KMS no mkinitcpio.conf & nvidia-drm.modeset=1]
        A3 --> A4[Pacotes Base Plasma 6: workspace, qt6-wayland, plasma-nm, plasma-pa]
        A4 --> A5[Preservação de Wi-Fi do Live ISO]
        A5 --> A6[Centralização de Menus entre install.sh e test_ui.sh]
    end

    subgraph Fase 2 - Experiência Desktop, Portais & Usabilidade
        B1[Configuração de Portais Hyprland: portals.conf & D-Bus] --> B2[Waybar, SwayNC e Wallpaper hyprpaper.conf]
        B2 --> B3[Cursor e NVIDIA: no_hardware_cursors & Variáveis XCURSOR]
        B3 --> B4[Atalhos de Volume, Brilho e Polkit KF6 Wrapper]
        B4 --> B5[KWallet com SDDM PAM Autounlock]
    end

    subgraph Fase 3 - Resiliência Avançada & Ecossistema
        C1[Serviços NVIDIA Suspend/Resume & Preservação VRAM] --> C2[Hook de Recompilação Hyprpm]
        C2 --> C3[Particionamento Btrfs com Snapshots Snapper no GRUB]
        C3 --> C4[Criptografia LUKS Opcional]
        C4 --> C5[Comandos aether doctor, aether repair e aether theme]
        C5 --> C6[Geração de ISO Oficial do Aether OS com archiso]
    end

    Fase 1 --> Fase 2 --> Fase 3
```

### Detalhamento das Fases:

#### 🟢 Fase 1: Estabilidade de Hardware & Base Gráfica Robusta (Imediato)
1. **Microcode de CPU:** Inserir detecção dinâmica (`intel-ucode`/`amd-ucode`) no `installer/bootstrap_system.sh`.
2. **GPU & Early KMS:** Criar módulo `installer/gpu.sh` para detecção de placas gráficas (Intel, AMD, Nvidia), configurando `MODULES=(...)` no `/etc/mkinitcpio.conf` e `nvidia-drm.modeset=1` no GRUB.
3. **Correção do Metapacote Plasma 6:** Atualizar `PLASMA_PACKAGES` em `installer/packages.sh` para incluir `plasma-workspace`, `qt6-wayland`, `qt5-wayland`, `kwayland`, `plasma-nm`, `plasma-pa`, `konsole` e `kwallet-pam`.
4. **Preservação de Wi-Fi:** Copiar conexões do NetworkManager da ISO para o `/mnt`.
5. **Centralização de Menus:** Eliminar duplicações de opções entre `install.sh` e `test_ui.sh`.

#### 🔵 Fase 2: Experiência Desktop, Portais & Usabilidade (Curto Prazo)
1. **Resolução de Portal Timeout:** Criar `/etc/xdg/xdg-desktop-portal/portals.conf` e `hyprland-portals.conf` com fallback seguro (`default=hyprland;gtk`) para eliminar atrasos de 25–30s e garantir compartilhamento de tela com OBS/Discord.
2. **Shell Completa do Hyprland:** Fornecer configurações completas de fábrica em `configs/waybar`, `configs/swaync` e `configs/hyprland/.config/hypr/hyprpaper.conf`.
3. **Blindagem de Cursor e NVIDIA no Hyprland:** Adicionar `cursor:no_hardware_cursors = true`, variáveis globais de cursor (`XCURSOR_THEME`, `XCURSOR_SIZE`) e bindings multimídia (`wpctl`, `brightnessctl`).
4. **Agente Polkit Resiliente:** Wrapper de ativação gráfica compatível com as alterações de caminho de binários do KF6 / Plasma 6.
5. **Autounlock KWallet:** Injetar configuração no `/etc/pam.d/sddm` para desbloqueio silencioso do chaveiro no login.

#### 🟣 Fase 3: Resiliência Avançada & Recursos de Ecossistema (Médio Prazo)
1. **Suspensão/Hibernação NVIDIA:** Ativação automática dos serviços `nvidia-suspend`, `nvidia-hibernate`, `nvidia-resume` e modprobe `NVreg_PreserveVideoMemoryAllocations=1`.
2. **Ciclo de Vida de Plugins Hyprland:** Pacman Hook para recompilar plugins do `hyprpm` automaticamente após atualizações do Hyprland.
3. **Prevenção de Quebras XWayland / KWin:** Regras de escalonamento nítido e sanitização de configurações legadas do KWin / Klipper.
4. **Resiliência de Dados com Btrfs & Snapper:** Rollback automático de snapshots diretamente no menu do GRUB.
5. **Expansão da Ferramenta de Linha de Comando:** Implementação do `aether doctor` (autodiagnóstico de áudio, portais, GPU, display manager e cache do Klipper).
