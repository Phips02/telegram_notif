#!/bin/bash

###############################################################################
# Script de notification Telegram pour les connexions SSH et su
###############################################################################

# Version du système
TELEGRAM_VERSION="4.8"

# Configuration du logger
export LOG_PREFIX="telegram_notif"
export LOG_LEVEL="INFO"
export ENABLE_TELEGRAM="false"  # Éviter la boucle infinie

# Configuration de performance (pour éviter les lags)
SKIP_PUBLIC_IP="${SKIP_PUBLIC_IP:-false}"  # Mettre à "true" pour désactiver la récupération IP publique

# Intégration du logger Phips
if [ -f "/usr/local/bin/phips_logger" ]; then
    source "/usr/local/bin/phips_logger"
else
    # Fallback si le logger n'est pas installé
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [telegram_notif] $1"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [telegram_notif] $1" >&2; }
    log_debug() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] [telegram_notif] $1"; }
fi

# Gestion des arguments
if [ "$1" = "--version" ]; then
    echo "Version $TELEGRAM_VERSION"
    exit 0
fi
BACKGROUND=false
TEST_MODE=false
for arg in "$@"; do
    case $arg in
        --background)
            BACKGROUND=true
            ;;
        --test)
            TEST_MODE=true
            ;;
        *)
            # Argument inconnu
            ;;
    esac
done

# Exécution en arrière-plan pour éviter le lag de connexion (sauf en mode test)
if [ "$BACKGROUND" = "false" ] && [ "$TEST_MODE" = "false" ]; then
    # Lancer le script en arrière-plan et se détacher immédiatement
    nohup "$0" --background </dev/null >/dev/null 2>&1 &
    # Retourner immédiatement pour ne pas bloquer la connexion
    exit 0
fi

# À partir d'ici, le script s'exécute en arrière-plan ou en mode test
if [ "$TEST_MODE" = "false" ]; then
    # Petite pause pour laisser la connexion se stabiliser
    sleep 1
fi

# Fonction simplifiée pour charger la configuration
safe_source() {
    local config_file="$1"
    if [ ! -f "$config_file" ]; then
        log_error "Fichier de configuration introuvable: $config_file"
        return 1
    fi
    
    if ! source "$config_file" 2>/dev/null; then
        log_error "Échec du chargement de $config_file"
        return 1
    fi
    return 0
}

# Chargement des identifiants Telegram
if [ -r "/etc/telegram/credentials.cfg" ]; then
    source "/etc/telegram/credentials.cfg" 2>/dev/null
else
    log_error "Identifiants Telegram non trouvés: /etc/telegram/credentials.cfg"
    exit 1
fi

# Chargement de la configuration spécifique
if [ -r "/etc/telegram/telegram_notif.cfg" ]; then
    source "/etc/telegram/telegram_notif.cfg" 2>/dev/null
else
    log_info "Configuration spécifique non trouvée, utilisation des valeurs par défaut"
    # Valeurs par défaut
    CURL_TIMEOUT=10
    DATE_FORMAT="%Y-%m-%d %H:%M:%S"
    SKIP_PUBLIC_IP="false"
fi

# Vérification des variables essentielles
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    log_error "BOT_TOKEN ou CHAT_ID non défini"
    exit 1
fi

log_debug "Configuration Telegram chargée avec succès"

# Vérification des dépendances
log_debug "Vérification des dépendances..."
for dep in curl; do
    if ! command -v "$dep" &> /dev/null; then
        log_error "Dépendance manquante : $dep"
        exit 1
    fi
done

# Charger les fonctions communes
BASE_DIR="/usr/local/bin/telegram_notif"
if [ ! -f "$BASE_DIR/telegram.functions.sh" ]; then
    log_error "Fichier de fonctions introuvable: $BASE_DIR/telegram.functions.sh"
    exit 1
fi
source "$BASE_DIR/telegram.functions.sh"

