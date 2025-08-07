#!/bin/bash

# =============================================================================
# NetCheck Installer - Vereinfachte Installation für End-User
# =============================================================================

set -euo pipefail

# Konfiguration
readonly REPO_URL="https://raw.githubusercontent.com/username/netcheck/main"
readonly INSTALL_DIR="$HOME/.netcheck"
readonly INSTALL_FILES=(
    "netcheck.sh"
    "lib/core.sh"
    "lib/system.sh" 
    "lib/network.sh"
    "lib/fixes.sh"
    "lib/ui.sh"
    "lib/json.sh"
    "config/defaults.conf"
    "LICENSE"
)

# Farben
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# =============================================================================
# Installation
# =============================================================================

main() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│                    NetCheck Installer                          │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    # Voraussetzungen prüfen
    check_requirements
    
    # Installationsverzeichnis erstellen
    setup_directories
    
    # Dateien herunterladen
    download_files
    
    # Berechtigungen setzen
    setup_permissions
    
    # PATH aktualisieren
    setup_path
    
    # Installation abschließen
    finish_installation
}

check_requirements() {
    echo "Prüfe Systemvoraussetzungen..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        die "NetCheck funktioniert nur auf macOS"
    fi
    
    if ! command -v curl &> /dev/null; then
        die "curl ist erforderlich aber nicht installiert"
    fi
    
    echo -e "  ${GREEN}✓ macOS erkannt${NC}"
    echo -e "  ${GREEN}✓ curl verfügbar${NC}"
    echo
}

setup_directories() {
    echo "Erstelle Installationsverzeichnisse..."
    
    # Alte Installation sichern
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "  ${YELLOW}⚠ Vorherige Installation gefunden${NC}"
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
        echo -e "  ${GREEN}✓ Backup erstellt${NC}"
    fi
    
    # Neue Verzeichnisse
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/logs"
    
    echo -e "  ${GREEN}✓ Verzeichnisse erstellt: $INSTALL_DIR${NC}"
    echo
}

download_files() {
    echo "Lade NetCheck-Dateien herunter..."
    
    for file in "${INSTALL_FILES[@]}"; do
        local url="${REPO_URL}/${file}"
        local local_path="${INSTALL_DIR}/${file}"
        
        echo -n "  Lade $file... "
        
        if curl -s -f "$url" -o "$local_path" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            die "Fehler beim Herunterladen von $file"
        fi
    done
    
    echo -e "  ${GREEN}✓ Alle Dateien heruntergeladen${NC}"
    echo
}

setup_permissions() {
    echo "Setze Dateiberechtigungen..."
    
    chmod +x "$INSTALL_DIR/netcheck.sh"
    chmod 644 "$INSTALL_DIR/lib/"*.sh
    chmod 644 "$INSTALL_DIR/config/defaults.conf"
    chmod 755 "$INSTALL_DIR/logs"
    
    echo -e "  ${GREEN}✓ Berechtigungen gesetzt${NC}"
    echo
}

setup_path() {
    echo "Konfiguriere PATH..."
    
    # Symlink im lokalen bin erstellen
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    if [[ -L "$bin_dir/netcheck" ]]; then
        rm "$bin_dir/netcheck"
    fi
    
    ln -s "$INSTALL_DIR/netcheck.sh" "$bin_dir/netcheck"
    
    # Shell-Konfiguration aktualisieren
    local shell_rc
    case "$SHELL" in
        */zsh) shell_rc="$HOME/.zshrc" ;;
        */bash) shell_rc="$HOME/.bashrc" ;;
        *) shell_rc="" ;;
    esac
    
    if [[ -n "$shell_rc" ]]; then
        # Prüfen ob PATH bereits konfiguriert
        if ! grep -q "$HOME/.local/bin" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# NetCheck PATH" >> "$shell_rc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            echo -e "  ${GREEN}✓ $shell_rc aktualisiert${NC}"
        else
            echo -e "  ${GREEN}✓ PATH bereits konfiguriert${NC}"
        fi
    fi
    
    echo -e "  ${GREEN}✓ Symlink erstellt: $bin_dir/netcheck${NC}"
    echo
}

finish_installation() {
    echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│                 Installation abgeschlossen!                    │${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    echo "NetCheck wurde erfolgreich installiert in:"
    echo "  $INSTALL_DIR"
    echo
    
    echo "Verfügbare Befehle:"
    echo "  netcheck                    # Standard-Analyse"
    echo "  netcheck --help             # Hilfe anzeigen"
    echo "  netcheck --json             # JSON-Export"
    echo
    
    echo "Zum Sofort-Test (neue Shell-Session erforderlich):"
    echo "  source ~/.zshrc  # oder ~/.bashrc"
    echo "  netcheck"
    echo
    
    echo "Oder direkt ausführen:"
    echo "  $INSTALL_DIR/netcheck.sh"
    echo
    
    # Quick-Test anbieten
    echo -ne "${BLUE}Möchten Sie NetCheck jetzt testen? [j/N] ${NC}"
    read -r -n 1 response
    echo
    
    if [[ "$response" =~ ^[JjYy]$ ]]; then
        echo
        echo "Führe NetCheck-Test aus..."
        "$INSTALL_DIR/netcheck.sh" --silent
    fi
}

die() {
    echo -e "${RED}FEHLER: $1${NC}" >&2
    exit 1
}

# Installation starten
main "$@"