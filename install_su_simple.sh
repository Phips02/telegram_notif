#!/bin/bash

# install_su_simple.sh - Installation du système de détection su simplifié
# Version: 1.0

set -e

# Configuration
INSTALL_DIR="/usr/local/bin/telegram_notif"
CONFIG_DIR="/etc/telegram"
SERVICE_NAME="telegram-su-simple"

echo "=== Installation du système de détection su simplifié ==="

# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
    echo "ERREUR: Ce script doit être exécuté en tant que root"
    exit 1
fi

# Créer les répertoires
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "/var/lib/telegram_su_simple"

# Copier le script principal
cp "telegram_su_simple.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/telegram_su_simple.sh"

# Créer le lien symbolique pour faciliter l'utilisation
ln -sf "$INSTALL_DIR/telegram_su_simple.sh" "/usr/local/bin/telegram-su-simple"

# Configuration des credentials Telegram
if [ ! -f "$CONFIG_DIR/credentials.cfg" ]; then
    echo "Configuration des identifiants Telegram..."
    read -p "Token du bot Telegram: " BOT_TOKEN
    read -p "Chat ID Telegram: " CHAT_ID
    
    cat > "$CONFIG_DIR/credentials.cfg" << EOF
# Configuration Telegram
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF
    
    chown root:root "$CONFIG_DIR/credentials.cfg"
    chmod 600 "$CONFIG_DIR/credentials.cfg"
else
    echo "Configuration Telegram existante trouvée"
fi

# Créer le service systemd avec timer
cat > "/etc/systemd/system/$SERVICE_NAME.service" << 'EOF'
[Unit]
Description=Telegram SU Simple Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/telegram_notif/telegram_su_simple.sh
User=root
Group=root

# Sécurité
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/telegram_su_simple /var/log
EOF

# Créer le timer systemd (exécution toutes les 30 secondes)
cat > "/etc/systemd/system/$SERVICE_NAME.timer" << 'EOF'
[Unit]
Description=Run Telegram SU Simple Monitor every 30 seconds
Requires=telegram-su-simple.service

[Timer]
OnBootSec=30
OnUnitActiveSec=30
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# Recharger systemd et démarrer le timer
systemctl daemon-reload
systemctl enable "$SERVICE_NAME.timer"
systemctl start "$SERVICE_NAME.timer"

echo "✅ Installation terminée !"
echo ""
echo "📋 Commandes utiles :"
echo "  • Voir le statut : systemctl status $SERVICE_NAME.timer"
echo "  • Voir les logs : tail -f /var/log/telegram_su_simple.log"
echo "  • Test manuel : telegram-su-simple"
echo "  • Arrêter : systemctl stop $SERVICE_NAME.timer"
echo "  • Démarrer : systemctl start $SERVICE_NAME.timer"
echo ""
echo "🧪 Test de la configuration..."

# Test de la configuration
if "$INSTALL_DIR/telegram_su_simple.sh"; then
    echo "✅ Test réussi - Le système est opérationnel"
else
    echo "❌ Test échoué - Vérifiez la configuration"
fi

echo ""
echo "📊 Statut du timer :"
systemctl status "$SERVICE_NAME.timer" --no-pager -l
