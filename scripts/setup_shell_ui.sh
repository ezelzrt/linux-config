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
  if [[ -e "$target" && ! -L "$target" ]]; then
    cp -r "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
    log_info "Backup creado: $target.bak.*"
  fi
}

symlink_dotfile() {
  local source="$1"
  local target="$2"
  if [[ -f "$source" ]]; then
    backup_if_needed "$target"
    ln -sfn "$source" "$target"
    log_ok "Link: ${C_DIM}$target${C_RESET} → ${C_DIM}$source${C_RESET}"
  fi
}

# ── Selección de perfil ────────────────────────────────────────────────────────
# Devuelve en stdout el path absoluto al directorio del perfil elegido.
# Si no hay perfiles usa fallback al root dconf/.
# El resto de la salida va a stderr.
select_profile() {
  local profiles_dir="$ROOT_DIR/profiles"

  # Listar perfiles existentes
  local -a existing=()
  if [[ -d "$profiles_dir" ]]; then
    while IFS= read -r -d '' d; do
      # Solo incluir si tiene al menos un dconf file
      if [[ -f "$d/dconf/gnome-settings.dconf" || -f "$d/dconf/gnome-extensions.dconf" ]]; then
        existing+=("$d")
      fi
    done < <(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi

  echo -e "\n${C_CYAN}${C_BOLD}── Selección de perfil ──${C_RESET}" >&2

  # Sin perfiles → fallback a root dconf/
  if [[ ${#existing[@]} -eq 0 ]]; then
    if [[ -f "$ROOT_DIR/dconf/gnome-settings.dconf" ]]; then
      log_warn "No hay perfiles. Usando configuración raíz (dconf/)." >&2
      echo "$ROOT_DIR"   # devuelve ROOT_DIR; apply_dconf lo maneja
      return
    else
      log_error "No hay perfiles ni configuración raíz. Saltando dconf." >&2
      echo ""
      return
    fi
  fi

  # Un solo perfil → seleccionar automáticamente
  if [[ ${#existing[@]} -eq 1 ]]; then
    local auto="${existing[0]}"
    log_info "Perfil único encontrado: ${C_BOLD}$(basename "$auto")${C_RESET}. Usando automáticamente." >&2
    echo "$auto"
    return
  fi

  # Múltiples perfiles → pedir elección
  echo -e "  Perfiles disponibles:" >&2
  local i=1
  for p in "${existing[@]}"; do
    echo -e "    ${C_BOLD}$i)${C_RESET}  $(basename "$p")" >&2
    (( i++ ))
  done

  local chosen=""
  while true; do
    echo -en "  ${C_BOLD}?${C_RESET}  Elegí el número de perfil a restaurar: " >&2
    read -r answer
    if [[ "$answer" =~ ^[0-9]+$ ]]; then
      local idx=$(( answer - 1 ))
      if (( idx >= 0 && idx < ${#existing[@]} )); then
        chosen="${existing[$idx]}"
        log_info "Perfil seleccionado: ${C_BOLD}$(basename "$chosen")${C_RESET}" >&2
        echo "$chosen"
        return
      fi
    fi
    log_warn "Número fuera de rango." >&2
  done
}

install_zsh_stack() {
  log_section "Zsh + Oh My Zsh + Powerlevel10k"
  if ! ask_yes_no "¿Instalar stack Zsh (zsh, fonts, utilidades)?" "Y"; then
    return
  fi

  sudo apt update -q
  sudo apt install -y zsh git curl wget unzip

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log_info "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log_ok "Oh My Zsh instalado."
  else
    log_skip "Oh My Zsh"
  fi

  if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    log_info "Clonando Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    log_ok "Powerlevel10k instalado."
  else
    log_skip "Powerlevel10k"
  fi

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

  if ask_yes_no "¿Cambiar shell por defecto a zsh?" "Y"; then
    chsh -s "$(command -v zsh)"
    log_ok "Shell por defecto cambiado a zsh."
  fi
}

install_meslo_nerd_font() {
  log_section "Fuentes MesloLGS NF"
  if ! ask_yes_no "¿Instalar fuentes MesloLGS NF recomendadas para Powerlevel10k?" "Y"; then
    return
  fi

  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"

  local -A fonts=(
    ["MesloLGS NF Regular.ttf"]="MesloLGS%20NF%20Regular.ttf"
    ["MesloLGS NF Bold.ttf"]="MesloLGS%20NF%20Bold.ttf"
    ["MesloLGS NF Italic.ttf"]="MesloLGS%20NF%20Italic.ttf"
    ["MesloLGS NF Bold Italic.ttf"]="MesloLGS%20NF%20Bold%20Italic.ttf"
  )

  for name in "${!fonts[@]}"; do
    if [[ -f "$font_dir/$name" ]]; then
      log_skip "$name"
    else
      log_info "Descargando $name..."
      wget -q -O "$font_dir/$name" "https://github.com/romkatv/powerlevel10k-media/raw/master/${fonts[$name]}"
      log_ok "$name"
    fi
  done

  fc-cache -fv >/dev/null
  log_ok "Cache de fuentes actualizado."
  log_warn "Recordá seleccionar 'MesloLGS NF' como fuente en tu terminal."
}

apply_dotfiles() {
  log_section "Dotfiles"
  if ! ask_yes_no "¿Aplicar dotfiles shell desde el repo?" "Y"; then
    return
  fi

  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.zshrc"    "$HOME/.zshrc"
  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.p10k.zsh" "$HOME/.p10k.zsh"
  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.bashrc"   "$HOME/.bashrc"
  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.profile"  "$HOME/.profile"
}

# ── Leer extensiones habilitadas desde el dconf de un perfil ──────────────────
# Busca la clave enabled-extensions en gnome-settings.dconf y devuelve una lista
# de UUIDs, uno por línea.
parse_enabled_extensions() {
  local settings_file="$1"
  if [[ ! -f "$settings_file" ]]; then
    return
  fi
  # La clave tiene este formato (puede estar en [/org/gnome/shell] o [org/gnome/shell]):
  #   enabled-extensions=['uuid1', 'uuid2', ...]
  grep -A0 "^enabled-extensions=" "$settings_file" \
    | grep -oE "'[^']+'" \
    | tr -d "'" \
    | grep -v "^$"
}

install_gnome_extensions() {
  local profile_dir="${1:-}"

  log_section "Extensiones GNOME"
  if ! ask_yes_no "¿Instalar extensiones GNOME?" "Y"; then
    return
  fi

  # ── Dependencias apt ────────────────────────────────────────────────────────
  log_info "Instalando dependencias del sistema para extensiones..."
  local -a ext_deps=(gir1.2-gtop-2.0)
  local missing_deps=()
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

  # ── Obtener lista de extensiones ─────────────────────────────────────────
  local -a extensions=()

  # Intentar leer desde el perfil seleccionado
  local settings_file=""
  if [[ -n "$profile_dir" && -f "$profile_dir/dconf/gnome-settings.dconf" ]]; then
    settings_file="$profile_dir/dconf/gnome-settings.dconf"
  elif [[ -f "$ROOT_DIR/dconf/gnome-settings.dconf" ]]; then
    # Fallback a dconf raíz
    settings_file="$ROOT_DIR/dconf/gnome-settings.dconf"
  fi

  if [[ -n "$settings_file" ]]; then
    while IFS= read -r uuid; do
      [[ -n "$uuid" ]] && extensions+=("$uuid")
    done < <(parse_enabled_extensions "$settings_file")
  fi

  # Fallback a lista hardcodeada si no se encontró nada
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
  else
    log_info "Extensiones leídas del perfil (${#extensions[@]}):"
    printf "    ${C_DIM}- %s${C_RESET}\n" "${extensions[@]}"
  fi

  # ── Instalar gext via pipx ───────────────────────────────────────────────
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
    log_error "No se pudo instalar gext. Instalá manualmente:"
    printf "    ${C_DIM}- %s${C_RESET}\n" "${extensions[@]}"
    return
  fi

  # ── Instalar extensiones ─────────────────────────────────────────────────
  log_info "Instalando extensiones..."
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

# ── Copiar imágenes del perfil a backgrounds ──────────────────────────────────
copy_profile_images() {
  local profile_dir="$1"
  local img_dir="$profile_dir/img"

  if [[ ! -d "$img_dir" ]]; then
    return
  fi

  local files
  files=$(find "$img_dir" -maxdepth 1 -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
    -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.svg" \
    -o -iname "*.bmp" \
  \) 2>/dev/null | sort)

  if [[ -z "$files" ]]; then
    return
  fi

  local dest="$HOME/.local/share/backgrounds"
  mkdir -p "$dest"

  log_info "Copiando imágenes del perfil a ${C_DIM}$dest${C_RESET}..."
  while IFS= read -r f; do
    local fname
    fname="$(basename "$f")"
    cp "$f" "$dest/$fname"
    log_ok "Imagen copiada: ${C_DIM}$fname${C_RESET}"
  done <<< "$files"
}

apply_dconf() {
  local profile_dir="${1:-}"

  log_section "Configuración GNOME (dconf)"
  if ! ask_yes_no "¿Aplicar configuraciones GNOME desde dconf?" "Y"; then
    return
  fi

  # Determinar qué dconf usar: perfil o fallback raíz
  local gnome_file ext_file
  if [[ -n "$profile_dir" && "$profile_dir" != "$ROOT_DIR" ]]; then
    gnome_file="$profile_dir/dconf/gnome-settings.dconf"
    ext_file="$profile_dir/dconf/gnome-extensions.dconf"
    log_info "Usando perfil: ${C_BOLD}$(basename "$profile_dir")${C_RESET}"
  else
    gnome_file="$ROOT_DIR/dconf/gnome-settings.dconf"
    ext_file="$ROOT_DIR/dconf/gnome-extensions.dconf"
    log_info "Usando configuración raíz (fallback)."
  fi

  # ── Detectar monitor principal ─────────────────────────────────────────────
  local monitor_id=""
  if command -v xrandr >/dev/null 2>&1; then
    monitor_id=$(xrandr --query 2>/dev/null \
      | awk '/ connected( primary)?/{print $1; exit}')
  fi

  if [[ -n "$monitor_id" ]]; then
    log_info "Monitor detectado: ${C_BOLD}$monitor_id${C_RESET}"
  else
    log_warn "No se pudo detectar el monitor. La config de dash-to-panel puede no aplicar."
    monitor_id="MONITOR_PLACEHOLDER"
  fi

  # ── Copiar imágenes del perfil antes de cargar dconf ──────────────────────
  if [[ -n "$profile_dir" && "$profile_dir" != "$ROOT_DIR" ]]; then
    copy_profile_images "$profile_dir"
  fi

  # ── Aplicar dconf ─────────────────────────────────────────────────────────
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

  log_warn "Cerrá y volvé a abrir sesión para que todos los cambios de GNOME Shell surtan efecto."
}

main() {
  echo -e "\n${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}   Setup Shell & UI${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"

  install_zsh_stack
  install_meslo_nerd_font
  apply_dotfiles

  # Seleccionar perfil una sola vez; se pasa a extensiones y a dconf
  local profile_dir
  profile_dir="$(select_profile)"

  install_gnome_extensions "$profile_dir"
  apply_dconf "$profile_dir"

  echo -e "\n${C_GREEN}${C_BOLD}✔ Setup shell/UI finalizado.${C_RESET}\n"
}

main "$@"
