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

install_apt_packages() {
  log_section "Paquetes base (apt)"
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

  log_info "Paquetes a instalar:"
  printf "    ${C_DIM}- %s${C_RESET}\n" "${packages[@]}"

  if ask_yes_no "¿Instalar paquetes base con apt?" "Y"; then
    sudo apt update -q
    sudo apt install -y "${packages[@]}"
    log_ok "Paquetes base instalados."
  fi
}

install_kitty() {
  log_section "Kitty"
  if ! ask_yes_no "¿Instalar Kitty (instalador oficial precompilado)?" "Y"; then
    return
  fi

  local kitty_app_dir="$HOME/.local/kitty.app"
  local kitty_bin="$kitty_app_dir/bin/kitty"
  local kitten_bin="$kitty_app_dir/bin/kitten"
  local desktop_src="$kitty_app_dir/share/applications/kitty.desktop"
  local desktop_dst="$HOME/.local/share/applications/kitty.desktop"
  local desktop_open_src="$kitty_app_dir/share/applications/kitty-open.desktop"
  local desktop_open_dst="$HOME/.local/share/applications/kitty-open.desktop"
  local xdg_terminals="$HOME/.config/xdg-terminals.list"
  local abs_home
  abs_home="$(readlink -f "$HOME")"

  if [[ -x "$kitty_bin" ]]; then
    log_skip "Kitty"
  else
    log_info "Instalando Kitty..."
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
    log_ok "Kitty instalado."
  fi

  if [[ ! -x "$kitty_bin" || ! -x "$kitten_bin" ]]; then
    log_error "La instalación de Kitty no generó binarios esperados en $kitty_app_dir/bin."
    return 1
  fi

  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.config"

  ln -sfn "$kitty_bin" "$HOME/.local/bin/kitty"
  ln -sfn "$kitten_bin" "$HOME/.local/bin/kitten"
  log_ok "Symlinks creados: ~/.local/bin/{kitty,kitten}"

  if [[ -f "$desktop_src" ]]; then
    cp "$desktop_src" "$desktop_dst"
    log_ok "kitty.desktop copiado a ~/.local/share/applications/"
  else
    log_warn "No se encontró kitty.desktop en ${C_DIM}$desktop_src${C_RESET}"
  fi

  if [[ -f "$desktop_open_src" ]]; then
    cp "$desktop_open_src" "$desktop_open_dst"
    log_ok "kitty-open.desktop copiado a ~/.local/share/applications/"
  else
    log_warn "No se encontró kitty-open.desktop en ${C_DIM}$desktop_open_src${C_RESET}"
  fi

  if compgen -G "$HOME/.local/share/applications/kitty*.desktop" >/dev/null 2>&1; then
    sed -i "s|Icon=kitty|Icon=$abs_home/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" "$HOME/.local/share/applications/kitty"*.desktop
    sed -i "s|Exec=kitty|Exec=$abs_home/.local/kitty.app/bin/kitty|g" "$HOME/.local/share/applications/kitty"*.desktop
    log_ok "Actualizados Exec/Icon en kitty*.desktop"
  fi

  if [[ ! -f "$xdg_terminals" ]]; then
    printf 'kitty.desktop\n' > "$xdg_terminals"
    log_ok "Creado ~/.config/xdg-terminals.list con kitty.desktop"
  elif grep -qx 'kitty.desktop' "$xdg_terminals"; then
    log_skip "xdg-terminals.list"
  else
    printf 'kitty.desktop\n' > "$xdg_terminals"
    log_ok "Actualizado ~/.config/xdg-terminals.list con kitty.desktop"
  fi
}

