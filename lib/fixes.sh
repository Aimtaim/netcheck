#!/bin/bash

# =============================================================================
# NetCheck Fixes - Automatische Problemlösung
# =============================================================================

# =============================================================================
# Reparatur-Hauptfunktionen
# =============================================================================

fixes_offer_solutions() {
    local issues_json="$1"
    
    if [[ "$SILENT_MODE" == true ]]; then
        return
    fi
    
    echo
    ui_show_fixes_header
    
    # Verfügbare Fixes anzeigen
    generate_fix_suggestions "$issues_json"
    
    # Benutzer fragen
    if [[ ${#NETCHECK_FIXES[@]} -gt 0 ]]; then
        echo
        ui_ask_permission "Automatische Reparaturen ausführen?"
        read -r -n 1 response
        echo
        
        if [[ "$response" =~ ^[JjYy]$ ]]; then
            perform_auto_fixes
        else
            log_info "Automatische Reparaturen vom Benutzer abgelehnt"
            echo -e "${GRAY}Reparaturen übersprungen.${NC}"
        fi
    else
        echo -e "${GRAY}Keine automatischen Reparaturen verfügbar.${NC}"
    fi
}

fixes_run_all() {
    log_info "Fix-Only Modus: Führe alle verfügbaren Reparaturen aus"
    
    # Schnelle Diagnose für aktuelle Issues
    local quick_issues
    quick_issues=$(diagnose_current_issues)
    
    generate_fix_suggestions "$quick_issues"
    
    if [[ ${#NETCHECK_FIXES[@]} -gt 0 ]]; then
        perform_auto_fixes
    else
        if [[ "$JSON_MODE" == true ]]; then
            echo '{"status": "no_fixes", "message": "Keine Reparaturen erforderlich"}'
        else
            echo -e "${GREEN}${ICON_CHECK} Keine Reparaturen erforderlich${NC}"
        fi
    fi
}

# =============================================================================
# Fix-Generierung basierend auf Issues
# =============================================================================

generate_fix_suggestions() {
    local issues_json="$1"
    
    # Issues parsen und entsprechende Fixes generieren
    if command -v jq &> /dev/null; then
        # Mit jq parsen
        while IFS= read -r issue; do
            local category
            category=$(echo "$issue" | jq -r '.category')
            local description 
            description=$(echo "$issue" | jq -r '.description')
            local auto_fixable
            auto_fixable=$(echo "$issue" | jq -r '.auto_fixable')
            
            if [[ "$auto_fixable" == "true" ]]; then
                generate_fixes_for_category "$category" "$description"
            fi
        done < <(echo "$issues_json" | jq -c '.[]' 2>/dev/null || echo "")
    else
        # Fallback ohne jq - einfaches Parsen
        generate_common_fixes
    fi
}

generate_fixes_for_category() {
    local category="$1"
    local description="$2"
    
    case "$category" in
        "wifi")
            add_fix "WiFi-Verbindung zurücksetzen" "reset_wifi_connection" false
            add_fix "DNS für WiFi erneuern" "renew_wifi_dns" true
            add_fix "WiFi-Präferenzen reparieren" "repair_wifi_prefs" true
            ;;
        "dns")
            add_fix "DNS-Cache leeren" "flush_dns_cache" true
            add_fix "DNS-Server auf Standard setzen" "reset_dns_servers" true
            ;;
        "connectivity")
            add_fix "Netzwerk-Konfiguration erneuern" "renew_network_config" true
            add_fix "Netzwerk-Services neu starten" "restart_network_services" true
            ;;
        "routing")
            add_fix "Routing-Tabelle zurücksetzen" "reset_routing_table" true
            add_fix "Netzwerk-Interface neu starten" "restart_network_interface" true
            ;;
        "interface")
            add_fix "Netzwerk-Interface zurücksetzen" "reset_network_interfaces" true
            ;;
        "firewall")
            add_fix "Firewall aktivieren" "enable_firewall" false
            ;;
        "proxy")
            add_fix "Proxy-Einstellungen zurücksetzen" "reset_proxy_settings" true
            ;;
    esac
}

