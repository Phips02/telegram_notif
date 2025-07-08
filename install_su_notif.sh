#!/bin/bash
# install_fixed_su.sh - Installation corrigée des notifications su
# Basé sur la version GitHub fonctionnelle

echo "🔧 Installation notifications élévations su (version corrigée)..."

# Vérifier root
[ "$EUID" -ne 0 ] && { echo "❌ Exécuter en root"; exit 1; }

# Vérifier config Telegram existe
[ ! -f "/etc/telegram/credentials.cfg" ] && {
    echo "❌ Configuration Telegram manquante"
    echo "   Installez d'abord telegram_wtmp_monitor.sh"
    exit 1
}

echo "✅ Configuration Telegram trouvée"

# Supprimer ancienne version si elle existe
if [ -f "/usr/local/bin/telegram_notif/telegram_su_notif.sh" ]; then
    echo "🗑️  Suppression ancienne version..."
    rm -f "/usr/local/bin/telegram_notif/telegram_su_notif.sh"
fi

# Créer le répertoire
mkdir -p /usr/local/bin/telegram_notif

# Créer le script corrigé
cat > /usr/local/bin/telegram_notif/telegram_su_notif.sh << 'EOF'
#!/bin/bash

# telegram_su_notif.sh - Notification Telegram pour élévations su
# Version: 2.1 - Corrigé basé sur version GitHub fonctionnelle
# Auteur: Phips

# Configuration
CONFIG_DIR="/etc/telegram"
CREDENTIALS_FILE="$CONFIG_DIR/credentials.cfg"
LOG_FILE="/var/log/telegram_su_notif.log"

# S'assurer que le log existe
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/telegram_su_notif.log"

# Fonction de logging renforcée
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] [PID:$$] $message"
    
    # Écrire dans le log
    echo "$log_entry" >> "$LOG_FILE" 2>/dev/null
    
    # Écrire aussi dans syslog pour debug
    logger -t "telegram_su_notif" "$log_entry" 2>/dev/null || true
}

# Log de démarrage
log_message "INFO" "=== SCRIPT DÉMARRÉ ==="
log_message "DEBUG" "Variables PAM: USER=$USER, PAM_USER=$PAM_USER, PAM_RUSER=$PAM_RUSER, PAM_TTY=$PAM_TTY, PAM_RHOST=$PAM_RHOST"
log_message "DEBUG" "Environnement: HOME=$HOME, LOGNAME=$LOGNAME"

# Fonction pour charger les credentials
load_credentials() {
    log_message "DEBUG" "Chargement credentials depuis: $CREDENTIALS_FILE"
    
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        log_message "ERROR" "Fichier credentials non trouvé: $CREDENTIALS_FILE"
        return 1
    fi
    
    if [ ! -r "$CREDENTIALS_FILE" ]; then
        log_message "ERROR" "Fichier credentials non lisible: $CREDENTIALS_FILE"
        return 1
    fi
    
    # Source avec vérification
    source "$CREDENTIALS_FILE" || {
        log_message "ERROR" "Erreur lors du source de $CREDENTIALS_FILE"
        return 1
    }
    
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        log_message "ERROR" "BOT_TOKEN ou CHAT_ID vide après chargement"
        return 1
    fi
    
    log_message "DEBUG" "Credentials chargés avec succès"
    return 0
}

