#!/bin/bash
# Telegram Notification System V6

# telegram_privilege_monitor.sh V1.0
# Daemon de surveillance des élévations de privilèges (su/sudo) via journalctl


# Configuration par défaut
SCRIPT_NAME="telegram_privilege_monitor"
VERSION="1.0"
CONFIG_DIR="/etc/telegram"
CREDENTIALS_FILE="$CONFIG_DIR/credentials.cfg"
CONFIG_FILE="$CONFIG_DIR/telegram_notif.cfg"
LOG_FILE="/var/log/telegram_privilege_monitor.log"
PID_FILE="/var/run/telegram_privilege_monitor.pid"
CACHE_DIR="/var/lib/telegram_privilege_monitor"
CACHE_FILE="$CACHE_DIR/seen_privileges"
CURL_TIMEOUT=5

# Variables globales
BOT_TOKEN=""
CHAT_ID=""
CHECK_INTERVAL=2
MAX_CACHE_SIZE=1000

# Fonction de logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] [$SCRIPT_NAME] $message" | tee -a "$LOG_FILE"
}

log_debug() {
    log_message "DEBUG" "$1"
}

log_info() {
    log_message "INFO" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

log_success() {
    log_message "SUCCESS" "$1"
}

# Fonction de chargement de la configuration
load_config() {
    # Charger les credentials
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        log_error "Fichier credentials non trouvé: $CREDENTIALS_FILE"
        return 1
    fi
    
    source "$CREDENTIALS_FILE"
    
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_error "BOT_TOKEN ou CHAT_ID non défini dans $CREDENTIALS_FILE"
        return 1
    fi
    
    # Charger la configuration système si elle existe
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    log_info "Configuration chargée avec succès"
    return 0
}

# Fonction de vérification de sécurité
check_config_security() {
    # Vérifier les permissions du fichier credentials
    local perms=$(stat -c "%a" "$CREDENTIALS_FILE" 2>/dev/null)
    if [ "$perms" != "600" ]; then
        log_error "Permissions incorrectes sur $CREDENTIALS_FILE (actuelles: $perms, requises: 600)"
        log_error "Corrigez avec: sudo chmod 600 $CREDENTIALS_FILE"
        return 1
    fi
    
    # Vérifier le propriétaire
    local owner=$(stat -c "%U:%G" "$CREDENTIALS_FILE" 2>/dev/null)
    if [ "$owner" != "root:root" ]; then
        log_error "Propriétaire incorrect sur $CREDENTIALS_FILE (actuel: $owner, requis: root:root)"
        log_error "Corrigez avec: sudo chown root:root $CREDENTIALS_FILE"
        return 1
    fi
    
    log_debug "Sécurité des fichiers de configuration validée"
    return 0
}

# Fonction d'envoi de message Telegram
send_telegram_message() {
    local message="$1"
    local temp_file=$(mktemp)
    
    # Écrire le message dans un fichier temporaire
    printf '%s' "$message" > "$temp_file"
    
    # Tentative d'envoi avec markdown
    local response=$(curl -s -m "$CURL_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
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
    local response=$(curl -s -m "$CURL_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "text@$temp_file" \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" 2>/dev/null)
    
    if echo "$response" | grep -q '"ok":true'; then
        log_debug "Message Telegram envoyé avec succès (fallback)"
        rm -f "$temp_file"
        return 0
    fi
    
    log_error "Échec envoi Telegram: $response"
    rm -f "$temp_file"
    return 1
}

# Fonction de création du hash pour éviter les doublons
create_privilege_hash() {
    local privilege_info="$1"
    local hash=""
    
    # Essayer différentes méthodes de hash
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(echo "$privilege_info" | sha256sum | cut -d' ' -f1)
    elif command -v md5sum >/dev/null 2>&1; then
        hash=$(echo "$privilege_info" | md5sum | cut -d' ' -f1)
    else
        hash=$(echo "$privilege_info" | od -An -tx1 | tr -d ' \n' | head -c 32)
        if [ -z "$hash" ]; then
            hash="$(date +%s)_$$_$(echo "$privilege_info" | wc -c)"
        fi
    fi
    
    echo "$hash"
}

# Fonction de nettoyage du cache
cleanup_cache() {
    if [ -f "$CACHE_FILE" ]; then
        local lines=$(wc -l < "$CACHE_FILE")
        if [ "$lines" -gt "$MAX_CACHE_SIZE" ]; then
            tail -n "$MAX_CACHE_SIZE" "$CACHE_FILE" > "$CACHE_FILE.tmp"
            mv "$CACHE_FILE.tmp" "$CACHE_FILE"
            log_debug "Cache nettoyé: $lines -> $MAX_CACHE_SIZE lignes"
        fi
    fi
}

# Fonction de surveillance des privilèges
monitor_privileges() {
    local new_privileges=0
    
    # Créer le répertoire de cache si nécessaire
    mkdir -p "$CACHE_DIR"
    
    # Surveiller les événements su et sudo des dernières 45 secondes
    local since_time=$(date -d "45 seconds ago" "+%Y-%m-%d %H:%M:%S")
    
    # Rechercher les événements su et sudo
    LC_ALL=C journalctl --since="$since_time" --no-pager -q 2>/dev/null | \
    grep -E "(sudo|su)\[" | \
    while IFS= read -r line; do
        # Parser les événements su
        if echo "$line" | grep -q "su\["; then
            # Format: Jul  8 13:30:15 hostname su[1234]: pam_unix(su-l:session): session opened for user root(uid=0) by user(uid=1000)
            if echo "$line" | grep -q "session opened for user"; then
                local user_info=$(echo "$line" | sed -n 's/.*session opened for user \([^(]*\)(uid=\([0-9]*\)) by \([^(]*\)(uid=\([0-9]*\)).*/\1:\2:\3:\4/p')
                if [ -n "$user_info" ]; then
                    local target_user=$(echo "$user_info" | cut -d: -f1)
                    local target_uid=$(echo "$user_info" | cut -d: -f2)
                    local source_user=$(echo "$user_info" | cut -d: -f3)
                    local source_uid=$(echo "$user_info" | cut -d: -f4)
                    
                    # Créer un ID basé sur la ligne complète (sans timestamp dynamique)
                    local privilege_id="su:$source_user:$target_user:$line"
                    local privilege_hash=$(create_privilege_hash "$privilege_id")
                    
                    # Vérifier si déjà traité
                    if ! grep -q "$privilege_hash" "$CACHE_FILE" 2>/dev/null; then
                        echo "$privilege_hash" >> "$CACHE_FILE"
                        
                        # Créer le message de notification
                        local message="🔐 *Élévation de privilège détectée*

👤 *Utilisateur source* : \`$source_user\` (UID: $source_uid)
🎯 *Utilisateur cible* : \`$target_user\` (UID: $target_uid)
📅 *Date/Heure* : \`$(date '+%Y-%m-%d %H:%M:%S')\`
🖥️ *Serveur* : \`$(hostname)\`

───────────────────────────"
                        
                        # Envoyer la notification
                        if send_telegram_message "$message"; then
                            log_info "Notification su envoyée: $source_user -> $target_user"
                            new_privileges=$((new_privileges + 1))
                        else
                            log_error "Échec notification su: $source_user -> $target_user"
                        fi
                    fi
                fi
            fi
        fi
        
        # Parser les événements sudo
        if echo "$line" | grep -q "sudo\["; then
            # Format: Jul  8 13:30:15 hostname sudo[1234]: user : TTY=pts/1 ; PWD=/home/user ; USER=root ; COMMAND=/bin/ls
            if echo "$line" | grep -q "TTY=.*USER=.*COMMAND="; then
                local sudo_info=$(echo "$line" | sed -n 's/.*sudo\[[0-9]*\]: \([^:]*\) : TTY=\([^ ]*\) .* USER=\([^ ]*\) ; COMMAND=\(.*\)/\1:\2:\3:\4/p')
                if [ -n "$sudo_info" ]; then
                    local source_user=$(echo "$sudo_info" | cut -d: -f1 | tr -d ' ')
                    local tty=$(echo "$sudo_info" | cut -d: -f2)
                    local target_user=$(echo "$sudo_info" | cut -d: -f3)
                    local command=$(echo "$sudo_info" | cut -d: -f4-)
                    
                    # Créer un ID basé sur la ligne complète (sans timestamp dynamique)
                    local privilege_id="sudo:$source_user:$target_user:$command:$line"
                    local privilege_hash=$(create_privilege_hash "$privilege_id")
                    
                    # Vérifier si déjà traité
                    if ! grep -q "$privilege_hash" "$CACHE_FILE" 2>/dev/null; then
                        echo "$privilege_hash" >> "$CACHE_FILE"
                        
                        # Créer le message de notification
                        local message="⚡ *Commande sudo détectée*

👤 *Utilisateur source* : \`$source_user\`
🎯 *Utilisateur cible* : \`$target_user\`
💻 *Terminal* : \`$tty\`
⚙️ *Commande* : \`$command\`
📅 *Date/Heure* : \`$(date '+%Y-%m-%d %H:%M:%S')\`
🖥️ *Serveur* : \`$(hostname)\`

───────────────────────────"
                        
                        # Envoyer la notification
                        if send_telegram_message "$message"; then
                            log_info "Notification sudo envoyée: $source_user -> $target_user ($command)"
                            new_privileges=$((new_privileges + 1))
                        else
                            log_error "Échec notification sudo: $source_user -> $target_user"
                        fi
                    fi
                fi
            fi
        fi
    done
    
    # Nettoyage périodique du cache
    cleanup_cache
    
    if [ "$new_privileges" -gt 0 ]; then
        log_debug "Cycle terminé - $new_privileges nouvelles élévations détectées"
    fi
}

# Fonction de création du fichier PID
create_pid_file() {
    echo $$ > "$PID_FILE"
    log_info "Fichier PID créé: $PID_FILE (PID: $$)"
}

# Fonction de suppression du fichier PID
remove_pid_file() {
    rm -f "$PID_FILE"
    log_info "Fichier PID supprimé"
}

# Fonction de test
test_function() {
    echo "Test de notification Telegram..."
    
    if ! check_config_security; then
        echo "❌ Échec - Problème de sécurité de configuration"
        return 1
    fi
    
    if ! load_config; then
        echo "❌ Échec - Problème de configuration"
        return 1
    fi
    
    local test_message="🧪 *Test du moniteur de privilèges*

📅 *Date/Heure* : \`$(date '+%Y-%m-%d %H:%M:%S')\`
🖥️ *Serveur* : \`$(hostname)\`
🔧 *Version* : \`$VERSION\`

✅ Le système de surveillance des privilèges fonctionne correctement !"
    
    if send_telegram_message "$test_message"; then
        echo "✅ Test réussi - Notification envoyée"
        return 0
    else
        echo "❌ Test échoué - Problème d'envoi"
        return 1
    fi
}

# Fonction principale
main() {
    case "${1:-start}" in
        start)
            log_info "Démarrage du daemon Telegram Privilege Monitor v$VERSION"
            
            # Vérifications préalables
            if ! check_config_security; then
                exit 1
            fi
            
            if ! load_config; then
                exit 1
            fi
            
            # Créer le fichier PID
            create_pid_file
            
            # Trap pour nettoyage à l'arrêt
            trap 'remove_pid_file; exit 0' TERM INT
            
            log_info "Démarrage surveillance privilèges (intervalle: ${CHECK_INTERVAL}s)"
            
            # Boucle principale
            while true; do
                monitor_privileges
                sleep "$CHECK_INTERVAL"
            done
            ;;
            
        stop)
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    kill "$pid"
                    log_info "Daemon arrêté (PID: $pid)"
                else
                    log_info "Daemon non actif"
                    rm -f "$PID_FILE"
                fi
            else
                log_info "Fichier PID non trouvé - daemon probablement arrêté"
            fi
            ;;
            
        restart)
            $0 stop
            sleep 2
            $0 start
            ;;
            
        status)
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "Daemon actif (PID: $pid)"
                    return 0
                else
                    echo "Daemon inactif (fichier PID obsolète)"
                    return 1
                fi
            else
                echo "Daemon arrêté"
                return 1
            fi
            ;;
            
        test)
            test_function
            ;;
            
        *)
            echo "Usage: $0 {start|stop|restart|status|test}"
            exit 1
            ;;
    esac
}

# Exécution
main "$@"
