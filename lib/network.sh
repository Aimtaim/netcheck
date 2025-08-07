#!/bin/bash

# =============================================================================
# NetCheck Network - Netzwerk-Diagnostik und Tests
# =============================================================================

# Test-Ergebnisse
declare -a NETWORK_TEST_RESULTS=()

# =============================================================================
# Netzwerk-Diagnostik Hauptfunktion
# =============================================================================

network_run_diagnostics() {
    log_info "Starte Netzwerk-Diagnostik..."
    
    local tests=(
        "test_network_interfaces"
        "test_wifi_connection" 
        "test_internet_connectivity"
        "test_dns_resolution"
        "test_gateway_reachability"
        "test_network_speed"
        "test_firewall_status"
        "test_proxy_settings"
    )
    
    local total_tests=${#tests[@]}
    local current_test=0
    
    for test in "${tests[@]}"; do
        ((current_test++))
        
        if [[ "$SILENT_MODE" != true ]]; then
            ui_show_test_progress "$current_test" "$total_tests" "$test"
        fi
        
        log_info "Führe Test aus: $test"
        
        # Test mit Timeout ausführen
        local result
        if result=$(run_test_with_fallback "$test"); then
            NETWORK_TEST_RESULTS+=("$result")
            log_info "Test $test: Erfolgreich"
        else
            local error_result="{\"test\":\"$test\",\"status\":\"error\",\"message\":\"Test fehlgeschlagen\",\"duration\":0}"
            NETWORK_TEST_RESULTS+=("$error_result")
            log_error "Test $test: Fehlgeschlagen"
        fi
        
        monitor_performance
    done
    
    log_info "Netzwerk-Diagnostik abgeschlossen. ${#NETWORK_TEST_RESULTS[@]} Tests durchgeführt"
    
    # Ergebnisse als JSON Array zurückgeben
    local json_array=""
    for result in "${NETWORK_TEST_RESULTS[@]}"; do
        if [[ -n "$json_array" ]]; then
            json_array+=","
        fi
        json_array+="$result"
    done
    echo "[$json_array]"
}

run_test_with_fallback() {
    local test_function="$1"
    local timeout="${CUSTOM_TIMEOUT:-10}"
    
    # Test mit Timeout ausführen
    local start_time end_time duration
    start_time=$(date +%s.%N)
    
    if timeout "$timeout" bash -c "$test_function" 2>/dev/null; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        return 0
    else
        # Fallback bei Timeout/Fehler
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "$timeout")
        log_warn "$test_function: Timeout nach ${timeout}s"
        return 1
    fi
}

# =============================================================================
# Netzwerk Interface Tests
# =============================================================================

