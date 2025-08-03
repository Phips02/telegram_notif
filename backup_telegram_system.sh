#!/bin/bash
# Script de backup pour préparer les fichiers à pousser sur GitHub
# Système de notification de connexion Telegram uniquement

BACKUP_DIR="/root/telegram_notif_backup"

echo "🔄 Backup du système de notification de connexion Telegram"
echo ""

# Créer la structure pour GitHub
mkdir -p "$BACKUP_DIR/scripts"
mkdir -p "$BACKUP_DIR/systemd"
mkdir -p "$BACKUP_DIR/config"

# 1. Scripts de monitoring des connexions uniquement
echo "📜 Copie des scripts de monitoring..."
cp /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh "$BACKUP_DIR/scripts/"
cp /usr/local/bin/telegram_notif/telegram_privilege_monitor.sh "$BACKUP_DIR/scripts/"

# 2. Services systemd associés
echo "⚙️  Copie des services systemd..."
cp /etc/systemd/system/telegram-wtmp-monitor.service "$BACKUP_DIR/systemd/"
cp /etc/systemd/system/telegram-privilege-monitor.service "$BACKUP_DIR/systemd/"

# 3. Fichiers de configuration exemple
echo "🔧 Création des exemples de configuration..."
cat > "$BACKUP_DIR/config/credentials.cfg.example" << 'EOF'
# Configuration Telegram Bot
BOT_TOKEN="VOTRE_BOT_TOKEN_ICI"
CHAT_ID="VOTRE_CHAT_ID_ICI"
EOF

cat > "$BACKUP_DIR/config/telegram_notif.cfg.example" << 'EOF'
# Configuration optionnelle
CHECK_INTERVAL=5
MAX_CACHE_SIZE=1000
CURL_TIMEOUT=10
SKIP_PUBLIC_IP=true
EOF

# 4. Documentation
echo "📚 Copie de la documentation..."
cp /usr/local/bin/CLAUDE.md "$BACKUP_DIR/"

echo ""
echo "✅ Backup terminé!"
echo "📁 Fichiers prêts dans: $BACKUP_DIR"
echo ""
echo "📋 Structure créée:"
find "$BACKUP_DIR" -type f | sort
echo ""
echo "🚀 Vous pouvez maintenant pousser ces fichiers sur GitHub"