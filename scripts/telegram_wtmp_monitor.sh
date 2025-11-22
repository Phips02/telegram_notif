#!/bin/bash

###############################################################################
# Telegram WTMP Monitor - Daemon de surveillance des connexions
# Version 6 - Approche simplifiée basée sur wtmp
###############################################################################

# Version du système
TELEGRAM_VERSION="5.1"

# Configuration par défaut
SCRIPT_NAME="telegram_wtmp_monitor"
PID_FILE="/var/run/${SCRIPT_NAME}.pid"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
LAST_CHECK_FILE="/var/lib/${SCRIPT_NAME}/last_check"
CHECK_INTERVAL=5
MAX_ENTRIES=50

# Configuration de performance
SKIP_PUBLIC_IP="${SKIP_PUBLIC_IP:-true}"  # Désactivé par défaut pour éviter les lags
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"
DATE_FORMAT="${DATE_FORMAT:-%Y-%m-%d %H:%M:%S}"

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

# Fonction pour vérifier la sécurité des fichiers de configuration
check_config_security() {
    local credentials_file="/etc/telegram/credentials.cfg"
    
    # Vérifier l'existence et les permissions du fichier credentials
    if [ ! -f "$credentials_file" ]; then
        log_error "Fichier credentials non trouvé: $credentials_file"
        return 1
    fi
    
    # Vérifier les permissions (doit être 600)
    local perms=$(stat -c "%a" "$credentials_file" 2>/dev/null)
    if [ "$perms" != "600" ]; then
        log_error "SÉCURITÉ: Permissions incorrectes sur $credentials_file (actuel: $perms, requis: 600)"
        log_error "Corrigez avec: sudo chmod 600 $credentials_file"
        return 1
    fi
    
    # Vérifier le propriétaire (doit être root:root)
    local owner=$(stat -c "%U:%G" "$credentials_file" 2>/dev/null)
    if [ "$owner" != "root:root" ]; then
        log_error "SÉCURITÉ: Propriétaire incorrect sur $credentials_file (actuel: $owner, requis: root:root)"
        log_error "Corrigez avec: sudo chown root:root $credentials_file"
        return 1
    fi
    
    log_debug "Sécurité des fichiers de configuration validée"
    return 0
}

# Fonction pour charger la configuration
load_config() {
    # Vérifier la sécurité des fichiers de configuration
    if ! check_config_security; then
        log_error "Échec de la vérification de sécurité - arrêt du daemon"
        exit 1
    fi
    
    # Charger les identifiants Telegram
    if [ ! -r "/etc/telegram/credentials.cfg" ]; then
        log_error "Identifiants Telegram non trouvés: /etc/telegram/credentials.cfg"
        exit 1
    fi
    source "/etc/telegram/credentials.cfg"

    # Charger la configuration spécifique
    if [ -r "/etc/telegram/telegram_notif.cfg" ]; then
        source "/etc/telegram/telegram_notif.cfg"
    fi

    # Vérifier les variables essentielles
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_error "BOT_TOKEN ou CHAT_ID non défini"
        exit 1
    fi

    log_info "Configuration chargée avec succès"
}

