#!/bin/bash

# telegram_su_simple_fixed.sh - Version corrigée sans notifications en boucle
# Version: 1.2 - Corrections anti-doublons robustes

# Forcer les locales pour compatibilité
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

# Créer un fichier de cache temporaire pour cette exécution
TEMP_CACHE="/tmp/telegram_su_temp_$$"

# Récupérer les lignes su/sudo récentes (dernières 45 secondes)
journalctl --since="45 seconds ago" --no-pager -q 2>/dev/null | \
grep -E "(su\[|sudo\[)[0-9]+\]:" | \
grep -E "session opened for user" | \
while IFS= read -r line; do
    
    # Extraire les informations avec une regex plus robuste
    if [[ "$line" =~ ([A-Za-z]{3}[[:space:]]+[0-9]{1,2}[[:space:]]+[0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]]+[^[:space:]]+[[:space:]]+(su|sudo)\[([0-9]+)\]:[[:space:]]+pam_unix\((su|sudo)(-l)?:session\):[[:space:]]+session[[:space:]]+opened[[:space:]]+for[[:space:]]+user[[:space:]]+([^(]+)\(uid=([0-9]+)\)[[:space:]]+by[[:space:]]+([^(]+)\(uid=([0-9]+)\) ]]; then
        
        timestamp="${BASH_REMATCH[1]}"
        command_type="${BASH_REMATCH[2]}"
        pid="${BASH_REMATCH[3]}"
        target_user="${BASH_REMATCH[6]}"
        target_uid="${BASH_REMATCH[7]}"
        source_user="${BASH_REMATCH[8]}"
        source_uid="${BASH_REMATCH[9]}"
        
        # CORRECTION PRINCIPALE : Créer un ID basé sur les éléments stables uniquement
        # Ne pas inclure le timestamp exact qui peut varier
        cache_id="${source_user}_to_${target_user}_${command_type}_${pid}"
        
        # Vérifier si cette élévation a déjà été notifiée (cache global ET temporaire)
        if grep -q "^$cache_id$" "$CACHE_FILE" 2>/dev/null || grep -q "^$cache_id$" "$TEMP_CACHE" 2>/dev/null; then
            continue
        fi
        
        # Ajouter au cache temporaire pour éviter les doublons dans cette exécution
        echo "$cache_id" >> "$TEMP_CACHE"
        
        # Ajouter au cache global
        echo "$cache_id" >> "$CACHE_FILE"
        
        # Déterminer l'icône selon le type de commande
        local icon="🔐"
        local action="Élévation su"
        if [ "$command_type" = "sudo" ]; then
            icon="⚡"
            action="Commande sudo"
        fi
        
        # Créer le message de notification (format simplifié pour éviter les caractères problématiques)
        message="$icon *$action detectee*

👤 Source: $source_user (UID: $source_uid)
🎯 Cible: $target_user (UID: $target_uid)
⏰ Heure: $timestamp
🔢 PID: $pid
🖥️ Serveur: $(hostname)

📋 Commande: $command_type"

        # Envoyer la notification
        if send_telegram "$message"; then
            log_message "INFO: Notification envoyée pour $command_type $source_user -> $target_user (PID: $pid)"
        else
            log_message "ERROR: Échec notification $command_type $source_user -> $target_user (PID: $pid)"
        fi
        
    fi
done

# Nettoyer le cache global (garder seulement les 50 dernières entrées)
if [ -f "$CACHE_FILE" ]; then
    tail -n 50 "$CACHE_FILE" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
fi

# Nettoyer le cache temporaire
rm -f "$TEMP_CACHE"

log_message "INFO: Verification terminee - Cache anti-doublons applique"