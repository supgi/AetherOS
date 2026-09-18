# Guia de Estilos e Design System - Aether OS

Este documento formaliza todos os padrões de elementos visuais, paleta de cores, componentes de interface de terminal (TUI) e convenções visuais do projeto **Aether OS**. O design é orientado pelo utilitário **Charm Gum**, priorizando um estilo minimalista, moderno, terminal-first e com tons frios e escuros.

---

## 1. Paleta de Cores (Aether Dark Palette)

A identidade visual do Aether OS baseia-se em tons de azul glacial, ciano escuro, ardósia e grafite:

| Nome do Token | Código ANSI / Hex | Descrição | Uso no Gum |
| :--- | :--- | :--- | :--- |
| `COLOR_PRIMARY` | `39` (`#00afff` / Ice Blue) | Destaques primários, títulos e links | `--foreground "39"` |
| `COLOR_SECONDARY` | `31` (`#0087af` / Deep Cyan) | Subtítulos, bordas ativas e itens selecionados | `--foreground "31"` |
| `COLOR_ACCENT` | `75` (`#5fafff` / Frost Blue) | Spinners, tags secundárias e ênfases | `--foreground "75"` |
| `COLOR_MUTED` | `242` (`#6c6c6c` / Slate Gray) | Textos secundários, bordas inativas e dicas | `--foreground "242"` |
| `COLOR_SUCCESS` | `48` (`#00ff87` / Neon Mint) | Mensagens de sucesso, confirmação e prontidão | `--foreground "48"` |
| `COLOR_WARNING` | `214` (`#ffaf00` / Amber Glow) | Avisos, checagens de atenção e downloads | `--foreground "214"` |
| `COLOR_DANGER` | `196` (`#ff0055` / Crimson) | Erros críticos, abortos e cancelamentos | `--foreground "196"` |
| `COLOR_BG_CARD` | `235` (`#262626` / Dark Charcoal)| Fundos de cartões e blocos em destaque | `--background "235"` |

---

## 2. Tipografia e Banner

* **Banner Principal**: Renderizado em caixa arredondada com preenchimento lateral e bordas duplas ou arredondadas.
* **Cabeçalhos de Seção**: Margens verticais de 1 linha, texto em caixa alta ou negrito com cor primária.
* **Badges/Tags**: Rótulos curtos em caixas ou preenchimentos suaves (ex.: `[ OK ]`, `[ ATENÇÃO ]`, `[ ERRO ]`).

---

## 3. Padrões de Componentes Charm Gum

### 3.1 Banner de Entrada
```bash
gum style \
  --foreground "39" \
  --border "rounded" \
  --border-foreground "31" \
  --padding "1 3" \
  --margin "1 0" \
  --align center \
  --bold \
  "A E T H E R   O S" \
  "Framework Minimalista Wayland para Arch Linux"
```

### 3.2 Título de Seção / Etapa
```bash
gum style \
  --foreground "75" \
  --bold \
  --margin "1 0 0 0" \
  "➜ $step_title"
```

### 3.3 Menu de Escolha (`gum choose`)
* Cursor: `› ` estilizado com cor `39`.
* Item selecionado: Negrito com cor primária.
```bash
gum choose \
  --cursor="› " \
  --cursor.foreground="39" \
  --item.foreground="252" \
  --selected.foreground="39" \
  --limit=1 \
  "Opção 1" "Opção 2"
```

### 3.4 Confirmação (`gum confirm`)
* Prompt conciso com destaque.
* Cor de seleção positiva em `COLOR_PRIMARY` (`39`).
```bash
gum confirm \
  --prompt.foreground="75" \
  --selected.background="31" \
  --selected.foreground="255" \
  "Deseja prosseguir com a instalação?"
```

### 3.5 Indicadores de Progresso (`gum spin`)
* Spinner do tipo `dot` ou `pulse`.
* Título estilizado em `COLOR_ACCENT` (`75`).
```bash
gum spin \
  --spinner.foreground="39" \
  --title.foreground="75" \
  --spinner="dots" \
  --title=" Processando..." -- "$@"
```

### 3.6 Coleta de Entradas (`gum input`)
* Placeholder discreto em `COLOR_MUTED` (`242`).
* Borda ou prompt com cor `COLOR_SECONDARY` (`31`).
```bash
gum input \
  --prompt="› " \
  --prompt.foreground="39" \
  --placeholder="Digite seu nome de usuário" \
  --width=50
```

### 3.7 Alerta de Operação Destrutiva de Disco
Utilizado antes do particionamento e formatação de discos:
```bash
gum style \
  --foreground "196" \
  --border "double" \
  --border-foreground "196" \
  --padding "1 3" \
  --margin "1 0" \
  --align center \
  --bold \
  "ATENÇÃO: OPERAÇÃO DESTRUTIVA DE DISCO!" \
  "" \
  "O disco selecionado será completamente formatado."
```

### 3.8 Seletor de Armazenamento / Discos
```bash
gum choose \
  --cursor="› " \
  --cursor.foreground="39" \
  --item.foreground="252" \
  --selected.foreground="39" \
  "/dev/nvme0n1 (512G - Samsung SSD 980)" \
  "/dev/sda (1TB - Crucial CT1000)"
```

---

## 4. Responsividade no Terminal

1. **Largura Limite (Max Width)**: As caixas e banners devem respeitar um limite seguro de 70 a 80 colunas para manter legibilidade em terminais estreitos (mobile / split windows / tiling managers).
2. **Fallback Gracioso**: Caso o comando `gum` não esteja presente no ambiente (ex.: antes da compilação inicial), mensagens em texto limpo com caracteres ANSI padrão devem ser exibidas sem quebrar a execução.
