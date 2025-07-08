#!/bin/bash
# install_su_notif.sh - Installation simple des notifications su
# Version: 2.0 - Ultra simplifié
# Auteur: Phips

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction de logging
log() {
    case $1 in
        "INFO") echo -e "${BLUE}[INFO]${NC} $2" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $2" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $2" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $2" ;;
    esac
}

# Vérifier root
if [ "$EUID" -ne 0 ]; then
    log "ERROR" "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Vérifier configuration Telegram
if [ ! -f "/etc/telegram/credentials.cfg" ]; then
    log "ERROR" "Configuration Telegram non trouvée dans /etc/telegram/credentials.cfg"
    log "INFO" "Veuillez d'abord configurer vos credentials Telegram"
    exit 1
fi

source "/etc/telegram/credentials.cfg"
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    log "ERROR" "BOT_TOKEN ou CHAT_ID non défini dans /etc/telegram/credentials.cfg"
    exit 1
fi

log "SUCCESS" "Configuration Telegram trouvée"

# Installer le script
SCRIPT_DIR="/usr/local/bin/telegram_notif"
SCRIPT_FILE="$SCRIPT_DIR/telegram_su_notif.sh"

mkdir -p "$SCRIPT_DIR"
cp "telegram_su_notif.sh" "$SCRIPT_FILE"
chown root:root "$SCRIPT_FILE"
chmod 755 "$SCRIPT_FILE"

log "SUCCESS" "Script installé: $SCRIPT_FILE"

# Configurer PAM pour su
PAM_FILE="/etc/pam.d/su"
PAM_LINE="session optional pam_exec.so quiet /usr/local/bin/telegram_notif/telegram_su_notif.sh"

if grep -q "telegram_su_notif.sh" "$PAM_FILE"; then
    log "WARN" "Configuration PAM déjà présente"
else
    # Sauvegarde
    cp "$PAM_FILE" "$PAM_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    log "INFO" "Sauvegarde PAM créée"
    
    # Ajouter la ligne après @include common-session
    if grep -q "@include common-session" "$PAM_FILE"; then
        sed -i "/^@include common-session/a\\$PAM_LINE" "$PAM_FILE"
    else
        echo "$PAM_LINE" >> "$PAM_FILE"
    fi
    
    log "SUCCESS" "Configuration PAM ajoutée"
fi

# Créer le fichier de log
LOG_FILE="/var/log/telegram_su_notif.log"
touch "$LOG_FILE"
chown root:root "$LOG_FILE"
chmod 640 "$LOG_FILE"

log "SUCCESS" "Fichier de log créé: $LOG_FILE"

# Test de la configuration
log "INFO" "Test de la configuration..."

# Simuler un appel PAM
export PAM_USER="testuser"
export PAM_RUSER="root"
export PAM_TTY="pts/0"
export PAM_RHOST="192.168.1.100"

if "$SCRIPT_FILE" >/dev/null 2>&1; then
    log "SUCCESS" "Test réussi - vérifiez votre Telegram"
else
    log "ERROR" "Test échoué - vérifiez les logs"
fi

log "SUCCESS" "Installation terminée !"
log "INFO" "Les notifications su sont maintenant actives"
log "INFO" "Testez avec: su - root"
log "INFO" "Logs disponibles: tail -f $LOG_FILE"
