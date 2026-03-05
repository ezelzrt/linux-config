# linux-config

Repositorio de dotfiles y configuración visual para Ubuntu/GNOME usando Git como backup central.

## Uso rápido (Bootstrap desde pendrive)

Si tenés `bootstrap_linux_config.sh` en un pendrive:

```bash
bash bootstrap_linux_config.sh
```

Clona el repo, instala git si hace falta y lanza el manager interactivo automáticamente.

## Estructura

- `init.sh`: manager interactivo de scripts.
- `scripts/setup_base.sh`: setup base de sistema (apt, Docker, NVM/Node, apps, Git profile).
- `scripts/setup_shell_ui.sh`: setup de Zsh/Oh My Zsh/Powerlevel10k/plugins + aplicación de `dconf`.
- `scripts/backup_configs.sh`: backup de dotfiles + `dconf` + commit/push opcional.
- `dotfiles/`: archivos versionados (shell, git, etc.).
- `dconf/`: exports de configuración visual GNOME.
- `bootstrap_linux_config.sh`: script de arranque rápido (para pendrive, versionado en git).