generate_common_fixes() {
    # Standard-Fixes die oft helfen
    add_fix "DNS-Cache leeren" "flush_dns_cache" true
    add_fix "Netzwerk-Konfiguration erneuern" "renew_network_config" true  
    add_fix "WiFi-Verbindung zurücksetzen" "reset_wifi_connection" false
}

# =============================================================================
# Reparatur-Ausführung
# =============================================================================

perform_auto_fixes() {
    log_info "Beginne automatische Reparaturen..."
    
    if [[ "$JSON_MODE" != true ]]; then
        ui_show_fixes_progress_start
    fi
    
    local applied_fixes=0
    local successful_fixes=0
    local total_fixes=${#NETCHECK_FIXES[@]}
    
    for i in "${!NETCHECK_FIXES[@]}"; do
        local fix="${NETCHECK_FIXES[$i]}"
        local description command requires_sudo
        
        # Fix-Details extrahieren (vereinfacht, da kein jq garantiert)
        if [[ "$fix" =~ \"description\":\"([^\"]*) ]]; then
            description="${BASH_REMATCH[1]}"
        else
            description="Unbekannter Fix"
        fi
        
        if [[ "$fix" =~ \"command\":\"([^\"]*) ]]; then
            command="${BASH_REMATCH[1]}"
        else
            command=""
        fi
        
        if [[ "$fix" =~ \"requires_sudo\":true ]]; then
            requires_sudo=true
        else
            requires_sudo=false
        fi
        
        ((applied_fixes++))
        
        if [[ "$SILENT_MODE" != true ]]; then
            ui_show_fix_progress "$applied_fixes" "$total_fixes" "$description"
        fi
        
        log_info "Führe Fix aus: $description"
        
        # Sudo-Warnung
        if [[ "$requires_sudo" == true ]]; then
            if [[ "$SILENT_MODE" != true ]] && [[ "$JSON_MODE" != true ]]; then
                echo -e "${YELLOW}⚠ Administrative Rechte erforderlich für: $description${NC}"
            fi
        fi
        
        # Fix ausführen
        if execute_fix "$command" "$requires_sudo"; then
            ((successful_fixes++))
            log_info "Fix erfolgreich: $description"
            
            # Fix als erfolgreich markieren
            NETCHECK_FIXES[$i]=$(echo "$fix" | sed 's/"applied":false/"applied":true/')
            
            if [[ "$SILENT_MODE" != true ]] && [[ "$JSON_MODE" != true ]]; then
                echo -e "  ${GREEN}${ICON_CHECK} $description${NC}"
            fi
        else
            log_error "Fix fehlgeschlagen: $description"
            
            if [[ "$SILENT_MODE" != true ]] && [[ "$JSON_MODE" != true ]]; then
                echo -e "  ${RED}${ICON_ERROR} $description${NC}"
            fi
        fi
        
        # Kurze Pause zwischen Fixes
        sleep 1
    done
    
    log_info "Automatische Reparaturen abgeschlossen: $successful_fixes/$applied_fixes erfolgreich"
    
    if [[ "$JSON_MODE" == true ]]; then
        echo "{\"fixes_applied\": $applied_fixes, \"fixes_successful\": $successful_fixes, \"fixes_total\": $total_fixes}"
    else
        echo
        echo -e "${GREEN}${ICON_CHECK} Reparaturen abgeschlossen: $successful_fixes von $applied_fixes erfolgreich${NC}"
        
        if [[ $successful_fixes -gt 0 ]]; then
            echo -e "${CYAN}${ICON_INFO} Führen Sie NetCheck erneut aus, um die Verbesserungen zu überprüfen${NC}"
        fi
    fi
}

execute_fix() {
    local command="$1"
    local requires_sudo="$2"
    
    case "$command" in
        "flush_dns_cache")
            flush_dns_cache
            ;;
        "renew_network_config")
            renew_network_config
            ;;
        "reset_wifi_connection")
            reset_wifi_connection
            ;;
        "renew_wifi_dns")
            renew_wifi_dns
            ;;
        "repair_wifi_prefs")
            repair_wifi_preferences
            ;;
        "reset_dns_servers")
            reset_dns_servers
            ;;
        "restart_network_services")
            restart_network_services
            ;;
        "reset_routing_table")
            reset_routing_table
            ;;
        "restart_network_interface")
            restart_network_interface
            ;;
        "reset_network_interfaces")
            reset_network_interfaces
            ;;
        "enable_firewall")
            enable_firewall
            ;;
        "reset_proxy_settings")
            reset_proxy_settings
            ;;
        *)
            log_error "Unbekannter Fix-Befehl: $command"
            return 1
            ;;
    esac
}

