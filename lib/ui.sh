#!/bin/bash

# =============================================================================
# NetCheck UI - User Interface und visuelle Darstellung
# =============================================================================

# UI-Konfiguration basierend auf Terminal-Features
declare -A UI_CONFIG=(
)

# UI_CONFIG sofort mit allen Keys initialisieren
UI_CONFIG[use_colors]="false"
UI_CONFIG[use_unicode]="false"
UI_CONFIG[width]="80"
UI_CONFIG[use_progress]="true"

# =============================================================================
# UI Initialisierung
# =============================================================================

ui_init() {
    # Terminal-Features erkennen und UI entsprechend konfigurieren
    # Funktion zur Farbunterstützung prüfen
    local supports_color=false
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        local colors=$(tput colors 2>/dev/null || echo 0)
        if [[ $colors -ge 8 ]] && [[ "$NO_COLOR" != true ]]; then
            supports_color=true
        fi
    fi
    
    if [[ "$supports_color" == true ]]; then
        # Farben definieren
        readonly RED='\033[0;31m'
        readonly GREEN='\033[0;32m'
        readonly YELLOW='\033[1;33m'
        readonly BLUE='\033[0;34m'
        readonly PURPLE='\033[0;35m'
        readonly CYAN='\033[0;36m'
        readonly WHITE='\033[1;37m'
        readonly GRAY='\033[0;90m'
        readonly NC='\033[0m'
        readonly BOLD='\033[1m'
        readonly DIM='\033[2m'
        
        UI_CONFIG[use_colors]="true"
    else
        # Keine Farben
        readonly RED=''
        readonly GREEN=''
        readonly YELLOW=''
        readonly BLUE=''
        readonly PURPLE=''
        readonly CYAN=''
        readonly WHITE=''
        readonly GRAY=''
        readonly NC=''
        readonly BOLD=''
        readonly DIM=''
        
        UI_CONFIG[use_colors]="false"
    fi
    
    # Icons basierend auf Unicode-Unterstützung
    if [[ "${SYSTEM_INFO[supports_unicode]}" == "true" ]] && [[ "$ACCESSIBLE_MODE" != true ]]; then
        readonly ICON_CHECK="✓"
        readonly ICON_ERROR="✗"
        readonly ICON_WARNING="⚠"
        readonly ICON_INFO="ℹ"
        readonly ICON_ARROW="→"
        readonly ICON_GEAR="⚙"
        readonly ICON_WIFI="📶"
        readonly ICON_NETWORK="🌐"
        readonly ICON_ROCKET="🚀"
        readonly ICON_WRENCH="🔧"
        readonly ICON_SPARKLES="✨"
        
        UI_CONFIG[use_unicode]="true"
    else
        # ASCII Fallback
        readonly ICON_CHECK="[OK]"
        readonly ICON_ERROR="[!!]"
        readonly ICON_WARNING="[**]"
        readonly ICON_INFO="[--]"
        readonly ICON_ARROW="-->"
        readonly ICON_GEAR="[*]"
        readonly ICON_WIFI="WiFi"
        readonly ICON_NETWORK="Net"
        readonly ICON_ROCKET="[^]"
        readonly ICON_WRENCH="[+]"
        readonly ICON_SPARKLES="[*]"
        
        UI_CONFIG[use_unicode]="false"
    fi
    
    # Terminal-Breite für Layout
    UI_CONFIG[width]="${SYSTEM_INFO[terminal_width]}"
    UI_CONFIG[use_progress]="${SYSTEM_INFO[supports_progress]}"
    
    log_debug "UI initialisiert: Farben=${UI_CONFIG[use_colors]}, Unicode=${UI_CONFIG[use_unicode]}, Breite=${UI_CONFIG[width]}"
}

# =============================================================================
# Header und Footer
# =============================================================================