# Fonction optimisée pour collecter les informations
collect_info() {
    log_debug "Collecte des informations système..."
    
    # Informations de base
    DATE=$(date "+%F %H:%M:%S")
    USER_INFO="$USER"
    HOST_INFO="$HOSTNAME"
    
    # Détection améliorée du type de connexion
    if [ -n "$SSH_CONNECTION" ]; then
        CONNECTION_TYPE="SSH"
        IP_SOURCE=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    elif [ -n "$PAM_TYPE" ]; then
        CONNECTION_TYPE="su/sudo"
        IP_SOURCE="Local"
    elif [ "$TERM" = "screen" ] || [ "$TERM" = "tmux" ]; then
        CONNECTION_TYPE="Screen/Tmux"
        IP_SOURCE="Local"
    elif [ -n "$SSH_CLIENT" ]; then
        CONNECTION_TYPE="SSH (legacy)"
        IP_SOURCE=$(echo "$SSH_CLIENT" | awk '{print $1}')
    elif [ "$TERM" = "xterm" ] || [ "$TERM" = "xterm-256color" ]; then
        # Détection spécifique Proxmox
        if pgrep -f "pveproxy" >/dev/null 2>&1; then
            CONNECTION_TYPE="Console Proxmox"
            # Version rapide : essayer d'abord les variables d'environnement
            if [ -n "$SSH_CLIENT" ]; then
                IP_SOURCE=$(echo "$SSH_CLIENT" | awk '{print $1}')
            elif [ -n "$REMOTE_ADDR" ]; then
                IP_SOURCE="$REMOTE_ADDR"
            else
                # Fallback rapide sans journalctl
                IP_SOURCE="Web Interface"
            fi
        else
            CONNECTION_TYPE="Console Web"
            IP_SOURCE="Web Interface"
        fi
    elif [ -t 0 ]; then
        # Terminal interactif local
        CONNECTION_TYPE="Console Locale"
        IP_SOURCE="Local"
    else
        # Exécution non-interactive (cron, script, etc.)
        CONNECTION_TYPE="Non-interactif"
        IP_SOURCE="Système"
    fi
    
    # Parallélisation des opérations pour optimiser les performances
    {
        # IP locale (simple et rapide)
        IP_LOCAL=$(hostname -I 2>/dev/null | awk '{print $1}') || IP_LOCAL="N/A" &
        
        # Informations publiques (avec option de désactivation)
        if [ "$SKIP_PUBLIC_IP" = "true" ]; then
            IP_PUBLIC="Désactivé"
        elif command -v curl >/dev/null 2>&1; then
            # Timeout réduit à 2 secondes pour éviter les lags
            IP_PUBLIC=$(timeout 2 curl -s --max-time 2 ipinfo.io/ip 2>/dev/null) || IP_PUBLIC="N/A" &
        else
            IP_PUBLIC="N/A"
        fi
        
        # Informations rapides (commandes locales)
        ACTIVE_SESSIONS=$(who | wc -l 2>/dev/null) || ACTIVE_SESSIONS="N/A" &
        TERMINAL_INFO=$(tty 2>/dev/null) || TERMINAL_INFO="N/A" &
        
        # Attendre que toutes les opérations en arrière-plan se terminent
        wait
    } 2>/dev/null
    

}

# Mode test : afficher les informations et sortir
if [ "$TEST_MODE" = "true" ]; then
    echo "Mode test activé - Vérification de la configuration..."
    echo "Identifiants Telegram : OK"
    echo "Configuration spécifique : OK"
    echo "Fonctions Telegram : OK"
    echo "Dépendances (curl) : OK"
    echo "Test réussi !"
    exit 0
fi

# Collecter les informations
collect_info

# Construction du message avec séparations
TEXT="🔔 *Connexion $CONNECTION_TYPE* %0A\
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ %0A\
📅 $DATE %0A\
👤 Utilisateur: $USER_INFO %0A\
💻 Hôte: $HOST_INFO %0A\
📺 Terminal: $TERMINAL_INFO %0A\
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ %0A\
🌐 IP Locale: $IP_LOCAL %0A\
📍 IP Source: $IP_SOURCE %0A\
🌍 IP Publique: $IP_PUBLIC %0A\
👥 Sessions actives: $ACTIVE_SESSIONS %0A\
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Envoi du message
if ! telegram_text_send "$TEXT"; then
    log_error "Échec de l'envoi de la notification"
    exit 1
fi
log_info "Notification envoyée avec succès"

exit 0