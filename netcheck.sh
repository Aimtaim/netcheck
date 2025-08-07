#!/bin/bash

# =============================================================================
# NetCheck - Netzwerkanalysetool für macOS
# Version: 2.0.0
# Autor: NetCheck Team
# Lizenz: MIT
# =============================================================================

set -euo pipefail

# Globale Variablen
readonly VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
readonly TEMP_DIR="/tmp/netcheck_$$"
readonly LOG_FILE="${TEMP_DIR}/netcheck.log"

# Sicherstellen dass temp dir existiert
mkdir -p "$TEMP_DIR"

# Cleanup beim Exit
cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# =============================================================================
# Module laden
# =============================================================================

source_module() {
    local module="$1"
    local module_path="${LIB_DIR}/${module}.sh"
    
    if [[ -f "$module_path" ]]; then
        # shellcheck source=/dev/null
        source "$module_path"
    else
        echo "FEHLER: Modul $module nicht gefunden: $module_path" >&2
        exit 1
    fi
}

# Core Module laden
source_module "core"
source_module "system" 
source_module "network"
source_module "fixes"
source_module "ui"
source_module "json"

# Konfiguration laden
if [[ -f "${CONFIG_DIR}/defaults.conf" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_DIR}/defaults.conf"
fi

# User Config laden falls vorhanden
if [[ -f "$HOME/.netcheck/config" ]]; then
    # shellcheck source=/dev/null  
    source "$HOME/.netcheck/config"
fi

# =============================================================================
# CLI Parameter verarbeiten
# =============================================================================

show_help() {
    cat << EOF
NetCheck v${VERSION} - Netzwerkanalysetool für macOS

VERWENDUNG:
    $0 [OPTIONEN]

OPTIONEN:
    -h, --help              Diese Hilfe anzeigen
    -v, --version           Version anzeigen
    -s, --silent            Stiller Modus (nur Zusammenfassung)
    -j, --json              JSON-Export aktivieren
    -f, --fix-only          Nur Reparaturen ausführen
    -r, --report-only       Nur Report erstellen, keine Fixes
    --no-color              Farbausgabe deaktivieren  
    --no-progress           Progress-Bars deaktivieren
    --accessible            Barrierefreier Modus
    --log-level LEVEL       Log-Level (DEBUG|INFO|WARN|ERROR)
    --timeout SECONDS       Timeout für Tests (Standard: 10)
    --config FILE           Eigene Konfigurationsdatei

BEISPIELE:
    $0                      Standard-Analyse
    $0 --json --silent      JSON-Report ohne Ausgabe
    $0 --fix-only           Nur bekannte Probleme reparieren
    
REMOTE VERWENDUNG:
    curl -s https://raw.githubusercontent.com/user/netcheck/main/netcheck.sh | bash
    bash <(curl -s https://raw.githubusercontent.com/user/netcheck/main/install.sh)

EOF
}

# Standardwerte
SILENT_MODE=false
JSON_MODE=false
FIX_ONLY=false 
REPORT_ONLY=false
NO_COLOR=false
NO_PROGRESS=false
ACCESSIBLE_MODE=false
LOG_LEVEL="INFO"
CUSTOM_TIMEOUT=10

# Parameter parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "NetCheck v${VERSION}"
            exit 0
            ;;
        -s|--silent)
            SILENT_MODE=true
            shift
            ;;
        -j|--json)
            JSON_MODE=true
            shift
            ;;
        -f|--fix-only)
            FIX_ONLY=true
            shift
            ;;
        -r|--report-only)
            REPORT_ONLY=true
            shift
            ;;
        --no-color)
            NO_COLOR=true
            shift
            ;;
        --no-progress)
            NO_PROGRESS=true
            shift
            ;;
        --accessible)
            ACCESSIBLE_MODE=true
            NO_COLOR=true
            shift
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --timeout)
            CUSTOM_TIMEOUT="$2"
            shift 2
            ;;
        --config)
            if [[ -f "$2" ]]; then
                # shellcheck source=/dev/null
                source "$2"
            else
                die "Konfigurationsdatei nicht gefunden: $2"
            fi
            shift 2
            ;;
        *)
            echo "Unbekannte Option: $1" >&2
            echo "Verwenden Sie --help für Hilfe" >&2
            exit 1
            ;;
    esac
