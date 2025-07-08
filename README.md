# 🔔 Système de surveillance des connexions serveur
Version 4.8 - Intégré avec Phips Logger V3

## 🎯 À propos

Système de surveillance complète pour recevoir des notifications Telegram lors de **toutes les connexions** à votre serveur :

- 🔐 **Connexions SSH** (standard et legacy)
- 🖥️ **Console Proxmox** (avec détection IP source)
- 📺 **Console Web** (interfaces d'administration)
- 💻 **Console locale** (accès direct serveur)
- 📱 **Sessions Screen/Tmux**
- 🔄 **Commandes su/sudo**
- ⚙️ **Exécutions non-interactives**

## 🆕 Nouveautés V4.8

- ✅ **Détection intelligente** de tous les types de connexion
- ✅ **Intégration Phips Logger V3** pour logs centralisés
- ✅ **Détection spécifique Proxmox** avec IP source
- ✅ **Messages modernes** avec emojis et séparations Unicode
- ✅ **Configuration unifiée** Telegram
- ✅ **Performance optimisée** et script plus court
- ✅ **Informations détaillées** (terminal, sessions actives)

## 🚀 Installation

### Prérequis

**1. Installer Phips Logger V3 (obligatoire) :**
```bash
cd /tmp
git clone https://github.com/Phips02/Phips_logger_v3.git
cd Phips_logger_v3
chmod +x install.sh
sudo ./install.sh
```

**2. Installer les dépendances système :**
```bash
sudo apt update
sudo apt install curl wget jq git -y
```

### Installation du système de notification

**Option 1 - Installation automatique :**
```bash
su -c "cd /tmp && wget https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v3.0/install_telegram_notif.sh && chmod +x install_telegram_notif.sh && ./install_telegram_notif.sh"
```

**Option 2 - Installation manuelle :**
```bash
# Cloner le dépôt
cd /tmp
git clone https://github.com/Phips02/telegram_notif_v3.0.git
cd telegram_notif_v3.0

# Exécuter l'installation
chmod +x install_telegram_notif.sh
sudo ./install_telegram_notif.sh
```

## Structure des fichiers
```
/usr/local/bin/telegram/notif_connexion/
├── telegram.sh                  # Script principal (intégré avec Phips Logger)
└── telegram.functions.sh        # Fonctions communes (API et utilitaires)

/etc/telegram/
└── credentials.cfg              # Configuration Telegram unifiée

/usr/local/bin/logger.sh        # Logger Phips (dépendance)
/etc/pam.d/su                   # Configuration PAM pour les notifications su
/etc/bash.bashrc                # Configuration système pour l'exécution automatique
```

## Configuration Telegram

Le système utilise une configuration Telegram unifiée compatible avec Phips Logger V3.

**Fichier de configuration:** `/etc/telegram/credentials.cfg`

**Configuration manuelle:**
```bash
# Créer le répertoire
sudo mkdir -p /etc/telegram

# Créer le fichier de configuration
sudo nano /etc/telegram/credentials.cfg
```

**Contenu du fichier:**
```bash
# Identifiants Telegram
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"

# Export des variables
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
```

**Sécuriser les permissions:**
```bash
sudo chmod 600 /etc/telegram/credentials.cfg
```

## ⚡ Optimisations de performance

### 🚀 Éviter les lags de connexion

Le script s'exécute automatiquement **en arrière-plan** pour ne pas bloquer vos connexions.

**Options de performance disponibles :**

```bash
# Dans /etc/telegram/credentials.cfg
SKIP_PUBLIC_IP="true"          # Désactive la récupération IP publique
export SKIP_PUBLIC_IP
```

### 🔧 Configuration recommandée pour serveurs lents

```bash
# Configuration optimale pour éviter tout lag
TELEGRAM_BOT_TOKEN="YOUR_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
SKIP_PUBLIC_IP="true"           # Performance maximale
CURL_TIMEOUT=5                  # Timeout réduit

export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID SKIP_PUBLIC_IP CURL_TIMEOUT
```

## 📱 Exemple de notification

```
🔔 Connexion Console Proxmox
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 2025-07-08 12:00:30
👤 Utilisateur: phips
💻 Hôte: proxmox-server
📺 Terminal: /dev/pts/0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌐 IP Locale: 192.168.1.100
📍 IP Source: 192.168.1.50
🌍 IP Publique: 203.0.113.1
👥 Sessions actives: 2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 🔍 Types de connexion détectés

| Type | Description | IP Source |
|------|-------------|----------|
| 🔐 **SSH** | Connexions SSH standard | IP réelle du client |
| 🔐 **SSH (legacy)** | Anciennes versions SSH | IP réelle du client |
| 🖥️ **Console Proxmox** | Interface web Proxmox | IP depuis logs pveproxy |
| 📺 **Console Web** | Autres interfaces web | "Web Interface" |
| 💻 **Console Locale** | Accès direct serveur | "Local" |
| 📱 **Screen/Tmux** | Sessions persistantes | "Local" |
| 🔄 **su/sudo** | Changement utilisateur | "Local" |
| ⚙️ **Non-interactif** | Scripts, cron, etc. | "Système" |

## 🔒 Avantages sécurité

- ✅ **Surveillance complète** de tous les accès
- ✅ **Traçabilité précise** des connexions
- ✅ **Détection Proxmox** avec IP source réelle
- ✅ **Logs centralisés** avec Phips Logger
- ✅ **Notifications instantanées** sur Telegram
- ✅ **Informations détaillées** (terminal, sessions)

## 🧪 Test et validation

### Tester le système

**1. Tester la configuration :**
```bash
# Vérifier que le logger est installé
ls -la /usr/local/bin/logger.sh

# Vérifier la configuration Telegram
ls -la /etc/telegram/credentials.cfg
```

**2. Tester manuellement :**
```bash
# Exécuter le script de notification
sudo /usr/local/bin/telegram/notif_connexion/telegram.sh
```

**3. Tester une nouvelle connexion :**
```bash
# Ouvrir une nouvelle session SSH ou console
# Vous devriez recevoir une notification Telegram
```

### 🔧 Dépannage

**Problème : Pas de notification reçue**
```bash
# Vérifier les logs
sudo journalctl -f | grep telegram

# Vérifier la configuration
sudo cat /etc/telegram/credentials.cfg

# Tester la connectivité Telegram
curl -s "https://api.telegram.org/bot<YOUR_TOKEN>/getMe"
```

**Problème : Logger non trouvé**
```bash
# Réinstaller le logger
cd /tmp && git clone https://github.com/Phips02/Phips_logger_v3.git
cd Phips_logger_v3 && sudo ./install.sh
```

**Problème : Permissions**
```bash
# Corriger les permissions
sudo chmod 600 /etc/telegram/credentials.cfg
sudo chmod +x /usr/local/bin/telegram/notif_connexion/telegram.sh
```

## Mise à jour

Pour mettre à jour le système de notification, exécutez les commandes suivantes en tant que root :

1. Se connecter en root :
```bash
su -
```

2. Copier et exécuter la commande de mise à jour :
```bash
cd /tmp && wget -qO update_telegram_notif.sh --no-cache https://raw.githubusercontent.com/Phips02/Bash/main/Telegram/Telegram%20-%20telegram_notif_v2/update_telegram_notif.sh && chmod +x update_telegram_notif.sh && ./update_telegram_notif.sh
```

## Mise à jour manuelle
```bash
# Se connecter en root
su -

# Télécharger le script de mise à jour
cd /tmp
rm -rf Bash
git clone https://github.com/Phips02/Bash.git
cd Bash/Telegram/Telegram\ -\ telegram_notif_v2
cp telegram.sh /usr/local/bin/telegram/notif_connexion/
chmod +x /usr/local/bin/telegram/notif_connexion/telegram.sh
cd /tmp
rm -rf Bash
```

## Licence
Ce projet est sous licence GNU GPLv3 - voir le fichier [LICENSE](LICENSE) pour plus de détails.

Cette licence :
- Permet l'utilisation privée
- Permet la modification
- Oblige le partage des modifications sous la même licence
- Interdit l'utilisation commerciale fermée
- Oblige à partager le code source 

## Désinstallation

Pour désinstaller complètement le système de notification (en tant que root) :

```bash
# Se connecter en root
su -

# Supprimer la configuration dans bash.bashrc et PAM
sed -i '/Notification Telegram/,/^fi$/d' /etc/bash.bashrc
sed -i '/Notification Telegram/,/telegram.sh/d' /etc/pam.d/su

# Supprimer les fichiers et sauvegardes
rm -rf /etc/telegram/notif_connexion
rm -rf /usr/local/bin/telegram/notif_connexion

# Supprimer le groupe
groupdel telegramnotif
``` 