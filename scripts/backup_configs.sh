#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

copy_if_exists() {
  local source="$1"
  local target="$2"
  if [[ -f "$source" ]]; then
    cp "$source" "$target"
    echo "Guardado: $target"
  else
    echo "No encontrado: $source"
  fi
}

backup_dotfiles() {
  echo "== Backup dotfiles =="
  mkdir -p "$ROOT_DIR/dotfiles/shell" "$ROOT_DIR/dotfiles/git"

  copy_if_exists "$HOME/.zshrc" "$ROOT_DIR/dotfiles/shell/.zshrc"
  copy_if_exists "$HOME/.p10k.zsh" "$ROOT_DIR/dotfiles/shell/.p10k.zsh"
  copy_if_exists "$HOME/.bashrc" "$ROOT_DIR/dotfiles/shell/.bashrc"
  copy_if_exists "$HOME/.profile" "$ROOT_DIR/dotfiles/shell/.profile"
  copy_if_exists "$HOME/.gitconfig" "$ROOT_DIR/dotfiles/git/.gitconfig"
}

backup_dconf() {
  echo "== Backup dconf =="
  mkdir -p "$ROOT_DIR/dconf"
  dconf dump /org/gnome/ > "$ROOT_DIR/dconf/gnome-settings.dconf"
  dconf dump /org/gnome/shell/extensions/ > "$ROOT_DIR/dconf/gnome-extensions.dconf"
  echo "Guardado: dconf/gnome-settings.dconf"
  echo "Guardado: dconf/gnome-extensions.dconf"
}

commit_and_push() {
  cd "$ROOT_DIR"
  git add .

  if git diff --cached --quiet; then
    echo "No hay cambios para commit."
    return
  fi

  local default_msg="backup: dotfiles + dconf $(date +%Y-%m-%d_%H-%M-%S)"
  read -r -p "Mensaje de commit [$default_msg]: " commit_msg
  commit_msg="${commit_msg:-$default_msg}"

  git commit -m "$commit_msg"

  if ask_yes_no "¿Hacer git push ahora?" "Y"; then
    git push
  else
    echo "Push omitido."
  fi
}

main() {
  echo "== Backup Configs =="

  backup_dotfiles
  backup_dconf

  if ask_yes_no "¿Hacer commit/push en este repo?" "Y"; then
    commit_and_push
  fi

  echo "\nBackup finalizado."
}

main "$@"