ui_show_header() {
    local version="$1"
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "NetCheck v${version} - Netzwerkanalyse für macOS"
        echo "System: ${SYSTEM_INFO[model]} (${SYSTEM_INFO[os_version]})"
        echo "Gestartet: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "----------------------------------------"
        return
    fi
    
    local width="${UI_CONFIG[width]}"
    if [[ $width -lt 70 ]]; then
        # Kompakte Version für schmale Terminals
        echo -e "${CYAN}┌─────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}${BOLD}        NetCheck v${version}         ${NC}${CYAN}│${NC}"
        echo -e "${CYAN}│${GRAY}    Netzwerkanalyse für macOS     ${NC}${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────┘${NC}"
    else
        # Vollständige Version
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}${BOLD}                        NetCheck v${version}                           ${NC}${CYAN}│${NC}"
        echo -e "${CYAN}│${GRAY}                   Netzwerkanalyse für macOS                    ${NC}${CYAN}│${NC}"
        echo -e "${CYAN}│${DIM}        ${SYSTEM_INFO[model]} • ${SYSTEM_INFO[os_version]} • $(date '+%H:%M:%S')        ${NC}${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
    fi
    echo
}

ui_show_footer() {
    local log_file="$1"
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "----------------------------------------"
        echo "NetCheck abgeschlossen"
        echo "Log-Datei: $log_file"
        echo "Support: github.com/netcheck/netcheck"
        return
    fi
    
    echo
    echo -e "${GRAY}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GRAY}│${DIM}  Log: $(basename "$log_file")${NC}${GRAY}${DIM}                           Support: github.com/netcheck/netcheck  ${NC}${GRAY}│${NC}"
    echo -e "${GRAY}└─────────────────────────────────────────────────────────────────┘${NC}"
}

# =============================================================================
# Test Progress Anzeige
# =============================================================================

ui_show_test_progress() {
    local current="$1"
    local total="$2"
    local test_name="$3"
    
    # Test-Namen humanisieren
    local display_name
    case "$test_name" in
        "test_network_interfaces") display_name="Netzwerk-Interfaces prüfen" ;;
        "test_wifi_connection") display_name="WiFi-Verbindung analysieren" ;;
        "test_internet_connectivity") display_name="Internet-Erreichbarkeit testen" ;;
        "test_dns_resolution") display_name="Website-Namen auflösen" ;;
        "test_gateway_reachability") display_name="Router-Verbindung prüfen" ;;
        "test_network_speed") display_name="Geschwindigkeit messen" ;;
        "test_firewall_status") display_name="Sicherheits-Einstellungen" ;;
        "test_proxy_settings") display_name="Proxy-Konfiguration" ;;
        *) display_name="$test_name" ;;
    esac
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "[$current/$total] $display_name..."
        return
    fi
    
    printf "${BLUE}[${WHITE}%d${BLUE}/${WHITE}%d${BLUE}]${NC} %s" "$current" "$total" "$display_name"
    
    # Progress bar falls aktiviert
    if [[ "${UI_CONFIG[use_progress]}" == "true" ]]; then
        show_progress_bar 1.5 ""
    else
        echo " ..."
    fi
}

show_progress_bar() {
    local duration="$1"
    local message="$2"
    local width=30
    
    if [[ "$ACCESSIBLE_MODE" == true ]] || [[ "${UI_CONFIG[use_progress]}" != "true" ]]; then
        sleep "$duration"
        echo -e " ${GREEN}${ICON_CHECK}${NC}"
        return
    fi
    
    echo -n " ["
    
    for ((i=0; i<=width; i++)); do
        printf "█"
        sleep $(echo "scale=3; $duration/$width" | bc -l 2>/dev/null || echo "0.05")
    done
    
    echo -e "] ${GREEN}${ICON_CHECK}${NC}"
}

# =============================================================================
# Ergebnisse anzeigen
# =============================================================================

