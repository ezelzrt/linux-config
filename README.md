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
- `scripts/setup_shell_ui.sh`: setup de terminal/UI por componentes (Zsh, plugins, Starship, GNOME base y extensiones).
- `scripts/backup_configs.sh`: backup por perfil de dotfiles terminal (`.zshrc`, `.bashrc`, `.profile`, `starship.toml`) + `dconf` + commit/push opcional.
- `profiles/`: perfiles reutilizables con `dotfiles/`, `dconf/` e `img/`.
- `dotfiles/`: archivos globales versionados (ej. Git).
- `bootstrap_linux_config.sh`: script de arranque rápido (para pendrive, versionado en git).
