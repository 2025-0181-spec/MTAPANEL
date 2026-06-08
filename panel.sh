#!/usr/bin/env bash
# ============================================================
#  MTAPANEL — Panel de Control MTA:SA
#  Repo: https://github.com/2025-0181-spec/MTAPANEL
# ============================================================

set -uo pipefail

# ── Configuración (editable) ─────────────────────────────────
MTA_SCREEN="mta"
MTA_DIR="/root/mta/Server/mta-server64"
MTA_BIN="mta-server64"
MTA_LOG="/var/log/mtapanel/server.log"
PANEL_LOG="/var/log/mtapanel/panel.log"
PANEL_VERSION="1.0.0"

# Cargar config guardada si existe
[[ -f /etc/mtapanel/mta.conf ]] && source /etc/mtapanel/mta.conf 2>/dev/null || true

# ── Colores ──────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; DIM='\033[2m'
NC='\033[0m'; BOLD='\033[1m'

# ── Utilidades ───────────────────────────────────────────────
_press_enter() { echo -e "\n  ${DIM}Presiona [Enter] para continuar...${NC}"; read -r; }
_log()         { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$PANEL_LOG" 2>/dev/null || true; }
_info()        { echo -e "  ${C}[INFO]${NC} $*"; }
_ok()          { echo -e "  ${G}[OK]${NC}   $*"; }
_warn()        { echo -e "  ${Y}[WARN]${NC}  $*"; }
_err()         { echo -e "  ${R}[ERR]${NC}  $*"; }

# ── Estado del servidor ──────────────────────────────────────
_mta_running() {
    screen -list 2>/dev/null | grep -qE "\b${MTA_SCREEN}\b"
}

_mta_pid() {
    pgrep -f "mta-server" 2>/dev/null | head -1 || true
}

_mta_uptime() {
    local pid; pid=$(_mta_pid)
    [[ -z "$pid" ]] && { echo "—"; return; }
    local start; start=$(ps -o lstart= -p "$pid" 2>/dev/null | xargs || true)
    [[ -z "$start" ]] && { echo "desconocido"; return; }
    local secs=$(( $(date +%s) - $(date -d "$start" +%s 2>/dev/null || date +%s) ))
    printf "%dh %dm %ds" $(( secs/3600 )) $(( (secs%3600)/60 )) $(( secs%60 ))
}

_mta_players() {
    local logfile="$MTA_DIR/mods/deathmatch/logs/server.log"
    [[ -f "$logfile" ]] && grep -oP "Players: \K[0-9]+" "$logfile" 2>/dev/null | tail -1 || echo "?"
}

_mta_cpu_mem() {
    local pid; pid=$(_mta_pid)
    if [[ -n "$pid" ]]; then
        local cpu; cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | xargs || echo "—")
        local mem; mem=$(ps -p "$pid" -o %mem= 2>/dev/null | xargs || echo "—")
        echo "${cpu}% CPU  ${mem}% RAM"
    else
        echo "— CPU  — RAM"
    fi
}

_mta_cmd() {
    _mta_running || return 1
    screen -S "$MTA_SCREEN" -X stuff "${1}$(printf '\r')" 2>/dev/null
}

_find_mta_bin() {
    find / -name "mta-server*" -type f 2>/dev/null | grep -v proc | head -5
}

