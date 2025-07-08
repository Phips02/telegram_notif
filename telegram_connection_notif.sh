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
for arg in "$@"; do
    case $arg in
        --background)
            BACKGROUND=true
            ;;
        *)
            # Argument inconnu
            ;;
    esac
done

# Exécution en arrière-plan pour éviter le lag de connexion
if [ "$BACKGROUND" = "false" ]; then
    # Lancer le script en arrière-plan et se détacher immédiatement
    nohup "$0" --background </dev/null >/dev/null 2>&1 &
    # Retourner immédiatement pour ne pas bloquer la connexion
    exit 0
fi

# À partir d'ici, le script s'exécute en arrière-plan
# Petite pause pour laisser la connexion se stabiliser
sleep 1

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

# Vérification précoce des fichiers de configuration
if [ ! -r "/etc/telegram/credentials.cfg" ]; then
    log_error "Identifiants Telegram non trouvés: /etc/telegram/credentials.cfg"
    # Sortir silencieusement pour ne pas perturber PAM
    exit 0
fi

# Chargement des identifiants Telegram
source "/etc/telegram/credentials.cfg" 2>/dev/null

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
    # Sortir silencieusement pour ne pas perturber PAM
    exit 0
fi

log_debug "Configuration Telegram chargée avec succès"

# Vérification des dépendances
log_debug "Vérification des dépendances..."
for dep in curl; do
    if ! command -v "$dep" &> /dev/null; then
        log_error "Dépendance manquante : $dep"
        # Sortir silencieusement pour ne pas perturber PAM
        exit 0
    fi
done

