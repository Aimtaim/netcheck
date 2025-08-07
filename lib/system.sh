#!/bin/bash

# =============================================================================
# NetCheck System - System-Erkennung und Kompatibilität (LINUX-FIX)
# =============================================================================

# System-Info Array initialisieren
declare -A SYSTEM_INFO=(
    [hostname]=""
    [os_version]="unknown"
    [architecture]="unknown"
    [model]="unknown"
    [uptime]="unknown"
    [os_major]="0"
    [os_minor]="0"
    [primary_interface]="unknown"
    [wifi_interfaces]="unknown"
    [ethernet_interfaces]="unknown"
    [all_interfaces]="unknown"
    [terminal_width]="80"
    [supports_color]="false"
    [supports_unicode]="false"
    [supports_progress]="true"
)

# =============================================================================
# System-Informationen sammeln
# =============================================================================

system_gather_info() {
    log_info "Sammle System-Informationen..."
    
    # Hostname
    SYSTEM_INFO[hostname]=$(hostname 2>/dev/null || echo "unknown")
    
    # OS Version
    if is_macos; then
        SYSTEM_INFO[os_version]=$(sw_vers -productVersion 2>/dev/null || echo "macOS-unknown")
        SYSTEM_INFO[model]=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | cut -d: -f2 | xargs || echo "Mac")
        
        # macOS Version parsen
        local version="${SYSTEM_INFO[os_version]}"
        if [[ "$version" =~ ^([0-9]+)\.([0-9]+) ]]; then
            SYSTEM_INFO[os_major]="${BASH_REMATCH[1]}"
            SYSTEM_INFO[os_minor]="${BASH_REMATCH[2]}"
        fi
    else
        # Linux
        if [[ -f /etc/os-release ]]; then
            SYSTEM_INFO[os_version]=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Linux")
        else
            SYSTEM_INFO[os_version]=$(uname -sr 2>/dev/null || echo "Linux")
        fi
        
        SYSTEM_INFO[model]=$(uname -m 2>/dev/null || echo "Linux-System")
        SYSTEM_INFO[os_major]="0"
        SYSTEM_INFO[os_minor]="0"
    fi
    
    # Architektur
    SYSTEM_INFO[architecture]=$(uname -m 2>/dev/null || echo "unknown")
    
    # Uptime
    if command -v uptime >/dev/null 2>&1; then
        SYSTEM_INFO[uptime]=$(uptime 2>/dev/null | cut -d',' -f1 | sed 's/.*up //' || echo "unknown")
    else
        SYSTEM_INFO[uptime]="unknown"
    fi
    
    # Netzwerk-Interfaces sammeln
    gather_network_interfaces
    
    # Terminal-Features
    detect_terminal_features
    
    log_info "System-Info: ${SYSTEM_INFO[os_version]} auf ${SYSTEM_INFO[architecture]}"
}

# =============================================================================
# Netzwerk-Interfaces
# =============================================================================

