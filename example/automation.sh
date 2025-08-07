#!/bin/bash

# =============================================================================
# NetCheck Automation Examples
# Beispiele für die Verwendung von NetCheck in Automation-Szenarien
# =============================================================================

# =============================================================================
# Beispiel 1: Monitoring Script mit JSON-Output
# =============================================================================

monitoring_check() {
    echo "=== Netzwerk-Monitoring Check ==="
    
    # NetCheck im JSON-Modus ausführen
    local result
    result=$(./netcheck.sh --json --silent 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # JSON parsen (mit jq)
        local status
        status=$(echo "$result" | jq -r '.summary.overall_status')
        
        local health_score
        health_score=$(echo "$result" | jq -r '.summary.health_score')
        
        case "$status" in
            "ok")
                echo "✓ Netzwerk OK (Health Score: ${health_score}%)"
                return 0
                ;;
            "warning")
                echo "⚠ Netzwerk-Warnungen (Health Score: ${health_score}%)"
                # Issues anzeigen
                echo "$result" | jq -r '.issues[].description' | while read -r issue; do
                    echo "  - $issue"
                done
                return 1
                ;;
            "critical"|"error")
                echo "✗ Kritische Netzwerkprobleme (Health Score: ${health_score}%)"
                echo "$result" | jq -r '.issues[].description' | while read -r issue; do
                    echo "  - $issue"
                done
                return 2
                ;;
        esac
    else
        echo "✗ NetCheck-Ausführung fehlgeschlagen"
        return 3
    fi
}

# =============================================================================
# Beispiel 2: Automatische Reparatur in Scripts
# =============================================================================

auto_fix_network() {
    echo "=== Automatische Netzwerk-Reparatur ==="
    
    # Erst prüfen ob Probleme vorliegen
    if ./netcheck.sh --json --silent | jq -r '.summary.overall_status' | grep -q "ok"; then
        echo "✓ Netzwerk bereits in Ordnung"
        return 0
    fi
    
    echo "Probleme erkannt, führe automatische Reparaturen durch..."
    
    # Fix-Only Modus mit JSON-Output für Logging
    local fix_result
    fix_result=$(./netcheck.sh --fix-only --json 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local applied_fixes
        applied_fixes=$(echo "$fix_result" | jq -r '.fixes_applied // 0')
        
        echo "✓ $applied_fixes Reparaturen durchgeführt"
        
        # Erneut prüfen
        sleep 5
        if ./netcheck.sh --json --silent | jq -r '.summary.overall_status' | grep -q "ok"; then
            echo "✓ Netzwerk nach Reparatur OK"
            return 0
        else
            echo "⚠ Weitere manuelle Eingriffe erforderlich"
            return 1
        fi
    else
        echo "✗ Automatische Reparatur fehlgeschlagen"
        return 2
    fi
}

# =============================================================================
# Beispiel 3: Cron-Job für regelmäßige Checks
# =============================================================================

# In crontab eintragen:
# */15 * * * * /path/to/netcheck/examples/automation.sh cron_check

cron_check() {
    local log_file="/tmp/netcheck_cron.log"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] Starte periodischen Netzwerk-Check..." >> "$log_file"
    
    # Stiller Check
    local result
    result=$(./netcheck.sh --json --silent 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local status
        status=$(echo "$result" | jq -r '.summary.overall_status')
        
        local health_score
        health_score=$(echo "$result" | jq -r '.summary.health_score')
        
        echo "[$timestamp] Status: $status, Health Score: ${health_score}%" >> "$log_file"
        
        # Bei Problemen: Alert senden
        if [[ "$status" != "ok" ]]; then
            send_alert "$status" "$health_score" "$result"
        fi
    else
        echo "[$timestamp] NetCheck-Fehler" >> "$log_file"
        send_alert "error" "0" ""
    fi
}

# =============================================================================
# Beispiel 4: Slack-Integration
# =============================================================================

send_slack_notification() {
    local webhook_url="$SLACK_WEBHOOK_URL"  # Als Environment Variable setzen
    local status="$1"
    local health_score="$2"
    local details="$3"
    
    if [[ -z "$webhook_url" ]]; then
        return
    fi
    
    local color icon message
    case "$status" in
        "ok")
            color="good"
            icon=":white_check_mark:"
            message="Netzwerk funktioniert einwandfrei"
            ;;
        "warning")
            color="warning"
            icon=":warning:"
            message="Netzwerk-Warnungen erkannt"
            ;;
        "critical"|"error")
            color="danger"
            icon=":x:"
            message="Kritische Netzwerkprobleme"
            ;;
    esac
    
    local payload
    payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "NetCheck Report - $(hostname)",
            "text": "$icon $message (Health Score: ${health_score}%)",
            "fields": [
                {
                    "title": "Timestamp",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S')",
                    "short": true
                },
                {
                    "title": "Host",
                    "value": "$(hostname)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
)
    
    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$webhook_url" > /dev/null
}

# =============================================================================
# Beispiel 5: E-Mail-Integration
# =============================================================================