# Fonction pour obtenir l'IP publique (rapide)
get_public_ip() {
    local public_ip
    public_ip=$(timeout 3 curl -s --max-time 2 "https://ipv4.icanhazip.com" 2>/dev/null | head -1)
    if [ -z "$public_ip" ] || ! [[ "$public_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        public_ip="N/A"
    fi
    echo "$public_ip"
}

# Fonction pour envoyer le message Telegram
send_telegram_message() {
    local message="$1"
    
    log_message "DEBUG" "Préparation envoi message Telegram"
    
    # Créer fichier temporaire
    local temp_file="/tmp/telegram_su_msg_$$.txt"
    printf '%s' "$message" > "$temp_file"
    
    # Premier essai avec markdown
    local response=$(timeout 10 curl -s --max-time 8 \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "text@$temp_file" \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" 2>&1)
    
    log_message "DEBUG" "Réponse Telegram (markdown): $response"
    
    # Vérifier le succès
    if echo "$response" | grep -q '"ok":true'; then
        log_message "INFO" "Message Telegram envoyé avec succès (markdown)"
        rm -f "$temp_file"
        return 0
    else
        log_message "WARN" "Échec envoi avec markdown, essai sans markdown"
        
        # Fallback sans markdown
        local response2=$(timeout 10 curl -s --max-time 8 \
            -X POST \
            -H "Content-Type: application/x-www-form-urlencoded" \
            --data-urlencode "chat_id=$CHAT_ID" \
            --data-urlencode "text@$temp_file" \
            "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" 2>&1)
        
        log_message "DEBUG" "Réponse Telegram (sans markdown): $response2"
        
        if echo "$response2" | grep -q '"ok":true'; then
            log_message "INFO" "Message Telegram envoyé sans markdown"
            rm -f "$temp_file"
            return 0
        else
            log_message "ERROR" "Échec complet envoi Telegram"
            log_message "ERROR" "Réponse 1: $response"
            log_message "ERROR" "Réponse 2: $response2"
            rm -f "$temp_file"
            return 1
        fi
    fi
}

# Fonction principale
main() {
    log_message "INFO" "=== DÉBUT TRAITEMENT ÉLÉVATION ==="
    
    # Charger les credentials
    if ! load_credentials; then
        log_message "ERROR" "Impossible de charger les credentials - arrêt"
        exit 1
    fi
    
    # Récupérer les informations de la session
    # CORRECTION IMPORTANTE: Utiliser les bonnes variables PAM
    local original_user="${PAM_USER:-$USER}"
    local target_user="${PAM_RUSER:-root}"
    local terminal="${PAM_TTY:-$(tty 2>/dev/null | sed 's|/dev/||')}"
    local source_ip="${PAM_RHOST:-${SSH_CLIENT%% *}}"
    
    # Si PAM_RUSER est vide, essayer d'autres méthodes
    if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
        # Regarder la ligne de commande du processus parent
        local parent_cmd=$(ps -p $PPID -o args= 2>/dev/null || echo "")
        if [[ "$parent_cmd" =~ su[[:space:]]+-[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
            target_user="${BASH_REMATCH[1]}"
        elif [[ "$parent_cmd" =~ su[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
            target_user="${BASH_REMATCH[1]}"
        fi
    fi
    
    local hostname=$(hostname)
    local local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_message "DEBUG" "Informations récupérées:"
    log_message "DEBUG" "  - Utilisateur original: $original_user"
    log_message "DEBUG" "  - Utilisateur cible: $target_user" 
    log_message "DEBUG" "  - Terminal: $terminal"
    log_message "DEBUG" "  - IP source: $source_ip"
    log_message "DEBUG" "  - Hostname: $hostname"
    log_message "DEBUG" "  - IP locale: $local_ip"
    
    # Ignorer certains cas
    if [ "$original_user" = "$target_user" ]; then
        log_message "DEBUG" "Même utilisateur source et cible - ignoré"
        exit 0
    fi
    
    # Ignorer si pas d'utilisateur source valide
    if [ -z "$original_user" ] || [ "$original_user" = "root" ]; then
        log_message "DEBUG" "Utilisateur source invalide ou déjà root - ignoré"
        exit 0
    fi
    
    # Déterminer le type d'élévation
    local elevation_type="su"
    if [ "$target_user" = "root" ]; then
        elevation_type="su vers root"
    else
        elevation_type="su vers $target_user"
    fi
    
    log_message "INFO" "Élévation détectée: $original_user → $target_user sur $terminal"
    
    # Obtenir l'IP publique
    local public_ip=$(get_public_ip)
    
    # Créer le message de notification (format simple comme la version GitHub)
    local message="🔐 *Élévation de privilège détectée*

👤 **Utilisateur:** $original_user → $target_user
🖥️ **Terminal:** $terminal
🏠 **Serveur:** $hostname
📍 **IP Locale:** $local_ip"

    # Ajouter l'IP source si disponible
    if [ -n "$source_ip" ] && [ "$source_ip" != "-" ] && [ "$source_ip" != "" ]; then
        message="$message
📡 **IP Source:** $source_ip"
    fi
    
    # Ajouter l'IP publique
    message="$message
🌍 **IP Publique:** $public_ip
🕐 **Heure:** $current_time

───────────────────────────
Type: $elevation_type"
    
    log_message "DEBUG" "Message créé, tentative d'envoi..."
    
    # Envoyer la notification
    if send_telegram_message "$message"; then
        log_message "SUCCESS" "Notification envoyée avec succès"
    else
        log_message "ERROR" "Échec de l'envoi de la notification"
    fi
    
    log_message "INFO" "=== FIN TRAITEMENT ==="
}

# Gestion des modes d'exécution
case "${1:-}" in
    "--background")
        # Mode PAM - exécuter en arrière-plan
        main >> "$LOG_FILE" 2>&1 &
        exit 0
        ;;
    "--test")
        # Mode test
        export PAM_USER="testuser"
        export PAM_RUSER="root"
        export PAM_TTY="pts/1"
        export PAM_RHOST=""
        main
        ;;
    "--debug")
        # Mode debug avec sortie console
        main
        ;;
    *)
        # Mode par défaut - background pour PAM
        main >> "$LOG_FILE" 2>&1 &
        exit 0
        ;;
esac
EOF

# Permissions
chmod +x /usr/local/bin/telegram_notif/telegram_su_notif.sh
chown root:root /usr/local/bin/telegram_notif/telegram_su_notif.sh

echo "✅ Script installé: /usr/local/bin/telegram_notif/telegram_su_notif.sh"

# Nettoyer la configuration PAM existante
PAM_FILE="/etc/pam.d/su"
echo "🧹 Nettoyage configuration PAM existante..."

# Supprimer les lignes existantes de telegram_su_notif
cp "$PAM_FILE" "$PAM_FILE.backup.$(date +%Y%m%d_%H%M%S)"
grep -v "telegram_su_notif" "$PAM_FILE" > "$PAM_FILE.tmp"
mv "$PAM_FILE.tmp" "$PAM_FILE"

# Ajouter la nouvelle ligne PAM (comme dans la version GitHub)
PAM_LINE="session optional pam_exec.so quiet /usr/local/bin/telegram_notif/telegram_su_notif.sh --background"

echo "✅ Backup PAM: $PAM_FILE.backup.*"

# Trouver la bonne position pour insérer la ligne
if grep -q "^@include common-session" "$PAM_FILE"; then
    # Ajouter après @include common-session
    sed -i "/^@include common-session/a\\$PAM_LINE" "$PAM_FILE"
    echo "✅ Configuration PAM ajoutée après @include common-session"
elif grep -q "^session.*required.*pam_limits.so" "$PAM_FILE"; then
    # Ajouter après pam_limits.so
    sed -i "/^session.*required.*pam_limits.so/a\\$PAM_LINE" "$PAM_FILE"
    echo "✅ Configuration PAM ajoutée après pam_limits.so"
else
    # Ajouter à la fin
    echo "$PAM_LINE" >> "$PAM_FILE"
    echo "✅ Configuration PAM ajoutée à la fin"
fi

# Configurer sudo aussi si le fichier existe
if [ -f "/etc/pam.d/sudo" ]; then
    if ! grep -q "telegram_su_notif" "/etc/pam.d/sudo"; then
        cp "/etc/pam.d/sudo" "/etc/pam.d/sudo.backup.$(date +%Y%m%d_%H%M%S)"
        echo "$PAM_LINE" >> "/etc/pam.d/sudo"
        echo "✅ Configuration PAM sudo ajoutée"
    fi
fi

# Créer les logs
touch /var/log/telegram_su_notif.log
chmod 644 /var/log/telegram_su_notif.log

echo ""
echo "🚀 Installation terminée !"
echo ""
echo "📋 Test immédiat:"
echo "   /usr/local/bin/telegram_notif/telegram_su_notif.sh --test"
echo ""
echo "📋 Test réel (dans un autre terminal):"
echo "   su -        # Vous devriez recevoir une notification"
echo ""
echo "📄 Logs:"
echo "   tail -f /var/log/telegram_su_notif.log"
echo "   grep telegram_su_notif /var/log/syslog"
echo ""
echo "🔧 Configuration PAM:"
echo "   cat /etc/pam.d/su | grep telegram"
echo ""

# Test automatique
echo "🧪 Test automatique..."
if /usr/local/bin/telegram_notif/telegram_su_notif.sh --test; then
    echo "✅ Test réussi - vérifiez Telegram !"
else
    echo "❌ Test échoué - vérifiez les logs"
fi