install_yazi() {
  log_section "Yazi"
  if ! ask_yes_no "¿Instalar Yazi (último release binario)?" "Y"; then
    return
  fi

  log_info "Instalando dependencias de Yazi..."
  sudo apt update -q
  sudo apt install -y ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick
  log_ok "Dependencias instaladas."

  local api_url="https://api.github.com/repos/sxyazi/yazi/releases/latest"
  local asset_url
  asset_url="$(curl -fsSL "$api_url" | jq -r '[.assets[] | select(.name | test("x86_64-unknown-linux-gnu\\.zip$"))][0].browser_download_url')"

  if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
    log_error "No se encontró un asset x86_64-unknown-linux-gnu en el último release de Yazi."
    return 1
  fi

  local tmp_dir archive_path extract_dir
  tmp_dir="$(mktemp -d)"
  archive_path="$tmp_dir/yazi.zip"
  extract_dir=""

  log_info "Descargando release: ${C_DIM}$asset_url${C_RESET}"
  curl -fL "$asset_url" -o "$archive_path"

  log_info "Descomprimiendo release..."
  unzip -q "$archive_path" -d "$tmp_dir"

  for d in "$tmp_dir"/yazi-x86_64-unknown-linux-gnu*; do
    if [[ -d "$d" ]]; then
      extract_dir="$d"
      break
    fi
  done

  if [[ -z "$extract_dir" ]]; then
    rm -rf "$tmp_dir"
    log_error "No se encontró el directorio extraído de Yazi."
    return 1
  fi

  sudo mv -f "$extract_dir/yazi" /usr/local/bin/yazi
  sudo mv -f "$extract_dir/ya" /usr/local/bin/ya
  sudo chmod +x /usr/local/bin/yazi /usr/local/bin/ya

  rm -rf "$tmp_dir"
  log_ok "Yazi instalado en /usr/local/bin (yazi, ya)."
}

install_rustup() {
  log_section "Rust (rustup)"
  if ! ask_yes_no "¿Instalar Rust (rustup oficial)?" "N"; then
    return
  fi

  if command -v rustup >/dev/null 2>&1; then
    log_skip "rustup"
    return
  fi

  log_info "Instalando Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
  log_ok "Rust instalado: $(rustc --version)"
}

install_docker() {
  log_section "Docker"
  if ! ask_yes_no "¿Instalar Docker (repo oficial)?" "Y"; then
    return
  fi

  if command -v docker >/dev/null 2>&1; then
    log_skip "Docker ($(docker --version))"
    return
  fi

  log_info "Eliminando paquetes Docker conflictivos..."
  sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  # Eliminar claves/repos previos conflictivos (formato viejo .gpg y .asc)
  sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc
  sudo rm -f /etc/apt/sources.list.d/docker.list

  sudo install -m 0755 -d /etc/apt/keyrings

  log_info "Descargando clave GPG de Docker (.asc)..."
  # Usar formato moderno .asc (ASCII-armored) para evitar conflictos con docker.gpg
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update -q
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  log_ok "Docker instalado."

  if ask_yes_no "¿Agregar usuario actual al grupo docker?" "Y"; then
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER"
    log_warn "Cerrá y volvé a abrir sesión para activar el grupo docker."
  fi
}

install_nvm_node() {
  log_section "NVM + Node.js LTS"
  if ! ask_yes_no "¿Instalar NVM y Node.js LTS?" "Y"; then
    return
  fi

  export NVM_DIR="$HOME/.nvm"
  if [[ ! -d "$NVM_DIR" ]]; then
    log_info "Instalando NVM v0.40.3..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    log_ok "NVM instalado."
  else
    log_skip "NVM"
  fi

  # nvm.sh usa variables internas sin inicializar; desactivamos -u temporalmente
  set +u
  # shellcheck disable=SC1091
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

  if nvm ls --no-colors 2>/dev/null | grep -q "lts/\*\|$(nvm version-remote --lts 2>/dev/null)"; then
    log_skip "Node.js LTS ($(nvm version 'lts/*' 2>/dev/null))"
  else
    log_info "Instalando Node.js LTS..."
    nvm install --lts
    log_ok "Node.js LTS instalado."
  fi

  nvm alias default 'lts/*'
  nvm use --lts
  set -u
}

