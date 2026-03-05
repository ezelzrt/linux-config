#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/ezelzrt/linux-config.git"
TARGET_DIR="${HOME}/linux-config"

ask_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"
  local answer

  while true; do
    if [[ "$default" == "Y" ]]; then
      read -r -p "$prompt [Y/n]: " answer
      answer="${answer:-Y}"
    else
      read -r -p "$prompt [y/N]: " answer
      answer="${answer:-N}"
    fi

    case "$answer" in
      Y|y|yes|YES) return 0 ;;
      N|n|no|NO) return 1 ;;
      *) echo "Respuesta inválida. Usá y/n." ;;
    esac
  done
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi

  echo "git no está instalado."
  if ask_yes_no "¿Instalar git con apt?" "Y"; then
    sudo apt update
    sudo apt install -y git
  else
    echo "No puedo continuar sin git."
    exit 1
  fi
}

clone_or_update_repo() {
  if [[ -d "$TARGET_DIR/.git" ]]; then
    echo "Repositorio ya existe en $TARGET_DIR"
    if ask_yes_no "¿Actualizarlo con git pull?" "Y"; then
      git -C "$TARGET_DIR" pull --ff-only
    fi
  else
    echo "Clonando repo en $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
  fi
}

run_init() {
  chmod +x "$TARGET_DIR/init.sh" "$TARGET_DIR/scripts"/*.sh
  echo "Ejecutando manager..."
  exec "$TARGET_DIR/init.sh"
}

main() {
  echo "== Bootstrap linux-config =="
  echo "Repo: $REPO_URL"
  echo "Destino: $TARGET_DIR"

  cd "$HOME"

  ensure_git
  clone_or_update_repo
  run_init
}

main "$@"
