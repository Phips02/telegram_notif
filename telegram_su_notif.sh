#!/bin/bash
# telegram_su_notif.sh - Script simple pour notifications élévations su
# Version: 2.0 - Ultra simplifié inspiré de Claude
# Auteur: Phips

# Charger les credentials Telegram
source /etc/telegram/credentials.cfg 2>/dev/null || exit 1

# Vérifier que les variables sont définies
[ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && exit 1

# Récupérer les informations
USER_FROM="${PAM_USER:-$USER}"
USER_TO="${PAM_RUSER:-root}"
TERMINAL="${PAM_TTY:-$(tty 2>/dev/null | cut -d'/' -f3-)}"
IP_SOURCE="${PAM_RHOST:-${SSH_CLIENT%% *}}"
HOSTNAME=$(hostname)
IP_LOCAL=$(hostname -I | awk '{print $1}' 2>/dev/null)
DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Ignorer si même utilisateur
[ "$USER_FROM" = "$USER_TO" ] && exit 0

# Créer le message simple
MESSAGE="🔐 Élévation de privilège

📅 $DATE_TIME
👤 $USER_FROM → $USER_TO
💻 $HOSTNAME ($IP_LOCAL)
📺 Terminal: $TERMINAL"

# Ajouter IP source si présente
[ -n "$IP_SOURCE" ] && [ "$IP_SOURCE" != "-" ] && MESSAGE="$MESSAGE
📡 Depuis: $IP_SOURCE"

# Envoyer via Telegram (simple)
curl -s --max-time 5 \
  -d "chat_id=$CHAT_ID" \
  -d "text=$MESSAGE" \
  "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" >/dev/null 2>&1 &

# Log simple
echo "$(date): $USER_FROM -> $USER_TO sur $TERMINAL" >> /var/log/telegram_su_notif.log 2>/dev/null

exit 0