done

# Environment Variable Overrides
[[ -n "${NETCHECK_SILENT:-}" ]] && SILENT_MODE=true
[[ -n "${NETCHECK_JSON:-}" ]] && JSON_MODE=true
[[ -n "${NETCHECK_TIMEOUT:-}" ]] && CUSTOM_TIMEOUT="${NETCHECK_TIMEOUT}"
[[ -n "${NO_COLOR:-}" ]] && NO_COLOR=true

# =============================================================================
# Hauptfunktion
# =============================================================================

main() {
    # Frühe Farbinitialisierung für Fehlerbehandlung
    if [[ -t 1 ]] && [[ "$NO_COLOR" != true ]] && command -v tput >/dev/null 2>&1; then
        local colors=$(tput colors 2>/dev/null || echo 0)
        if [[ $colors -ge 8 ]]; then
            RED='\033[0;31m'
            GREEN='\033[0;32m'
            YELLOW='\033[1;33m'
            BLUE='\033[0;34m'
            NC='\033[0m'
        fi
    fi
    
    # System Kompatibilität prüfen
    if ! is_macos; then
        echo -e "${YELLOW}⚠️  WARNUNG: NetCheck ist für macOS optimiert, läuft aber auch auf anderen Unix-Systemen${NC}"
        echo "Einige Features könnten nicht verfügbar sein oder anders funktionieren."
        echo
        
        # Kurze Pause für User-Aufmerksamkeit
        if [[ "$SILENT_MODE" != true ]]; then
            sleep 2
        fi
    fi
    
    if ! check_macos_version; then
        echo -e "${YELLOW}⚠️  Alte macOS-Version erkannt. Einige Features sind möglicherweise nicht verfügbar.${NC}"
        if [[ "$SILENT_MODE" != true ]]; then
            sleep 1
        fi
    fi
    
    # UI initialisieren
    ui_init
    
    # Logging starten
    log_init "$LOG_FILE" "$LOG_LEVEL"
    
    log_info "NetCheck v${VERSION} gestartet"
    log_info "Parameter: silent=$SILENT_MODE, json=$JSON_MODE, fix_only=$FIX_ONLY"
    
    # JSON Output initialisieren falls erforderlich
    if [[ "$JSON_MODE" == true ]]; then
        json_init
    fi
    
    # Header anzeigen (außer im Silent Mode)
    if [[ "$SILENT_MODE" != true ]]; then
        ui_show_header "$VERSION"
    fi
    
    # Fix-Only Modus
    if [[ "$FIX_ONLY" == true ]]; then
        log_info "Fix-Only Modus aktiv"
        fixes_run_all
        exit 0
    fi
    
    # System-Informationen sammeln
    system_gather_info
    
    # Netzwerk-Diagnostik durchführen
    local test_results
    test_results=$(network_run_diagnostics)
    
    # Ergebnisse verarbeiten
    local issues
    issues=$(parse_test_results "$test_results")
    
    # Report erstellen
    if [[ "$JSON_MODE" == true ]]; then
        json_generate_report "$test_results" "$issues"
    else
        ui_show_results "$test_results" "$issues"
    fi
    
    # Auto-Fixes anbieten (außer im Report-Only Modus)
    if [[ "$REPORT_ONLY" != true ]] && [[ ${#issues[@]} -gt 0 ]]; then
        fixes_offer_solutions "$issues"
    fi
    
    # Cleanup
    log_info "NetCheck abgeschlossen"
    
    if [[ "$SILENT_MODE" != true ]] && [[ "$JSON_MODE" != true ]]; then
        ui_show_footer "$LOG_FILE"
    fi
}

# Script ausführen
main "$@"