# Fonction d'envoi Telegram simplifiée
telegram_send() {
    local message="$1"
    local api_url="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
    
    # Créer fichier temporaire avec encodage UTF-8
    local temp_file="/tmp/telegram_msg_$$.txt"
    printf '%s' "$message" > "$temp_file"
    
    # Tentative d'envoi avec markdown
    local response=$(curl -s --max-time "$CURL_TIMEOUT" \
        -X POST \
        -d "chat_id=${CHAT_ID}" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text@${temp_file}" \
        "$api_url" 2>/dev/null)
    
    local success=false
    if echo "$response" | grep -q '"ok":true'; then
        success=true
    else
        # Tentative sans markdown
        response=$(curl -s --max-time "$CURL_TIMEOUT" \
            -X POST \
            -d "chat_id=${CHAT_ID}" \
            --data-urlencode "text@${temp_file}" \
            "$api_url" 2>/dev/null)
        
        if echo "$response" | grep -q '"ok":true'; then
            success=true
        fi
    fi
    
    # Nettoyer le fichier temporaire
    rm -f "$temp_file"
    
    if [ "$success" = true ]; then
        log_debug "Message Telegram envoyé avec succès"
        return 0
    else
        log_error "Échec envoi Telegram: $response"
        return 1
    fi
}

# Fonction pour obtenir l'IP publique (optionnelle)
get_public_ip() {
    if [ "$SKIP_PUBLIC_IP" = "true" ]; then
        echo "Désactivé"
        return
    fi
    
    local public_ip=$(timeout 5 curl -s --max-time 3 \
        -H "User-Agent: curl/7.68.0" \
        "https://ipv4.icanhazip.com" 2>/dev/null | head -1)
    
    if [ -n "$public_ip" ] && [[ "$public_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$public_ip"
    else
        echo "N/A"
    fi
}

# Fonction pour parser une ligne de 'last' (version améliorée)
# Compatible Debian 12 (util-linux last) et Debian 13 (wtmpdb)
parse_last_line() {
    local line="$1"

    # Forcer locale C pour un format standardisé
    export LC_ALL=C

    # Ignorer les lignes vides, headers et reboots
    if [[ -z "$line" || "$line" =~ ^wtmp || "$line" =~ ^$ || "$line" =~ ^reboot || "$line" =~ ^shutdown ]]; then
        return 1
    fi

    # Liste des jours de la semaine pour détecter l'absence de host
    local days_pattern="^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$"

    # Parser avec regex plus robuste
    if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
        local user="${BASH_REMATCH[1]}"
        local terminal="${BASH_REMATCH[2]}"
        local host="${BASH_REMATCH[3]}"
        local rest="${BASH_REMATCH[4]}"

        # Filtrer les entrées SSH redondantes pour éviter les notifications en double
        # Les connexions SSH génèrent à la fois une entrée "ssh" et "pts/X"
        # On ne garde que les entrées pts/* qui sont plus informatives
        if [[ "$terminal" == "ssh" ]]; then
            return 1
        fi

        # Debian 13 (wtmpdb) : Détecter si le "host" est en fait le début de la date
        # Cela arrive pour les connexions console (tty) sans host distant
        if [[ "$host" =~ $days_pattern ]]; then
            # Pas de host - c'est une connexion console locale
            rest="$host $rest"
            host=""
        fi

        # Extraire la partie date et déterminer le type de connexion
        local datetime
        local is_active=false

        # Debian 13 (wtmpdb) : Format "DATE - still logged in" avec tiret séparateur
        if [[ "$rest" =~ ^(.+)[[:space:]]+-[[:space:]]+still[[:space:]]+logged[[:space:]]+in ]]; then
            # Connexion active avec format wtmpdb
            datetime="${BASH_REMATCH[1]}"
            is_active=true
        elif [[ "$rest" =~ ^(.+)[[:space:]]+still[[:space:]]+logged[[:space:]]+in ]]; then
            # Connexion active format classique (Debian 12)
            datetime="${BASH_REMATCH[1]}"
            # Nettoyer le tiret résiduel si présent (compatibilité)
            datetime="${datetime% -}"
            datetime="${datetime% }"
            is_active=true
        elif [[ "$rest" =~ ^(.+)[[:space:]]+-[[:space:]]+.* ]]; then
            # Connexion terminée : ignorer complètement les déconnexions
            return 1
        else
            # Fallback : prendre tout sauf les parenthèses finales
            datetime=$(echo "$rest" | sed -E 's/[[:space:]]+\([^)]+\)[[:space:]]*$//' | xargs)

            # Vérifier si c'est une déconnexion dans le fallback (version améliorée)
            if [[ "$rest" =~ [[:space:]]-[[:space:]] ]] || [[ "$rest" =~ -[[:space:]] ]]; then
                return 1
            fi

            # Si ce n'est pas une déconnexion, c'est une connexion active
            is_active=true
        fi

        # Nettoyer le datetime (supprimer espaces et tirets résiduels)
        datetime=$(echo "$datetime" | sed -E 's/[[:space:]]+-?[[:space:]]*$//')

        # Validation des champs
        if [[ -z "$user" || -z "$terminal" || -z "$datetime" ]]; then
            return 1
        fi

        export PARSED_USER="$user"
        export PARSED_TERMINAL="$terminal"
        export PARSED_HOST="$host"
        export PARSED_DATETIME="$datetime"
        export PARSED_IS_ACTIVE="$is_active"

        return 0
    fi

    return 1
}

# Fonction pour valider la configuration
validate_configuration() {
    log_debug "Validation de la configuration..."
    
    # Vérifier les variables Telegram essentielles
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_error "Configuration incomplète: BOT_TOKEN ou CHAT_ID manquant"
        return 1
    fi
    
    # Vérifier la connectivité réseau (optionnel mais recommandé)
    if ! timeout 5 curl -s --max-time 3 "https://api.telegram.org" >/dev/null 2>&1; then
        log_error "Impossible de joindre l'API Telegram - vérifiez votre connexion réseau"
        return 1
    fi
    
    log_debug "Configuration validée avec succès"
    return 0
}

# Fonction pour créer un hash unique pour une connexion
create_connection_hash() {
    local user="$1"
    local terminal="$2"
    local host="$3"
    local datetime="$4"
    
    local connection_string="${user}:${terminal}:${host}:${datetime}"
    
    # Essayer sha256sum en premier (plus fiable)
    if command -v sha256sum >/dev/null 2>&1; then
        echo "$connection_string" | sha256sum | awk '{print $1}'
    # Fallback sur md5sum
    elif command -v md5sum >/dev/null 2>&1; then
        echo "$connection_string" | md5sum | awk '{print $1}'
    # Fallback sur od (toujours disponible)
    elif command -v od >/dev/null 2>&1; then
        echo "$connection_string" | od -An -tx1 | tr -d ' \n'
    # Dernier recours: hash simple basé sur la longueur et timestamp
    else
        echo "${#connection_string}:${datetime}:$$"
    fi
}

# Fonction pour créer le message de notification
create_notification_message() {
    local user="$1"
    local terminal="$2"
    local host="$3"
    local datetime="$4"
    
    local hostname=$(hostname)
    local local_ip=$(hostname -I | awk '{print $1}')
    local public_ip=$(get_public_ip)
    
    # Déterminer le type de connexion
    local connection_type="Connexion"
    if [[ "$terminal" =~ ^pts/ ]]; then
        connection_type="SSH"
    elif [[ "$terminal" =~ ^tty ]]; then
        connection_type="Console"
    fi
    
    # Message formaté
    cat << EOF
🔐 *NOUVELLE CONNEXION DÉTECTÉE*

📅 Date: $datetime
───────────────────────────
👤 Utilisateur: \`$user\`
🖥️ Terminal: \`$terminal\`
🌐 Depuis: ${host:-"Console locale"}
───────────────────────────
💻 Serveur: \`$hostname\`
🏠 IP locale: \`$local_ip\`
🌍 IP publique: \`$public_ip\`
───────────────────────────
📊 Type: $connection_type
EOF
}

# Fonction principale de monitoring WTMP
monitor_wtmp() {
    log_info "Démarrage de la surveillance WTMP"
    
    # Créer le répertoire de stockage de l'état
    local state_dir="/var/lib/${SCRIPT_NAME}"
    mkdir -p "$state_dir"
    
    # Fichier pour tracker les connexions déjà vues
    local seen_connections_file="${state_dir}/seen_connections"
    touch "$seen_connections_file"
    
    # Boucle principale de surveillance
    while true; do
        local since_time=$(date -d "1 minute ago" "+%Y-%m-%d %H:%M")
        local new_connections=0
        
        # Parser les connexions récentes
        while IFS= read -r line; do
            if parse_last_line "$line"; then
                # Vérifier si c'est une connexion active
                if [ "$PARSED_IS_ACTIVE" = true ]; then
                    # Créer un hash unique pour cette connexion
                    local connection_hash=$(create_connection_hash "$PARSED_USER" "$PARSED_TERMINAL" "$PARSED_HOST" "$PARSED_DATETIME")
                    
                    # Vérifier si on a déjà notifié cette connexion
                    if ! grep -q "^${connection_hash}$" "$seen_connections_file" 2>/dev/null; then
                        log_debug "Nouvelle connexion détectée: $PARSED_USER@$PARSED_TERMINAL depuis $PARSED_HOST"
                        
                        # Créer et envoyer la notification
                        local message=$(create_notification_message "$PARSED_USER" "$PARSED_TERMINAL" "$PARSED_HOST" "$PARSED_DATETIME")
                        
                        if telegram_send "$message"; then
                            log_info "Notification envoyée pour $PARSED_USER@$PARSED_TERMINAL"
                            # Marquer comme traité
                            echo "$connection_hash" >> "$seen_connections_file"
                            new_connections=$((new_connections + 1))
                        else
                            log_error "Échec notification pour $PARSED_USER@$PARSED_TERMINAL"
                        fi
                    fi
                fi
            fi
        done < <(LC_ALL=C last -F -w -s "$since_time" 2>/dev/null)
        
        # Nettoyer le fichier des connexions vues (garder seulement les 1000 dernières)
        if [ -f "$seen_connections_file" ]; then
            tail -1000 "$seen_connections_file" > "${seen_connections_file}.tmp" 2>/dev/null
            mv "${seen_connections_file}.tmp" "$seen_connections_file" 2>/dev/null
        fi
        
        log_debug "Cycle terminé - $new_connections nouvelles connexions détectées"
        sleep "$CHECK_INTERVAL"
    done
}

# Fonction pour créer le fichier PID
create_pid_file() {
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_error "Le daemon est déjà en cours d'exécution (PID: $old_pid)"
            exit 1
        else
            log_info "Suppression du fichier PID obsolète"
            rm -f "$PID_FILE"
        fi
    fi
    
    echo $$ > "$PID_FILE"
    log_info "Fichier PID créé: $PID_FILE (PID: $$)"
}

# Fonction de nettoyage
cleanup() {
    log_info "Arrêt du daemon en cours..."
    rm -f "$PID_FILE"
    exit 0
}

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  start       Démarrer le daemon
  stop        Arrêter le daemon
  restart     Redémarrer le daemon
  status      Afficher le statut
  test        Tester l'envoi d'une notification
  debug       Debug du parsing des connexions récentes
  --version   Afficher la version
  --help      Afficher cette aide

Fichiers:
  Configuration: /etc/telegram/credentials.cfg
  Log: $LOG_FILE
  PID: $PID_FILE
EOF
}

# Fonction pour arrêter le daemon
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Arrêt du daemon (PID: $pid)"
            kill "$pid"
            rm -f "$PID_FILE"
            echo "Daemon arrêté"
        else
            log_info "Le daemon n'est pas en cours d'exécution"
            rm -f "$PID_FILE"
        fi
    else
        echo "Le daemon n'est pas en cours d'exécution"
    fi
}

# Fonction pour afficher le statut
show_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Daemon en cours d'exécution (PID: $pid)"
            echo "Log: $LOG_FILE"
            echo "Dernières lignes du log:"
            tail -5 "$LOG_FILE" 2>/dev/null || echo "Aucun log disponible"
        else
            echo "Daemon arrêté (fichier PID obsolète)"
            rm -f "$PID_FILE"
        fi
    else
        echo "Daemon arrêté"
    fi
}

# Fonction de debug pour tester le parsing
debug_parsing() {
    log_info "Debug du parsing des connexions récentes..."
    load_config
    
    local since_time=$(date -d "1 hour ago" "+%Y-%m-%d %H:%M")
    log_info "Recherche des connexions depuis: $since_time"
    
    echo "=== Sortie brute de 'last' ==="
    LC_ALL=C last -F -w -s "$since_time" 2>/dev/null
    
    echo ""
    echo "=== Parsing des lignes ==="
    while IFS= read -r line; do
        echo "Ligne: $line"
        if parse_last_line "$line"; then
            echo "  ✓ Parsé: $PARSED_USER@$PARSED_TERMINAL depuis $PARSED_HOST à $PARSED_DATETIME"
            local connection_id="${PARSED_USER}:${PARSED_TERMINAL}:${PARSED_HOST}:${PARSED_DATETIME}"
            echo "  ID: $connection_id"
        else
            echo "  ✗ Ignoré"
        fi
        echo ""
    done < <(LC_ALL=C last -F -w -s "$since_time" 2>/dev/null)
}

# Fonction de test
test_notification() {
    log_info "Test de notification Telegram..."
    load_config
    
    local test_message="🧪 *Test Telegram WTMP Monitor*

📅 $(date "+$DATE_FORMAT")
───────────────────────────
🔔 Système de notification opérationnel
💻 Serveur: $(hostname)
🏠 IP: $(hostname -I | awk '{print $1}')
📊 Version: $TELEGRAM_VERSION
───────────────────────────
✅ Configuration OK
🚀 Surveillance WTMP active"

    if telegram_send "$test_message"; then
        echo "✅ Test réussi - Notification envoyée"
    else
        echo "❌ Test échoué - Vérifiez la configuration"
        exit 1
    fi
}

# Gestion des signaux
trap cleanup SIGINT SIGTERM

# Vérifications préalables
check_requirements() {
    # Vérifier les permissions root
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # Vérifier l'accès à wtmp
    if [ ! -r /var/log/wtmp ]; then
        echo "❌ Impossible de lire /var/log/wtmp"
        exit 1
    fi
    
    # Vérifier les commandes nécessaires
    for cmd in curl last date; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "❌ Commande manquante: $cmd"
            exit 1
        fi
    done
    
    # Vérifier qu'au moins une méthode de hachage est disponible
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v md5sum >/dev/null 2>&1 && ! command -v od >/dev/null 2>&1; then
        echo "⚠️  Aucune méthode de hachage disponible (sha256sum, md5sum, od)"
        echo "   Le système utilisera un fallback basique (timestamp + PID)"
    fi
    
    # Créer le répertoire de log
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# Point d'entrée principal
main() {
    case "${1:-start}" in
        "start")
            check_requirements
            load_config
            
            # Validation de la configuration
            if ! validate_configuration; then
                log_error "Échec de la validation de la configuration - arrêt du daemon"
                exit 1
            fi
            
            create_pid_file
            log_info "Démarrage du daemon Telegram WTMP Monitor v$TELEGRAM_VERSION"
            monitor_wtmp
            ;;
        "stop")
            stop_daemon
            ;;
        "restart")
            stop_daemon
            sleep 2
            exec "$0" start
            ;;
        "status")
            show_status
            ;;
        "test")
            check_requirements
            test_notification
            ;;
        "debug")
            check_requirements
            debug_parsing
            ;;
        "--version")
            echo "Telegram WTMP Monitor v$TELEGRAM_VERSION"
            ;;
        "--help"|"help")
            show_help
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|test|debug|--version|--help}"
            exit 1
            ;;
    esac
}

# Exécution
main "$@"