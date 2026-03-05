#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_exec() {
  chmod +x "$ROOT_DIR/scripts/setup_base.sh" "$ROOT_DIR/scripts/setup_shell_ui.sh" "$ROOT_DIR/scripts/backup_configs.sh"
}

show_menu() {
  cat <<'EOF'

================ linux-config manager ================
1) Setup base (apt + Docker + NVM/Node + Git profile)
2) Setup shell & UI (Zsh + Oh My Zsh + P10k + dconf)
3) Backup configs y push a git
0) Salir
======================================================
EOF
}

run_option() {
  local option="$1"
  case "$option" in
    1)
      "$ROOT_DIR/scripts/setup_base.sh"
      ;;
    2)
      "$ROOT_DIR/scripts/setup_shell_ui.sh"
      ;;
    3)
      "$ROOT_DIR/scripts/backup_configs.sh"
      ;;
    0)
      exit 0
      ;;
    *)
      echo "Opción inválida"
      ;;
  esac
}

main() {
  ensure_exec

  while true; do
    show_menu
    read -r -p "Elegí una opción: " selected
    run_option "$selected"
  done
}

main "$@"