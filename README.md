# NetCheck v2.0 - Professionelles Netzwerkanalysetool für macOS

Ein modulares, benutzerfreundliches und mächtiges Bash-Tool zur umfassenden Diagnose und automatischen Behebung von Netzwerkproblemen auf macOS.

![NetCheck Demo](https://via.placeholder.com/800x400/2563eb/ffffff?text=NetCheck+v2.0+Demo)

## ✨ Features

### 🔍 Umfassende Diagnose
- **8 verschiedene Netzwerk-Tests** mit intelligenter Fallback-Logik
- **Automatische Interface-Erkennung** (WiFi, Ethernet, Thunderbolt)
- **macOS-Version-spezifische Kompatibilität** (10.13+)
- **Geschwindigkeitsmessung** mit realistischen Bewertungen
- **Proxy- und Firewall-Erkennung**

### 🎨 Benutzerfreundliche Oberfläche
- **Adaptive UI** basierend auf Terminal-Fähigkeiten
- **Barrierefreier Modus** für Screen-Reader
- **Farbcodierte Ausgaben** mit hohem Kontrast
- **Progress Bars** und Live-Status-Updates
- **Humanisierte Fehlermeldungen** ohne Fachchinesisch

### 🛠️ Intelligente Problemlösung
- **Automatische Issue-Erkennung** mit Kategorisierung
- **Kontextspezifische Lösungsvorschläge**
- **Sichere Auto-Reparaturen** mit expliziten Benutzer-Warnungen
- **Minimale sudo-Verwendung** mit transparenter Dokumentation

### ⚙️ Flexible Konfiguration
- **CLI-Parameter** für verschiedene Anwendungsfälle
- **JSON-Export** für Automation und Integration
- **Konfigurationsdateien** für Anpassungen
- **Silent/Batch-Modus** für Scripts

### 🔒 Sicherheit & Stabilität
- **Fehlertolerante Ausführung** ohne harte Abbrüche
- **Tool-Verfügbarkeitsprüfung** mit Alternativen
- **Sichere Temp-Datei-Handhabung**
- **Umfassende Logging** für Debugging

## 🚀 Installation & Verwendung

### Direkte Ausführung (Empfohlen)
```bash
# Einfache Analyse
curl -s https://raw.githubusercontent.com/username/netcheck/main/netcheck.sh | bash

# Mit Optionen
bash <(curl -s https://raw.githubusercontent.com/username/netcheck/main/netcheck.sh) --json --silent
```

### Lokale Installation
```bash
# Repository klonen
git clone https://github.com/username/netcheck.git
cd netcheck

# Ausführbar machen
chmod +x netcheck.sh

# Standard-Analyse
./netcheck.sh

# Mit Optionen
./netcheck.sh --help
```

## 📋 CLI-Optionen

```
NetCheck v2.0.0 - Netzwerkanalysetool für macOS

VERWENDUNG:
    ./netcheck.sh [OPTIONEN]

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
```

## 💡 Anwendungsbeispiele

### Für Endnutzer
```bash
# Standard-Diagnose mit Reparatur-Angeboten
./netcheck.sh

# Schnelle Analyse ohne UI
./netcheck.sh --silent

# Für Sehbehinderte optimiert
./netcheck.sh --accessible
```

### Für IT-Administratoren
```bash
# JSON-Report für Monitoring-Systeme
./netcheck.sh --json --silent > network_status.json

# Nur bekannte Probleme reparieren
./netcheck.sh --fix-only

# Mit erweiterten Logs für Debugging
./netcheck.sh --log-level DEBUG
```

### Für Automation
```bash
# In Scripts verwenden
if ./netcheck.sh --json --silent | jq -r '.summary.overall_status' | grep -q "ok"; then
    echo "Netzwerk OK"
else
    echo "Netzwerkprobleme erkannt"
fi

# Webhook-Integration
./netcheck.sh --json --silent | curl -X POST -H "Content-Type: application/json" \
    -d @- https://monitoring.company.com/webhook/netcheck
```

## 🔧 Unterstützte Probleme & Lösungen

| Problem-Kategorie | Automatisch erkannt | Auto-Fix verfügbar |
|------------------|-------------------|-------------------|
| **WiFi-Verbindung** | ✅ Signal, SSID, Konnektivität | ✅ Reset, DNS-Refresh |
| **DNS-Auflösung** | ✅ Multi-Domain-Tests | ✅ Cache-Flush, Server-Reset |
| **Internet-Zugang** | ✅ Multi-Host-Pings | ✅ Config-Refresh, Interface-Reset |
| **Router/Gateway** | ✅ Erreichbarkeit, Routing | ✅ Route-Reset, DHCP-Refresh |
| **Netzwerk-Speed** | ✅ Download-Messung | ⚠️ Optimierungsvorschläge |
| **Firewall-Status** | ✅ Status-Erkennung | ✅ Aktivierung |
| **Proxy-Settings** | ✅ Konfiguration | ✅ Reset |
| **Interface-Probleme** | ✅ Status aller Interfaces | ✅ Restart, Re-enable |

## 📊 JSON-API

NetCheck generiert strukturierte JSON-Ausgaben für Integration:

```json
{
  "timestamp": "2025-01-27T14:30:15+01:00",
  "version": "2.0.0",
  "system_info": {
    "hostname": "MacBook-Pro",
    "os_version": "14.2.1",
    "model": "MacBook Pro (14-inch, M3, 2023)",
    "primary_interface": "en0"
  },
  "summary": {
    "overall_status": "ok",
    "health_score": 95,
    "total_tests": 8,
    "tests_ok": 7,
    "issues_found": 1,
    "fixes_applied": 1
  },
  "tests": [...],
  "issues": [...],
  "fixes": [...]
}
```

## 🏗️ Architektur

NetCheck v2.0 folgt einer modularen Architektur:

```
netcheck/
├── netcheck.sh          # Haupt-Einstiegspunkt
├── lib/                 # Core-Module
│   ├── core.sh          # Grundfunktionen, Logging
│   ├── system.sh        # System-Erkennung, Kompatibilität
│   ├── network.sh       # Netzwerk-Diagnostik
│   ├── fixes.sh         # Automatische Reparaturen
│   ├── ui.sh            # User Interface
│   └── json.sh          # JSON Export/API
├── config/
│   └── defaults.conf    # Konfiguration
├── README.md
├── LICENSE
└── CHANGELOG.md
```

## 🔄 Kompatibilität

| macOS Version | Status | Besonderheiten |
|--------------|--------|---------------|
| **14.x (Sonoma)** | ✅ Vollständig | Alle Features |
| **13.x (Ventura)** | ✅ Vollständig | Alle Features |
| **12.x (Monterey)** | ✅ Vollständig | Alle Features |
| **11.x (Big Sur)** | ✅ Vollständig | Neue Firewall-API |
| **10.15 (Catalina)** | ✅ Kompatibel | Legacy WiFi-Tools |
| **10.14 (Mojave)** | ✅ Kompatibel | Begrenzte WiFi-API |
| **10.13 (High Sierra)** | ⚠️ Basis-Support | Minimale Features |
| **< 10.13** | ❌ Nicht unterstützt | - |

## 🤝 Beitragen

Wir freuen uns über Contributions! Siehe unsere [Contributing Guidelines](CONTRIBUTING.md).

### Entwicklung
```bash
# Development Mode
export NETCHECK_DEV=1
export NETCHECK_DEBUG=1

# Tests ausführen
./tests/run_tests.sh

# Code-Style prüfen
shellcheck netcheck.sh lib/*.sh
```

## 📈 Roadmap

### v2.1 (Q2 2025)
- [ ] Webhook-Integration
- [ ] VPN-Erkennung
- [ ] IPv6-Support
- [ ] Netzwerk-Qualitäts-Trends

### v3.0 (Q4 2025)
- [ ] Web-Interface
- [ ] Multi-Platform (Linux)
- [ ] Enterprise-Features
- [ ] ML-basierte Problemvorhersage

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/username/netcheck/issues)
- **Discussions**: [GitHub Discussions](https://github.com/username/netcheck/discussions)
- **Wiki**: [Ausführliche Dokumentation](https://github.com/username/netcheck/wiki)

## 📄 Lizenz

NetCheck ist unter der MIT-Lizenz lizenziert. Siehe [LICENSE](LICENSE) für Details.

## 🙏 Danksagungen

- Apple für die robusten macOS-Netzwerk-APIs
- Die Open-Source-Community für Inspiration und Feedback
- Alle Beta-Tester für wertvolle Rückmeldungen

---

<div align="center">

**Gemacht mit ❤️ für die macOS-Community**

[⭐ Star uns auf GitHub](https://github.com/username/netcheck) • [🐛 Bug melden](https://github.com/username/netcheck/issues) • [💡 Feature vorschlagen](https://github.com/username/netcheck/discussions)

</div>