send_email_alert() {
    local status="$1"
    local health_score="$2"
    local json_report="$3"
    
    local email_to="${NETCHECK_EMAIL_TO:-admin@company.com}"
    local email_from="${NETCHECK_EMAIL_FROM:-netcheck@$(hostname)}"
    
    # Issues extrahieren
    local issues
    issues=$(echo "$json_report" | jq -r '.issues[].description' | head -10)
    
    local subject="NetCheck Alert - $status - $(hostname)"
    
    local body
    body=$(cat << EOF
NetCheck Netzwerk-Analyse Report
========================================

Host: $(hostname)
Zeit: $(date '+%Y-%m-%d %H:%M:%S')
Status: $status
Health Score: ${health_score}%

Gefundene Probleme:
$issues

Vollständiger JSON-Report siehe Anhang.

--
NetCheck v2.0 Automated Monitoring
EOF
)
    
    # E-Mail senden (erfordert konfiguriertes sendmail/postfix)
    {
        echo "To: $email_to"
        echo "From: $email_from"
        echo "Subject: $subject"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo ""
        echo "$body"
    } | sendmail "$email_to" 2>/dev/null || {
        # Fallback: macOS mail command
        echo "$body" | mail -s "$subject" "$email_to" 2>/dev/null
    }
}

# =============================================================================
# Beispiel 6: Webhook-Integration
# =============================================================================

send_webhook() {
    local webhook_url="$NETCHECK_WEBHOOK_URL"
    local json_report="$1"
    
    if [[ -z "$webhook_url" ]]; then
        return
    fi
    
    # Webhook-Payload erstellen
    local payload
    payload=$(echo "$json_report" | jq '. + {
        "source": "netcheck",
        "hostname": "'$(hostname)'",
        "sent_at": "'$(date -Iseconds)'"
    }')
    
    # Webhook senden
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "User-Agent: NetCheck/2.0" \
        -d "$payload" \
        "$webhook_url" \
        --max-time 10 > /dev/null
}

# =============================================================================
# Beispiel 7: System-Integration (LaunchDaemon)
# =============================================================================

create_launch_daemon() {
    local plist_path="/Library/LaunchDaemons/com.netcheck.monitor.plist"
    
    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.netcheck.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/netcheck</string>
        <string>--json</string>
        <string>--silent</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer> <!-- 15 Minuten -->
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/netcheck.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/netcheck.error.log</string>
</dict>
</plist>
EOF
    
    # Daemon laden
    sudo launchctl load "$plist_path"
    echo "NetCheck LaunchDaemon erstellt und geladen"
}

# =============================================================================
# Beispiel 8: Batch-Processing für mehrere Hosts
# =============================================================================

batch_check_hosts() {
    local hosts=("$@")
    local results_dir="/tmp/netcheck_batch_$(date +%s)"
    
    mkdir -p "$results_dir"
    
    echo "Starte Batch-Check für ${#hosts[@]} Hosts..."
    
    for host in "${hosts[@]}"; do
        echo "Prüfe $host..."
        
        # SSH-basierter Check (NetCheck muss auf Zielhost installiert sein)
        ssh "$host" "netcheck --json --silent" > "$results_dir/$host.json" 2>/dev/null &
        
        # Parallel-Verarbeitung begrenzen
        if (( $(jobs -r | wc -l) >= 5 )); then
            wait
        fi
    done
    
    # Auf alle Jobs warten
    wait
    
    # Ergebnisse zusammenfassen
    echo "Batch-Check Ergebnisse:"
    for host in "${hosts[@]}"; do
        local result_file="$results_dir/$host.json"
        
        if [[ -f "$result_file" ]] && [[ -s "$result_file" ]]; then
            local status
            status=$(jq -r '.summary.overall_status' "$result_file" 2>/dev/null || echo "error")
            
            printf "  %-20s %s\n" "$host:" "$status"
        else
            printf "  %-20s %s\n" "$host:" "unreachable"
        fi
    done
    
    echo "Detaillierte Ergebnisse in: $results_dir"
}

# =============================================================================
# Helper Functions
# =============================================================================

send_alert() {
    local status="$1"
    local health_score="$2"
    local json_report="$3"
    
    # Verschiedene Alert-Kanäle
    [[ -n "${SLACK_WEBHOOK_URL:-}" ]] && send_slack_notification "$status" "$health_score" "$json_report"
    [[ -n "${NETCHECK_EMAIL_TO:-}" ]] && send_email_alert "$status" "$health_score" "$json_report"
    [[ -n "${NETCHECK_WEBHOOK_URL:-}" ]] && send_webhook "$json_report"
}

# =============================================================================
# Main Function für direkten Aufruf
# =============================================================================

main() {
    case "${1:-}" in
        "monitoring")
            monitoring_check
            ;;
        "auto_fix")
            auto_fix_network
            ;;
        "cron_check")
            cron_check
            ;;
        "batch")
            shift
            batch_check_hosts "$@"
            ;;
        "create_daemon")
            create_launch_daemon
            ;;
        *)
            echo "NetCheck Automation Examples"
            echo ""
            echo "Verwendung: $0 <command> [args...]"
            echo ""
            echo "Verfügbare Befehle:"
            echo "  monitoring      - Monitoring-Check mit JSON-Output"
            echo "  auto_fix        - Automatische Problemreparatur"
            echo "  cron_check      - Für Cron-Job geeigneter Check"
            echo "  batch <hosts>   - Batch-Check für mehrere Hosts"
            echo "  create_daemon   - LaunchDaemon erstellen"
            echo ""
            echo "Environment Variablen:"
            echo "  SLACK_WEBHOOK_URL     - Slack Webhook für Notifications"
            echo "  NETCHECK_EMAIL_TO     - E-Mail für Alerts"
            echo "  NETCHECK_WEBHOOK_URL  - Custom Webhook URL"
            ;;
    esac
}

# Script ausführen falls direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