test_network_interfaces() {
    local active_interfaces=()
    local inactive_interfaces=()
    local interface_details="{}"
    
    # Alle Interfaces prüfen
    IFS=',' read -ra interfaces <<< "${SYSTEM_INFO[all_interfaces]}"
    
    for interface in "${interfaces[@]}"; do
        if [[ -n "$interface" ]]; then
            if is_interface_active "$interface"; then
                active_interfaces+=("$interface")
                
                # Interface Details sammeln
                local ip_addr
                ip_addr=$(get_interface_ip "$interface")
                
                local status_info="{\"interface\":\"$interface\",\"status\":\"active\",\"ip\":\"$ip_addr\"}"
                interface_details=$(echo "$interface_details" | jq ". + {\"$interface\": $status_info}" 2>/dev/null || echo "$interface_details")
            else
                inactive_interfaces+=("$interface")
                local status_info="{\"interface\":\"$interface\",\"status\":\"inactive\",\"ip\":\"\"}"
                interface_details=$(echo "$interface_details" | jq ". + {\"$interface\": $status_info}" 2>/dev/null || echo "$interface_details")
            fi
        fi
    done
    
    # Bewertung
    local status="ok"
    local message="Alle Interfaces funktional"
    
    if [[ ${#active_interfaces[@]} -eq 0 ]]; then
        status="critical"
        message="Keine aktiven Netzwerk-Interfaces"
        add_issue "critical" "interface" "Keine aktiven Netzwerk-Interfaces gefunden" true
    elif [[ ${#active_interfaces[@]} -eq 1 ]]; then
        status="warning" 
        message="Nur ein aktives Interface: ${active_interfaces[0]}"
        add_issue "warning" "interface" "Nur ein aktives Netzwerk-Interface" false
    fi
    
    # Ergebnis zusammenstellen
    local result="{\"test\":\"network_interfaces\",\"status\":\"$status\",\"message\":\"$message\",\"active_count\":${#active_interfaces[@]},\"inactive_count\":${#inactive_interfaces[@]},\"details\":$interface_details,\"duration\":$duration}"
    
    echo "$result"
}

get_interface_ip() {
    local interface="$1"
    ifconfig "$interface" 2>/dev/null | grep "inet " | head -1 | awk '{print $2}'
}

# =============================================================================
# WiFi Connection Tests
# =============================================================================

test_wifi_connection() {
    local wifi_interface
    wifi_interface=$(get_wifi_interface)
    
    if [[ -z "$wifi_interface" ]]; then
        local result="{\"test\":\"wifi_connection\",\"status\":\"skip\",\"message\":\"Kein WiFi-Interface verfügbar\",\"duration\":$duration}"
        echo "$result"
        return
    fi
    
    # WiFi Status prüfen
    local wifi_status
    wifi_status=$(networksetup -getairportnetwork "$wifi_interface" 2>/dev/null)
    
    if [[ "$wifi_status" =~ "You are not associated with an AirPort network" ]]; then
        add_issue "critical" "wifi" "WiFi nicht verbunden" true
        local result="{\"test\":\"wifi_connection\",\"status\":\"error\",\"message\":\"WiFi nicht verbunden\",\"interface\":\"$wifi_interface\",\"duration\":$duration}"
        echo "$result"
        return
    fi
    
    # SSID extrahieren
    local ssid
    ssid=$(echo "$wifi_status" | cut -d':' -f2- | trim)
    
    # Signal-Stärke prüfen
    local signal_strength rssi signal_quality
    if supports_modern_wifi_api; then
        signal_strength=$(get_modern_wifi_signal "$wifi_interface")
    else
        signal_strength=$(get_legacy_wifi_signal "$wifi_interface")
    fi
    
    rssi="${signal_strength:-0}"
    signal_quality=$(calculate_signal_quality "$rssi")
    
    # Bewertung
    local status="ok"
    local message="WiFi verbunden mit '$ssid'"
    
    if [[ $rssi -lt -80 ]]; then
        status="warning"
        message="WiFi Signal schwach"
        add_issue "warning" "wifi" "WiFi-Signal sehr schwach ($rssi dBm)" true
    elif [[ $rssi -lt -70 ]]; then
        status="warning"
        message="WiFi Signal könnte besser sein"
    fi
    
    local result="{\"test\":\"wifi_connection\",\"status\":\"$status\",\"message\":\"$message\",\"ssid\":\"$ssid\",\"interface\":\"$wifi_interface\",\"rssi\":$rssi,\"signal_quality\":\"$signal_quality\",\"duration\":$duration}"
    
    echo "$result"
}

get_modern_wifi_signal() {
    local interface="$1"
    
    if command -v wdutil &> /dev/null; then
        wdutil info 2>/dev/null | grep "RSSI" | head -1 | awk '{print $2}'
    else
        # Fallback über system_profiler
        system_profiler SPAirPortDataType 2>/dev/null | grep -A10 "Current Network Information" | grep "Signal / Noise" | awk '{print $4}' | sed 's/dBm.*//'
    fi
}

get_legacy_wifi_signal() {
    local interface="$1"
    local airport_tool
    
    if airport_tool=$(get_legacy_wifi_tool); then
        "$airport_tool" -I 2>/dev/null | grep "agrCtlRSSI" | awk '{print $2}'
    fi
}

calculate_signal_quality() {
    local rssi="$1"
    
    if [[ $rssi -ge -50 ]]; then
        echo "excellent"
    elif [[ $rssi -ge -60 ]]; then
        echo "good"
    elif [[ $rssi -ge -70 ]]; then
        echo "fair"
    elif [[ $rssi -ge -80 ]]; then
        echo "weak"
    else
        echo "poor"
    fi
}

# =============================================================================
# Internet Connectivity Tests
# =============================================================================

test_internet_connectivity() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222" "9.9.9.9")
    local successful_pings=0
    local failed_hosts=()
    local ping_results=()
    
    for host in "${test_hosts[@]}"; do
        local ping_time
        if ping_time=$(ping -c 1 -W 3000 "$host" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}'); then
            ((successful_pings++))
            ping_results+=("{\"host\":\"$host\",\"status\":\"ok\",\"time\":\"$ping_time\"}")
            log_debug "Ping zu $host: ${ping_time}ms"
        else
            failed_hosts+=("$host")
            ping_results+=("{\"host\":\"$host\",\"status\":\"failed\",\"time\":null}")
            log_debug "Ping zu $host: Fehlgeschlagen"
        fi
    done
    
    # Bewertung
    local status message
    if [[ $successful_pings -eq 0 ]]; then
        status="critical"
        message="Keine Internetverbindung"
        add_issue "critical" "connectivity" "Keine Internetverbindung verfügbar" true
    elif [[ $successful_pings -lt 2 ]]; then
        status="warning"
        message="Instabile Internetverbindung"
        add_issue "warning" "connectivity" "Internetverbindung instabil ($successful_pings von ${#test_hosts[@]} Hosts erreichbar)" true
    else
        status="ok"
        message="Internetverbindung stabil"
    fi
    
    # Ping-Ergebnisse als JSON Array
    local pings_json
    pings_json=$(IFS=','; echo "[${ping_results[*]}]")
    
    local result="{\"test\":\"internet_connectivity\",\"status\":\"$status\",\"message\":\"$message\",\"successful_pings\":$successful_pings,\"total_hosts\":${#test_hosts[@]},\"ping_results\":$pings_json,\"duration\":$duration}"
    
    echo "$result"
}

# =============================================================================
# DNS Resolution Tests
# =============================================================================

test_dns_resolution() {
    local test_domains=("google.com" "apple.com" "cloudflare.com" "github.com")
    local successful_lookups=0
    local failed_domains=()
    local dns_results=()
    local dns_servers
    
    # DNS Server ermitteln
    dns_servers=$(get_dns_servers)
    
    for domain in "${test_domains[@]}"; do
        local lookup_time start_time end_time
        start_time=$(date +%s.%N)
        
        if timeout 5 nslookup "$domain" >/dev/null 2>&1; then
            end_time=$(date +%s.%N)
            lookup_time=$(echo "($end_time - $start_time) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
            ((successful_lookups++))
            dns_results+=("{\"domain\":\"$domain\",\"status\":\"ok\",\"time\":${lookup_time:-0}}")
            log_debug "DNS Lookup $domain: ${lookup_time}ms"
        else
            failed_domains+=("$domain")
            dns_results+=("{\"domain\":\"$domain\",\"status\":\"failed\",\"time\":null}")
            log_debug "DNS Lookup $domain: Fehlgeschlagen"
        fi
    done
    
    # Bewertung
    local status message
    if [[ $successful_lookups -eq 0 ]]; then
        status="critical"
        message="DNS funktioniert nicht"
        add_issue "critical" "dns" "DNS-Auflösung funktioniert nicht" true
    elif [[ $successful_lookups -lt 3 ]]; then
        status="warning"
        message="DNS teilweise problematisch"
        add_issue "warning" "dns" "DNS-Auflösung teilweise fehlerhaft ($successful_lookups von ${#test_domains[@]} Domains)" true
    else
        status="ok"
        message="DNS funktioniert korrekt"
    fi
    
    # DNS-Ergebnisse als JSON Array
    local dns_json
    dns_json=$(IFS=','; echo "[${dns_results[*]}]")
    
    local result="{\"test\":\"dns_resolution\",\"status\":\"$status\",\"message\":\"$message\",\"successful_lookups\":$successful_lookups,\"total_domains\":${#test_domains[@]},\"dns_servers\":\"$dns_servers\",\"dns_results\":$dns_json,\"duration\":$duration}"
    
    echo "$result"
}

get_dns_servers() {
    # DNS Server aus verschiedenen Quellen sammeln
    local dns_servers=()
    
    # Über scutil
    if command -v scutil &> /dev/null; then
        while IFS= read -r line; do
            if [[ "$line" =~ nameserver\[0\] ]]; then
                local server
                server=$(echo "$line" | awk '{print $3}')
                dns_servers+=("$server")
            fi
        done < <(scutil --dns 2>/dev/null | grep "nameserver\[0\]" | head -3)
    fi
    
    # Fallback über networksetup
    if [[ ${#dns_servers[@]} -eq 0 ]] && command -v networksetup &> /dev/null; then
        local primary_interface="${SYSTEM_INFO[primary_interface]}"
        if [[ -n "$primary_interface" ]]; then
            while IFS= read -r server; do
                [[ -n "$server" ]] && dns_servers+=("$server")
            done < <(networksetup -getdnsservers "$primary_interface" 2>/dev/null | grep -v "There aren't any")
        fi
    fi
    
    # Als komma-separierte Liste zurückgeben
    (IFS=','; echo "${dns_servers[*]}")
}

# =============================================================================
# Gateway Reachability Test
# =============================================================================

test_gateway_reachability() {
    local gateway
    gateway=$(route -n get default 2>/dev/null | grep 'gateway' | awk '{print $2}')
    
    if [[ -z "$gateway" ]]; then
        add_issue "critical" "routing" "Kein Standard-Gateway konfiguriert" true
        local result="{\"test\":\"gateway_reachability\",\"status\":\"error\",\"message\":\"Kein Standard-Gateway gefunden\",\"gateway\":\"\",\"duration\":$duration}"
        echo "$result"
        return
    fi
    
    # Gateway Erreichbarkeit testen
    local ping_time
    if ping_time=$(ping -c 1 -W 3000 "$gateway" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}'); then
        local status="ok"
        local message="Gateway erreichbar"
        log_debug "Gateway $gateway: ${ping_time}ms"
    else
        local status="error"
        local message="Gateway nicht erreichbar"
        add_issue "critical" "routing" "Standard-Gateway ($gateway) nicht erreichbar" true
        log_debug "Gateway $gateway: Nicht erreichbar"
    fi
    
    local result="{\"test\":\"gateway_reachability\",\"status\":\"$status\",\"message\":\"$message\",\"gateway\":\"$gateway\",\"ping_time\":\"${ping_time:-null}\",\"duration\":$duration}"
    
    echo "$result"
}

# =============================================================================
# Network Speed Test
# =============================================================================

test_network_speed() {
    local speed_test_url="http://speedtest.ftp.otenet.gr/files/test1Mb.db"
    local test_size="1048576" # 1MB in bytes
    
    log_debug "Führe Geschwindigkeitstest durch..."
    
    local start_time end_time duration_real download_speed
    start_time=$(date +%s.%N)
    
    # Download-Test mit curl
    if curl -s -m 30 -w "%{speed_download}" -o /dev/null "$speed_test_url" > "$TEMP_DIR/speed_result" 2>/dev/null; then
        end_time=$(date +%s.%N)
        duration_real=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "30")
        download_speed=$(cat "$TEMP_DIR/speed_result")
        
        # Geschwindigkeit in Mbps umrechnen
        local speed_mbps
        speed_mbps=$(echo "scale=2; $download_speed * 8 / 1000000" | bc -l 2>/dev/null || echo "0")
        
        # Bewertung
        local status message
        if (( $(echo "$speed_mbps >= 25" | bc -l 2>/dev/null || echo 0) )); then
            status="ok"
            message="Sehr gute Geschwindigkeit"
        elif (( $(echo "$speed_mbps >= 10" | bc -l 2>/dev/null || echo 0) )); then
            status="ok"
            message="Gute Geschwindigkeit"
        elif (( $(echo "$speed_mbps >= 5" | bc -l 2>/dev/null || echo 0) )); then
            status="warning"
            message="Mäßige Geschwindigkeit"
        else
            status="warning"
            message="Langsame Verbindung"
            add_issue "warning" "performance" "Netzwerkgeschwindigkeit unter 5 Mbps (${speed_mbps} Mbps)" false
        fi
        
        local result="{\"test\":\"network_speed\",\"status\":\"$status\",\"message\":\"$message\",\"download_speed_mbps\":$speed_mbps,\"test_duration\":$duration_real,\"duration\":$duration}"
        
        log_info "Netzwerk-Geschwindigkeit: ${speed_mbps} Mbps"
    else
        add_issue "warning" "performance" "Geschwindigkeitstest nicht durchführbar" false
        local result="{\"test\":\"network_speed\",\"status\":\"skip\",\"message\":\"Geschwindigkeitstest fehlgeschlagen\",\"download_speed_mbps\":null,\"duration\":$duration}"
    fi
    
    rm -f "$TEMP_DIR/speed_result"
    echo "$result"
}

# =============================================================================
# Firewall Status Test
# =============================================================================

test_firewall_status() {
    local firewall_status
    firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "unknown")
    
    local status message firewall_enabled
    case $firewall_status in
        0)
            status="warning"
            message="Firewall deaktiviert"
            firewall_enabled=false
            add_issue "warning" "security" "macOS Firewall ist nicht aktiviert" false
            ;;
        1)
            status="ok"
            message="Firewall aktiv (spezifische Apps)"
            firewall_enabled=true
            ;;
        2)
            status="ok"
            message="Firewall aktiv (alle eingehenden Verbindungen blockiert)"
            firewall_enabled=true
            ;;
        *)
            status="warning"
            message="Firewall-Status unbekannt"
            firewall_enabled=null
            ;;
    esac
    
    local result="{\"test\":\"firewall_status\",\"status\":\"$status\",\"message\":\"$message\",\"firewall_enabled\":$firewall_enabled,\"firewall_mode\":$firewall_status,\"duration\":$duration}"
    
    echo "$result"
}

# =============================================================================
# Proxy Settings Test
# =============================================================================

test_proxy_settings() {
    local proxy_settings="{}"
    local issues_found=false
    
    # HTTP Proxy prüfen
    local http_proxy
    http_proxy=$(networksetup -getwebproxy "Wi-Fi" 2>/dev/null || echo "")
    
    if [[ "$http_proxy" =~ Enabled:\ Yes ]]; then
        local proxy_server proxy_port
        proxy_server=$(echo "$http_proxy" | grep "Server:" | awk '{print $2}')
        proxy_port=$(echo "$http_proxy" | grep "Port:" | awk '{print $2}')
        
        # Proxy Erreichbarkeit testen
        if ! nc -z "$proxy_server" "$proxy_port" 2>/dev/null; then
            add_issue "warning" "proxy" "HTTP Proxy nicht erreichbar: $proxy_server:$proxy_port" true
            issues_found=true
        fi
        
        proxy_settings=$(echo "$proxy_settings" | jq ". + {\"http_proxy\": {\"enabled\": true, \"server\": \"$proxy_server\", \"port\": $proxy_port}}" 2>/dev/null || echo "$proxy_settings")
    fi
    
    # HTTPS Proxy prüfen
    local https_proxy
    https_proxy=$(networksetup -getsecurewebproxy "Wi-Fi" 2>/dev/null || echo "")
    
    if [[ "$https_proxy" =~ Enabled:\ Yes ]]; then
        local proxy_server proxy_port
        proxy_server=$(echo "$https_proxy" | grep "Server:" | awk '{print $2}')
        proxy_port=$(echo "$https_proxy" | grep "Port:" | awk '{print $2}')
        
        proxy_settings=$(echo "$proxy_settings" | jq ". + {\"https_proxy\": {\"enabled\": true, \"server\": \"$proxy_server\", \"port\": $proxy_port}}" 2>/dev/null || echo "$proxy_settings")
    fi
    
    local status message
    if [[ "$issues_found" == true ]]; then
        status="warning"
        message="Proxy-Konfigurationsprobleme"
    else
        status="ok"
        message="Proxy-Einstellungen in Ordnung"
    fi
    
    local result="{\"test\":\"proxy_settings\",\"status\":\"$status\",\"message\":\"$message\",\"proxy_settings\":$proxy_settings,\"duration\":$duration}"
    
    echo "$result"
}