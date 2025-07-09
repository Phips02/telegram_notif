#!/bin/bash

###############################################################################
# Telegram Privilege Monitor - Surveillance des élévations de privilèges
# Version 1.0 - Surveillance journalctl pour su/sudo
###############################################################################

# Configuration
SCRIPT_NAME="telegram_privilege_monitor"
PID_FILE="/var/run/${SCRIPT_NAME}.pid"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
LAST_CHECK_FILE="/var/lib/${SCRIPT_NAME}/last_check"
SEEN_EVENTS_FILE="/var/lib/${SCRIPT_NAME}/seen_events"
CHECK_INTERVAL=2
DATE_FORMAT="%Y-%m-%d %H:%M:%S"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"

# Configuration Telegram
CREDENTIALS_FILE="/etc/telegram/credentials.cfg"
CONFIG_FILE="/etc/telegram/telegram_notif.cfg"

# Fonction de logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+$DATE_FORMAT")
    echo "[$timestamp] [$level] [$SCRIPT_NAME] $message" | tee -a "$LOG_FILE"
}

log_info() { log_message "INFO" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }

# Charger la configuration
load_config() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        source "$CREDENTIALS_FILE"
    else
        log_error "Fichier credentials non trouvé: $CREDENTIALS_FILE"
        exit 1
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    # Vérifier les variables essentielles
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_error "BOT_TOKEN ou CHAT_ID non défini dans $CREDENTIALS_FILE"
        exit 1
    fi
}