# ── Banner ───────────────────────────────────────────────────
_banner() {
    clear
    echo -e "${C}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║          MTA:SA — PANEL DE CONTROL               ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ── Status Bar ───────────────────────────────────────────────
_status_bar() {
    local estado recursos uptime pid players stats
    if _mta_running; then
        estado="${G}${BOLD}● ONLINE${NC}"
        uptime=$(_mta_uptime)
        pid=$(_mta_pid)
        players=$(_mta_players)
        stats=$(_mta_cpu_mem)
    else
        estado="${R}${BOLD}● OFFLINE${NC}"
        uptime="—"; pid="—"; players="—"; stats="— CPU  — RAM"
    fi

    echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
    printf "  Estado    : %b\n" "$estado"
    echo -e "  Uptime    : ${W}${uptime}${NC}"
    echo -e "  PID       : ${W}${pid}${NC}    Jugadores: ${Y}${players}${NC}"
    echo -e "  Recursos  : ${DIM}${stats}${NC}"
    echo -e "  Servidor  : ${DIM}${MTA_DIR}${NC}"
    echo -e "  ${DIM}──────────────────────────────────────────────────────${NC}"
    echo ""
}

# ╔══════════════════════════════════════════════════════════╗
#  [1] INICIAR
# ╚══════════════════════════════════════════════════════════╝
handle_start() {
    _banner
    echo -e "\n  ${W}${BOLD}── Iniciar Servidor MTA ─────────────────────────────${NC}\n"

    if _mta_running; then
        _warn "El servidor ya está corriendo."
        _press_enter; return
    fi

    # Buscar ejecutable
    local bin_path="$MTA_DIR/$MTA_BIN"
    if [[ ! -f "$bin_path" ]]; then
        _warn "Ejecutable no encontrado en $bin_path"
        _info "Buscando automáticamente..."
        bin_path=$(find "$MTA_DIR" -name "mta-server*" -type f 2>/dev/null | head -1 || true)
        if [[ -z "$bin_path" ]]; then
            _err "No se encontró el ejecutable MTA."
            echo -e "\n  Ve a ${C}Configuración → Cambiar directorio${NC} para configurarlo."
            _press_enter; return
        fi
        _ok "Encontrado: $bin_path"
    fi

    _info "Iniciando servidor en screen '${MTA_SCREEN}'..."
    chmod +x "$bin_path" 2>/dev/null || true
    cd "$(dirname "$bin_path")" || { _err "No se pudo acceder al directorio."; _press_enter; return; }

    screen -dmS "$MTA_SCREEN" bash -c "\"$bin_path\" 2>&1 | tee -a \"$MTA_LOG\""
    sleep 3

    if _mta_running; then
        _ok "Servidor iniciado correctamente."
        echo -e "  Screen: ${C}screen -r ${MTA_SCREEN}${NC}"
        _log "Servidor iniciado — bin: $bin_path"
    else
        _err "El servidor no pudo iniciarse."
        echo -e "  Revisa el log: ${C}tail -30 $MTA_LOG${NC}"
    fi
    _press_enter
}

# ╔══════════════════════════════════════════════════════════╗
#  [2] DETENER
# ╚══════════════════════════════════════════════════════════╝
handle_stop() {
    _banner
    echo -e "\n  ${W}${BOLD}── Detener Servidor MTA ─────────────────────────────${NC}\n"

    if ! _mta_running; then
        _warn "El servidor ya está detenido."
        _press_enter; return
    fi

    echo -e "  ${W}[1]${NC} ${G}Shutdown seguro${NC} ${DIM}(guarda datos — recomendado)${NC}"
    echo -e "  ${W}[2]${NC} ${R}Forzar cierre${NC}  ${DIM}(kill — puede perder datos)${NC}"
    echo -e "  ${DIM}[0]${NC} Cancelar"
    echo ""; echo -e "  Selección: \c"; read -r opt

    case "$opt" in
    1)
        _info "Enviando 'shutdown' al servidor..."
        _mta_cmd "shutdown"
        local t=0
        while _mta_running && (( t < 30 )); do
            printf "\r  ${DIM}Esperando cierre seguro... %ds${NC}" "$t"
            sleep 2; (( t+=2 ))
        done
        echo ""
        if ! _mta_running; then
            _ok "Servidor detenido correctamente."
            _log "Servidor detenido — shutdown seguro"
        else
            _warn "Timeout. Forzando cierre..."
            local pid; pid=$(_mta_pid)
            [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
            screen -S "$MTA_SCREEN" -X quit 2>/dev/null || true
            sleep 1
            _ok "Proceso terminado."
            _log "Servidor forzado a cerrar (timeout)"
        fi
        ;;
    2)
        echo -e "  ${R}⚠  ¿Confirmar cierre forzado? [s/N]: \c"; read -r c
        if [[ "${c,,}" == "s" ]]; then
            local pid; pid=$(_mta_pid)
            [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null || true
            screen -S "$MTA_SCREEN" -X quit 2>/dev/null || true
            sleep 1
            _ok "Proceso terminado forzosamente."
            _log "Servidor terminado forzosamente (kill -9)"
        else
            _info "Cancelado."
        fi
        ;;
    0) return ;;
    esac
    _press_enter
}

