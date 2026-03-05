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

install_apt_packages() {
  local -a packages=(
    curl
    wget
    git
    ca-certificates
    gnupg
    lsb-release
    build-essential
    unzip
    zip
    jq
    htop
    tree
    net-tools
    wireshark
    gnome-tweaks
    dconf-cli
  )

  echo "\nPaquetes base recomendados:"
  printf ' - %s\n' "${packages[@]}"

  if ask_yes_no "¿Instalar paquetes base con apt?" "Y"; then
    sudo apt update
    sudo apt install -y "${packages[@]}"
  fi
}

install_rustup() {
  if ! ask_yes_no "¿Instalar Rust (rustup oficial)?" "N"; then
    return
  fi

  if command -v rustup >/dev/null 2>&1; then
    echo "rustup ya está instalado."
    return
  fi

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
  echo "Rust instalado: $(rustc --version)"
}

install_docker() {
  if ! ask_yes_no "¿Instalar Docker (repo oficial)?" "Y"; then
    return
  fi

  sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  if ask_yes_no "¿Agregar usuario actual al grupo docker?" "Y"; then
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER"
    echo "Te deslogueás/logueás para aplicar grupo docker."
  fi
}

install_nvm_node() {
  if ! ask_yes_no "¿Instalar NVM y Node.js LTS?" "Y"; then
    return
  fi

  export NVM_DIR="$HOME/.nvm"
  if [[ ! -d "$NVM_DIR" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi

  # shellcheck disable=SC1091
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use --lts
}

setup_git_profile() {
  local source_gitconfig="$ROOT_DIR/dotfiles/git/.gitconfig"
  local target_gitconfig="$HOME/.gitconfig"

  if [[ ! -f "$source_gitconfig" ]]; then
    echo "No existe $source_gitconfig. Saltando perfil git."
    return
  fi

  if ask_yes_no "¿Aplicar perfil git desde dotfiles/git/.gitconfig?" "Y"; then
    if [[ -f "$target_gitconfig" && ! -L "$target_gitconfig" ]]; then
      cp "$target_gitconfig" "$target_gitconfig.bak.$(date +%Y%m%d%H%M%S)"
      echo "Backup creado de ~/.gitconfig"
    fi

    ln -sfn "$source_gitconfig" "$target_gitconfig"
    echo "Perfil git aplicado desde el repo."
  fi
}

setup_dualboot_time_sync() {
  if ! ask_yes_no "¿Configurar sincronización de hora para dual boot Windows/Linux?" "N"; then
    return
  fi

  sudo timedatectl set-local-rtc 1 --adjust-system-clock
  echo "RTC configurado en hora local para dual boot."
}

setup_corectrl() {
  if ! ask_yes_no "¿Instalar y configurar CoreCtrl? (para GPU's AMD)" "N"; then
    return
  fi

  sudo apt update
  sudo apt install -y corectrl

  mkdir -p "$HOME/.config/autostart"
  if [[ -f "/usr/share/applications/org.corectrl.corectrl.desktop" ]]; then
    cp /usr/share/applications/org.corectrl.corectrl.desktop "$HOME/.config/autostart/org.corectrl.CoreCtrl.desktop"
  fi

  local user_group
  user_group="$(id -gn)"
  sudo tee /etc/polkit-1/rules.d/90-corectrl.rules > /dev/null <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.corectrl.helper.init" ||
         action.id == "org.corectrl.helperkiller.init") &&
        subject.local == true &&
        subject.active == true &&
        subject.isInGroup("$user_group")) {
            return polkit.Result.YES;
    }
});
EOF

  echo "CoreCtrl configurado."
  if [[ -f "$ROOT_DIR/configs/profile_coreCtrl_RX580.ccpro" ]]; then
    echo "Perfil detectado: $ROOT_DIR/configs/profile_coreCtrl_RX580.ccpro"
    echo "Importalo manualmente desde CoreCtrl -> Profiles -> Import profile"
  else
    echo "No se encontró profile_coreCtrl_RX580.ccpro en $ROOT_DIR/configs"
  fi
}

main() {
  echo "== Setup Base =="

  install_apt_packages
  install_rustup
  install_docker
  install_nvm_node
  setup_git_profile
  setup_dualboot_time_sync
  setup_corectrl

  echo "\nSetup base finalizado."
}

main "$@"