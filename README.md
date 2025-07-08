# 🔔 Système de surveillance des connexions serveur
Version 4.8 -  avec Phips Logger V3

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
- ✅ **Configuration séparée** (identifiants + paramètres)
- ✅ **Performance optimisée** avec exécution en arrière-plan
- ✅ **Installation automatisée** avec gestion des dépendances
- ✅ **Architecture moderne** avec fichiers de configuration séparés

## 📁 Fichiers du dépôt

| Fichier | Description |
|---------|-------------|
| `install_telegram_notif.sh` | Script d'installation automatique |
| `telegram_connection_notif.sh` | Script principal de notification |
| `telegram.functions.sh` | Fonctions communes pour l'API Telegram |
| `credentials_example.cfg` | Exemple de configuration des identifiants |
| `telegram_notif_example.cfg` | Exemple de configuration du système |
| `README.md` | Documentation complète |

## 🚀 Installation

### Prérequis

**1. Phips Logger V3 (installation automatique) :**
Le script d'installation se charge automatiquement de télécharger et installer le Phips Logger V3 depuis le dépôt officiel si nécessaire. Aucune action manuelle requise.

**Installation manuelle du Phips Logger (si nécessaire) :**
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
su -c "cd /tmp && wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_telegram_notif.sh && chmod +x install_telegram_notif.sh && ./install_telegram_notif.sh"
```

**Option 2 - Installation manuelle :**
```bash
# Cloner le dépôt
cd /tmp
git clone https://github.com/Phips02/telegram_notif.git
cd telegram_notif

# Exécuter l'installation
chmod +x install_telegram_notif.sh
sudo ./install_telegram_notif.sh
```

## Structure des fichiers
```
/usr/local/bin/telegram_notif/
├── telegram_connection_notif.sh # Script principal de notification
└── telegram.functions.sh        # Fonctions communes (API et utilitaires)

/etc/telegram/
├── credentials.cfg              # Identifiants Telegram partagés
└── telegram_notif.cfg          # Configuration spécifique du système

/usr/local/bin/
├── logger.sh                    # Logger Phips V3 (fichier principal)
└── phips_logger                 # Lien symbolique vers logger.sh

/etc/pam.d/su                   # Configuration PAM pour les notifications su
/etc/bash.bashrc                # Configuration système pour l'exécution automatique
```

## Configuration Telegram

Le système utilise une configuration Telegram unifiée compatible avec Phips Logger V3.

**Configuration automatique lors de l'installation :**
Le script d'installation vous demandera vos identifiants Telegram et créera automatiquement les fichiers de configuration.

**Configuration manuelle (si nécessaire) :**

**1. Identifiants Telegram :** `/etc/telegram/credentials.cfg`
```bash
# Identifiants Telegram partagés
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"

# Export des variables pour compatibilité
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
```

**2. Configuration spécifique :** `/etc/telegram/telegram_notif.cfg`
```bash
# Configuration pour le logger Phips
TELEGRAM_NOTIFICATION_LEVEL="WARNING"
TELEGRAM_MESSAGE_FORMAT="simple"

# Configuration pour telegram_notif
CURL_TIMEOUT=10
DATE_FORMAT="%Y-%m-%d %H:%M:%S"

# Options de performance (pour éviter les lags de connexion)
SKIP_PUBLIC_IP="false"  # Mettre à "true" pour désactiver la récupération IP publique

# Export des variables
export TELEGRAM_NOTIFICATION_LEVEL TELEGRAM_MESSAGE_FORMAT
export CURL_TIMEOUT DATE_FORMAT SKIP_PUBLIC_IP
```

**Sécuriser les permissions:**
```bash
sudo chmod 600 /etc/telegram/credentials.cfg
sudo chmod 644 /etc/telegram/telegram_notif.cfg
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
ls -la /usr/local/bin/phips_logger
ls -la /usr/local/bin/logger.sh

# Vérifier la configuration Telegram
ls -la /etc/telegram/credentials.cfg
ls -la /etc/telegram/telegram_notif.cfg
```

**2. Tester manuellement :**
```bash
# Exécuter le script de notification en mode test
sudo /usr/local/bin/telegram_notif/telegram_connection_notif.sh --test

# Vérifier la version
/usr/local/bin/telegram_notif/telegram_connection_notif.sh --version
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
# Vérifier la présence du logger
ls -la /usr/local/bin/phips_logger
ls -la /usr/local/bin/logger.sh

# Réinstaller le logger si nécessaire
cd /tmp
git clone https://github.com/Phips02/Phips_logger_v3.git
cd Phips_logger_v3
chmod +x install.sh
sudo ./install.sh
```

**Problème : Permissions**
```bash
# Corriger les permissions
sudo chmod 600 /etc/telegram/credentials.cfg
sudo chmod 644 /etc/telegram/telegram_notif.cfg
sudo chmod +x /usr/local/bin/telegram_notif/telegram_connection_notif.sh
sudo chmod +x /usr/local/bin/telegram_notif/telegram.functions.sh
```

## Mise à jour

Pour mettre à jour le système de notification, vous pouvez soit réexécuter le script d'installation, soit effectuer une mise à jour manuelle.

### Méthode 1 : Réinstallation complète (recommandée)
```bash
# Se connecter en root
su -

# Réexécuter l'installation (conserve la configuration existante)
cd /tmp
wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_telegram_notif.sh
chmod +x install_telegram_notif.sh
./install_telegram_notif.sh
```

### Méthode 2 : Mise à jour manuelle
```bash
# Se connecter en root
su -

# Télécharger les derniers scripts
cd /tmp
rm -rf telegram_notif
git clone https://github.com/Phips02/telegram_notif.git
cd telegram_notif

# Copier les nouveaux scripts
cp telegram_connection_notif.sh /usr/local/bin/telegram_notif/
cp telegram.functions.sh /usr/local/bin/telegram_notif/

# Appliquer les permissions
chmod +x /usr/local/bin/telegram_notif/telegram_connection_notif.sh
chmod +x /usr/local/bin/telegram_notif/telegram.functions.sh

# Nettoyer
cd /tmp
rm -rf telegram_notif

echo "Mise à jour terminée !"
```

## ⚠️ Compatibilité et notes importantes

- **Système supporté :** Debian/Ubuntu (testé sur Debian 11/12, Ubuntu 20.04/22.04)
- **Proxmox :** Compatible avec Proxmox VE 7.x et 8.x
- **Architecture :** x86_64 (AMD64)
- **Prérequis :** bash, curl, wget (installés automatiquement)
- **Droits :** Installation en tant que root obligatoire

**Migration depuis les anciennes versions :**
Si vous avez une ancienne version installée, le script d'installation détectera et migrera automatiquement votre configuration.

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
sed -i '/telegram_notif/d' /etc/bash.bashrc
sed -i '/telegram_connection_notif/d' /etc/pam.d/su

# Supprimer les fichiers et répertoires
rm -rf /etc/telegram/
rm -rf /usr/local/bin/telegram_notif/

# Optionnel : supprimer le logger Phips si non utilisé ailleurs
# rm -rf /usr/local/bin/phips_logger/

echo "Désinstallation terminée !"
``` 