# ╔══════════════════════════════════════════════════════════╗
#  [3] REINICIAR
# ╚══════════════════════════════════════════════════════════╝
handle_restart() {
    _banner
    echo -e "\n  ${W}${BOLD}── Reiniciar Servidor MTA ───────────────────────────${NC}\n"
    echo -e "  ${Y}⚠  Se enviará 'shutdown' y el servidor volverá a iniciar.${NC}"
    echo -e "  ${Y}   Los datos se guardarán correctamente.${NC}"
    echo ""
    echo -e "  ${W}[1]${NC} Confirmar  ${DIM}[0]${NC} Cancelar"
    echo -e "  Selección: \c"; read -r opt
    [[ "$opt" == "1" ]] || return

    # Detener
    if _mta_running; then
        _info "Enviando shutdown..."
        _mta_cmd "shutdown"
        local t=0
        while _mta_running && (( t < 30 )); do
            printf "\r  ${DIM}Esperando cierre... %ds${NC}" "$t"
            sleep 2; (( t+=2 ))
        done
        echo ""
        if _mta_running; then
            local pid; pid=$(_mta_pid)
            [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
            screen -S "$MTA_SCREEN" -X quit 2>/dev/null || true
            sleep 2
        fi
        _ok "Servidor detenido."
    fi

    sleep 2

    # Iniciar
    local bin_path="$MTA_DIR/$MTA_BIN"
    [[ ! -f "$bin_path" ]] && \
        bin_path=$(find "$MTA_DIR" -name "mta-server*" -type f 2>/dev/null | head -1 || true)

    if [[ -z "$bin_path" || ! -f "$bin_path" ]]; then
        _err "Ejecutable no encontrado. No se puede reiniciar."
        _press_enter; return
    fi

    _info "Iniciando servidor..."
    cd "$(dirname "$bin_path")" || return
    screen -dmS "$MTA_SCREEN" bash -c "\"$bin_path\" 2>&1 | tee -a \"$MTA_LOG\""
    sleep 3

    if _mta_running; then
        _ok "Servidor reiniciado correctamente."
        _log "Servidor reiniciado"
    else
        _err "El servidor no pudo iniciarse tras el restart."
    fi
    _press_enter
}

# ╔══════════════════════════════════════════════════════════╗
#  [4] CONSOLA EN VIVO
# ╚══════════════════════════════════════════════════════════╝
handle_console() {
    _banner
    echo -e "\n  ${W}${BOLD}── Consola del Servidor MTA ─────────────────────────${NC}\n"

    if ! _mta_running; then
        _err "El servidor no está corriendo."
        _press_enter; return
    fi

    echo -e "  ${W}[1]${NC} Ver output en tiempo real ${DIM}(tail -f del log)${NC}"
    echo -e "  ${W}[2]${NC} Adjuntarse al screen ${DIM}(consola interactiva completa)${NC}"
    echo -e "  ${DIM}[0]${NC} Volver"
    echo ""; echo -e "  Selección: \c"; read -r opt

    case "$opt" in
    1)
        clear
        echo -e "  ${DIM}── Output en tiempo real (Ctrl+C para salir) ────────${NC}\n"
        local logfile="$MTA_DIR/mods/deathmatch/logs/server.log"
        [[ ! -f "$logfile" ]] && logfile="$MTA_LOG"
        if [[ -f "$logfile" ]]; then
            trap "trap - INT; return" INT
            tail -f "$logfile" 2>/dev/null | while read -r line; do
                echo -e "  ${DIM}$line${NC}"
            done &
            local tp=$!
            wait $tp 2>/dev/null || true
            trap - INT
        else
            _warn "Log no encontrado. Adjuntando al screen..."
            sleep 1
            screen -r "$MTA_SCREEN"
        fi
        ;;
    2)
        clear
        echo -e "  ${Y}Adjuntando al screen '${MTA_SCREEN}'...${NC}"
        echo -e "  ${DIM}Usa Ctrl+A luego D para desadjuntarte sin cerrar el server.${NC}"
        sleep 2
        screen -r "$MTA_SCREEN"
        ;;
    0) return ;;
    esac
}

