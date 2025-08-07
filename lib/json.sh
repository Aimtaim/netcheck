#!/bin/bash

# =============================================================================
# NetCheck JSON - JSON Export und API Funktionalität
# =============================================================================

# JSON-Datenstruktur
declare -A JSON_DATA

# =============================================================================
# JSON Initialisierung
# =============================================================================

json_init() {
    log_debug "JSON-Export initialisiert"
    
    # Basis-Struktur vorbereiten
    JSON_DATA[timestamp]=$(date -Iseconds)
    JSON_DATA[version]="$VERSION"
    JSON_DATA[system_info]="{}"
    JSON_DATA[tests]="[]"
    JSON_DATA[issues]="[]" 
    JSON_DATA[fixes]="[]"
    JSON_DATA[summary]="{}"
}

# =============================================================================
# Hauptfunktion für Report-Generierung
# =============================================================================

json_generate_report() {
    local test_results="$1"
    local issues_json="$2"
    
    log_info "Generiere JSON-Report..."
    
    # System-Info sammeln
    json_add_system_info
    
    # Test-Ergebnisse hinzufügen
    JSON_DATA[tests]="$test_results"
    
    # Issues hinzufügen
    JSON_DATA[issues]="$issues_json"
    
    # Fixes hinzufügen
    json_add_fixes
    
    # Summary generieren
    json_generate_summary "$test_results" "$issues_json"
    
    # Finalen JSON ausgeben
    json_output_report
}

# =============================================================================
# System-Informationen für JSON
# =============================================================================

json_add_system_info() {
    local system_json="{"
    
    # Basis System-Info
    system_json+="\"hostname\":\"${SYSTEM_INFO[hostname]}\","
    system_json+="\"os_version\":\"${SYSTEM_INFO[os_version]}\","
    system_json+="\"architecture\":\"${SYSTEM_INFO[architecture]}\","
    system_json+="\"model\":\"${SYSTEM_INFO[model]}\","
    system_json+="\"uptime\":\"${SYSTEM_INFO[uptime]}\","
    
    # Netzwerk-Hardware
    system_json+="\"primary_interface\":\"${SYSTEM_INFO[primary_interface]}\","
    system_json+="\"wifi_interfaces\":\"${SYSTEM_INFO[wifi_interfaces]}\","
    system_json+="\"ethernet_interfaces\":\"${SYSTEM_INFO[ethernet_interfaces]}\","
    
    # Terminal-Features
    system_json+="\"terminal_width\":${SYSTEM_INFO[terminal_width]},"
    system_json+="\"supports_color\":${SYSTEM_INFO[supports_color]},"
    system_json+="\"supports_unicode\":${SYSTEM_INFO[supports_unicode]}"
    
    system_json+="}"
    
    JSON_DATA[system_info]="$system_json"
}

# =============================================================================
# Fixes für JSON
# =============================================================================

