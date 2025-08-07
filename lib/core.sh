#!/bin/bash

# =============================================================================
# NetCheck Core - Grundlegende Funktionen und Utilities
# =============================================================================

# Globale Arrays für Ergebnisse
declare -a NETCHECK_ISSUES=()
declare -a NETCHECK_FIXES=()
declare -a NETCHECK_TEST_RESULTS=()

# =============================================================================
# Logging System
# =============================================================================

LOG_FILE=""
LOG_LEVEL="INFO"

log_init() {
    LOG_FILE="$1"
    LOG_LEVEL="${2:-INFO}"
    
    # Log-Datei erstellen
    cat > "$LOG_FILE" << EOF
# NetCheck Log - $(date '+%Y-%m-%d %H:%M:%S')
# Version: $VERSION
# System: $(uname -a)
# User: $(whoami)
# PID: $$
EOF
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Debug Output falls aktiviert
    if [[ "${NETCHECK_DEBUG:-}" == "1" ]]; then
        echo "DEBUG: [$level] $message" >&2
    fi
}

log_debug() { [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1"; }

# =============================================================================
# Error Handling
# =============================================================================

die() {
    local message="$1"
    log_error "$message"
    
    if [[ "$JSON_MODE" == true ]]; then
        echo '{"error": "'"$message"'", "timestamp": "'"$(date -Iseconds)"'"}'
    else
        echo -e "${RED}FEHLER:${NC} $message" >&2
    fi
    
    exit 1
}

warn() {
    local message="$1"
    log_warn "$message"
    
    if [[ "$JSON_MODE" != true ]] && [[ "$SILENT_MODE" != true ]]; then
        echo -e "${YELLOW}WARNUNG:${NC} $message" >&2
    fi
}

# =============================================================================
# Tool Availability Checks
# =============================================================================

check_tool_availability() {
    local tool="$1"
    local alternatives=("${@:2}")
    
    if command -v "$tool" &> /dev/null; then
        echo "$tool"
        return 0
    fi
    
    # Alternativen prüfen
    for alt in "${alternatives[@]}"; do
        if command -v "$alt" &> /dev/null; then
            log_warn "Tool '$tool' nicht verfügbar, verwende Alternative: '$alt'"
            echo "$alt"
            return 0
        fi
    done
    
    log_error "Tool '$tool' und Alternativen nicht verfügbar: ${alternatives[*]}"
    return 1
}

# =============================================================================
# Timeout-basierte Ausführung
# =============================================================================

run_with_timeout() {
    local timeout="$1"
    local description="$2"
    shift 2
    
    log_debug "Ausführung mit Timeout ${timeout}s: $description"
    
    if timeout "$timeout" "$@" 2>/dev/null; then
        log_debug "$description: Erfolgreich"
        return 0
    else
        local exit_code=$?
        log_warn "$description: Timeout oder Fehler (Exit: $exit_code)"
        return $exit_code
    fi
}

# =============================================================================
# Array Utilities
# =============================================================================

array_contains() {
    local item="$1"
    shift
    local array=("$@")
    
    for element in "${array[@]}"; do
        [[ "$element" == "$item" ]] && return 0
    done
    return 1
}

add_issue() {
    local severity="$1"
    local category="$2" 
    local description="$3"
    local auto_fixable="${4:-false}"
    
    local issue_json="{\"severity\":\"$severity\",\"category\":\"$category\",\"description\":\"$description\",\"auto_fixable\":$auto_fixable,\"timestamp\":\"$(date -Iseconds)\"}"
    NETCHECK_ISSUES+=("$issue_json")
    
    log_warn "Issue gefunden: $description (Kategorie: $category, Severity: $severity)"
}

add_fix() {
    local description="$1"
    local command="${2:-}"
    local requires_sudo="${3:-false}"
    
    local fix_json="{\"description\":\"$description\",\"command\":\"$command\",\"requires_sudo\":$requires_sudo,\"applied\":false}"
    NETCHECK_FIXES+=("$fix_json")
    
    log_info "Fix hinzugefügt: $description"
}

# =============================================================================
# Netzwerk Utilities
# =============================================================================

get_primary_interface() {
    local interface
    
    # Aktive Netzwerk-Services finden
    while IFS= read -r line; do
        if [[ "$line" =~ Hardware\ Port:\ Wi-Fi.*Device:\ (.*) ]]; then
            interface="${BASH_REMATCH[1]}"
            if is_interface_active "$interface"; then
                echo "$interface"
                return 0
            fi
        elif [[ "$line" =~ Hardware\ Port:\ Ethernet.*Device:\ (.*) ]]; then
            interface="${BASH_REMATCH[1]}"
            if is_interface_active "$interface"; then
                echo "$interface"
                return 0
            fi
        fi
    done < <(networksetup -listallhardwareports 2>/dev/null || echo "")
    
    # Fallback: en0, en1, en2 testen
    for fallback in en0 en1 en2; do
        if is_interface_active "$fallback"; then
            log_warn "Verwendung von Fallback-Interface: $fallback"
            echo "$fallback"
            return 0
        fi
    done
    
    log_error "Kein aktives Netzwerk-Interface gefunden"
    return 1
}

is_interface_active() {
    local interface="$1"
    
    if ifconfig "$interface" 2>/dev/null | grep -q "status: active"; then
        return 0
    fi
    return 1
}

get_wifi_interface() {
    local interface
    
    # WiFi-spezifisches Interface finden
    while IFS= read -r line; do
        if [[ "$line" =~ Hardware\ Port:\ Wi-Fi.*Device:\ (.*) ]]; then
            interface="${BASH_REMATCH[1]}"
            if is_interface_active "$interface"; then
                echo "$interface"
                return 0
            fi
        fi
    done < <(networksetup -listallhardwareports 2>/dev/null || echo "")
    
    return 1
}

# =============================================================================
# String Utilities
# =============================================================================

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# =============================================================================
# Validation
# =============================================================================

is_valid_ip() {
    local ip="$1"
    local pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ $ip =~ $pattern ]]; then
        # Prüfe dass alle Oktette <= 255 sind
        IFS='.' read -ra ADDR <<< "$ip"
        for octet in "${ADDR[@]}"; do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

is_valid_domain() {
    local domain="$1"
    local pattern="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    
    [[ $domain =~ $pattern ]] && [[ ${#domain} -le 253 ]]
}

# =============================================================================
# Performance Monitoring
# =============================================================================

get_memory_usage() {
    ps -o pid,ppid,%mem,rss,command -p $$ | tail -1
}

monitor_performance() {
    if [[ "${NETCHECK_DEBUG:-}" == "1" ]]; then
        log_debug "Memory usage: $(get_memory_usage)"
    fi
}