ui_show_results() {
    local test_results="$1"
    local issues_json="$2"
    
    echo
    ui_show_results_summary "$test_results"
    
    if command -v jq &> /dev/null; then
        local issues_count
        issues_count=$(echo "$issues_json" | jq 'length' 2>/dev/null || echo "0")
        
        if [[ $issues_count -gt 0 ]]; then
            ui_show_issues "$issues_json"
        else
            ui_show_success
        fi
    else
        # Fallback ohne jq
        if [[ ${#NETCHECK_ISSUES[@]} -gt 0 ]]; then
            ui_show_issues_fallback
        else
            ui_show_success
        fi
    fi
}

ui_show_results_summary() {
    local results="$1"
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "========== TESTERGEBNISSE =========="
        return
    fi
    
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}${BOLD}                          TESTERGEBNISSE                         ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    # Test-Ergebnisse durchgehen und Status anzeigen
    if command -v jq &> /dev/null; then
        while IFS= read -r result; do
            local test_name status message
            test_name=$(echo "$result" | jq -r '.test')
            status=$(echo "$result" | jq -r '.status')
            message=$(echo "$result" | jq -r '.message')
            
            ui_show_test_result "$test_name" "$status" "$message"
        done < <(echo "$results" | jq -c '.[]' 2>/dev/null || echo "")
    fi
}

ui_show_test_result() {
    local test_name="$1"
    local status="$2" 
    local message="$3"
    
    # Test-Namen humanisieren
    local display_name
    case "$test_name" in
        "network_interfaces") display_name="Netzwerk-Interfaces" ;;
        "wifi_connection") display_name="WiFi-Verbindung" ;;
        "internet_connectivity") display_name="Internet-Zugang" ;;
        "dns_resolution") display_name="Website-Namen" ;;
        "gateway_reachability") display_name="Router-Verbindung" ;;
        "network_speed") display_name="Geschwindigkeit" ;;
        "firewall_status") display_name="Firewall" ;;
        "proxy_settings") display_name="Proxy-Einstellungen" ;;
        *) display_name="$test_name" ;;
    esac
    
    local icon color
    case "$status" in
        "ok")
            icon="$ICON_CHECK"
            color="$GREEN"
            ;;
        "warning")
            icon="$ICON_WARNING"
            color="$YELLOW"
            ;;
        "error"|"critical")
            icon="$ICON_ERROR"
            color="$RED"
            ;;
        "skip")
            icon="$ICON_INFO"
            color="$GRAY"
            ;;
        *)
            icon="$ICON_INFO"
            color="$CYAN"
            ;;
    esac
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "$display_name: $message"
    else
        printf "  %s%s%s %-20s %s\n" "$color" "$icon" "$NC" "$display_name" "$message"
    fi
}

# =============================================================================
# Issues anzeigen
# =============================================================================

