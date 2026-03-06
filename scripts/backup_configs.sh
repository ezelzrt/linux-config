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
  if [[ -f "$source" ]]; then
    cp "$source" "$target"
    log_ok "Guardado: ${C_DIM}$target${C_RESET}"
  else
    log_skip "$source"
  fi
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
  log_section "Backup dconf"
  mkdir -p "$ROOT_DIR/dconf"

  # Detectar el ID del monitor principal (conector xrandr, ej: eDP-1, DP-1, HDMI-1)
  # Se sanitiza tanto el ID de clave JSON de dash-to-panel (MONITOR_PLACEHOLDER)
  # como el valor de preferred-monitor-by-connector (CONNECTOR_PLACEHOLDER)
  local monitor_id=""
  if command -v xrandr >/dev/null 2>&1; then
    monitor_id=$(xrandr --query 2>/dev/null | awk '/ connected( primary)?/ {print $1; exit}')
  fi

  # Construir los argumentos de sed
  local sed_args=(-e "s|$HOME|HOME_PLACEHOLDER|g")
  if [[ -n "$monitor_id" ]]; then
    log_info "Monitor detectado para sanitizar: ${C_BOLD}$monitor_id${C_RESET}"
    # El mismo conector aparece como clave JSON en panel-* Y como valor en preferred-monitor-by-connector
    sed_args+=(-e "s|$monitor_id|MONITOR_PLACEHOLDER|g")
    # CONNECTOR_PLACEHOLDER cubre preferred-monitor-by-connector (puede ser un monitor distinto)
    # En caso de monitor único, ambos placeholders tendrán el mismo valor al restaurar
    sed_args+=(-e "s|preferred-monitor-by-connector='$monitor_id'|preferred-monitor-by-connector='CONNECTOR_PLACEHOLDER'|g")
  else
    log_warn "No se pudo detectar el monitor. El backup puede contener IDs específicos de hardware."
  fi

  dconf dump /org/gnome/ \
    | sed "${sed_args[@]}" \
    > "$ROOT_DIR/dconf/gnome-settings.dconf"
  log_ok "Guardado: dconf/gnome-settings.dconf"

  dconf dump /org/gnome/shell/extensions/ \
    | sed "${sed_args[@]}" \
    > "$ROOT_DIR/dconf/gnome-extensions.dconf"
  log_ok "Guardado: dconf/gnome-extensions.dconf"
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
  backup_dconf

  if ask_yes_no "¿Hacer commit/push en este repo?" "Y"; then
    commit_and_push
  fi

  echo -e "\n${C_GREEN}${C_BOLD}✔ Backup finalizado.${C_RESET}\n"
}

main "$@"
