#!/bin/bash

# =============================================================================
# NetCheck System - Systemerkennung und Kompatibilität
# =============================================================================

# System-Informationen
declare -A SYSTEM_INFO

# =============================================================================
# macOS Erkennung und Kompatibilität
# =============================================================================

is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

check_macos_version() {
    # Auch auf Non-macOS basic info sammeln
    if ! is_macos; then
        local os_version="$(uname -r || echo 'unknown')"
        SYSTEM_INFO[os_version]="$os_version"
        # Für Non-macOS: Verwende sichere Standardwerte
        SYSTEM_INFO[os_major]="1"
        SYSTEM_INFO[os_minor]="0"
        log_info "Non-macOS System erkannt: $(uname -s) $os_version"
        return 0
    fi
    
    local os_version="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
    local major="$(echo "$os_version" | cut -d. -f1 || echo '0')"
    local minor="$(echo "$os_version" | cut -d. -f2 || echo '0')"
    
    # macOS 10.13 oder neuer erforderlich
    if [[ "${major:-0}" -eq 10 && "${minor:-0}" -lt 13 ]] || [[ "${major:-0}" -lt 10 ]]; then
        log_warn "Alte macOS Version: $os_version (empfohlen: 10.13+)"
        return 0
    fi
    
    SYSTEM_INFO[os_version]="$os_version"
    SYSTEM_INFO[os_major]="$major"
    SYSTEM_INFO[os_minor]="$minor"
    
    log_info "macOS Version erkannt: $os_version"
    return 0
}

get_macos_codename() {
    local os_version="${SYSTEM_INFO[os_version]:-'unknown'}"
    local major="${SYSTEM_INFO[os_major]:-1}"
    local minor="${SYSTEM_INFO[os_minor]:-0}"
    
    # Nur für macOS Codenamen
    if ! is_macos; then
        echo "Non-macOS ($(uname -s))"
        return
    fi
    
    if [[ "${major:-1}" -ge 11 ]]; then
        case "${major:-1}" in
            14) echo "Sonoma" ;;
            13) echo "Ventura" ;;
            12) echo "Monterey" ;;
            11) echo "Big Sur" ;;
            *) echo "Unknown ($os_version)" ;;
        esac
    else
        case "${major:-1}.${minor:-0}" in
            10.15) echo "Catalina" ;;
            10.14) echo "Mojave" ;;
            10.13) echo "High Sierra" ;;
            *) echo "Unknown ($os_version)" ;;
        esac
    fi
}

# =============================================================================
# System-Informationen sammeln
# =============================================================================

system_gather_info() {
    log_info "Sammle System-Informationen..."
    
    # Variablen initialisieren
    local hostname username uptime architecture
    local model cpu memory
    
    # Basic System Info
    hostname=$(hostname 2>/dev/null || echo "unknown")
    username=$(whoami 2>/dev/null || echo "unknown")
    uptime=$(uptime 2>/dev/null | awk '{print $3,$4}' | sed 's/,//' || echo "unknown")
    architecture=$(uname -m 2>/dev/null || echo "unknown")
    
    SYSTEM_INFO[hostname]="$hostname"
    SYSTEM_INFO[username]="$username"
    SYSTEM_INFO[uptime]="$uptime"
    SYSTEM_INFO[architecture]="$architecture"
    
    # Hardware Info
    if command -v system_profiler &> /dev/null; then
        model=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | cut -d: -f2 | trim || echo "Unknown")
        SYSTEM_INFO[model]="${model:-Unknown}"
        
        cpu=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Processor Name" | cut -d: -f2 | trim || echo "Unknown")
        SYSTEM_INFO[cpu]="${cpu:-Unknown}"
        
        memory=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Memory" | cut -d: -f2 | trim || echo "Unknown")
        SYSTEM_INFO[memory]="${memory:-Unknown}"
    else
        log_warn "system_profiler nicht verfügbar, Hardware-Info begrenzt"
        SYSTEM_INFO[model]="Unknown"
        SYSTEM_INFO[cpu]="Unknown"
        SYSTEM_INFO[memory]="Unknown"
    fi
    
    # Terminal Capabilities
    detect_terminal_capabilities
    
    # Netzwerk Interfaces
    detect_network_interfaces
    
    log_info "System-Info gesammelt: ${SYSTEM_INFO[model]} (${SYSTEM_INFO[os_version]})"
}