# =============================================================================
# Spezifische Reparatur-Funktionen
# =============================================================================

flush_dns_cache() {
    log_debug "Leere DNS-Cache..."
    
    if is_macos; then
        # macOS DNS Cache
        sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
    else
        # Linux DNS Cache
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl restart systemd-resolved 2>/dev/null || true
        elif command -v service >/dev/null 2>&1; then
            sudo service networking restart 2>/dev/null || true
        fi
    fi
}

renew_network_config() {
    log_debug "Erneuere Netzwerk-Konfiguration..."
    
    local primary_interface="${SYSTEM_INFO[primary_interface]}"
    if [[ -n "$primary_interface" ]]; then
        if is_macos; then
            # macOS DHCP renewal
            sudo networksetup -renewdhcp "$primary_interface" 2>/dev/null
        else
            # Linux interface restart
            if command -v ip >/dev/null 2>&1; then
                sudo ip link set "$primary_interface" down
                sleep 2
                sudo ip link set "$primary_interface" up
                # DHCP renewal on Linux
                if command -v dhclient >/dev/null 2>&1; then
                    sudo dhclient -r "$primary_interface" 2>/dev/null || true
                    sudo dhclient "$primary_interface" 2>/dev/null || true
                fi
            fi
        fi
    else
        return 1
    fi
}

reset_wifi_connection() {
    log_debug "Setze WiFi-Verbindung zurück..."
    
    if is_macos; then
        local wifi_interface
        wifi_interface=$(get_wifi_interface)
        
        if [[ -n "$wifi_interface" ]]; then
            networksetup -setairportpower "$wifi_interface" off
            sleep 3
            networksetup -setairportpower "$wifi_interface" on
            sleep 5
            return 0
        fi
    else
        # Linux WiFi restart
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl restart NetworkManager 2>/dev/null || true
            return 0
        fi
    fi
    return 1
}

renew_wifi_dns() {
    log_debug "Erneuere WiFi DNS-Konfiguration..."
    
    local wifi_interface
    wifi_interface=$(get_wifi_interface)
    
    if [[ -n "$wifi_interface" ]]; then
        sudo networksetup -renewdhcp "$wifi_interface"
        return 0
    else
        return 1
    fi
}

repair_wifi_preferences() {
    log_debug "Repariere WiFi-Präferenzen..."
    
    # WiFi-Konfigurationsdateien zurücksetzen
    local wifi_prefs=(
        "/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist"
        "/Library/Preferences/SystemConfiguration/com.apple.network.identification.plist"
        "/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist"
    )
    
    for pref in "${wifi_prefs[@]}"; do
        if [[ -f "$pref" ]]; then
            sudo mv "$pref" "${pref}.backup.$(date +%s)" 2>/dev/null
        fi
    done
    
    # Netzwerk-Services neu laden
    sudo launchctl unload /System/Library/LaunchDaemons/com.apple.configd.plist 2>/dev/null
    sleep 2
    sudo launchctl load /System/Library/LaunchDaemons/com.apple.configd.plist 2>/dev/null
}

reset_dns_servers() {
    log_debug "Setze DNS-Server zurück..."
    
    local primary_interface="${SYSTEM_INFO[primary_interface]}"
    if [[ -n "$primary_interface" ]]; then
        # Standard DNS-Server setzen (Cloudflare + Google)
        sudo networksetup -setdnsservers "$primary_interface" 1.1.1.1 8.8.8.8
        return 0
    else
        return 1
    fi
}

restart_network_services() {
    log_debug "Starte Netzwerk-Services neu..."
    
    # Verschiedene Netzwerk-Daemons neustarten
    local services=(
        "com.apple.configd"
        "com.apple.mDNSResponder"
        "com.apple.networkd"
    )
    
    for service in "${services[@]}"; do
        sudo launchctl unload "/System/Library/LaunchDaemons/${service}.plist" 2>/dev/null
        sleep 1
        sudo launchctl load "/System/Library/LaunchDaemons/${service}.plist" 2>/dev/null
    done
}