install_google_chrome() {
  log_section "Google Chrome"
  if ! ask_yes_no "¿Instalar Google Chrome?" "Y"; then
    return
  fi

  if command -v google-chrome >/dev/null 2>&1; then
    log_skip "Google Chrome"
    return
  fi

  log_info "Instalando Google Chrome..."
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
    | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
  sudo apt update -q
  sudo apt install -y google-chrome-stable
  log_ok "Google Chrome instalado."
}

install_bruno() {
  log_section "Bruno API Client"
  if ! ask_yes_no "¿Instalar Bruno API Client?" "Y"; then
    return
  fi

  if command -v bruno >/dev/null 2>&1; then
    log_skip "Bruno"
    return
  fi

  log_info "Instalando Bruno..."
  sudo mkdir -p /etc/apt/keyrings
  # Pre-crear carpeta gnupg de root para evitar error de archivo temporal con sudo gpg
  sudo mkdir -p /root/.gnupg
  sudo chmod 700 /root/.gnupg
  sudo gpg --no-default-keyring \
           --keyring /etc/apt/keyrings/bruno.gpg \
           --keyserver keyserver.ubuntu.com \
           --recv-keys 9FA6017ECABE0266
  echo "deb [signed-by=/etc/apt/keyrings/bruno.gpg] http://debian.usebruno.com/ bruno stable" \
    | sudo tee /etc/apt/sources.list.d/bruno.list > /dev/null
  sudo apt update -q
  sudo apt install -y bruno
  log_ok "Bruno instalado."
}

install_vscode() {
  log_section "Visual Studio Code"
  if ! ask_yes_no "¿Instalar Visual Studio Code?" "Y"; then
    return
  fi

  if command -v code >/dev/null 2>&1; then
    log_skip "VS Code"
    return
  fi

  log_info "Instalando VS Code..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > /tmp/packages.microsoft.gpg
  sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg \
    /usr/share/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  rm /tmp/packages.microsoft.gpg
  sudo apt update -q
  sudo apt install -y code
  log_ok "VS Code instalado."
  log_warn "Iniciá sesión en VS Code para sincronizar extensiones y configuración."
}

install_slack() {
  log_section "Slack"
  if ! ask_yes_no "¿Instalar Slack?" "Y"; then
    return
  fi

  if command -v slack >/dev/null 2>&1; then
    log_skip "Slack"
    return
  fi

  log_info "Descargando Slack..."
  wget -q -O /tmp/slack-desktop.deb \
    https://downloads.slack-edge.com/releases/linux/4.41.104/prod/x64/slack-desktop-4.41.104-amd64.deb
  sudo apt install -y /tmp/slack-desktop.deb
  rm /tmp/slack-desktop.deb
  log_ok "Slack instalado."
}

install_zoom() {
  log_section "Zoom"
  if ! ask_yes_no "¿Instalar Zoom?" "Y"; then
    return
  fi

  if command -v zoom >/dev/null 2>&1; then
    log_skip "Zoom"
    return
  fi

  log_info "Descargando Zoom..."
  wget -q -O /tmp/zoom_amd64.deb https://zoom.us/client/latest/zoom_amd64.deb
  sudo apt install -y /tmp/zoom_amd64.deb
  rm /tmp/zoom_amd64.deb
  log_ok "Zoom instalado."
}

