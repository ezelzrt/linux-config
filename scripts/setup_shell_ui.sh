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

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    rm "$target"
  fi

  backup_if_needed "$target"
  cp "$source" "$target"
  log_ok "Copiado: ${C_DIM}$(basename "$source")${C_RESET} → ${C_DIM}$target${C_RESET}"
}

copy_dotdir() {
  local source="$1"
  local target="$2"

  if [[ ! -d "$source" ]]; then
    log_warn "No encontrado en repo: ${C_DIM}$source${C_RESET}"
    return
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -d "$target" ]] && diff -qr "$source" "$target" >/dev/null 2>&1; then
    log_skip "$(basename "$source")"
    return
  fi

  backup_if_needed "$target"

  if [[ -L "$target" || -f "$target" ]]; then
    rm -f "$target"
  elif [[ -d "$target" ]]; then
    rm -rf "$target"
  fi

  cp -a "$source" "$target"
  log_ok "Copiado dir: ${C_DIM}$(basename "$source")${C_RESET} → ${C_DIM}$target${C_RESET}"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

is_zsh_installed() {
  has_cmd zsh
}

is_starship_installed() {
  has_cmd starship
}

is_kitty_installed() {
  has_cmd kitty || [[ -x "$HOME/.local/kitty.app/bin/kitty" ]]
}

can_apply_gnome_dconf() {
  has_cmd dconf && (has_cmd gnome-shell || [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* || "${XDG_CURRENT_DESKTOP:-}" == *ubuntu* || "${DESKTOP_SESSION:-}" == *gnome* || "${DESKTOP_SESSION:-}" == *ubuntu* ]])
}