reset_routing_table() {
    log_debug "Setze Routing-Tabelle zurück..."
    
    # Route-Cache leeren
    sudo route -n flush 2>/dev/null || return 1
}

restart_network_interface() {
    log_debug "Starte Netzwerk-Interface neu..."
    
    local primary_interface="${SYSTEM_INFO[primary_interface]}"
    if [[ -n "$primary_interface" ]]; then
        sudo ifconfig "$primary_interface" down
        sleep 2
        sudo ifconfig "$primary_interface" up
        sleep 5
        return 0
    else
        return 1
    fi
}

reset_network_interfaces() {
    log_debug "Setze alle Netzwerk-Interfaces zurück..."
    
    # Alle aktiven Interfaces neustarten
    IFS=',' read -ra interfaces <<< "${SYSTEM_INFO[all_interfaces]}"
    
    for interface in "${interfaces[@]}"; do
        if [[ -n "$interface" ]] && is_interface_active "$interface"; then
            sudo ifconfig "$interface" down 2>/dev/null
        fi
    done
    
    sleep 3
    
    for interface in "${interfaces[@]}"; do
        if [[ -n "$interface" ]]; then
            sudo ifconfig "$interface" up 2>/dev/null
        fi
    done
    
    sleep 5
}

enable_firewall() {
    log_debug "Aktiviere Firewall..."
    
    # Firewall einschalten
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
    sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
    sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
}

reset_proxy_settings() {
    log_debug "Setze Proxy-Einstellungen zurück..."
    
    local primary_interface="${SYSTEM_INFO[primary_interface]}"
    if [[ -n "$primary_interface" ]]; then
        # Alle Proxy-Einstellungen deaktivieren
        sudo networksetup -setwebproxystate "$primary_interface" off
        sudo networksetup -setsecurewebproxystate "$primary_interface" off
        sudo networksetup -setftpproxystate "$primary_interface" off
        sudo networksetup -setsocksfirewallproxystate "$primary_interface" off
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Diagnose für Fix-Only Modus
# =============================================================================

diagnose_current_issues() {
    log_debug "Führe schnelle Diagnose für Fix-Only Modus durch..."
    
    # Grundlegende Tests ohne UI
    local quick_tests=(
        "quick_test_connectivity"
        "quick_test_dns"
        "quick_test_wifi"
        "quick_test_gateway"
    )
    
    for test in "${quick_tests[@]}"; do
        "$test" 2>/dev/null || true
    done
    
    # Issues als JSON zurückgeben
    local json_array=""
    for issue in "${NETCHECK_ISSUES[@]}"; do
        if [[ -n "$json_array" ]]; then
            json_array+=","
        fi
        json_array+="$issue"
    done
    echo "[$json_array]"
}

quick_test_connectivity() {
    if ! ping -c 1 -W 3000 8.8.8.8 >/dev/null 2>&1; then
        add_issue "critical" "connectivity" "Keine Internetverbindung" true
    fi
}

quick_test_dns() {
    if ! timeout 5 nslookup google.com >/dev/null 2>&1; then
        add_issue "critical" "dns" "DNS funktioniert nicht" true
    fi
}

quick_test_wifi() {
    local wifi_interface
    wifi_interface=$(get_wifi_interface)
    
    if [[ -n "$wifi_interface" ]]; then
        local wifi_status
        wifi_status=$(networksetup -getairportnetwork "$wifi_interface" 2>/dev/null)
        
        if [[ "$wifi_status" =~ "You are not associated" ]]; then
            add_issue "critical" "wifi" "WiFi nicht verbunden" true
        fi
    fi
}

quick_test_gateway() {
    local gateway
    gateway=$(route -n get default 2>/dev/null | grep 'gateway' | awk '{print $2}')
    
    if [[ -n "$gateway" ]]; then
        if ! ping -c 1 -W 3000 "$gateway" >/dev/null 2>&1; then
            add_issue "critical" "routing" "Gateway nicht erreichbar" true
        fi
    else
        add_issue "critical" "routing" "Kein Gateway konfiguriert" true
    fi
}
