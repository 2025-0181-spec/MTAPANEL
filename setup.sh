#!/usr/bin/env bash
# ============================================================
#  MTAPANEL — Instalador
#  Uso: curl -sL https://raw.githubusercontent.com/2025-0181-spec/MTAPANEL/main/setup.sh | bash
# ============================================================

set -euo pipefail

readonly REPO_RAW="https://raw.githubusercontent.com/2025-0181-spec/MTAPANEL/main"
readonly INSTALL_DIR="/etc/mtapanel"
readonly BIN_PATH="/usr/local/bin/mta"
readonly LOG_DIR="/var/log/mtapanel"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║      MTAPANEL — INSTALADOR v1.0          ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
}

check_root()    { [[ $EUID -eq 0 ]] || die "Ejecuta como root: sudo bash setup.sh"; }
check_internet(){ info "Verificando internet..."; curl -s --max-time 5 https://github.com>/dev/null 2>&1 || die "Sin internet."; success "Conexión OK"; }

check_os() {
    [[ -f /etc/os-release ]] && source /etc/os-release || true
    case "${ID:-}" in
        ubuntu|debian) success "SO: ${PRETTY_NAME:-Linux}" ;;
        *) warn "SO no probado: ${PRETTY_NAME:-desconocido} — continuando..." ;;
    esac
}

install_dependencies() {
    info "Instalando dependencias..."
    apt-get update -qq
    local pkgs=(screen curl wget)
    local missing=()
    for p in "${pkgs[@]}"; do
        dpkg -l "$p" 2>/dev/null | grep -q "^ii" || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        apt-get install -y -qq "${missing[@]}" 2>/dev/null || warn "Algunas dependencias fallaron."
        success "Instaladas: ${missing[*]}"
    else
        success "Dependencias ya presentes."
    fi
}

create_dirs() {
    info "Preparando directorios..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR" "$LOG_DIR"
    chmod 755 "$INSTALL_DIR" "$LOG_DIR"
    success "Directorios listos: $INSTALL_DIR"
}

download_scripts() {
    info "Descargando scripts desde GitHub..."
    local files=("panel.sh" "version.txt")
    for f in "${files[@]}"; do
        local dest="$INSTALL_DIR/$f"
        if curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$REPO_RAW/$f" 2>/dev/null; then
            [[ "$f" != "version.txt" ]] && chmod +x "$dest"
            success "Descargado: $f"
        else
            warn "No se pudo descargar: $f"
        fi
    done
}

create_global_command() {
    cat > "$BIN_PATH" << 'CMD'
#!/usr/bin/env bash
exec bash /etc/mtapanel/panel.sh "$@"
CMD
    chmod +x "$BIN_PATH"
    success "Comando global creado: 'mta'"
}

save_version() {
    local ver; ver=$(curl -fsSL --max-time 5 "$REPO_RAW/version.txt" 2>/dev/null || echo "1.0.0")
    echo "$ver" > "$INSTALL_DIR/version.txt"
    success "Versión: $ver"
}

print_success() {
    echo ""
    echo -e "${GREEN}${BOLD}  ✔  MTAPANEL instalado correctamente.${RESET}"
    echo ""
    echo -e "  Escribe ${CYAN}mta${RESET} para abrir el panel."
    echo ""
}

main() {
    print_banner
    check_root
    check_os
    check_internet
    install_dependencies
    create_dirs
    download_scripts
    save_version
    create_global_command
    print_success
}

main "$@"
