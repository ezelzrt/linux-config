#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

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

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    cp -r "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

symlink_dotfile() {
  local source="$1"
  local target="$2"
  if [[ -f "$source" ]]; then
    backup_if_needed "$target"
    ln -sfn "$source" "$target"
    echo "Link: $target -> $source"
  fi
}

install_zsh_stack() {
  if ! ask_yes_no "¿Instalar stack Zsh (zsh, fonts, utilidades)?" "Y"; then
    return
  fi

  sudo apt update
  sudo apt install -y zsh git curl wget unzip

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
  fi

  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi

  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi

  if ask_yes_no "¿Cambiar shell por defecto a zsh?" "Y"; then
    chsh -s "$(command -v zsh)"
  fi
}

install_meslo_nerd_font() {
  if ! ask_yes_no "¿Instalar fuentes MesloLGS NF recomendadas para Powerlevel10k?" "Y"; then
    return
  fi

  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"

  wget -q -O "$font_dir/MesloLGS NF Regular.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
  wget -q -O "$font_dir/MesloLGS NF Bold.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
  wget -q -O "$font_dir/MesloLGS NF Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
  wget -q -O "$font_dir/MesloLGS NF Bold Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"

  fc-cache -fv >/dev/null
  echo "Fuentes MesloLGS NF instaladas."
  echo "Recordatorio: en tu terminal, seleccioná 'MesloLGS NF' como fuente personalizada."
}

apply_dotfiles() {
  if ! ask_yes_no "¿Aplicar dotfiles shell desde el repo?" "Y"; then
    return
  fi

  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.zshrc" "$HOME/.zshrc"
  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.p10k.zsh" "$HOME/.p10k.zsh"
  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.bashrc" "$HOME/.bashrc"
  symlink_dotfile "$ROOT_DIR/dotfiles/shell/.profile" "$HOME/.profile"
}

apply_dconf() {
  if ! ask_yes_no "¿Aplicar configuraciones GNOME desde dconf?" "Y"; then
    return
  fi

  local gnome_file="$ROOT_DIR/dconf/gnome-settings.dconf"
  local ext_file="$ROOT_DIR/dconf/gnome-extensions.dconf"

  if [[ -s "$gnome_file" ]]; then
    sed "s|HOME_PLACEHOLDER|$HOME|g" "$gnome_file" | dconf load /org/gnome/
    echo "dconf GNOME aplicado."
  else
    echo "No hay contenido en dconf/gnome-settings.dconf"
  fi

  if [[ -s "$ext_file" ]]; then
    sed "s|HOME_PLACEHOLDER|$HOME|g" "$ext_file" | dconf load /org/gnome/shell/extensions/
    echo "dconf extensiones aplicado."
  else
    echo "No hay contenido en dconf/gnome-extensions.dconf"
  fi
}

main() {
  echo "== Setup Shell & UI =="

  install_zsh_stack
  install_meslo_nerd_font
  apply_dotfiles
  apply_dconf

  echo "\nSetup shell/UI finalizado."
}

main "$@"