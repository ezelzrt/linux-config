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
    gnome-shell-extension-manager
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

install_google_chrome() {
  if ! ask_yes_no "¿Instalar Google Chrome?" "Y"; then
    return
  fi

  if command -v google-chrome >/dev/null 2>&1; then
    echo "Google Chrome ya está instalado."
    return
  fi

  echo "Instalando Google Chrome..."
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null

  sudo apt update
  sudo apt install -y google-chrome-stable
  echo "Google Chrome instalado."
}

install_bruno() {
  if ! ask_yes_no "¿Instalar Bruno API Client?" "Y"; then
    return
  fi

  if command -v bruno >/dev/null 2>&1; then
    echo "Bruno ya está instalado."
    return
  fi

  echo "Instalando Bruno..."
  sudo mkdir -p /etc/apt/keyrings
  sudo gpg --no-default-keyring --keyring /etc/apt/keyrings/bruno.gpg --keyserver keyserver.ubuntu.com --recv-keys 9FA6017ECABE0266
  echo "deb [signed-by=/etc/apt/keyrings/bruno.gpg] http://debian.usebruno.com/ bruno stable" | sudo tee /etc/apt/sources.list.d/bruno.list > /dev/null

  sudo apt update
  sudo apt install -y bruno
  echo "Bruno instalado."
}

install_vscode() {
  if ! ask_yes_no "¿Instalar Visual Studio Code?" "Y"; then
    return
  fi

  if command -v code >/dev/null 2>&1; then
    echo "VS Code ya está instalado."
    return
  fi

  echo "Instalando Visual Studio Code..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
  sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /usr/share/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  rm /tmp/packages.microsoft.gpg

  sudo apt update
  sudo apt install -y code
  echo "VS Code instalado. Recordá iniciar sesión para sincronizar extensiones y configuración."
}

install_slack() {
  if ! ask_yes_no "¿Instalar Slack?" "Y"; then
    return
  fi

  if command -v slack >/dev/null 2>&1; then
    echo "Slack ya está instalado."
    return
  fi

  echo "Descargando e instalando Slack..."
  wget -O /tmp/slack-desktop.deb https://downloads.slack-edge.com/releases/linux/4.41.104/prod/x64/slack-desktop-4.41.104-amd64.deb
  sudo apt install -y /tmp/slack-desktop.deb
  rm /tmp/slack-desktop.deb
  echo "Slack instalado."
}

install_zoom() {
  if ! ask_yes_no "¿Instalar Zoom?" "Y"; then
    return
  fi

  if command -v zoom >/dev/null 2>&1; then
    echo "Zoom ya está instalado."
    return
  fi

  echo "Descargando e instalando Zoom..."
  wget -O /tmp/zoom_amd64.deb https://zoom.us/client/latest/zoom_amd64.deb
  sudo apt install -y /tmp/zoom_amd64.deb
  rm /tmp/zoom_amd64.deb
  echo "Zoom instalado."
}

install_snap_apps() {
  if ! ask_yes_no "¿Instalar aplicaciones por Snap (Discord, Postman, Spotify)?" "Y"; then
    return
  fi

  if ! command -v snap >/dev/null 2>&1; then
    echo "Snap no está instalado. Instalando snapd..."
    sudo apt update
    sudo apt install -y snapd
  fi

  # Discord
  if ! snap list discord >/dev/null 2>&1; then
    echo "Instalando Discord..."
    sudo snap install discord
  else
    echo "Discord ya está instalado."
  fi

  # Postman (con --classic para permisos completos)
  if ! snap list postman >/dev/null 2>&1; then
    echo "Instalando Postman..."
    sudo snap install postman --classic
  else
    echo "Postman ya está instalado."
  fi

  # Spotify
  if ! snap list spotify >/dev/null 2>&1; then
    echo "Instalando Spotify..."
    sudo snap install spotify
  else
    echo "Spotify ya está instalado."
  fi

  echo "Apps Snap instaladas."
}

install_opencode() {
  if ! ask_yes_no "¿Instalar OpenCode (AI coding agent)?" "Y"; then
    return
  fi

  if command -v opencode >/dev/null 2>&1; then
    echo "OpenCode ya está instalado."
    return
  fi

  echo "Instalando OpenCode..."
  curl -fsSL https://opencode.ai/install | bash
  echo "OpenCode instalado. Ejecutá 'opencode' en tu proyecto para comenzar."
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
  install_google_chrome
  install_bruno
  install_vscode
  install_slack
  install_zoom
  install_snap_apps
  install_opencode
  setup_git_profile
  setup_dualboot_time_sync
  setup_corectrl

  echo "\nSetup base finalizado."
}

main "$@"