detect_terminal_capabilities() {
    # Variablen initialisieren
    local terminal_width terminal_height
    
    # Farben
    if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "$NO_COLOR" != true ]]; then
        SYSTEM_INFO[supports_color]="true"
    else
        SYSTEM_INFO[supports_color]="false"
    fi
    
    # Unicode
    if [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]]; then
        SYSTEM_INFO[supports_unicode]="true"
    else
        SYSTEM_INFO[supports_unicode]="false"
    fi
    
    # Progress Bars
    if [[ -t 1 ]] && [[ "$NO_PROGRESS" != true ]]; then
        SYSTEM_INFO[supports_progress]="true"
    else
        SYSTEM_INFO[supports_progress]="false"
    fi
    
    # Terminal Größe
    if command -v tput &> /dev/null; then
        terminal_width=$(tput cols 2>/dev/null || echo "80")
        terminal_height=$(tput lines 2>/dev/null || echo "24")
        SYSTEM_INFO[terminal_width]="$terminal_width"
        SYSTEM_INFO[terminal_height]="$terminal_height"
    else
        SYSTEM_INFO[terminal_width]="80"
        SYSTEM_INFO[terminal_height]="24"
    fi
    
    log_debug "Terminal: Farben=${SYSTEM_INFO[supports_color]}, Unicode=${SYSTEM_INFO[supports_unicode]}, Größe=${SYSTEM_INFO[terminal_width]}x${SYSTEM_INFO[terminal_height]}"
}

detect_network_interfaces() {
    local interfaces=()
    local wifi_interfaces=()
    local ethernet_interfaces=()
    local port_name device
    
    # Alle Hardware Ports scannen
    if command -v networksetup &> /dev/null; then
        while IFS= read -r line; do
            if [[ "$line" =~ Hardware\ Port:\ (.*)$ ]]; then
                port_name="${BASH_REMATCH[1]}"
                read -r device_line
                if [[ "$device_line" =~ Device:\ (.*)$ ]]; then
                    device="${BASH_REMATCH[1]}"
                    interfaces+=("$device")
                    
                    if [[ "$port_name" =~ Wi-Fi|AirPort ]]; then
                        wifi_interfaces+=("$device")
                    elif [[ "$port_name" =~ Ethernet|Thunderbolt|USB ]]; then
                        ethernet_interfaces+=("$device")
                    fi
                fi
            fi
        done < <(networksetup -listallhardwareports 2>/dev/null || echo "")
    else
        # Fallback für Non-macOS: Verwende Standard-Interfaces
        for iface in eth0 eth1 wlan0 wlan1 enp0s3 enp0s8; do
            if [[ -d "/sys/class/net/$iface" ]]; then
                interfaces+=("$iface")
                if [[ "$iface" =~ wlan|wlp ]]; then
                    wifi_interfaces+=("$iface")
                else
                    ethernet_interfaces+=("$iface")
                fi
            fi
        done
    fi
    
    # Als komma-separierte Strings speichern
    SYSTEM_INFO[all_interfaces]=$(IFS=','; echo "${interfaces[*]}")
    SYSTEM_INFO[wifi_interfaces]=$(IFS=','; echo "${wifi_interfaces[*]}")
    SYSTEM_INFO[ethernet_interfaces]=$(IFS=','; echo "${ethernet_interfaces[*]}")
    
    # Primary Interface bestimmen
    local primary
    if primary=$(get_primary_interface); then
        SYSTEM_INFO[primary_interface]="$primary"
        log_info "Primäres Interface: $primary"
    else
        SYSTEM_INFO[primary_interface]=""
        add_issue "critical" "network" "Kein aktives Netzwerk-Interface gefunden" true
    fi
    
    log_debug "Interfaces: All=${SYSTEM_INFO[all_interfaces]}, WiFi=${SYSTEM_INFO[wifi_interfaces]}, Ethernet=${SYSTEM_INFO[ethernet_interfaces]}"
}

# =============================================================================
# macOS Version-spezifische Features
# =============================================================================