# Charger les fonctions communes
BASE_DIR="/usr/local/bin/telegram_notif"
if [ ! -f "$BASE_DIR/telegram.functions.sh" ]; then
    log_error "Fichier de fonctions introuvable: $BASE_DIR/telegram.functions.sh"
    # Sortir silencieusement pour ne pas perturber PAM
    exit 0
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
    
    # Collecte des informations système de manière optimisée
    # IP locale (simple et rapide)
    IP_LOCAL=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$IP_LOCAL" ] && IP_LOCAL="N/A"
    
    # Informations publiques (avec option de désactivation)
    if [ "$SKIP_PUBLIC_IP" = "true" ]; then
        IP_PUBLIC="Désactivé"
    elif command -v curl >/dev/null 2>&1; then
        # Timeout réduit à 3 secondes pour éviter les lags
        IP_PUBLIC=$(timeout 3 curl -s --max-time 3 ipinfo.io/ip 2>/dev/null)
        [ -z "$IP_PUBLIC" ] && IP_PUBLIC="N/A"
    else
        IP_PUBLIC="N/A"
    fi
    
    # Informations de sessions détaillées depuis who
    WHO_OUTPUT=$(who 2>/dev/null)
    TOTAL_SESSIONS=$(echo "$WHO_OUTPUT" | grep -v '^$' | wc -l 2>/dev/null)
    [ -z "$TOTAL_SESSIONS" ] && TOTAL_SESSIONS="0"
    
    # Sessions SSH avec détails
    SSH_SESSIONS=$(echo "$WHO_OUTPUT" | grep -c "pts/" 2>/dev/null)
    [ -z "$SSH_SESSIONS" ] && SSH_SESSIONS="0"
    
    # Sessions console avec détails
    CONSOLE_SESSIONS=$(echo "$WHO_OUTPUT" | grep -c "tty" 2>/dev/null)
    [ -z "$CONSOLE_SESSIONS" ] && CONSOLE_SESSIONS="0"
    
    # Détail des sessions actives (limité à 5 pour éviter un message trop long)
    SESSIONS_DETAIL=""
    if [ "$TOTAL_SESSIONS" -gt 0 ] && [ "$TOTAL_SESSIONS" -le 5 ]; then
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Extraire les informations de chaque ligne
                user=$(echo "$line" | awk '{print $1}')
                terminal=$(echo "$line" | awk '{print $2}')
                time=$(echo "$line" | awk '{print $3, $4}')
                ip=$(echo "$line" | grep -o '([^)]*)' | tr -d '()')
                
                if [[ "$terminal" == pts/* ]]; then
                    type_conn="SSH"
                    if [ -n "$ip" ]; then
                        SESSIONS_DETAIL="${SESSIONS_DETAIL}• $type_conn ($terminal) depuis $ip à $time %0A"
                    else
                        SESSIONS_DETAIL="${SESSIONS_DETAIL}• $type_conn ($terminal) à $time %0A"
                    fi
                elif [[ "$terminal" == tty* ]]; then
                    type_conn="Console"
                    SESSIONS_DETAIL="${SESSIONS_DETAIL}• $type_conn ($terminal) à $time %0A"
                else
                    SESSIONS_DETAIL="${SESSIONS_DETAIL}• Autre ($terminal) à $time %0A"
                fi
            fi
        done <<< "$WHO_OUTPUT"
    elif [ "$TOTAL_SESSIONS" -gt 5 ]; then
        SESSIONS_DETAIL="• Trop de sessions pour affichage détaillé ($TOTAL_SESSIONS) %0A"
    fi
    
    TERMINAL_INFO=$(tty 2>/dev/null)
    [ -z "$TERMINAL_INFO" ] && TERMINAL_INFO="N/A"
    

}

# Système de verrou global pour éviter les notifications multiples
# Créer un identifiant basé sur la session réelle, pas sur le processus
if [ -n "$SSH_CONNECTION" ]; then
    # Pour SSH, utiliser l'IP source et le terminal
    IP_SRC=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    TERMINAL=$(tty 2>/dev/null | sed 's|/dev/||' | tr '/' '_')
    SESSION_ID="ssh_${USER}_${IP_SRC}_${TERMINAL}"
elif [ -n "$SSH_CLIENT" ]; then
    # Pour SSH legacy
    IP_SRC=$(echo "$SSH_CLIENT" | awk '{print $1}')
    TERMINAL=$(tty 2>/dev/null | sed 's|/dev/||' | tr '/' '_')
    SESSION_ID="ssh_${USER}_${IP_SRC}_${TERMINAL}"
else
    # Pour console locale ou autres
    TERMINAL=$(tty 2>/dev/null | sed 's|/dev/||' | tr '/' '_')
    SESSION_ID="local_${USER}_${TERMINAL}_$(date +%Y%m%d_%H%M)"
fi

LOCK_FILE="/tmp/telegram_notif_${SESSION_ID}"

# Vérifier si une notification a déjà été envoyée pour cette session
if [ -f "$LOCK_FILE" ]; then
    # Vérifier l'âge du fichier de verrou (max 2 minutes)
    if [ $(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0))) -lt 120 ]; then
        log_debug "Notification déjà envoyée pour cette session ($SESSION_ID)"
        exit 0
    fi
fi

# Créer le fichier de verrou
touch "$LOCK_FILE" 2>/dev/null
log_debug "Verrou créé pour session: $SESSION_ID"

# Nettoyer les anciens fichiers de verrou (plus de 30 minutes)
find /tmp -name "telegram_notif_*" -type f -mmin +30 -delete 2>/dev/null

# Collecter les informations
collect_info

# Construction du message avec séparations
TEXT="🔔 *Connexion $CONNECTION_TYPE* %0A\
📅 $DATE %0A\
─────────────────────────── %0A\
Connexion sur la machine : %0A\
👤 Utilisateur: $USER_INFO %0A\
💻 Hôte: $HOST_INFO %0A\
🏠 $IP_LOCAL %0A\
─────────────────────────── %0A\
Connexion depuis : %0A\
📡 IP Client: $IP_SOURCE %0A\
🌍 IP Publique: $IP_PUBLIC %0A\
👥 Sessions actives sur la machine: %0A\
$SESSIONS_DETAIL
─────────────────────────── %0A\
📺 Terminal: $TERMINAL_INFO"

# Envoi du message avec gestion d'erreur robuste
if telegram_text_send "$TEXT"; then
    log_info "Notification envoyée avec succès"
else
    log_error "Échec de l'envoi de la notification"
    # Ne pas faire échouer le processus PAM avec exit 1
    # Sortir silencieusement pour éviter les erreurs PAM
fi

# Toujours sortir avec succès pour ne pas perturber PAM
exit 0