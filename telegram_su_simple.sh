#!/bin/bash

# telegram_su_simple.sh - Détection simplifiée des élévations su
# Version: 1.1 - Optimisé pour Debian/Ubuntu
# Utilise journalctl pour détecter les élévations su avec cache basé sur l'heure

# Forcer les locales pour compatibilité Debian/Ubuntu
export LC_ALL=C
export LANG=C

# Configuration
CACHE_FILE="/var/lib/telegram_su_simple/cache"
CONFIG_FILE="/etc/telegram/credentials.cfg"
LOG_FILE="/var/log/telegram_su_simple.log"

# Créer le répertoire de cache si nécessaire
mkdir -p "$(dirname "$CACHE_FILE")"

# Fonction de log simple
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Charger la configuration Telegram
if [ ! -f "$CONFIG_FILE" ]; then
    log_message "ERROR: Fichier de configuration non trouvé: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    log_message "ERROR: BOT_TOKEN ou CHAT_ID non défini dans $CONFIG_FILE"
    exit 1
fi

# Fonction d'envoi Telegram simplifiée
send_telegram() {
    local message="$1"
    curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$message" \
        -d "parse_mode=Markdown" \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        --connect-timeout 10 \
        --max-time 30 > /dev/null 2>&1
}

# Charger le cache existant
if [ -f "$CACHE_FILE" ]; then
    source "$CACHE_FILE"
else
    touch "$CACHE_FILE"
fi

# Récupérer les lignes su/sudo récentes (optimisé pour Debian/Ubuntu)
journalctl --since="45 seconds ago" --no-pager | grep -E "(su\[|sudo\[)[0-9]+\]:" | grep -E "(session opened|authentication)" | while IFS= read -r line; do
    
    # Regex étendue pour Debian/Ubuntu - capture su et su -l
    if [[ "$line" =~ ^([A-Za-z]{3}[[:space:]]+[0-9]{1,2}[[:space:]]+[0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]]+[^[:space:]]+[[:space:]]+(su|sudo)\[([0-9]+)\]:[[:space:]]+pam_unix\((su|sudo)(-l)?:(session|auth)\):[[:space:]]+(session[[:space:]]+opened[[:space:]]+for[[:space:]]+user[[:space:]]+([^(]+)\(uid=([0-9]+)\)[[:space:]]+by[[:space:]]+([^(]+)\(uid=([0-9]+)\)|authentication) ]]; then
        
        timestamp="${BASH_REMATCH[1]}"
        command_type="${BASH_REMATCH[2]}"  # su ou sudo
        pid="${BASH_REMATCH[3]}"
        
        # Pour les sessions ouvertes, extraire les utilisateurs
        if [[ "$line" =~ session[[:space:]]+opened ]]; then
            if [[ "$line" =~ session[[:space:]]+opened[[:space:]]+for[[:space:]]+user[[:space:]]+([^(]+)\(uid=([0-9]+)\)[[:space:]]+by[[:space:]]+([^(]+)\(uid=([0-9]+)\) ]]; then
                target_user="${BASH_REMATCH[1]}"
                target_uid="${BASH_REMATCH[2]}"
                source_user="${BASH_REMATCH[3]}"
                source_uid="${BASH_REMATCH[4]}"
            else
                continue  # Ignorer si on ne peut pas extraire les utilisateurs
            fi
        else
            continue  # Ignorer les autres types d'événements pour le moment
        fi
        
        # Créer un ID de cache basé sur timestamp + PID pour unicité
        cache_id="${pid}_$(echo "$timestamp" | tr -d ' :')"
        
        # Vérifier si cette élévation a déjà été notifiée
        if grep -q "^$cache_id$" "$CACHE_FILE" 2>/dev/null; then
            continue
        fi
        
        # Ajouter au cache
        echo "$cache_id" >> "$CACHE_FILE"
        
        # Déterminer l'icône selon le type de commande
        local icon="🔐"
        local action="Élévation su"
        if [ "$command_type" = "sudo" ]; then
            icon="⚡"
            action="Commande sudo"
        fi
        
        # Créer le message de notification
        message="$icon *$action détectée*

👤 **Utilisateur source:** \`$source_user\` (UID: $source_uid)
🎯 **Utilisateur cible:** \`$target_user\` (UID: $target_uid)
⏰ **Heure:** $timestamp
🔢 **PID:** $pid
🖥️ **Serveur:** \`$(hostname)\`

📋 **Commande:** $command_type
📄 **Ligne complète:**
\`$line\`"

        # Envoyer la notification
        send_telegram "$message"
        log_message "INFO: Notification envoyée pour $command_type $source_user -> $target_user à $timestamp (PID: $pid)"
        
    fi
done

# Nettoyer le cache (garder seulement les 100 dernières entrées pour serveurs actifs)
if [ -f "$CACHE_FILE" ]; then
    tail -n 100 "$CACHE_FILE" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
fi

log_message "INFO: Vérification terminée - Debian/Ubuntu optimized"