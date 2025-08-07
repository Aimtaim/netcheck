# Changelog

Alle wichtigen Änderungen an NetCheck werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-27

### Hinzugefügt
- **Modulare Architektur**: Aufgeteilt in separate Module (core, system, network, fixes, ui, json)
- **CLI-Parameter**: Umfassende Kommandozeilen-Optionen
  - `--silent`: Stiller Modus
  - `--json`: JSON-Export
  - `--fix-only`: Nur Reparaturen
  - `--no-color`: Ohne Farben
  - `--accessible`: Barrierefreier Modus
- **Automatische Interface-Erkennung**: Dynamische Erkennung aller Netzwerk-Interfaces
- **Erweiterte macOS-Kompatibilität**: Unterstützung für macOS 10.13+
- **JSON-Export**: Vollständige JSON-API für Automation
- **Intelligente Fehlertoleranz**: Graceful Degradation bei fehlenden Tools
- **Barrierefreiheit**: Screen-Reader kompatible Ausgaben
- **Konfigurationssystem**: Externe Konfigurationsdateien
- **Streaming JSON**: Live-Updates über stderr
- **Erweiterte Diagnostik**: 8 verschiedene Netzwerk-Tests

### Verbessert
- **Benutzerfreundlichkeit**: Humanisierte Fehlermeldungen
- **Sicherheit**: Minimierte sudo-Aufrufe mit expliziten Warnungen
- **Performance**: Parallele Test-Ausführung
- **Logging**: Strukturierte Logs mit verschiedenen Leveln
- **UI**: Responsive Darstellung für verschiedene Terminal-Größen

### Geändert
- **Breaking**: Komplett neue Architektur (nicht kompatibel mit v1.x)
- **API**: JSON-Output Format geändert
- **Konfiguration**: Neue Konfigurationsdatei-Struktur

## [1.0.0] - 2025-01-27

### Hinzugefügt
- Grundlegende Netzwerk-Diagnostik
- WiFi-Verbindungstest
- DNS-Auflösungstest
- Internet-Konnektivitätstest
- Geschwindigkeitstest
- Automatische Problemlösung
- Farbige Terminal-Ausgabe
- Progress Bars
- Log-Dateien

### Bekannte Probleme
- Nur WiFi-Interface en0 unterstützt
- Begrenzte macOS-Version Kompatibilität
- Keine CLI-Parameter
- Monolithische Code-Struktur

## [Unveröffentlicht]

### Geplant für v2.1.0
- [ ] Webhook-Integration
- [ ] E-Mail-Benachrichtigungen
- [ ] Erweiterte VPN-Erkennung
- [ ] Netzwerk-Qualitäts-Monitoring
- [ ] Historische Trend-Analyse
- [ ] Docker/Container-Netzwerk-Tests
- [ ] IPv6-Unterstützung
- [ ] Automatische Update-Funktion
- [ ] Plugin-System für Erweiterungen
- [ ] Web-Interface (optional)

### Geplant für v3.0.0
- [ ] Vollständige IPv6-Unterstützung
- [ ] Netzwerk-Security-Scans
- [ ] Enterprise-Features
- [ ] Multi-Platform-Support (Linux, Windows)
- [ ] Cloud-Integration
- [ ] Machine Learning für Problemvorhersage

---

## Versionsschema

NetCheck verwendet [Semantic Versioning](https://semver.org/):

- **MAJOR**: Inkompatible API-Änderungen
- **MINOR**: Neue Features (abwärtskompatibel)
- **PATCH**: Bugfixes (abwärtskompatibel)

## Support-Richtlinie

- **Aktuelle Version**: Vollständiger Support
- **Vorherige MAJOR**: Sicherheitsupdates für 12 Monate
- **Ältere Versionen**: Community Support nur

## Migration

### Von v1.x zu v2.x

```bash
# Backup der alten Version
mv netcheck.sh netcheck_v1_backup.sh

# Neue Version herunterladen
curl -O https://raw.githubusercontent.com/username/netcheck/main/netcheck.sh

# Neue Features nutzen
./netcheck.sh --help
```

**Breaking Changes:**
- Neues Modul-System erfordert alle Dateien
- JSON-Output Format geändert
- Einige Konfigurationsoptionen verschoben

**Neue Features:**
- CLI-Parameter verwenden
- JSON-Export für Automation
- Verbesserte Fehlerbehandlung