install_snap_apps() {
  log_section "Apps Snap (Discord, Postman, Spotify)"
  if ! ask_yes_no "¿Instalar aplicaciones por Snap (Discord, Postman, Spotify)?" "Y"; then
    return
  fi

  if ! command -v snap >/dev/null 2>&1; then
    log_info "snapd no encontrado. Instalando..."
    sudo apt update -q
    sudo apt install -y snapd
    log_ok "snapd instalado."
  fi

  if ! snap list discord >/dev/null 2>&1; then
    log_info "Instalando Discord..."
    sudo snap install discord
    log_ok "Discord instalado."
  else
    log_skip "Discord"
  fi

  if ! snap list postman >/dev/null 2>&1; then
    log_info "Instalando Postman..."
    sudo snap install postman --classic
    log_ok "Postman instalado."
  else
    log_skip "Postman"
  fi

  if ! snap list spotify >/dev/null 2>&1; then
    log_info "Instalando Spotify..."
    sudo snap install spotify
    log_ok "Spotify instalado."
  else
    log_skip "Spotify"
  fi
}

install_opencode() {
  log_section "OpenCode"
  if ! ask_yes_no "¿Instalar OpenCode (AI coding agent)?" "Y"; then
    return
  fi

  if command -v opencode >/dev/null 2>&1; then
    log_skip "OpenCode"
    return
  fi

  log_info "Instalando OpenCode..."
  curl -fsSL https://opencode.ai/install | bash
  log_ok "OpenCode instalado."
  log_info "Ejecutá 'opencode' en tu proyecto para comenzar."
}

setup_git_profile() {
  log_section "Perfil Git"
  local source_gitconfig="$ROOT_DIR/dotfiles/git/.gitconfig"
  local target_gitconfig="$HOME/.gitconfig"

  if [[ ! -f "$source_gitconfig" ]]; then
    log_warn "No existe $source_gitconfig. Saltando perfil git."
    return
  fi

  if ask_yes_no "¿Aplicar perfil git desde dotfiles/git/.gitconfig?" "Y"; then
    if [[ -f "$target_gitconfig" && ! -L "$target_gitconfig" ]]; then
      cp "$target_gitconfig" "$target_gitconfig.bak.$(date +%Y%m%d%H%M%S)"
      log_info "Backup creado de ~/.gitconfig"
    fi
    ln -sfn "$source_gitconfig" "$target_gitconfig"
    log_ok "Perfil git aplicado desde el repo."
  fi
}

setup_dualboot_time_sync() {
  log_section "Dual Boot — sincronización de hora"
  if ! ask_yes_no "¿Configurar sincronización de hora para dual boot Windows/Linux?" "N"; then
    return
  fi

  sudo timedatectl set-local-rtc 1 --adjust-system-clock
  log_ok "RTC configurado en hora local para dual boot."
}

setup_corectrl() {
  log_section "CoreCtrl (GPU AMD)"
  if ! ask_yes_no "¿Instalar y configurar CoreCtrl? (para GPU's AMD)" "N"; then
    return
  fi

  if command -v corectrl >/dev/null 2>&1; then
    log_skip "CoreCtrl"
  else
    sudo apt update -q
    sudo apt install -y corectrl
    log_ok "CoreCtrl instalado."
  fi

  mkdir -p "$HOME/.config/autostart"
  if [[ -f "/usr/share/applications/org.corectrl.corectrl.desktop" ]]; then
    cp /usr/share/applications/org.corectrl.corectrl.desktop \
       "$HOME/.config/autostart/org.corectrl.CoreCtrl.desktop"
    log_ok "Autostart configurado."
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
  log_ok "Regla polkit creada."

  if [[ -f "$ROOT_DIR/configs/profile_coreCtrl_RX580.ccpro" ]]; then
    log_warn "Perfil detectado: $ROOT_DIR/configs/profile_coreCtrl_RX580.ccpro"
    log_warn "Importalo manualmente: CoreCtrl → Profiles → Import profile"
  else
    log_warn "No se encontró profile_coreCtrl_RX580.ccpro en $ROOT_DIR/configs"
  fi
}

main() {
  echo -e "\n${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}   Setup Base${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}════════════════════════════════════${C_RESET}"

  install_apt_packages
  install_kitty
  install_yazi
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

  echo -e "\n${C_GREEN}${C_BOLD}✔ Setup base finalizado.${C_RESET}\n"
}

main "$@"