# ╔══════════════════════════════════════════════════════════╗
#  [5] EJECUTAR COMANDO
# ╚══════════════════════════════════════════════════════════╝
handle_command() {
    while true; do
        _banner
        echo -e "\n  ${W}${BOLD}── Ejecutar Comando en MTA ──────────────────────────${NC}\n"

        if ! _mta_running; then
            _err "El servidor no está corriendo."
            _press_enter; return
        fi

        echo -e "  ${Y}${BOLD}Comandos frecuentes:${NC}"
        echo -e "  ${DIM}  say <msg>        Mensaje global en el chat${NC}"
        echo -e "  ${DIM}  kick <nick>      Expulsar jugador${NC}"
        echo -e "  ${DIM}  ban <nick>       Banear jugador${NC}"
        echo -e "  ${DIM}  start <recurso>  Iniciar recurso${NC}"
        echo -e "  ${DIM}  stop <recurso>   Detener recurso${NC}"
        echo -e "  ${DIM}  restart <recurso>Reiniciar recurso${NC}"
        echo -e "  ${DIM}  debugscript 3    Nivel máximo de debug${NC}"
        echo -e "  ${DIM}  shutdown         Apagar servidor${NC}"
        echo ""
        echo -e "  ${W}Comando${NC} ${DIM}(Enter vacío para volver)${NC}: \c"
        read -r cmd

        [[ -z "$cmd" ]] && return

        if _mta_cmd "$cmd"; then
            _ok "Comando enviado: ${W}$cmd${NC}"
            _log "Comando: $cmd"

            # Mostrar output reciente
            sleep 1
            local logfile="$MTA_DIR/mods/deathmatch/logs/server.log"
            [[ ! -f "$logfile" ]] && logfile="$MTA_LOG"
            if [[ -f "$logfile" ]]; then
                echo ""
                echo -e "  ${DIM}── Output reciente ──────────────────────────────────${NC}"
                tail -6 "$logfile" 2>/dev/null | while read -r l; do
                    echo -e "  ${DIM}$l${NC}"
                done
            fi
        else
            _err "No se pudo enviar el comando."
        fi
        _press_enter
    done
}