# Fonction d'envoi Telegram
send_telegram_message() {
    local message="$1"
    local temp_file=$(mktemp)
    
    # Écrire le message dans un fichier temporaire
    printf '%s' "$message" > "$temp_file"
    
    # Tentative d'envoi avec markdown
    local response=$(curl -s -X POST \
        --connect-timeout "$CURL_TIMEOUT" \
        --max-time "$CURL_TIMEOUT" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "text@$temp_file" \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" 2>/dev/null)
    
    # Vérifier le succès
    if echo "$response" | grep -q '"ok":true'; then
        log_debug "Message Telegram envoyé avec succès"
        rm -f "$temp_file"
        return 0
    fi
    
    # Fallback sans markdown
    local response=$(curl -s -X POST \
        --connect-timeout "$CURL_TIMEOUT" \
        --max-time "$CURL_TIMEOUT" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "text@$temp_file" \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" 2>/dev/null)
    
    rm -f "$temp_file"
    
    if echo "$response" | grep -q '"ok":true'; then
        log_debug "Message Telegram envoyé (sans markdown)"
        return 0
    else
        log_error "Échec envoi Telegram: $response"
        return 1
    fi
}

# Créer les répertoires nécessaires
create_directories() {
    local lib_dir="/var/lib/${SCRIPT_NAME}"
    if [ ! -d "$lib_dir" ]; then
        mkdir -p "$lib_dir"
        chmod 755 "$lib_dir"
    fi
}

# Fonction pour créer le fichier PID
create_pid_file() {
    echo $$ > "$PID_FILE"
    if [ $? -ne 0 ]; then
        log_error "Impossible de créer le fichier PID: $PID_FILE"
        exit 1
    fi
}

# Fonction pour nettoyer à la sortie
cleanup() {
    log_info "Arrêt du daemon de surveillance des privilèges"
    rm -f "$PID_FILE"
    exit 0
}

# Parser une ligne de log su/sudo
parse_privilege_event() {
    local log_line="$1"
    local event_type=""
    local source_user=""
    local target_user=""
    local terminal=""
    local timestamp=""
    local success=""
    
    # Extraire le timestamp du journal
    timestamp=$(echo "$log_line" | awk '{print $1, $2, $3}')
    
    # Détecter le type d'événement
    if echo "$log_line" | grep -q "su\["; then
        event_type="su"
        # Format: "su[PID]: (to root) user on pts/1"
        if echo "$log_line" | grep -q "(to "; then
            target_user=$(echo "$log_line" | sed -n 's/.*su\[[0-9]*\]: (to \([^)]*\)).*/\1/p')
            source_user=$(echo "$log_line" | sed -n 's/.*) \([^ ]*\) on.*/\1/p')
            terminal=$(echo "$log_line" | sed -n 's/.* on \([^ ]*\).*/\1/p')
            success="true"
        fi
    elif echo "$log_line" | grep -q "sudo\["; then
        event_type="sudo"
        # Format: "sudo[PID]: user : TTY=pts/1 ; PWD=/home/user ; USER=root ; COMMAND=/bin/bash"
        if echo "$log_line" | grep -q "TTY="; then
            source_user=$(echo "$log_line" | sed -n 's/.*sudo\[[0-9]*\]: *\([^ ]*\) :.*/\1/p')
            target_user=$(echo "$log_line" | sed -n 's/.*USER=\([^ ;]*\).*/\1/p')
            terminal=$(echo "$log_line" | sed -n 's/.*TTY=\([^ ;]*\).*/\1/p')
            success="true"
        fi
    elif echo "$log_line" | grep -q "pam_unix.*session opened"; then
        # Session PAM ouverte
        if echo "$log_line" | grep -q "su-l:session"; then
            event_type="su_session_open"
            target_user=$(echo "$log_line" | sed -n 's/.*session opened for user \([^(]*\).*/\1/p')
            source_user=$(echo "$log_line" | sed -n 's/.*by \([^(]*\).*/\1/p')
            success="true"
        fi
    elif echo "$log_line" | grep -q "pam_unix.*session closed"; then
        # Session PAM fermée - on ignore pour éviter le spam
        return 1
    fi
    
    # Vérifier si on a les informations essentielles
    if [ -z "$event_type" ] || [ -z "$source_user" ] || [ -z "$target_user" ]; then
        return 1
    fi
    
    # Créer un ID unique pour cet événement
    local event_id="${timestamp}_${event_type}_${source_user}_${target_user}_${terminal}"
    local event_hash=$(echo "$event_id" | sha256sum | cut -d' ' -f1 2>/dev/null || echo "$event_id" | md5sum | cut -d' ' -f1 2>/dev/null || echo "${event_id}_$$")
    
    # Vérifier si déjà traité
    if [ -f "$SEEN_EVENTS_FILE" ] && grep -q "$event_hash" "$SEEN_EVENTS_FILE"; then
        return 1
    fi
    
    # Ajouter à la liste des événements traités
    echo "$event_hash" >> "$SEEN_EVENTS_FILE"
    
    # Nettoyer le fichier (garder seulement les 500 derniers)
    if [ -f "$SEEN_EVENTS_FILE" ]; then
        tail -n 500 "$SEEN_EVENTS_FILE" > "$SEEN_EVENTS_FILE.tmp"
        mv "$SEEN_EVENTS_FILE.tmp" "$SEEN_EVENTS_FILE"
    fi
    
    # Créer la notification
    create_privilege_notification "$event_type" "$source_user" "$target_user" "$terminal" "$timestamp"
    
    return 0
}

# Créer une notification d'élévation de privilège
create_privilege_notification() {
    local event_type="$1"
    local source_user="$2"
    local target_user="$3"
    local terminal="$4"
    local timestamp="$5"
    
    local icon=""
    local action=""
    
    case "$event_type" in
        "su"|"su_session_open")
            icon="🔐"
            action="Élévation su"
            ;;
        "sudo")
            icon="⚡"
            action="Commande sudo"
            ;;
        *)
            icon="🔑"
            action="Élévation privilège"
            ;;
    esac
    
    # Obtenir des informations supplémentaires
    local hostname=$(hostname)
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Obtenir l'IP source si possible
    local source_ip=""
    if [ -n "$terminal" ] && [[ "$terminal" =~ ^pts/ ]]; then
        # Essayer de trouver l'IP source via who
        source_ip=$(who | grep "$source_user" | grep "$terminal" | awk '{print $5}' | tr -d '()' | head -n1)
        if [ -z "$source_ip" ] || [ "$source_ip" = "" ]; then
            source_ip="Local"
        fi
    else
        source_ip="Console"
    fi
    
    # Construire le message
    local message="$icon *$action détectée*