# ── Selección de perfil ────────────────────────────────────────────────────────
select_profile() {
  local profiles_dir="$ROOT_DIR/profiles"

  local -a existing=()
  if [[ -d "$profiles_dir" ]]; then
    while IFS= read -r -d '' d; do
      if [[ -f "$d/dconf/gnome-settings.dconf" || -f "$d/dconf/gnome-extensions.dconf" || -d "$d/dotfiles" ]]; then
        existing+=("$d")
      fi
    done < <(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi

  log_section "Selección de perfil"

  if [[ ${#existing[@]} -eq 0 ]]; then
    if [[ -d "$ROOT_DIR/profiles/default" ]]; then
      log_warn "No hay perfiles. Usando perfil por defecto (profiles/default/)."
      echo "$ROOT_DIR/profiles/default"
    else
      log_error "No hay perfiles ni configuración por defecto."
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
    echo -en "  ${C_BOLD}?${C_RESET}  Elegí el número de perfil que querés aplicar por componentes: " >&2
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

profile_label() {
  local profile_dir="$1"
  if [[ -n "$profile_dir" ]]; then
    echo " ${C_DIM}[perfil: $(basename "$profile_dir")]${C_RESET}"
  else
    echo ""
  fi
}

resolve_profile_file() {
  local profile_dir="$1"
  local rel_path="$2"
  local profile_candidate="$profile_dir/$rel_path"
  local fallback_candidate="$ROOT_DIR/profiles/default/$rel_path"

  if [[ -n "$profile_dir" && -f "$profile_candidate" ]]; then
    echo "$profile_candidate"
  elif [[ -f "$fallback_candidate" ]]; then
    echo "$fallback_candidate"
  else
    echo ""
  fi
}

resolve_dotfiles_dir() {
  local profile_dir="$1"
  if [[ -n "$profile_dir" && -d "$profile_dir/dotfiles" ]]; then
    echo "$profile_dir/dotfiles"
  elif [[ -d "$ROOT_DIR/profiles/default/dotfiles" ]]; then
    echo "$ROOT_DIR/profiles/default/dotfiles"
  else
    echo ""
  fi
}

migrate_zshrc_for_starship() {
  local zshrc="$HOME/.zshrc"
  [[ -f "$zshrc" ]] || return

  if grep -Eq 'powerlevel10k/powerlevel10k|\.p10k\.zsh|p10k-instant-prompt' "$zshrc"; then
    sed -i \
      -e '/p10k-instant-prompt-.*\.zsh/,/^fi$/d' \
      -e 's/^ZSH_THEME="powerlevel10k\/powerlevel10k"/ZSH_THEME=""/' \
      -e '/\.p10k\.zsh/d' \
      "$zshrc"
    log_info "Se ajustó ~/.zshrc para compatibilidad con Starship."
  fi

  if ! grep -q 'starship init zsh' "$zshrc"; then
    {
      printf "\n"
      printf "# Inicializar Starship\n"
      printf "eval \"\$(starship init zsh)\"\n"
    } >> "$zshrc"
    log_info "Se agregó inicialización de Starship al final de ~/.zshrc"
  fi
}

install_terminal_stack() {
  log_section "[TERMINAL] Stack base (Zsh + Oh My Zsh + plugins + Starship)"
  if ! ask_yes_no "[TERMINAL] ¿Instalar stack base de terminal (zsh, Oh My Zsh, plugins, Starship)?" "Y"; then
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

  if command -v starship >/dev/null 2>&1; then
    log_skip "Starship"
  else
    log_info "Instalando Starship..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
    log_ok "Starship instalado."
  fi

  if ask_yes_no "[TERMINAL] ¿Cambiar shell por defecto a zsh?" "Y"; then
    chsh -s "$(command -v zsh)"
    log_ok "Shell por defecto cambiado a zsh."
  fi
}

apply_terminal_dotfiles() {
  local profile_dir="$1"
  local label
  label="$(profile_label "$profile_dir")"

  log_section "[TERMINAL] Dotfiles${label}"

  if [[ -z "$profile_dir" ]]; then
    log_warn "Sin perfil seleccionado. Saltando dotfiles de terminal."
    return
  fi

  if ! ask_yes_no "[TERMINAL] ¿Aplicar dotfiles del perfil $(basename "$profile_dir")? (.zshrc, .bashrc, .profile, kitty, xdg-terminals.list, .zsh_funcs)" "Y"; then
    return
  fi

  local dotfiles_src
  dotfiles_src="$(resolve_dotfiles_dir "$profile_dir")"

  if [[ -z "$dotfiles_src" ]]; then
    log_warn "No hay directorio de dotfiles en el perfil ni en fallback default."
    return
  fi

  if [[ "$dotfiles_src" == "$profile_dir/dotfiles" ]]; then
    log_info "Dotfiles desde perfil: ${C_DIM}$dotfiles_src${C_RESET}"
  else
    log_warn "Perfil sin dotfiles propios. Usando fallback: ${C_DIM}$dotfiles_src${C_RESET}"
  fi

  if is_zsh_installed; then
    copy_dotfile "$dotfiles_src/.zshrc" "$HOME/.zshrc"
    copy_dotdir "$dotfiles_src/.zsh_funcs" "$HOME/.zsh_funcs"
  else
    log_info "Zsh no está instalado. Se omiten .zshrc y .zsh_funcs"
  fi

  copy_dotfile "$dotfiles_src/.bashrc" "$HOME/.bashrc"
  copy_dotfile "$dotfiles_src/.profile" "$HOME/.profile"

  if is_kitty_installed; then
    copy_dotdir "$dotfiles_src/.config/kitty" "$HOME/.config/kitty"
    copy_dotfile "$dotfiles_src/.config/xdg-terminals.list" "$HOME/.config/xdg-terminals.list"
  else
    log_info "Kitty no está instalado. Se omiten kitty/ y xdg-terminals.list"
  fi
}

apply_terminal_prompt_config() {
  local profile_dir="$1"
  local label
  label="$(profile_label "$profile_dir")"

  log_section "[TERMINAL] Prompt${label}"

  if [[ -z "$profile_dir" ]]; then
    log_warn "Sin perfil seleccionado. Saltando configuración de prompt."
    return
  fi

  if ! ask_yes_no "[TERMINAL] ¿Aplicar configuración de prompt del perfil $(basename "$profile_dir")?" "Y"; then
    return
  fi

  local starship_src legacy_p10k_src
  starship_src="$(resolve_profile_file "$profile_dir" "dotfiles/.config/starship.toml")"
  legacy_p10k_src="$(resolve_profile_file "$profile_dir" "dotfiles/.p10k.zsh")"

  if ! is_starship_installed; then
    log_info "Starship no está instalado. Se omite configuración de prompt del perfil."
    return
  fi

  if [[ -n "$starship_src" ]]; then
    copy_dotfile "$starship_src" "$HOME/.config/starship.toml"

    if is_zsh_installed; then
      migrate_zshrc_for_starship
    else
      log_info "Zsh no está instalado. Se aplicó starship.toml sin modificar ~/.zshrc"
    fi

    log_ok "Configuración de Starship aplicada."
    return
  fi

  log_warn "No se encontró dotfiles/.config/starship.toml en el perfil ni fallback default."

  if [[ -n "$legacy_p10k_src" ]]; then
    if ask_yes_no "[TERMINAL][LEGACY] ¿Aplicar configuración Powerlevel10k (.p10k.zsh) como fallback temporal?" "Y"; then
      copy_dotfile "$legacy_p10k_src" "$HOME/.p10k.zsh"
      log_warn "Fallback legacy aplicado (.p10k.zsh)."
    fi
  else
    log_warn "Tampoco se encontró .p10k.zsh. El prompt quedará según la shell actual."
  fi
}

detect_monitor_id() {
  if command -v xrandr >/dev/null 2>&1; then
    xrandr --query 2>/dev/null | awk '/ connected( primary)?/{print $1; exit}'
  fi
}

copy_profile_images() {
  local profile_dir="$1"
  [[ -d "$profile_dir/img" ]] || return

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

  if (( img_count > 0 )); then
    log_info "$img_count imagen(es) copiada(s) a ${C_DIM}$dest${C_RESET}"
  fi
}

apply_gnome_base_config() {
  local profile_dir="$1"
  local label
  label="$(profile_label "$profile_dir")"

  log_section "[UI] GNOME base${label}"

  if [[ -z "$profile_dir" ]]; then
    log_warn "Sin perfil seleccionado. Saltando GNOME base."
    return
  fi

  if ! can_apply_gnome_dconf; then
    log_info "Entorno GNOME/dconf no detectado. Se omite GNOME base."
    return
  fi

  if ! ask_yes_no "[UI] ¿Aplicar configuración GNOME base del perfil $(basename "$profile_dir")? (dconf /org/gnome/)" "Y"; then
    return
  fi

  local gnome_file
  gnome_file="$(resolve_profile_file "$profile_dir" "dconf/gnome-settings.dconf")"

  if [[ -z "$gnome_file" || ! -s "$gnome_file" ]]; then
    log_warn "No hay contenido de GNOME base para aplicar."
    return
  fi

  local monitor_id=""
  monitor_id="$(detect_monitor_id || true)"

  if [[ -n "$monitor_id" ]]; then
    log_info "Monitor detectado: ${C_BOLD}$monitor_id${C_RESET}"
  else
    log_warn "No se pudo detectar el monitor. La config de panel puede no aplicar exactamente igual."
    monitor_id="MONITOR_PLACEHOLDER"
  fi

  copy_profile_images "$profile_dir"

  sed -e "s|HOME_PLACEHOLDER|$HOME|g" \
      -e "s|MONITOR_PLACEHOLDER|$monitor_id|g" \
      -e "s|CONNECTOR_PLACEHOLDER|$monitor_id|g" \
      "$gnome_file" | dconf load /org/gnome/

  log_ok "dconf GNOME base aplicado."
  log_warn "Cerrá y volvé a abrir sesión para que los cambios de GNOME Shell surtan efecto."
}

apply_gnome_extensions_config() {
  local profile_dir="$1"
  local label
  label="$(profile_label "$profile_dir")"

  log_section "[UI] GNOME extensiones (config)${label}"

  if [[ -z "$profile_dir" ]]; then
    log_warn "Sin perfil seleccionado. Saltando configuración dconf de extensiones."
    return
  fi

  if ! can_apply_gnome_dconf; then
    log_info "Entorno GNOME/dconf no detectado. Se omite dconf de extensiones."
    return
  fi

  if ! ask_yes_no "[UI] ¿Aplicar configuración dconf de extensiones del perfil $(basename "$profile_dir")? (dconf /org/gnome/shell/extensions/)" "Y"; then
    return
  fi

  local ext_file
  ext_file="$(resolve_profile_file "$profile_dir" "dconf/gnome-extensions.dconf")"

  if [[ -z "$ext_file" || ! -s "$ext_file" ]]; then
    log_warn "No hay contenido de extensiones GNOME para aplicar."
    return
  fi

  local monitor_id=""
  monitor_id="$(detect_monitor_id || true)"
  [[ -n "$monitor_id" ]] || monitor_id="MONITOR_PLACEHOLDER"

  sed -e "s|HOME_PLACEHOLDER|$HOME|g" \
      -e "s|MONITOR_PLACEHOLDER|$monitor_id|g" \
      -e "s|CONNECTOR_PLACEHOLDER|$monitor_id|g" \
      "$ext_file" | dconf load /org/gnome/shell/extensions/

  log_ok "dconf de extensiones aplicado."
}

parse_enabled_extensions() {
  local settings_file="$1"
  [[ -f "$settings_file" ]] || return
  grep -A0 "^enabled-extensions=" "$settings_file" \
    | grep -oE "'[^']+'" \
    | tr -d "'" \
    | grep -v "^$"
}

install_gnome_extensions() {
  local profile_dir="$1"
  local label
  label="$(profile_label "$profile_dir")"

  log_section "[UI] Instalación de extensiones GNOME${label}"

  if [[ -z "$profile_dir" ]]; then
    log_warn "Sin perfil seleccionado. Saltando instalación de extensiones GNOME."
    return
  fi

  if ! can_apply_gnome_dconf; then
    log_info "Entorno GNOME no detectado. Se omite instalación de extensiones GNOME."
    return
  fi

  local -a extensions=()
  local settings_file=""

  if [[ -n "$profile_dir" ]]; then
    settings_file="$(resolve_profile_file "$profile_dir" "dconf/gnome-settings.dconf")"
  fi

  if [[ -n "$settings_file" ]]; then
    while IFS= read -r uuid; do
      [[ -n "$uuid" ]] && extensions+=("$uuid")
    done < <(parse_enabled_extensions "$settings_file")
  fi

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

  log_info "Extensiones candidatas (${#extensions[@]}):"
  printf "    ${C_DIM}- %s${C_RESET}\n" "${extensions[@]}"

  if ! ask_yes_no "[UI] ¿Instalar extensiones GNOME definidas para el perfil $(basename "$profile_dir")?" "Y"; then
    return
  fi

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

main() {
  echo -e "\n${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}   Setup Shell & UI${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"

  local profile_dir
  profile_dir="$(select_profile)"

  install_terminal_stack
  apply_terminal_dotfiles "$profile_dir"
  apply_terminal_prompt_config "$profile_dir"
  apply_gnome_base_config "$profile_dir"
  apply_gnome_extensions_config "$profile_dir"
  install_gnome_extensions "$profile_dir"

  echo -e "\n${C_GREEN}${C_BOLD}✔ Setup shell/UI finalizado.${C_RESET}\n"
}

main "$@"
