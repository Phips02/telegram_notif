#!/bin/bash
# Script de déploiement du système de notification Telegram
# Compatible: Debian/Ubuntu uniquement
# Usage: curl -sSL https://raw.githubusercontent.com/Phips02/telegram_notif/main/deploy_telegram_notif.sh | bash

set -e

GITHUB_REPO="https://raw.githubusercontent.com/Phips02/telegram_notif/main"
TEMP_DIR="/tmp/telegram_notif_install"

echo "🚀 Installation du système de notification Telegram"
echo "📦 Depuis: https://github.com/Phips02/telegram_notif"
echo ""

# Vérification des prérequis
echo "🔍 Vérification des prérequis..."
if [[ $EUID -ne 0 ]]; then
   echo "❌ Ce script doit être exécuté en tant que root"
   exit 1
fi

# Installation des dépendances pour Debian/Ubuntu
echo "📦 Installation des dépendances..."
apt-get update -qq
apt-get install -y curl systemd

# Vérifier les commandes nécessaires
echo "✅ Vérification des commandes requises..."
for cmd in curl systemctl journalctl last date stat who hostname; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Commande manquante: $cmd"
        exit 1
    fi
done

# Créer le répertoire temporaire
echo "📁 Préparation des répertoires..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Télécharger les fichiers depuis GitHub
echo "⬇️  Téléchargement des fichiers..."
curl -sSL "$GITHUB_REPO/scripts/telegram_wtmp_monitor.sh" -o telegram_wtmp_monitor.sh
curl -sSL "$GITHUB_REPO/scripts/telegram_privilege_monitor.sh" -o telegram_privilege_monitor.sh
curl -sSL "$GITHUB_REPO/systemd/telegram-wtmp-monitor.service" -o telegram-wtmp-monitor.service
curl -sSL "$GITHUB_REPO/systemd/telegram-privilege-monitor.service" -o telegram-privilege-monitor.service
curl -sSL "$GITHUB_REPO/config/telegram_notif.cfg.example" -o telegram_notif.cfg.example

# Installation des scripts
echo "📜 Installation des scripts..."
mkdir -p /usr/local/bin/telegram_notif
cp telegram_wtmp_monitor.sh /usr/local/bin/telegram_notif/
cp telegram_privilege_monitor.sh /usr/local/bin/telegram_notif/
chmod +x /usr/local/bin/telegram_notif/*.sh

# Création des liens symboliques
echo "🔗 Création des liens symboliques..."
ln -sf /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh /usr/local/bin/telegram-wtmp-monitor
ln -sf /usr/local/bin/telegram_notif/telegram_privilege_monitor.sh /usr/local/bin/telegram-privilege-monitor

# Installation des services systemd
echo "⚙️  Installation des services systemd..."
cp telegram-wtmp-monitor.service /etc/systemd/system/
cp telegram-privilege-monitor.service /etc/systemd/system/
systemctl daemon-reload

# Configuration interactive des credentials Telegram
echo ""
echo "🔧 Configuration des credentials Telegram"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Pour obtenir vos credentials Telegram :"
echo "1. Créez un bot via @BotFather sur Telegram"
echo "2. Obtenez votre CHAT_ID en envoyant un message au bot puis en consultant :"
echo "   https://api.telegram.org/bot<VOTRE_TOKEN>/getUpdates"
echo ""

# Rediriger depuis /dev/tty pour permettre l'interaction via pipe
exec < /dev/tty
read -p "🤖 Entrez votre BOT_TOKEN : " BOT_TOKEN
read -p "💬 Entrez votre CHAT_ID : " CHAT_ID

# Validation basique des inputs
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo "❌ BOT_TOKEN et CHAT_ID sont obligatoires"
    exit 1
fi

# Création du répertoire de configuration
echo "📝 Création de la configuration..."
mkdir -p /etc/telegram

# Création du fichier credentials avec les bonnes permissions
cat > /etc/telegram/credentials.cfg << EOF
# Configuration Telegram Bot
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF

# Configuration des permissions de sécurité
chmod 600 /etc/telegram/credentials.cfg
chown root:root /etc/telegram/credentials.cfg

# Copie de la configuration optionnelle (renommer sans .example)
cp telegram_notif.cfg.example /etc/telegram/telegram_notif.cfg

# Création des répertoires de logs et cache
echo "📁 Création des répertoires système..."
mkdir -p /var/log
mkdir -p /var/lib/telegram_wtmp_monitor
mkdir -p /var/lib/telegram_privilege_monitor
mkdir -p /var/run

# Test de la configuration
echo ""
echo "🧪 Test de la configuration Telegram..."
if /usr/local/bin/telegram-wtmp-monitor test >/dev/null 2>&1; then
    echo "✅ Test réussi - Configuration Telegram fonctionnelle"
else
    echo "⚠️  Test échoué - Vérifiez vos credentials"
fi

# Activation et démarrage automatique des services
echo ""
echo "🚀 Activation des services..."
systemctl enable telegram-wtmp-monitor.service
systemctl enable telegram-privilege-monitor.service
systemctl start telegram-wtmp-monitor.service
systemctl start telegram-privilege-monitor.service

# Vérification du statut des services
echo ""
echo "📊 Statut des services :"
if systemctl is-active --quiet telegram-wtmp-monitor.service; then
    echo "✅ telegram-wtmp-monitor.service : Actif"
else
    echo "❌ telegram-wtmp-monitor.service : Inactif"
fi

if systemctl is-active --quiet telegram-privilege-monitor.service; then
    echo "✅ telegram-privilege-monitor.service : Actif"
else
    echo "❌ telegram-privilege-monitor.service : Inactif"
fi

# Nettoyage
echo ""
echo "🧹 Nettoyage..."
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Installation et configuration terminées !"
echo ""
echo "📋 Commandes utiles :"
echo "   telegram-wtmp-monitor status      # Statut du moniteur de connexions"
echo "   telegram-privilege-monitor status # Statut du moniteur de privilèges"
echo "   telegram-wtmp-monitor test        # Test de notification"
echo "   telegram-privilege-monitor test   # Test de notification"
echo ""
echo "📝 Logs disponibles :"
echo "   /var/log/telegram_wtmp_monitor.log"
echo "   /var/log/telegram_privilege_monitor.log"