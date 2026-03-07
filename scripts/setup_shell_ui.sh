#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── Colores ────────────────────────────────────────────────────────────────────
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[1;36m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_BLUE='\033[1;34m'
C_DIM='\033[2m'

log_section() { echo -e "\n${C_CYAN}${C_BOLD}── $1 ──${C_RESET}"; }
log_ok()      { echo -e "  ${C_GREEN}✔${C_RESET}  $1"; }
log_skip()    { echo -e "  ${C_DIM}↷  $1 (ya instalado)${C_RESET}"; }
log_info()    { echo -e "  ${C_BLUE}→${C_RESET}  $1"; }
log_warn()    { echo -e "  ${C_YELLOW}⚠${C_RESET}  $1"; }
log_error()   { echo -e "  ${C_RED}✖${C_RESET}  $1"; }

ask_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"
  local answer

  while true; do
    if [[ "$default" == "Y" ]]; then
      echo -en "  ${C_BOLD}?${C_RESET}  $prompt ${C_DIM}[Y/n]${C_RESET}: "
      read -r answer
      answer="${answer:-Y}"
    else
      echo -en "  ${C_BOLD}?${C_RESET}  $prompt ${C_DIM}[y/N]${C_RESET}: "
      read -r answer
      answer="${answer:-N}"
    fi

    case "$answer" in
      Y|y|yes|YES) return 0 ;;
      N|n|no|NO)   return 1 ;;
      *) log_warn "Respuesta inválida. Usá y/n." ;;
    esac
  done
}

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" ]]; then
    # Respaldar tanto archivos reales como symlinks viejos
    local bak="$target.bak.$(date +%Y%m%d%H%M%S)"
    cp -rL "$target" "$bak"
    log_info "Backup local creado: ${C_DIM}$(basename "$bak")${C_RESET}"
  fi
}

copy_dotfile() {
  local source="$1"
  local target="$2"
  if [[ ! -f "$source" ]]; then
    log_warn "No encontrado en repo: ${C_DIM}$source${C_RESET}"
    return
  fi
  # Si el target actual es un symlink (al repo), eliminarlo primero para crear copia real
  if [[ -L "$target" ]]; then
    rm "$target"
  fi
  backup_if_needed "$target"
  cp "$source" "$target"
  log_ok "Copiado: ${C_DIM}$(basename "$source")${C_RESET} → ${C_DIM}$target${C_RESET}"
}

