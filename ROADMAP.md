# 🗺️ Roadmap Técnico & Plano Estratégico - Aether OS

Este documento apresenta uma análise abrangente da arquitetura atual do **Aether OS**, mapeando as redundâncias técnicas a serem eliminadas, correções preventivas de estabilidade, melhorias de experiência de usuário e as fases de evolução recomendadas para consolidar o sistema como uma distribuição/framework Arch Linux de referência.

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
* **Problema:** As opções interativas de teclado (`br-abnt2`, `us`), kernels (`linux-zen`, `linux`), fusos horários, swap e perfis gráficos estão declaradas separadamente em [install.sh](install.sh) e em [test_ui.sh](test_ui.sh). Qualquer alteração de texto ou nova opção adicionada em um precisa ser sincronizada manualmente no outro.
* **Solução Recomendada:** Criar um módulo centralizador (ex.: `installer/options.sh` ou expandir `installer/env.sh`) que declare os arrays de opções reutilizáveis. Dessa forma, tanto o instalador de produção quanto o simulador leem estritamente a mesma fonte da verdade.

### 2.2 Duplicação de Lógica de Provisionamento de Usuário (`user.sh` vs `chroot_exec.sh`)
* **Problema:** A criação de usuários não-root existe em duas implementações: `setup_target_user` em [installer/user.sh](installer/user.sh) (para sistemas já instalados) e `provision_user_in_chroot` em [installer/chroot_exec.sh](installer/chroot_exec.sh) (para a instalação bare-metal). Ambas possuem passos redundantes de definição de shell Zsh, `chpasswd` e configuração do `/etc/sudoers.d/10-wheel-sudo`.
* **Solução Recomendada:** Unificar a lógica de criação de contas em uma função utilitária com parâmetro de raiz de montagem opcional (ex.: `create_user_account [mount_point] [user] [pass]`).

### 2.3 Sobreposição entre `pacstrap` e `CORE_PACKAGES`
* **Problema:** O `pacstrap` em [installer/bootstrap_system.sh](installer/bootstrap_system.sh) instala pacotes como `git`, `zsh` e `sudo`, enquanto `CORE_PACKAGES` em [installer/packages.sh](installer/packages.sh) reinstala esses mesmos itens no primeiro boot/chroot.
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

## 🚀 4. Novas Funcionalidades e Melhorias de Experiência (UX)

### 4.1 Suporte a Sistema de Arquivos Btrfs com Rollback Automático (Snapper)
* **Objetivo:** Permitir restaurar o sistema instantaneamente pelo GRUB caso uma atualização quebre algum pacote.
* **Arquitetura:**
  * Subvolumes padrão: `@` (raiz), `@home` (dados do usuário), `@snapshots` (pontos de restauração), `@var_log` (logs persistentes), `@swap` (arquivo de troca).
  * Instalação e pré-configuração do `snapper`, `snap-pac` (snapshots automáticos a cada `pacman -S`) e `grub-btrfs`.

### 4.2 Suporte Opcional a Criptografia Completa de Disco (LUKS)
* **Objetivo:** Segurança de dados para laptops contra roubo ou acesso físico não autorizado.
* **Implementação:** Menu interativo opcional solicitando frase secreta para criptografar a partição raiz com `cryptsetup luksFormat`.

### 4.3 Acabamento Visual e Temas Out-of-the-Box
* **Waybar para Hyprland:** Criar uma configuração completa com tema Aether Dark (bateria, controle de volume, status de rede, consumo de RAM e relógio).
* **Hyprpaper Wallpaper:** Incluir um papel de parede oficial minimalista do Aether OS e gerar o arquivo `hyprpaper.conf` automaticamente.
* **Atalhos Multimídia no Hyprland:** Vincular teclas de função (Volume Up/Down/Mute via `wpctl`, Brilho via `brightnessctl` e PrintScreen via `grim`/`slurp`).
* **SDDM Personalizado:** Aplicar um tema escuro e moderno ao Display Manager, combinando com o `INFO.md`.

### 4.4 Gerenciamento Integrado de Flatpak e Flathub
* **Objetivo:** Permitir instalar aplicativos sandboxed de forma transparente.
* **Implementação:** Habilitar automaticamente o repositório oficial do Flathub quando `flatpak` estiver instalado.

### 4.5 Expansão do Utilitário `aether-cli`
* `aether theme [cor]`: Alternar paletas visuais globais (Ice Blue, Neon Mint, Crimson, Frost Blue).
* `aether doctor`: Utilitário de diagnóstico que valida status do áudio Pipewire, serviços do systemd, drivers de vídeo e integridade do fstab.
* `aether backup`: Exportar ou sincronizar dotfiles para um repositório Git pessoal do usuário.

---

## 📅 5. Cronograma Recomendado de Implementação

```mermaid
flowchart TD
    subgraph Fase 1 - Estabilidade de Hardware & Refatoração
        A1[Detecção de Microcode Intel/AMD] --> A2[Detecção de Drivers de Vídeo Nvidia/AMD/Intel]
        A2 --> A3[Preservação de Wi-Fi do Live ISO]
        A3 --> A4[Centralização de Menus entre install.sh e test_ui.sh]
    end

    subgraph Fase 2 - Experiência Desktop & Visual
        B1[Waybar e Wofi Customizados com Aether Dark] --> B2[Wallpaper Oficial e hyprpaper.conf]
        B2 --> B3[Tema Escuro Customizado no SDDM]
        B3 --> B4[Atalhos de Volume e Brilho no Hyprland]
    end

    subgraph Fase 3 - Resiliência e Ecossistema
        C1[Opção de Particionamento Btrfs com Snapshots Snapper] --> C2[Suporte a Criptografia LUKS]
        C2 --> C3[Comandos aether doctor e aether theme na CLI]
        C3 --> C4[Geração de ISO Oficial Própria do Aether OS]
    end

    Fase 1 --> Fase 2 --> Fase 3
```

### Detalhamento das Fases:

#### 🟢 Fase 1: Estabilidade de Hardware e Limpeza Técnica (Curto Prazo)
1. Inserir detecção de microcode (`intel-ucode`/`amd-ucode`) no [bootstrap_system.sh](installer/bootstrap_system.sh).
2. Criar módulo `installer/gpu.sh` para detecção de GPU e drivers de aceleração gráfica.
3. Centralizar os arrays de opções dos menus em um arquivo compartilhado para eliminar duplicações entre `install.sh` e `test_ui.sh`.
4. Copiar conexões do NetworkManager da ISO para o `/mnt`.

#### 🔵 Fase 2: Experiência Desktop e Acabamento de Dotfiles (Médio Prazo)
1. Fornecer barra `Waybar` estilizada em `configs/waybar`.
2. Incluir papel de parede minimalista do Aether OS e arquivo `configs/hyprland/.config/hypr/hyprpaper.conf`.
3. Ajustar tema escuro do SDDM para início de sessão visualmente uniforme.
4. Adicionar atalhos de mídia e utilitários de áudio (`pavucontrol`, `brightnessctl`) nos perfis.

#### 🟣 Fase 3: Resiliência de Dados e Recursos Avançados (Longo Prazo)
1. Implementar opção de particionamento Btrfs com subvolumes e integração do Snapper ao GRUB.
2. Adicionar opção de criptografia LUKS para notebooks.
3. Implementar comandos adicionais no `aether-cli` (`aether doctor`, `aether theme`).
4. Criar pipeline de compilação de uma mídia Live ISO customizada do Aether OS baseada em `archiso`.