# ╔══════════════════════════════════════════════════════════╗
#  [6] LOGS
# ╚══════════════════════════════════════════════════════════╝
handle_logs() {
    while true; do
        _banner
        echo -e "\n  ${W}${BOLD}── Logs del Servidor ────────────────────────────────${NC}\n"
        echo -e "  ${W}[1]${NC} Log del servidor ${DIM}(últimas 50 líneas)${NC}"
        echo -e "  ${W}[2]${NC} Log en tiempo real ${DIM}(tail -f)${NC}"
        echo -e "  ${W}[3]${NC} Log de errores"
        echo -e "  ${W}[4]${NC} Log del panel"
        echo -e "  ${W}[5]${NC} Limpiar log capturado"
        echo -e "  ${DIM}[0]${NC} Volver"
        echo ""; echo -e "  Selección: \c"; read -r opt

        local srv_log="$MTA_DIR/mods/deathmatch/logs/server.log"
        local err_log="$MTA_DIR/mods/deathmatch/logs/error.log"

        case "$opt" in
        1)
            clear
            echo -e "\n  ${Y}${BOLD}── Log del servidor ─────────────────────────────────${NC}\n"
            local lf="$srv_log"; [[ ! -f "$lf" ]] && lf="$MTA_LOG"
            if [[ -f "$lf" ]]; then
                tail -50 "$lf" | while read -r l; do echo -e "  ${DIM}$l${NC}"; done
            else
                _warn "Log no encontrado: $lf"
            fi
            _press_enter
            ;;
        2)
            clear
            echo -e "  ${DIM}Presiona Ctrl+C para salir.${NC}\n"
            local lf="$srv_log"; [[ ! -f "$lf" ]] && lf="$MTA_LOG"
            if [[ -f "$lf" ]]; then
                trap "trap - INT; return" INT
                tail -f "$lf" | while read -r l; do echo -e "  ${DIM}$l${NC}"; done &
                wait $! 2>/dev/null || true
                trap - INT
            else
                _warn "Log no encontrado."
                _press_enter
            fi
            ;;
        3)
            clear
            echo -e "\n  ${Y}${BOLD}── Log de errores ───────────────────────────────────${NC}\n"
            if [[ -f "$err_log" ]]; then
                tail -50 "$err_log" | while read -r l; do echo -e "  ${R}$l${NC}"; done
            else
                _warn "No hay log de errores en: $err_log"
            fi
            _press_enter
            ;;
        4)
            clear
            echo -e "\n  ${Y}${BOLD}── Log del panel ────────────────────────────────────${NC}\n"
            [[ -f "$PANEL_LOG" ]] && \
                tail -30 "$PANEL_LOG" | while read -r l; do echo -e "  ${DIM}$l${NC}"; done || \
                _warn "Sin registros."
            _press_enter
            ;;
        5)
            echo -e "  ${Y}¿Limpiar log capturado ($MTA_LOG)? [s/N]: \c"; read -r c
            [[ "${c,,}" == "s" ]] && > "$MTA_LOG" && _ok "Log limpiado."
            _press_enter
            ;;
        0) return ;;
        esac
    done
}