👤 **Utilisateur source:** \`$source_user\`
🎯 **Utilisateur cible:** \`$target_user\`
💻 **Terminal:** \`$terminal\`
🌐 **Source IP:** \`$source_ip\`
🖥️ **Serveur:** \`$hostname\`
⏰ **Heure:** \`$current_time\`

───────────────────────────
📊 **Détails système:**
• Événement: $event_type
• Timestamp journal: $timestamp"

    # Envoyer la notification
    send_telegram_message "$message"
    
    log_info "Notification envoyée: $action $source_user -> $target_user sur $terminal"
}

# Fonction principale de surveillance
monitor_privileges() {
    log_info "Démarrage surveillance des élévations de privilèges"
    
    # Obtenir le timestamp de la dernière vérification
    local last_check_time=""
    if [ -f "$LAST_CHECK_FILE" ]; then
        last_check_time=$(cat "$LAST_CHECK_FILE")
    else
        # Première exécution - commencer depuis maintenant
        last_check_time=$(date "+%Y-%m-%d %H:%M:%S")
        echo "$last_check_time" > "$LAST_CHECK_FILE"
    fi
    
    while true; do
        local current_time=$(date "+%Y-%m-%d %H:%M:%S")
        local events_found=0
        
        # Surveiller les événements depuis la dernière vérification
        journalctl --since "$last_check_time" --no-pager -q 2>/dev/null | \
        grep -E "(su\[[0-9]+\]:|sudo\[[0-9]+\]:|pam_unix\(su.*session)" | \
        while IFS= read -r line; do
            if parse_privilege_event "$line"; then
                events_found=$((events_found + 1))
            fi
        done
        
        # Mettre à jour le timestamp de dernière vérification
        echo "$current_time" > "$LAST_CHECK_FILE"
        
        # Attendre avant la prochaine vérification
        sleep "$CHECK_INTERVAL"
    done
}

# Fonction de test
test_privilege_monitor() {
    echo "=== Test du moniteur de privilèges ==="
    
    # Test 1: Simulation événement su
    echo "Test 1: Simulation élévation su"
    local test_line="jui 09 11:42:01 notif su[106412]: (to root) phips on pts/1"
    if parse_privilege_event "$test_line"; then
        echo "✅ Test su réussi"
    else
        echo "❌ Test su échoué"
    fi
    
    # Test 2: Simulation événement sudo
    echo "Test 2: Simulation commande sudo"
    local test_line="jui 09 12:00:01 notif sudo[123456]: phips : TTY=pts/1 ; PWD=/home/phips ; USER=root ; COMMAND=/bin/bash"
    if parse_privilege_event "$test_line"; then
        echo "✅ Test sudo réussi"
    else
        echo "❌ Test sudo échoué"
    fi
    
    echo "=== Fin des tests ==="
}

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTION]

Options:
  start     Démarrer le daemon de surveillance
  stop      Arrêter le daemon
  restart   Redémarrer le daemon
  status    Afficher le statut du daemon
  test      Tester la détection d'événements
  debug     Afficher les logs en temps réel
  help      Afficher cette aide

Exemples:
  $0 start          # Démarrer la surveillance
  $0 test           # Tester la détection
  $0 debug          # Voir les logs en temps réel

EOF
}

# Fonction principale
main() {
    case "${1:-start}" in
        "start")
            # Vérifier si déjà en cours
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "Le daemon est déjà en cours d'exécution (PID: $pid)"
                    exit 1
                else
                    rm -f "$PID_FILE"
                fi
            fi
            
            load_config
            create_directories
            create_pid_file
            
            # Configurer les signaux
            trap cleanup SIGTERM SIGINT
            
            # Démarrer la surveillance
            monitor_privileges
            ;;
        "stop")
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    kill "$pid"
                    rm -f "$PID_FILE"
                    echo "Daemon arrêté"
                else
                    echo "Daemon non actif"
                    rm -f "$PID_FILE"
                fi
            else
                echo "Daemon non actif"
            fi
            ;;
        "restart")
            $0 stop
            sleep 2
            $0 start
            ;;
        "status")
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "Daemon actif (PID: $pid)"
                else
                    echo "Daemon inactif (fichier PID obsolète)"
                fi
            else
                echo "Daemon inactif"
            fi
            ;;
        "test")
            load_config
            test_privilege_monitor
            ;;
        "debug")
            echo "Surveillance des logs en temps réel (Ctrl+C pour arrêter):"
            tail -f "$LOG_FILE" 2>/dev/null || echo "Aucun log disponible"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
}

# Point d'entrée
main "$@"