# ── Selección de perfil ────────────────────────────────────────────────────────
# Devuelve en stdout el path absoluto al directorio del perfil elegido.
# Si no hay perfiles usa fallback al root (ROOT_DIR).
# Toda la salida al usuario va a stderr.
select_profile() {
  local profiles_dir="$ROOT_DIR/profiles"

  local -a existing=()
  if [[ -d "$profiles_dir" ]]; then
    while IFS= read -r -d '' d; do
      if [[ -f "$d/dconf/gnome-settings.dconf" || -f "$d/dconf/gnome-extensions.dconf" ]]; then
        existing+=("$d")
      fi
    done < <(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi

  log_section "Selección de perfil"

  if [[ ${#existing[@]} -eq 0 ]]; then
    if [[ -f "$ROOT_DIR/dconf/gnome-settings.dconf" ]]; then
      log_warn "No hay perfiles. Usando configuración raíz (dconf/)."
      echo "$ROOT_DIR"
    else
      log_error "No hay perfiles ni configuración raíz. Saltando configuración GNOME."
      echo ""
    fi
    return
  fi

  if [[ ${#existing[@]} -eq 1 ]]; then
    local auto="${existing[0]}"
    log_info "Perfil único encontrado: ${C_BOLD}$(basename "$auto")${C_RESET}. Usando automáticamente."
    echo "$auto"
    return
  fi

  echo -e "  Perfiles disponibles:" >&2
  local i=1
  for p in "${existing[@]}"; do
    echo -e "    ${C_BOLD}$i)${C_RESET}  $(basename "$p")" >&2
    (( i++ ))
  done

  while true; do
    echo -en "  ${C_BOLD}?${C_RESET}  Elegí el número de perfil a restaurar: " >&2
    read -r answer
    if [[ "$answer" =~ ^[0-9]+$ ]]; then
      local idx=$(( answer - 1 ))
      if (( idx >= 0 && idx < ${#existing[@]} )); then
        local chosen="${existing[$idx]}"
        log_info "Perfil seleccionado: ${C_BOLD}$(basename "$chosen")${C_RESET}"
        echo "$chosen"
        return
      fi
    fi
    log_warn "Número fuera de rango." >&2
  done
}

# ── Etiqueta de sección con perfil ────────────────────────────────────────────
profile_label() {
  local profile_dir="$1"
  if [[ -n "$profile_dir" && "$profile_dir" != "$ROOT_DIR" ]]; then
    echo " ${C_DIM}[perfil: $(basename "$profile_dir")]${C_RESET}"
  elif [[ "$profile_dir" == "$ROOT_DIR" ]]; then
    echo " ${C_DIM}[fallback: dconf/]${C_RESET}"
  else
    echo ""
  fi
}

# ── 1. Zsh + Oh My Zsh + Powerlevel10k + MesloLGS NF ─────────────────────────
install_zsh_stack() {
  log_section "Zsh + Oh My Zsh + Powerlevel10k + MesloLGS NF"
  if ! ask_yes_no "¿Instalar stack Zsh completo (zsh, Oh My Zsh, P10k, fuentes)?" "Y"; then
    return
  fi

  # ── Paquetes base ────────────────────────────────────────────────────────
  sudo apt update -q
  sudo apt install -y zsh git curl wget unzip

  # ── Oh My Zsh ────────────────────────────────────────────────────────────
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log_info "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log_ok "Oh My Zsh instalado."
  else
    log_skip "Oh My Zsh"
  fi

  # ── Powerlevel10k ────────────────────────────────────────────────────────
  if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    log_info "Clonando Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    log_ok "Powerlevel10k instalado."
  else
    log_skip "Powerlevel10k"
  fi

  # ── Plugins ──────────────────────────────────────────────────────────────
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    log_info "Clonando zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    log_ok "zsh-autosuggestions instalado."
  else
    log_skip "zsh-autosuggestions"
  fi

  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    log_info "Clonando zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    log_ok "zsh-syntax-highlighting instalado."
  else
    log_skip "zsh-syntax-highlighting"
  fi

  # ── Fuentes MesloLGS NF ──────────────────────────────────────────────────
  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"
  local -A fonts=(
    ["MesloLGS NF Regular.ttf"]="MesloLGS%20NF%20Regular.ttf"
    ["MesloLGS NF Bold.ttf"]="MesloLGS%20NF%20Bold.ttf"
    ["MesloLGS NF Italic.ttf"]="MesloLGS%20NF%20Italic.ttf"
    ["MesloLGS NF Bold Italic.ttf"]="MesloLGS%20NF%20Bold%20Italic.ttf"
  )
  local fonts_installed=0
  for name in "${!fonts[@]}"; do
    if [[ -f "$font_dir/$name" ]]; then
      log_skip "Fuente $name"
    else
      log_info "Descargando $name..."
      wget -q -O "$font_dir/$name" "https://github.com/romkatv/powerlevel10k-media/raw/master/${fonts[$name]}"
      log_ok "Fuente $name"
      (( fonts_installed++ )) || true
    fi
  done
  if (( fonts_installed > 0 )); then
    fc-cache -fv >/dev/null
    log_ok "Cache de fuentes actualizado."
  fi
  log_warn "Recordá seleccionar 'MesloLGS NF' como fuente en tu terminal."

  # ── Shell por defecto ────────────────────────────────────────────────────
  if ask_yes_no "¿Cambiar shell por defecto a zsh?" "Y"; then
    chsh -s "$(command -v zsh)"
    log_ok "Shell por defecto cambiado a zsh."
  fi
}

# ── 2. Dotfiles + dconf del perfil ────────────────────────────────────────────
apply_profile_config() {
  local profile_dir="$1"
  local label
  label="$(profile_label "$profile_dir")"

  log_section "Dotfiles + configuración GNOME${label}"

  if [[ -z "$profile_dir" ]]; then
    log_warn "Sin perfil seleccionado. Saltando dotfiles y dconf."
    return
  fi

  if ! ask_yes_no "¿Aplicar dotfiles y configuración GNOME del perfil $(basename "$profile_dir")?" "Y"; then
    return
  fi

  # ── Dotfiles: desde el perfil, con fallback a dotfiles/shell/ del repo ───────
  local dotfiles_src
  if [[ "$profile_dir" != "$ROOT_DIR" && -d "$profile_dir/dotfiles" ]]; then
    dotfiles_src="$profile_dir/dotfiles"
    log_info "Dotfiles desde perfil: ${C_DIM}$dotfiles_src${C_RESET}"
  else
    dotfiles_src="$ROOT_DIR/dotfiles/shell"
    log_warn "Perfil sin dotfiles propios. Usando fallback: ${C_DIM}$dotfiles_src${C_RESET}"
  fi
  copy_dotfile "$dotfiles_src/.zshrc"    "$HOME/.zshrc"
  copy_dotfile "$dotfiles_src/.p10k.zsh" "$HOME/.p10k.zsh"
  copy_dotfile "$dotfiles_src/.bashrc"   "$HOME/.bashrc"
  copy_dotfile "$dotfiles_src/.profile"  "$HOME/.profile"

  # ── Determinar archivos dconf ─────────────────────────────────────────────
  local gnome_file ext_file
  if [[ "$profile_dir" != "$ROOT_DIR" ]]; then
    gnome_file="$profile_dir/dconf/gnome-settings.dconf"
    ext_file="$profile_dir/dconf/gnome-extensions.dconf"
  else
    gnome_file="$ROOT_DIR/dconf/gnome-settings.dconf"
    ext_file="$ROOT_DIR/dconf/gnome-extensions.dconf"
  fi

  # ── Detectar monitor ─────────────────────────────────────────────────────
  local monitor_id=""
  if command -v xrandr >/dev/null 2>&1; then
    monitor_id=$(xrandr --query 2>/dev/null | awk '/ connected( primary)?/{print $1; exit}')
  fi
  if [[ -n "$monitor_id" ]]; then
    log_info "Monitor detectado: ${C_BOLD}$monitor_id${C_RESET}"
  else
    log_warn "No se pudo detectar el monitor. La config de dash-to-panel puede no aplicar."
    monitor_id="MONITOR_PLACEHOLDER"
  fi

  # ── Copiar imágenes del perfil antes de cargar dconf ─────────────────────
  if [[ "$profile_dir" != "$ROOT_DIR" && -d "$profile_dir/img" ]]; then
    local dest="$HOME/.local/share/backgrounds"
    mkdir -p "$dest"
    local img_count=0
    while IFS= read -r f; do
      cp "$f" "$dest/$(basename "$f")"
      log_ok "Imagen copiada: ${C_DIM}$(basename "$f")${C_RESET}"
      (( img_count++ )) || true
    done < <(find "$profile_dir/img" -maxdepth 1 -type f \
      \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
         -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.svg" \
         -o -iname "*.bmp" \) | sort)
    (( img_count > 0 )) && log_info "$img_count imagen(es) copiada(s) a ${C_DIM}$dest${C_RESET}" || true
  fi

  # ── Cargar dconf ─────────────────────────────────────────────────────────
  if [[ -s "$gnome_file" ]]; then
    sed -e "s|HOME_PLACEHOLDER|$HOME|g" \
        -e "s|MONITOR_PLACEHOLDER|$monitor_id|g" \
        -e "s|CONNECTOR_PLACEHOLDER|$monitor_id|g" \
        "$gnome_file" | dconf load /org/gnome/
    log_ok "dconf GNOME aplicado."
  else
    log_warn "No hay contenido en $(basename "$gnome_file")"
  fi

  if [[ -s "$ext_file" ]]; then
    sed -e "s|HOME_PLACEHOLDER|$HOME|g" \
        -e "s|MONITOR_PLACEHOLDER|$monitor_id|g" \
        -e "s|CONNECTOR_PLACEHOLDER|$monitor_id|g" \
        "$ext_file" | dconf load /org/gnome/shell/extensions/
    log_ok "dconf extensiones aplicado."
  else
    log_warn "No hay contenido en $(basename "$ext_file")"
  fi

  log_warn "Cerrá y volvé a abrir sesión para que los cambios de GNOME Shell surtan efecto."
}

# ── Helper: leer extensiones habilitadas desde gnome-settings.dconf ──────────
parse_enabled_extensions() {
  local settings_file="$1"
  [[ -f "$settings_file" ]] || return
  grep -A0 "^enabled-extensions=" "$settings_file" \
    | grep -oE "'[^']+'" \
    | tr -d "'" \
    | grep -v "^$"
}

# ── 3. Extensiones GNOME ──────────────────────────────────────────────────────
install_gnome_extensions() {
  local profile_dir="$1"
  local label
  label="$(profile_label "$profile_dir")"

  log_section "Extensiones GNOME${label}"

  # ── Obtener lista de extensiones del perfil ───────────────────────────────
  local -a extensions=()
  local settings_file=""

  if [[ -n "$profile_dir" && "$profile_dir" != "$ROOT_DIR" && -f "$profile_dir/dconf/gnome-settings.dconf" ]]; then
    settings_file="$profile_dir/dconf/gnome-settings.dconf"
  elif [[ -f "$ROOT_DIR/dconf/gnome-settings.dconf" ]]; then
    settings_file="$ROOT_DIR/dconf/gnome-settings.dconf"
  fi

  if [[ -n "$settings_file" ]]; then
    while IFS= read -r uuid; do
      [[ -n "$uuid" ]] && extensions+=("$uuid")
    done < <(parse_enabled_extensions "$settings_file")
  fi

  # Fallback a lista hardcodeada
  if [[ ${#extensions[@]} -eq 0 ]]; then
    log_warn "No se encontraron extensiones en el perfil. Usando lista por defecto."
    extensions=(
      "dash-to-panel@jderose9.github.com"
      "blur-my-shell@aunetx"
      "clipboard-indicator@tudmotu.com"
      "system-monitor-next@paradoxxx.zero.gmail.com"
      "tiling-assistant@ubuntu.com"
      "ding@rastersoft.com"
    )
  fi

  # ── Mostrar lista y preguntar ─────────────────────────────────────────────
  log_info "Extensiones a instalar (${#extensions[@]}):"
  printf "    ${C_DIM}- %s${C_RESET}\n" "${extensions[@]}"

  if ! ask_yes_no "¿Instalar las extensiones GNOME listadas?" "Y"; then
    return
  fi

  # ── Dependencias apt ─────────────────────────────────────────────────────
  log_info "Verificando dependencias del sistema..."
  local -a ext_deps=(gir1.2-gtop-2.0)
  local -a missing_deps=()
  for pkg in "${ext_deps[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      log_skip "$pkg"
    else
      missing_deps+=("$pkg")
    fi
  done
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    sudo apt install -y "${missing_deps[@]}"
    log_ok "Dependencias instaladas: ${missing_deps[*]}"
  fi

  # ── Instalar gext via pipx ────────────────────────────────────────────────
  if ! command -v gext >/dev/null 2>&1; then
    log_info "Instalando gnome-extensions-cli (gext) via pipx..."
    if ! command -v pipx >/dev/null 2>&1; then
      sudo apt install -y pipx
      pipx ensurepath
    fi
    pipx install gnome-extensions-cli --system-site-packages
    export PATH="$HOME/.local/bin:$PATH"
  else
    log_skip "gnome-extensions-cli (gext)"
  fi

  if ! command -v gext >/dev/null 2>&1; then
    log_error "No se pudo instalar gext. Instalá las extensiones manualmente."
    return
  fi

  # ── Instalar extensiones ──────────────────────────────────────────────────
  for uuid in "${extensions[@]}"; do
    if gnome-extensions info "$uuid" >/dev/null 2>&1; then
      log_skip "$uuid"
    else
      log_info "Instalando: $uuid"
      if gext install "$uuid" 2>/dev/null; then
        log_ok "$uuid"
      else
        log_warn "No se pudo instalar $uuid (puede requerir reinicio de sesión)"
      fi
    fi
  done

  log_warn "Si alguna extensión no aparece activa, cerrá y volvé a abrir sesión."
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}   Setup Shell & UI${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"

  # 1. Elegir perfil primero — todo lo que sigue queda atado a él
  local profile_dir
  profile_dir="$(select_profile)"

  # 2. Stack Zsh completo (zsh + OMZ + P10k + fuentes)
  install_zsh_stack

  # 3. Dotfiles + dconf del perfil (una sola pregunta)
  apply_profile_config "$profile_dir"

  # 4. Extensiones GNOME (lista del perfil + confirmación)
  install_gnome_extensions "$profile_dir"

  echo -e "\n${C_GREEN}${C_BOLD}✔ Setup shell/UI finalizado.${C_RESET}\n"
}

main "$@"