# ╔══════════════════════════════════════════════════════════╗
#  [7] CONFIGURACIÓN
# ╚══════════════════════════════════════════════════════════╝
handle_config() {
    while true; do
        _banner
        echo -e "\n  ${W}${BOLD}── Configuración ────────────────────────────────────${NC}\n"
        echo -e "  Directorio MTA : ${C}${MTA_DIR}${NC}"
        echo -e "  Ejecutable     : ${C}${MTA_BIN}${NC}"
        echo -e "  Screen name    : ${C}${MTA_SCREEN}${NC}"
        echo -e "  Versión panel  : ${DIM}${PANEL_VERSION}${NC}"
        echo ""
        echo -e "  ${W}[1]${NC} Cambiar directorio del servidor"
        echo -e "  ${W}[2]${NC} Cambiar nombre del screen"
        echo -e "  ${W}[3]${NC} Buscar ejecutable MTA automáticamente"
        echo -e "  ${W}[4]${NC} Ver screens activos"
        echo -e "  ${W}[5]${NC} Adjuntarse al screen MTA"
        echo -e "  ${W}[6]${NC} Actualizar panel desde GitHub"
        echo -e "  ${DIM}[0]${NC} Volver"
        echo ""; echo -e "  Selección: \c"; read -r opt

        case "$opt" in
        1)
            echo -e "  Nuevo directorio (actual: $MTA_DIR): \c"; read -r d
            if [[ -d "$d" ]]; then
                MTA_DIR="$d"
                { echo "MTA_DIR=\"$MTA_DIR\""; echo "MTA_BIN=\"$MTA_BIN\""; echo "MTA_SCREEN=\"$MTA_SCREEN\""; } \
                    > /etc/mtapanel/mta.conf
                _ok "Directorio actualizado: $d"
            else
                _err "Directorio no existe: $d"
            fi
            _press_enter
            ;;
        2)
            echo -e "  Nuevo nombre de screen (actual: $MTA_SCREEN): \c"; read -r s
            if [[ -n "$s" ]]; then
                MTA_SCREEN="$s"
                { echo "MTA_DIR=\"$MTA_DIR\""; echo "MTA_BIN=\"$MTA_BIN\""; echo "MTA_SCREEN=\"$MTA_SCREEN\""; } \
                    > /etc/mtapanel/mta.conf
                _ok "Screen name: $s"
            fi
            _press_enter
            ;;
        3)
            _info "Buscando ejecutable MTA..."
            local found; found=$(_find_mta_bin)
            if [[ -n "$found" ]]; then
                echo -e "\n  ${G}Encontrados:${NC}"
                local i=1
                while IFS= read -r f; do
                    echo -e "  ${W}[$i]${NC} $f"
                    (( i++ ))
                done <<< "$found"
                echo ""
                echo -e "  Número a usar (0 para cancelar): \c"; read -r n
                if [[ "$n" =~ ^[1-9]$ ]]; then
                    local sel; sel=$(echo "$found" | sed -n "${n}p")
                    if [[ -n "$sel" ]]; then
                        MTA_DIR=$(dirname "$sel")
                        MTA_BIN=$(basename "$sel")
                        { echo "MTA_DIR=\"$MTA_DIR\""; echo "MTA_BIN=\"$MTA_BIN\""; echo "MTA_SCREEN=\"$MTA_SCREEN\""; } \
                            > /etc/mtapanel/mta.conf
                        _ok "Configurado: $MTA_DIR/$MTA_BIN"
                    fi
                fi
            else
                _warn "No se encontró ningún ejecutable MTA."
            fi
            _press_enter
            ;;
        4)
            echo ""
            echo -e "  ${Y}Screens activos:${NC}"
            screen -list 2>/dev/null | while read -r l; do echo -e "  ${DIM}$l${NC}"; done
            _press_enter
            ;;
        5)
            if _mta_running; then
                echo -e "  ${DIM}Adjuntando... (Ctrl+A luego D para desadjuntarte)${NC}"
                sleep 1
                screen -r "$MTA_SCREEN"
            else
                _err "El servidor no está corriendo."
                _press_enter
            fi
            ;;
        6)
            _info "Actualizando panel desde GitHub..."
            local url="https://raw.githubusercontent.com/2025-0181-spec/MTAPANEL/main/panel.sh"
            if curl -fsSL --retry 3 -o /etc/mtapanel/panel.sh "$url" 2>/dev/null; then
                chmod +x /etc/mtapanel/panel.sh
                _ok "Panel actualizado. Reiniciando..."
                sleep 1
                exec bash /etc/mtapanel/panel.sh
            else
                _err "No se pudo descargar la actualización."
            fi
            _press_enter
            ;;
        0) return ;;
        esac
    done
}

# ╔══════════════════════════════════════════════════════════╗
#  MENÚ PRINCIPAL
# ╚══════════════════════════════════════════════════════════╝
main_menu() {
    command -v screen &>/dev/null || apt-get install -y -qq screen 2>/dev/null || true
    mkdir -p "$(dirname "$MTA_LOG")" "$(dirname "$PANEL_LOG")" 2>/dev/null || true

    while true; do
        _banner
        _status_bar

        echo -e "  ${W}[1]${NC} ${G}Iniciar servidor${NC}"
        echo -e "  ${W}[2]${NC} ${R}Detener servidor${NC}   ${DIM}(shutdown seguro)${NC}"
        echo -e "  ${W}[3]${NC} ${Y}Reiniciar servidor${NC}"
        echo -e "  ${W}[4]${NC} ${C}Consola en vivo${NC}    ${DIM}(output del server)${NC}"
        echo -e "  ${W}[5]${NC} ${C}Ejecutar comando${NC}   ${DIM}(en la consola MTA)${NC}"
        echo -e "  ${W}[6]${NC} Ver logs"
        echo -e "  ${W}[7]${NC} Configuración"
        echo -e "  ${DIM}[0]${NC} Salir"
        echo ""
        echo -e "  Selección: \c"; read -r opt

        case "$opt" in
            1) handle_start   ;;
            2) handle_stop    ;;
            3) handle_restart ;;
            4) handle_console ;;
            5) handle_command ;;
            6) handle_logs    ;;
            7) handle_config  ;;
            0) clear; echo -e "  ${DIM}Hasta luego.${NC}\n"; exit 0 ;;
        esac
    done
}

main_menu
