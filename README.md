# linux-config

Repositorio de dotfiles y configuración visual para Ubuntu/GNOME usando Git como backup central.

## Estructura

- `init.sh`: manager interactivo de scripts.
- `scripts/setup_base.sh`: setup base de sistema (apt, Docker, NVM/Node, perfil Git).
- `scripts/setup_shell_ui.sh`: setup de Zsh/Oh My Zsh/Powerlevel10k/plugins + aplicación de `dconf`.
- `scripts/backup_configs.sh`: backup de dotfiles + `dconf` + commit/push opcional.
- `dotfiles/`: archivos versionados (shell, git, etc.).
- `dconf/`: exports de configuración visual GNOME.
