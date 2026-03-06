#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
log_skip()    { echo -e "  ${C_DIM}↷  No encontrado: $1${C_RESET}"; }
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

copy_if_exists() {
  local source="$1"
  local target="$2"
  if [[ ! -f "$source" ]]; then
    log_skip "$source"
    return
  fi
  # Si source es un symlink que apunta al mismo archivo que target, no hay nada que copiar
  local real_source real_target
  real_source="$(realpath "$source" 2>/dev/null || echo "$source")"
  real_target="$(realpath "$target" 2>/dev/null || echo "$target")"
  if [[ "$real_source" == "$real_target" ]]; then
    log_skip "$(basename "$source") (symlink al repo, sin cambios)"
    return
  fi
  cp "$source" "$target"
  log_ok "Guardado: ${C_DIM}$target${C_RESET}"
}

# ── Selección / creación de perfil ────────────────────────────────────────────
# Imprime el nombre del perfil elegido en stdout (las demás salidas van a stderr).
# Retorna 0 siempre; el llamador captura stdout.
select_or_create_profile() {
  local profiles_dir="$ROOT_DIR/profiles"
  mkdir -p "$profiles_dir"

  # Listar perfiles existentes
  local -a existing=()
  while IFS= read -r -d '' d; do
    existing+=("$(basename "$d")")
  done < <(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

  echo -e "\n${C_CYAN}${C_BOLD}── Perfil de backup ──${C_RESET}" >&2

  # ── Helper: pedir un nombre nuevo válido y que no exista ──────────────────
  ask_new_profile_name() {
    local name=""
    while true; do
      echo -en "  ${C_BOLD}?${C_RESET}  Nombre del nuevo perfil: " >&2
      read -r name
      # Sanitizar: solo alfanuméricos, guiones y guiones bajos
      name="${name//[^a-zA-Z0-9_-]/-}"
      name="${name#-}"   # quitar guión inicial
      name="${name%-}"   # quitar guión final
      if [[ -z "$name" ]]; then
        log_warn "El nombre no puede estar vacío. Intentá de nuevo." >&2
        continue
      fi
      # Verificar que no exista ya
      local exists=0
      for e in "${existing[@]}"; do
        if [[ "$e" == "$name" ]]; then
          exists=1
          break
        fi
      done
      if (( exists )); then
        log_warn "Ya existe un perfil llamado '${C_BOLD}$name${C_RESET}'. Elegí otro nombre." >&2
        continue
      fi
      echo "$name"
      return
    done
  }

  local chosen_name=""

  if [[ ${#existing[@]} -eq 0 ]]; then
    # Sin perfiles: pedir nombre directamente
    echo -e "  ${C_BLUE}→${C_RESET}  No hay perfiles existentes." >&2
    chosen_name="$(ask_new_profile_name)"
    echo -e "  ${C_BLUE}→${C_RESET}  Creando perfil: ${C_BOLD}$chosen_name${C_RESET}" >&2
  else
    # Con perfiles: mostrar menú
    echo -e "  Perfiles disponibles:" >&2
    local i=1
    for name in "${existing[@]}"; do
      echo -e "    ${C_BOLD}$i)${C_RESET}  $name" >&2
      (( i++ ))
    done
    echo -e "    ${C_BOLD}n)${C_RESET}  Crear perfil nuevo" >&2

    while true; do
      echo -en "  ${C_BOLD}?${C_RESET}  Elegí un número para sobreescribir o ${C_BOLD}n${C_RESET} para nuevo: " >&2
      read -r answer

      if [[ "$answer" =~ ^[0-9]+$ ]]; then
        local idx=$(( answer - 1 ))
        if (( idx >= 0 && idx < ${#existing[@]} )); then
          chosen_name="${existing[$idx]}"
          echo -e "  ${C_BLUE}→${C_RESET}  Sobreescribiendo perfil: ${C_BOLD}$chosen_name${C_RESET}" >&2
          break
        else
          log_warn "Número fuera de rango." >&2
        fi
      elif [[ "$answer" == "n" ]]; then
        chosen_name="$(ask_new_profile_name)"
        echo -e "  ${C_BLUE}→${C_RESET}  Creando perfil: ${C_BOLD}$chosen_name${C_RESET}" >&2
        break
      else
        log_warn "Opción inválida. Ingresá un número o 'n'." >&2
      fi
    done
  fi

  echo "$chosen_name"
}

backup_dotfiles() {
  log_section "Backup dotfiles"
  mkdir -p "$ROOT_DIR/dotfiles/shell" "$ROOT_DIR/dotfiles/git"

  copy_if_exists "$HOME/.zshrc"     "$ROOT_DIR/dotfiles/shell/.zshrc"
  copy_if_exists "$HOME/.p10k.zsh"  "$ROOT_DIR/dotfiles/shell/.p10k.zsh"
  copy_if_exists "$HOME/.bashrc"    "$ROOT_DIR/dotfiles/shell/.bashrc"
  copy_if_exists "$HOME/.profile"   "$ROOT_DIR/dotfiles/shell/.profile"
  copy_if_exists "$HOME/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
}

backup_dconf() {
  local profile_name="$1"
  local profile_dir="$ROOT_DIR/profiles/$profile_name"
  local dconf_dir="$profile_dir/dconf"
  local img_dir="$profile_dir/img"

  log_section "Backup dconf → perfil '$profile_name'"
  mkdir -p "$dconf_dir" "$img_dir"

  # ── Detectar monitor principal ─────────────────────────────────────────────
  local monitor_id=""
  if command -v xrandr >/dev/null 2>&1; then
    monitor_id=$(xrandr --query 2>/dev/null | awk '/ connected( primary)?/ {print $1; exit}')
  fi

  local -a sed_args=(-e "s|$HOME|HOME_PLACEHOLDER|g")
  if [[ -n "$monitor_id" ]]; then
    log_info "Monitor detectado para sanitizar: ${C_BOLD}$monitor_id${C_RESET}"
    sed_args+=(-e "s|$monitor_id|MONITOR_PLACEHOLDER|g")
    sed_args+=(-e "s|preferred-monitor-by-connector='$monitor_id'|preferred-monitor-by-connector='CONNECTOR_PLACEHOLDER'|g")
  else
    log_warn "No se pudo detectar el monitor. El backup puede contener IDs específicos de hardware."
  fi

  # ── Volcar dconf ───────────────────────────────────────────────────────────
  dconf dump /org/gnome/ \
    | sed "${sed_args[@]}" \
    > "$dconf_dir/gnome-settings.dconf"
  log_ok "Guardado: profiles/$profile_name/dconf/gnome-settings.dconf"

  dconf dump /org/gnome/shell/extensions/ \
    | sed "${sed_args[@]}" \
    > "$dconf_dir/gnome-extensions.dconf"
  log_ok "Guardado: profiles/$profile_name/dconf/gnome-extensions.dconf"

  # ── Copiar wallpapers referenciados en el dconf ────────────────────────────
  # Buscamos líneas con 'HOME_PLACEHOLDER/...' que apunten a archivos de imagen
  log_info "Buscando wallpapers referenciados en el dconf..."
  local copied_count=0
  while IFS= read -r placeholder_path; do
    # Reconstruir el path real en el sistema actual
    local real_path="${placeholder_path/HOME_PLACEHOLDER/$HOME}"
    if [[ -f "$real_path" ]]; then
      local filename
      filename="$(basename "$real_path")"
      cp "$real_path" "$img_dir/$filename"
      log_ok "Wallpaper copiado: ${C_DIM}$filename${C_RESET}"
      (( copied_count++ )) || true
    fi
  done < <(
    grep -ohE "HOME_PLACEHOLDER[^'\" )>]+" "$dconf_dir/gnome-settings.dconf" \
      "$dconf_dir/gnome-extensions.dconf" 2>/dev/null \
    | grep -iE "\.(jpg|jpeg|png|webp|gif|svg|bmp)$" \
    | sort -u
  )

  if (( copied_count == 0 )); then
    log_info "No se encontraron wallpapers referenciados (o ya están en el perfil)."
  fi
}

commit_and_push() {
  log_section "Git commit / push"
  cd "$ROOT_DIR"
  git add .

  if git diff --cached --quiet; then
    log_info "No hay cambios para commit."
    return
  fi

  local default_msg="backup: dotfiles + dconf $(date +%Y-%m-%d_%H-%M-%S)"
  echo -en "  ${C_BOLD}?${C_RESET}  Mensaje de commit ${C_DIM}[$default_msg]${C_RESET}: "
  read -r commit_msg
  commit_msg="${commit_msg:-$default_msg}"

  git commit -m "$commit_msg"
  log_ok "Commit creado."

  if ask_yes_no "¿Hacer git push ahora?" "Y"; then
    git push
    log_ok "Push completado."
  else
    log_info "Push omitido."
  fi
}

main() {
  echo -e "\n${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}   Backup Configs${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"

  backup_dotfiles

  local profile_name
  profile_name="$(select_or_create_profile)"
  backup_dconf "$profile_name"

  if ask_yes_no "¿Hacer commit y/o push en este repo?" "Y"; then
    commit_and_push
  fi

  echo -e "\n${C_GREEN}${C_BOLD}✔ Backup finalizado.${C_RESET}\n"
}

main "$@"
