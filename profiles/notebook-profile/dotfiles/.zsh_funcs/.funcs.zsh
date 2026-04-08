# Docker Interactive Cleanup
dclean() {
    echo -e "\n🧹 \033[1;34mDocker Cleanup Menu\033[0m"
    echo -e "\033[1;32m1.\033[0m 🟢 Safe: Solo dangling, caché local y redes vacías"
    echo -e "\033[1;33m2.\033[0m 🟡 Time-based: Imágenes, containers y caché con > 15 días"
    echo -e "\033[1;35m3.\033[0m 🟠 Aggressive: TODO lo que no esté corriendo (Conserva volúmenes)"
    echo -e "\033[1;31m4.\033[0m 🔴 Nuke: TODO + Volúmenes huérfanos (Peligro de datos)\n"
    
    echo -n "Selecciona una opción [1-4, cualquier otra para cancelar]: "
    read opcion
    echo ""

    case $opcion in
        1)
            echo "Ejecutando limpieza Safe..."
            docker image prune -f
            docker builder prune -f
            docker network prune -f
            ;;
        2)
            local TIME_FILTER="360h" # 720h = 30 días. 360h = 15 días. 168h = 7 días
            echo "Ejecutando limpieza Time-based (>${TIME_FILTER})..."
            docker image prune -a --filter "until=${TIME_FILTER}" -f
            docker container prune --filter "until=${TIME_FILTER}" -f
            docker builder prune --filter "until=${TIME_FILTER}" -f
            ;;
        3)
            echo "Ejecutando limpieza Aggressive..."
            docker system prune -a -f
            ;;
        4)
            # Confirmación de seguridad nativa de Zsh
            if read -q "?⚠️  ¿Estás 100% seguro de purgar TODO y perder volúmenes? [s/N]: "; then
                echo -e "\nEntonces ejecuta lo siguiente: "
                echo -e "\n docker system prune -a --volumes -f"
            else
                echo -e "\nAbortado por el usuario."
            fi
            ;;
        *)
            echo "Cancelado. Tu entorno sigue intacto."
            ;;
    esac
    echo -e "\nPara ver estado actual del  disco:\n docker system df"
}

# --- Wrapper para Yazi (CD al salir) ---
function yy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