ui_show_issues() {
    local issues_json="$1"
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo
        echo "========== GEFUNDENE PROBLEME =========="
        return
    fi
    
    local issues_count
    issues_count=$(echo "$issues_json" | jq 'length' 2>/dev/null || echo "0")
    
    echo
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│${WHITE}${BOLD}                  GEFUNDENE PROBLEME (${issues_count})                     ${NC}${YELLOW}│${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    local i=1
    while IFS= read -r issue; do
        local description severity category
        description=$(echo "$issue" | jq -r '.description')
        severity=$(echo "$issue" | jq -r '.severity')
        category=$(echo "$issue" | jq -r '.category')
        
        ui_show_single_issue "$i" "$severity" "$category" "$description"
        ((i++))
    done < <(echo "$issues_json" | jq -c '.[]' 2>/dev/null || echo "")
}

ui_show_issues_fallback() {
    echo
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│${WHITE}${BOLD}                  GEFUNDENE PROBLEME (${#NETCHECK_ISSUES[@]})                     ${NC}${YELLOW}│${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    local i=1
    for issue in "${NETCHECK_ISSUES[@]}"; do
        # Einfaches Parsen ohne jq
        if [[ "$issue" =~ \"description\":\"([^\"]*) ]]; then
            local description="${BASH_REMATCH[1]}"
            ui_show_single_issue "$i" "warning" "general" "$description"
        fi
        ((i++))
    done
}

ui_show_single_issue() {
    local number="$1"
    local severity="$2"
    local category="$3" 
    local description="$4"
    
    local icon color
    case "$severity" in
        "critical")
            icon="$ICON_ERROR"
            color="$RED"
            ;;
        "warning")
            icon="$ICON_WARNING"
            color="$YELLOW"
            ;;
        "info")
            icon="$ICON_INFO"
            color="$CYAN"
            ;;
        *)
            icon="$ICON_WARNING"
            color="$YELLOW"
            ;;
    esac
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "${number}. $description"
    else
        echo -e "${color}${number}.${NC} ${icon} ${description}"
    fi
}

# =============================================================================
# Success Screen
# =============================================================================

ui_show_success() {
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo
        echo "========== ALLE TESTS BESTANDEN =========="
        echo "Ihr Netzwerk funktioniert einwandfrei!"
        return
    fi
    
    echo
    echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${WHITE}${BOLD}                     ALLE TESTS BESTANDEN!                      ${NC}${GREEN}│${NC}"
    echo -e "${GREEN}│${GRAY}               Ihr Netzwerk funktioniert einwandfrei             ${NC}${GREEN}│${NC}"
    echo -e "${GREEN}│${DIM}                            ${ICON_ROCKET}${ICON_SPARKLES}${ICON_ROCKET}                              ${NC}${GREEN}│${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────────────┘${NC}"
}

# =============================================================================
# Fixes UI
# =============================================================================

ui_show_fixes_header() {
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo
        echo "========== LÖSUNGSVORSCHLÄGE =========="
        return
    fi
    
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}${BOLD}                    LÖSUNGSVORSCHLÄGE                           ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────┘${NC}"
}

ui_ask_permission() {
    local question="$1"
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "$question [j/N]"
        return
    fi
    
    echo -e "${PURPLE}${ICON_GEAR} $question [${WHITE}j${PURPLE}/${WHITE}N${PURPLE}]${NC}"
}

ui_show_fixes_progress_start() {
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo
        echo "========== REPARATUREN WERDEN AUSGEFÜHRT =========="
        return
    fi
    
    echo
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE}${BOLD}                  AUTOMATISCHE REPARATUREN                      ${NC}${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo
}

ui_show_fix_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    
    if [[ "$ACCESSIBLE_MODE" == true ]]; then
        echo "[$current/$total] $description..."
        return
    fi
    
    echo -e "${CYAN}${ICON_GEAR}${NC} [$current/$total] $description..."
}

# =============================================================================
# Utility Functions
# =============================================================================

ui_clear_screen() {
    if [[ "$ACCESSIBLE_MODE" != true ]]; then
        clear
    fi
}

ui_pause() {
    if [[ "$ACCESSIBLE_MODE" != true ]] && [[ -t 0 ]]; then
        echo -e "${GRAY}Drücken Sie eine beliebige Taste zum Fortfahren...${NC}"
        read -r -n 1
        echo
    fi
}

# Wrapper für Benutzer-freundliche Nachrichten
ui_humanize_message() {
    local technical_message="$1"
    
    # Technische Begriffe durch verständliche ersetzen
    local friendly_message="$technical_message"
    
    friendly_message="${friendly_message//DNS/Website-Namen}"
    friendly_message="${friendly_message//Gateway/Router}"
    friendly_message="${friendly_message//Interface/Netzwerk-Anschluss}"
    friendly_message="${friendly_message//DHCP/automatische Netzwerk-Einstellung}"
    friendly_message="${friendly_message//Ping/Erreichbarkeitstest}"
    friendly_message="${friendly_message//Timeout/Zeitüberschreitung}"
    
    echo "$friendly_message"
}
