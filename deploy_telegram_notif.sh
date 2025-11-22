#!/bin/bash
# Telegram Notification System V6.2

# Script de déploiement du système de notification Telegram
# Compatible: Debian/Ubuntu uniquement

set -e

VERSION="6.2"
GITHUB_REPO="https://raw.githubusercontent.com/Phips02/telegram_notif/main"
TEMP_DIR="/tmp/telegram_notif_install"
INSTALL_DIR="/usr/local/bin/telegram_notif"
CONFIG_DIR="/etc/telegram"

# === Gestion des arguments ===
show_help() {
    echo "Telegram Notification System - Deploy Script v$VERSION"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --update, -u    Met à jour les scripts sans reconfigurer les credentials"
    echo "  --version, -v   Affiche la version"
    echo "  --help, -h      Affiche cette aide"
    echo ""
    echo "Sans option: Installation complète avec configuration interactive"
}

update_only() {
    echo "🔄 Mode mise à jour - v$VERSION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Vérification root
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Ce script doit être exécuté en tant que root"
        exit 1
    fi

    # Vérifier que l'installation existe
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "❌ Installation non trouvée dans $INSTALL_DIR"
        echo "   Lancez le script sans --update pour une installation complète."
        exit 1
    fi

    if [[ ! -f "$CONFIG_DIR/credentials.cfg" ]]; then
        echo "❌ Configuration non trouvée dans $CONFIG_DIR/credentials.cfg"
        echo "   Lancez le script sans --update pour une installation complète."
        exit 1
    fi

    echo "⬇️  Téléchargement des scripts mis à jour..."
    curl -fsSL "$GITHUB_REPO/scripts/telegram_wtmp_monitor.sh" -o "$INSTALL_DIR/telegram_wtmp_monitor.sh"
    curl -fsSL "$GITHUB_REPO/scripts/telegram_privilege_monitor.sh" -o "$INSTALL_DIR/telegram_privilege_monitor.sh"

    # Mise à jour des services systemd (au cas où ils auraient changé)
    echo "⬇️  Téléchargement des services systemd..."
    curl -fsSL "$GITHUB_REPO/systemd/telegram-wtmp-monitor.service" -o /etc/systemd/system/telegram-wtmp-monitor.service
    curl -fsSL "$GITHUB_REPO/systemd/telegram-privilege-monitor.service" -o /etc/systemd/system/telegram-privilege-monitor.service
    systemctl daemon-reload

    # Permissions
    chmod +x "$INSTALL_DIR"/*.sh

    # Redémarrer les services
    echo "🔄 Redémarrage des services..."
    systemctl restart telegram-wtmp-monitor telegram-privilege-monitor

    # Vérification du statut
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

    echo ""
    echo "🎉 Mise à jour terminée !"
    exit 0
}

# Traitement des arguments
case "${1:-}" in
    --update|-u)
        update_only
        ;;
    --version|-v)
        echo "Telegram Notification System - Deploy Script v$VERSION"
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    "")
        # Pas d'argument = installation complète
        ;;
    *)
        echo "❌ Option inconnue: $1"
        show_help
        exit 1
        ;;
esac

# === Installation complète (code original) ===

echo "🚀 Installation du système de notification Telegram v$VERSION"
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
mkdir -p "$INSTALL_DIR"
cp telegram_wtmp_monitor.sh "$INSTALL_DIR/"
cp telegram_privilege_monitor.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh

# Création des liens symboliques
echo "🔗 Création des liens symboliques..."
ln -sf "$INSTALL_DIR/telegram_wtmp_monitor.sh" /usr/local/bin/telegram-wtmp-monitor
ln -sf "$INSTALL_DIR/telegram_privilege_monitor.sh" /usr/local/bin/telegram-privilege-monitor

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

read -p "🤖 Entrez votre BOT_TOKEN : " BOT_TOKEN
read -p "💬 Entrez votre CHAT_ID : " CHAT_ID

# Validation basique des inputs
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo "❌ BOT_TOKEN et CHAT_ID sont obligatoires"
    exit 1
fi

# Création du répertoire de configuration
echo "📝 Création de la configuration..."
mkdir -p "$CONFIG_DIR"

# Création du fichier credentials avec les bonnes permissions
cat > "$CONFIG_DIR/credentials.cfg" << EOF
# Configuration Telegram Bot
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF

# Configuration des permissions de sécurité
chmod 600 "$CONFIG_DIR/credentials.cfg"
chown root:root "$CONFIG_DIR/credentials.cfg"

# Copie de la configuration optionnelle (renommer sans .example)
cp telegram_notif.cfg.example "$CONFIG_DIR/telegram_notif.cfg"

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
echo ""
echo "🔄 Pour mettre à jour ultérieurement :"
echo "   curl -fsSL $GITHUB_REPO/deploy_telegram_notif.sh | bash -s -- --update"