gather_network_interfaces() {
    local all_interfaces=()
    local wifi_interfaces=()
    local ethernet_interfaces=()
    
    if is_macos; then
        # macOS Interface-Erkennung
        while IFS= read -r line; do
            if [[ "$line" =~ Hardware\ Port:\ Wi-Fi.*Device:\ (.*) ]]; then
                local interface="${BASH_REMATCH[1]}"
                wifi_interfaces+=("$interface")
                all_interfaces+=("$interface")
                
                if [[ -z "${SYSTEM_INFO[primary_interface]}" ]] && is_interface_active "$interface"; then
                    SYSTEM_INFO[primary_interface]="$interface"
                fi
            elif [[ "$line" =~ Hardware\ Port:\ Ethernet.*Device:\ (.*) ]]; then
                local interface="${BASH_REMATCH[1]}"
                ethernet_interfaces+=("$interface")
                all_interfaces+=("$interface")
                
                if [[ -z "${SYSTEM_INFO[primary_interface]}" ]] && is_interface_active "$interface"; then
                    SYSTEM_INFO[primary_interface]="$interface"
                fi
            fi
        done < <(networksetup -listallhardwareports 2>/dev/null || echo "")
    else
        # Linux Interface-Erkennung
        for interface in /sys/class/net/*; do
            if [[ -d "$interface" ]]; then
                local iface_name=$(basename "$interface")
                
                # Skip loopback
                [[ "$iface_name" == "lo" ]] && continue
                
                all_interfaces+=("$iface_name")
                
                # WiFi vs Ethernet unterscheiden
                if [[ "$iface_name" =~ ^(wlan|wlp|wifi|wlo) ]] || [[ -d "$interface/wireless" ]]; then
                    wifi_interfaces+=("$iface_name")
                elif [[ "$iface_name" =~ ^(eth|enp|eno|ens) ]]; then
                    ethernet_interfaces+=("$iface_name")
                fi
                
                # Primary Interface setzen (erstes aktives)
                if [[ -z "${SYSTEM_INFO[primary_interface]}" ]] && is_interface_active "$iface_name"; then
                    SYSTEM_INFO[primary_interface]="$iface_name"
                fi
            fi
        done
    fi
    
    # Arrays zu Strings
    SYSTEM_INFO[all_interfaces]=$(IFS=','; echo "${all_interfaces[*]}")
    SYSTEM_INFO[wifi_interfaces]=$(IFS=','; echo "${wifi_interfaces[*]}")
    SYSTEM_INFO[ethernet_interfaces]=$(IFS=','; echo "${ethernet_interfaces[*]}")
    
    # Fallback für Primary Interface
    if [[ -z "${SYSTEM_INFO[primary_interface]}" ]] && [[ ${#all_interfaces[@]} -gt 0 ]]; then
        SYSTEM_INFO[primary_interface]="${all_interfaces[0]}"
    fi
    
    log_debug "Gefundene Interfaces: ${SYSTEM_INFO[all_interfaces]}"
    log_debug "Primary Interface: ${SYSTEM_INFO[primary_interface]}"
}

# =============================================================================
# Terminal-Features erkennen
# =============================================================================

detect_terminal_features() {
    # Terminal-Breite
    if command -v tput >/dev/null 2>&1; then
        SYSTEM_INFO[terminal_width]=$(tput cols 2>/dev/null || echo "80")
    else
        SYSTEM_INFO[terminal_width]="80"
    fi
    
    # Farb-Unterstützung
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        local colors=$(tput colors 2>/dev/null || echo "0")
        if [[ "$colors" -ge 8 ]] && [[ "${NO_COLOR:-}" != "true" ]]; then
            SYSTEM_INFO[supports_color]="true"
        fi
    fi
    
    # Unicode-Unterstützung (einfache Heuristik)
    if [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]]; then
        SYSTEM_INFO[supports_unicode]="true"
    fi
    
    # Progress-Bar Unterstützung
    if [[ -t 1 ]] && [[ "${SYSTEM_INFO[terminal_width]}" -gt 60 ]]; then
        SYSTEM_INFO[supports_progress]="true"
    else
        SYSTEM_INFO[supports_progress]="false"
    fi
}

# =============================================================================
# Plattform-Erkennung
# =============================================================================

is_macos() {
    [[ "$OSTYPE" == "darwin"* ]] || [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]
}

is_linux() {
    [[ "$OSTYPE" == "linux"* ]] || [[ "$(uname -s 2>/dev/null)" == "Linux" ]] || [[ ! "$OSTYPE" == "darwin"* && -f /etc/os-release ]]
}

check_macos_version() {
    if ! is_macos; then
        return 0  # Für Non-macOS immer OK
    fi
    
    local version="${SYSTEM_INFO[os_version]}"
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+) ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        
        # macOS 10.13+ erforderlich
        if [[ "$major" -gt 10 ]] || [[ "$major" -eq 10 && "$minor" -ge 13 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# =============================================================================
# Tool-Verfügbarkeit
# =============================================================================

supports_modern_wifi_api() {
    if ! is_macos; then
        return 1  # Linux hat andere WiFi-APIs
    fi
    
    command -v wdutil >/dev/null 2>&1
}

get_legacy_wifi_tool() {
    local airport_paths=(
        "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        "/usr/local/bin/airport"
    )
    
    for path in "${airport_paths[@]}"; do
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# =============================================================================
# Interface-Hilfsfunktionen  
# =============================================================================

is_interface_active() {
    local interface="$1"
    
    if [[ -z "$interface" ]]; then
        return 1
    fi
    
    if is_macos; then
        ifconfig "$interface" 2>/dev/null | grep -q "status: active"
    else
        # Linux: Interface ist "up" und hat IP
        if command -v ip >/dev/null 2>&1; then
            ip link show "$interface" 2>/dev/null | grep -q "state UP"
        elif command -v ifconfig >/dev/null 2>&1; then
            ifconfig "$interface" 2>/dev/null | grep -q "UP.*RUNNING"
        else
            return 0
        fi
    fi
}

# =============================================================================
# System-spezifische Varianten
# =============================================================================

parse_test_results() {
    local test_results="$1"
    
    # Issues aus Testergebnissen extrahieren
    if command -v jq >/dev/null 2>&1; then
        echo "$test_results" | jq '[.[] | select(.status == "error" or .status == "critical" or .status == "warning")]' 2>/dev/null || echo "[]"
    else
        # Fallback ohne jq
        local issues_json="["
        local first=true
        
        for issue in "${NETCHECK_ISSUES[@]}"; do
            if [[ "$first" != "true" ]]; then
                issues_json+=","
            fi
            issues_json+="$issue"
            first=false
        done
        
        issues_json+="]"
        echo "$issues_json"
    fi
}

# =============================================================================
# Debug-Informationen
# =============================================================================

system_debug_info() {
    if [[ "${LOG_LEVEL}" == "DEBUG" ]]; then
        log_debug "=== SYSTEM DEBUG ==="
        for key in "${!SYSTEM_INFO[@]}"; do
            log_debug "SYSTEM_INFO[$key]=${SYSTEM_INFO[$key]}"
        done
        log_debug "===================="
    fi
}