supports_modern_wifi_api() {
    local major="${SYSTEM_INFO[os_major]:-1}"
    local minor="${SYSTEM_INFO[os_minor]:-0}"
    
    # Nur auf macOS verfügbar
    if ! is_macos; then
        return 1
    fi
    
    # macOS 10.14+ hat modernere WiFi APIs
    if [[ "${major:-1}" -ge 11 ]] || [[ "${major:-1}" -eq 10 && "${minor:-0}" -ge 14 ]]; then
        return 0
    fi
    return 1
}

supports_system_profiler() {
    command -v system_profiler &> /dev/null
}

get_legacy_wifi_tool() {
    # Für ältere macOS Versionen
    if [[ -x "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport" ]]; then
        echo "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        return 0
    fi
    
    # Homebrew Installation
    if command -v airport &> /dev/null; then
        echo "airport"
        return 0
    fi
    
    return 1
}

get_firewall_command() {
    local major="${SYSTEM_INFO[os_major]:-1}"
    
    # Non-macOS Systeme
    if ! is_macos; then
        echo "iptables"
        return
    fi
    
    # macOS 11+ verwendet socketfilterfw anders
    if [[ "${major:-1}" -ge 11 ]]; then
        echo "socketfilterfw"
    else
        echo "pfctl"
    fi
}

# =============================================================================
# Hardware-spezifische Erkennung
# =============================================================================

is_apple_silicon() {
    [[ "${SYSTEM_INFO[architecture]}" == "arm64" ]]
}

get_network_hardware_info() {
    if ! supports_system_profiler; then
        return 1
    fi
    
    local network_info
    network_info=$(system_profiler SPNetworkDataType 2>/dev/null) || return 1
    
    # WiFi Hardware
    if echo "$network_info" | grep -q "Wi-Fi"; then
        SYSTEM_INFO[has_wifi_hardware]="true"
        local wifi_card
        wifi_card=$(echo "$network_info" | grep -A5 "Wi-Fi" | grep "Card Type" | cut -d: -f2 | trim)
        SYSTEM_INFO[wifi_hardware]="${wifi_card:-Unknown}"
    else
        SYSTEM_INFO[has_wifi_hardware]="false"
        SYSTEM_INFO[wifi_hardware]="None"
    fi
    
    # Ethernet Hardware
    if echo "$network_info" | grep -q "Ethernet"; then
        SYSTEM_INFO[has_ethernet_hardware]="true"
    else
        SYSTEM_INFO[has_ethernet_hardware]="false"
    fi
    
    log_debug "Hardware: WiFi=${SYSTEM_INFO[has_wifi_hardware]} (${SYSTEM_INFO[wifi_hardware]}), Ethernet=${SYSTEM_INFO[has_ethernet_hardware]}"
}

# =============================================================================
# System Health Check
# =============================================================================

check_system_health() {
    local health_score=0
    local max_score=10
    
    # Disk Space
    local available_space
    available_space=$(df -h / | tail -1 | awk '{print $4}' | sed 's/G.*$//')
    if [[ ${available_space%.*} -gt 5 ]]; then
        ((health_score++))
    else
        add_issue "warning" "system" "Wenig freier Speicherplatz: ${available_space}GB" false
    fi
    
    # Memory Pressure
    if command -v memory_pressure &> /dev/null; then
        local memory_pressure
        memory_pressure=$(memory_pressure | head -1)
        if [[ "$memory_pressure" =~ "Memory pressure: Normal" ]]; then
            ((health_score++))
        else
            add_issue "warning" "system" "Speicherdruck erkannt: $memory_pressure" false
        fi
    else
        ((health_score++)) # Annahme: OK wenn Tool nicht verfügbar
    fi
    
    # Load Average
    local load_avg
    load_avg=$(uptime | awk '{print $10}' | sed 's/,//')
    if (( $(echo "$load_avg < 2.0" | bc -l 2>/dev/null || echo 1) )); then
        ((health_score++))
    else
        add_issue "info" "system" "Hohe CPU-Last: $load_avg" false
    fi
    
    SYSTEM_INFO[health_score]="$health_score"
    SYSTEM_INFO[max_health_score]="$max_score"
    
    log_info "System Health Score: $health_score/$max_score"
}