json_add_fixes() {
    if [[ ${#NETCHECK_FIXES[@]} -eq 0 ]]; then
        JSON_DATA[fixes]="[]"
        return
    fi
    
    local fixes_json="["
    local first=true
    
    for fix in "${NETCHECK_FIXES[@]}"; do
        if [[ "$first" != true ]]; then
            fixes_json+=","
        fi
        fixes_json+="$fix"
        first=false
    done
    
    fixes_json+="]"
    JSON_DATA[fixes]="$fixes_json"
}

# =============================================================================
# Summary generieren
# =============================================================================

json_generate_summary() {
    local test_results="$1"
    local issues_json="$2"
    
    local summary_json="{"
    
    # Test-Statistiken
    local total_tests ok_tests warning_tests error_tests skip_tests
    total_tests=0
    ok_tests=0
    warning_tests=0
    error_tests=0
    skip_tests=0
    
    if command -v jq &> /dev/null; then
        while IFS= read -r result; do
            local status
            status=$(echo "$result" | jq -r '.status' 2>/dev/null || echo "unknown")
            ((total_tests++))
            
            case "$status" in
                "ok") ((ok_tests++)) ;;
                "warning") ((warning_tests++)) ;;
                "error"|"critical") ((error_tests++)) ;;
                "skip") ((skip_tests++)) ;;
            esac
        done < <(echo "$test_results" | jq -c '.[]' 2>/dev/null || echo "")
        
        # Issues zählen
        local issues_count
        issues_count=$(echo "$issues_json" | jq 'length' 2>/dev/null || echo "0")
        
        # Fixes zählen
        local fixes_count applied_fixes
        fixes_count=${#NETCHECK_FIXES[@]}
        applied_fixes=0
        
        for fix in "${NETCHECK_FIXES[@]}"; do
            if [[ "$fix" =~ \"applied\":true ]]; then
                ((applied_fixes++))
            fi
        done
        
        # Summary zusammenstellen
        summary_json+="\"total_tests\":$total_tests,"
        summary_json+="\"tests_ok\":$ok_tests,"
        summary_json+="\"tests_warning\":$warning_tests,"
        summary_json+="\"tests_error\":$error_tests,"
        summary_json+="\"tests_skipped\":$skip_tests,"
        summary_json+="\"issues_found\":$issues_count,"
        summary_json+="\"fixes_available\":$fixes_count,"
        summary_json+="\"fixes_applied\":$applied_fixes,"
        
        # Overall Status bestimmen
        local overall_status
        if [[ $error_tests -gt 0 ]] || [[ $issues_count -gt 0 ]]; then
            if [[ $error_tests -gt 2 ]] || [[ $issues_count -gt 3 ]]; then
                overall_status="critical"
            else
                overall_status="warning"
            fi
        else
            overall_status="ok"
        fi
        
        summary_json+="\"overall_status\":\"$overall_status\","
        
        # Health Score berechnen (0-100)
        local health_score
        if [[ $total_tests -gt 0 ]]; then
            health_score=$(( (ok_tests * 100) / total_tests ))
        else
            health_score=0
        fi
        
        summary_json+="\"health_score\":$health_score"
        
    else
        # Fallback ohne jq
        summary_json+="\"total_tests\":0,"
        summary_json+="\"tests_ok\":0,"
        summary_json+="\"tests_warning\":0,"
        summary_json+="\"tests_error\":0,"
        summary_json+="\"tests_skipped\":0,"
        summary_json+="\"issues_found\":${#NETCHECK_ISSUES[@]},"
        summary_json+="\"fixes_available\":${#NETCHECK_FIXES[@]},"
        summary_json+="\"fixes_applied\":0,"
        summary_json+="\"overall_status\":\"unknown\","
        summary_json+="\"health_score\":0"
    fi
    
    summary_json+="}"
    JSON_DATA[summary]="$summary_json"
}

# =============================================================================
# JSON Output
# =============================================================================

json_output_report() {
    local final_json="{"
    
    final_json+="\"timestamp\":\"${JSON_DATA[timestamp]}\","
    final_json+="\"version\":\"${JSON_DATA[version]}\","
    final_json+="\"system_info\":${JSON_DATA[system_info]},"
    final_json+="\"summary\":${JSON_DATA[summary]},"
    final_json+="\"tests\":${JSON_DATA[tests]},"
    final_json+="\"issues\":${JSON_DATA[issues]},"
    final_json+="\"fixes\":${JSON_DATA[fixes]}"
    
    final_json+="}"
    
    # JSON formatieren falls jq verfügbar
    if command -v jq &> /dev/null; then
        echo "$final_json" | jq '.'
    else
        echo "$final_json"
    fi
    
    log_info "JSON-Report generiert (${#final_json} Zeichen)"
}

# =============================================================================
# Streaming JSON für Live-Updates
# =============================================================================

json_stream_test_result() {
    local test_result="$1"
    
    if [[ "$JSON_MODE" == true ]] && [[ "$SILENT_MODE" != true ]]; then
        # Test-Ergebnis als einzelnes JSON-Event ausgeben
        local event_json="{\"type\":\"test_result\",\"timestamp\":\"$(date -Iseconds)\",\"data\":$test_result}"
        echo "$event_json" >&2  # Über stderr damit es nicht den finalen Report stört
    fi
}

json_stream_issue() {
    local issue="$1"
    
    if [[ "$JSON_MODE" == true ]] && [[ "$SILENT_MODE" != true ]]; then
        local event_json="{\"type\":\"issue_found\",\"timestamp\":\"$(date -Iseconds)\",\"data\":$issue}"
        echo "$event_json" >&2
    fi
}

json_stream_fix_applied() {
    local fix="$1"
    local success="$2"
    
    if [[ "$JSON_MODE" == true ]] && [[ "$SILENT_MODE" != true ]]; then
        local event_json="{\"type\":\"fix_applied\",\"timestamp\":\"$(date -Iseconds)\",\"success\":$success,\"data\":$fix}"
        echo "$event_json" >&2
    fi
}

# =============================================================================
# JSON Validation und Utilities
# =============================================================================

json_validate() {
    local json_string="$1"
    
    if command -v jq &> /dev/null; then
        if echo "$json_string" | jq empty 2>/dev/null; then
            return 0
        else
            log_warn "Ungültiges JSON: $(echo "$json_string" | head -c 100)..."
            return 1
        fi
    else
        # Einfache JSON-Syntax-Prüfung ohne jq
        if [[ "$json_string" =~ ^\{.*\}$ ]] || [[ "$json_string" =~ ^\[.*\]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

json_escape_string() {
    local string="$1"
    
    # JSON-String escaping
    string="${string//\\/\\\\}"  # Backslash
    string="${string//\"/\\\"}"  # Quote
    string="${string//$'\t'/\\t}" # Tab
    string="${string//$'\n'/\\n}" # Newline
    string="${string//$'\r'/\\r}" # Carriage return
    
    echo "$string"
}

# =============================================================================
# Export für externe Tools
# =============================================================================

json_export_to_file() {
    local output_file="$1"
    local json_data="$2"
    
    if [[ -n "$output_file" ]]; then
        if echo "$json_data" > "$output_file" 2>/dev/null; then
            log_info "JSON-Report exportiert: $output_file"
            return 0
        else
            log_error "Fehler beim Export nach: $output_file"
            return 1
        fi
    fi
}

# API-kompatibles Format für Webhook etc.
json_generate_webhook_payload() {
    local test_results="$1"
    local issues_json="$2"
    
    local payload="{"
    payload+="\"service\":\"netcheck\","
    payload+="\"version\":\"$VERSION\","
    payload+="\"timestamp\":\"$(date -Iseconds)\","
    payload+="\"host\":\"${SYSTEM_INFO[hostname]}\","
    payload+="\"status\":\"$(json_get_overall_status "$test_results" "$issues_json")\","
    payload+="\"summary\":${JSON_DATA[summary]},"
    payload+="\"details\":{\"tests\":$test_results,\"issues\":$issues_json}"
    payload+="}"
    
    echo "$payload"
}

json_get_overall_status() {
    local test_results="$1"
    local issues_json="$2"
    
    if command -v jq &> /dev/null; then
        local error_count
        error_count=$(echo "$test_results" | jq '[.[] | select(.status == "error" or .status == "critical")] | length' 2>/dev/null || echo "0")
        
        local issues_count
        issues_count=$(echo "$issues_json" | jq 'length' 2>/dev/null || echo "0")
        
        if [[ $error_count -gt 0 ]] || [[ $issues_count -gt 2 ]]; then
            echo "error"
        elif [[ $issues_count -gt 0 ]]; then
            echo "warning"
        else
            echo "ok"
        fi
    else
        echo "unknown"
    fi
}