# 🔔 Telegram WTMP Monitor
Version 5.0 - Surveillance des connexions serveur

## 🎯 À propos

Système de surveillance des connexions serveur basé sur **wtmp** pour recevoir des notifications Telegram lors de **toutes les connexions** :

- 🔐 **Connexions SSH** (toutes versions)
- 🖥️ **Console locale** (tty, pts)
- 📺 **Interface graphique** (X11, sessions GUI)
- 💻 **Connexions système** (su, sudo, login)
- 📱 **Sessions utilisateur** (screen, tmux détectées automatiquement)

## 🚀 Fonctionnalités V5.0

- ✅ **Surveillance unifiée** via fichier wtmp système
- ✅ **Daemon robuste** avec gestion PID et logs
- ✅ **Service systemd** intégré pour démarrage automatique
- ✅ **Détection fiable** sans faux positifs
- ✅ **Notifications temps réel** avec informations complètes
- ✅ **Interface de gestion** complète (start/stop/status/test)
- ✅ **Configuration flexible** et sécurisée

## 📁 Fichiers du projet

| Fichier | Description |
|---------|-------------|
| `install_wtmp_notif.sh` | Script d'installation automatique |
| `telegram_wtmp_monitor.sh` | Daemon principal de surveillance |
| `telegram-wtmp-monitor.service` | Service systemd |
| `credentials_example.cfg` | Exemple configuration identifiants Telegram |
| `telegram_notif_example.cfg` | Exemple configuration système |
| `README.md` | Documentation complète |

## 🚀 Installation

### Prérequis

**Installation automatique !** 🎉

Le script d'installation se charge automatiquement de :
- ✅ Vérifier et installer les dépendances (curl, last)
- ✅ Configurer le service systemd
- ✅ Créer tous les fichiers et permissions
- ✅ Tester la configuration Telegram

**Exigence :** Exécuter en tant que **root** (accès à /var/log/wtmp requis)

### Installation du système

**Option 1 - Installation automatique :**
```bash
su -c "cd /tmp && wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_wtmp_notif.sh && chmod +x install_wtmp_notif.sh && ./install_wtmp_notif.sh"
```

**Option 2 - Installation manuelle :**
```bash
# Cloner le dépôt
cd /tmp
git clone https://github.com/Phips02/telegram_notif.git
cd telegram_notif

# Exécuter l'installation
chmod +x install_wtmp_notif.sh
sudo ./install_wtmp_notif.sh
```

## Structure des fichiers
```
/usr/local/bin/telegram_notif/
└── telegram_wtmp_monitor.sh     # Daemon principal de surveillance

/usr/local/bin/
└── telegram-wtmp-monitor        # Lien symbolique pour accès rapide

/etc/telegram/
├── credentials.cfg              # Identifiants Telegram
└── telegram_notif.cfg          # Configuration du monitoring

/etc/systemd/system/
└── telegram-wtmp-monitor.service # Service systemd

/var/log/telegram_wtmp_monitor.log      # Fichier de logs
/var/lib/telegram_wtmp_monitor/         # Données du daemon
/var/run/telegram_wtmp_monitor.pid      # Fichier PID
```

## Configuration Telegram

Configuration simple et sécurisée pour les notifications Telegram.

**Configuration automatique lors de l'installation :**
Le script d'installation vous demandera vos identifiants Telegram, les validera et créera automatiquement les fichiers de configuration.

**Configuration manuelle (si nécessaire) :**

**1. Identifiants Telegram :** `/etc/telegram/credentials.cfg`
```bash
# Identifiants Telegram
BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
CHAT_ID="YOUR_CHAT_ID_HERE"

# Export des variables
export BOT_TOKEN CHAT_ID
```

**2. Configuration monitoring :** `/etc/telegram/telegram_notif.cfg`
```bash
# Configuration pour le monitoring WTMP
CHECK_INTERVAL=5                    # Intervalle de vérification en secondes
MAX_ENTRIES=50                      # Nombre maximum d'entrées à vérifier
CURL_TIMEOUT=10                     # Timeout pour les requêtes HTTP
DATE_FORMAT="%Y-%m-%d %H:%M:%S"     # Format de date

# Options de performance
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

## 🔧 Gestion du service

### Commandes systemd
```bash
# Démarrer le service
sudo systemctl start telegram-wtmp-monitor

# Arrêter le service
sudo systemctl stop telegram-wtmp-monitor

# Redémarrer le service
sudo systemctl restart telegram-wtmp-monitor

# Voir le statut
sudo systemctl status telegram-wtmp-monitor

# Activer au démarrage (déjà fait par l'installation)
sudo systemctl enable telegram-wtmp-monitor
```

### Commandes manuelles
```bash
# Utiliser le lien symbolique
telegram-wtmp-monitor {start|stop|restart|status|test}

# Ou directement
/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh {start|stop|restart|status|test}
```

### Logs et monitoring
```bash
# Voir les logs en temps réel
sudo journalctl -u telegram-wtmp-monitor -f

# Voir les logs du daemon
sudo tail -f /var/log/telegram_wtmp_monitor.log

# Vérifier le processus
ps aux | grep telegram_wtmp_monitor
```

## 📱 Exemple de notification

```
🔔 Nouvelle connexion SSH

📅 2025-07-08 18:05:30
───────────────────────────────
Connexion sur la machine :
👤 Utilisateur: phips
💻 Hôte: server-01
🏠 IP Locale: 192.168.1.100
───────────────────────────────
Connexion depuis :
📡 IP Source: 192.168.1.50
🌍 IP Publique: 203.0.113.1
───────────────────────────────
📺 Terminal: pts/0
👥 Sessions actives: 2
```

## 🔍 Types de connexion détectés

| Type | Description | Détection |
|------|-------------|----------|
| 🔐 **SSH** | Connexions SSH (toutes versions) | Via wtmp - pts/* |
| 🖥️ **Console** | Console locale (tty) | Via wtmp - tty* |
| 📺 **GUI** | Sessions graphiques X11 | Via wtmp - :* |
| 💻 **Login** | Connexions directes | Via wtmp - console |
| 🔄 **su/sudo** | Changements d'utilisateur | Via wtmp automatique |
| 📱 **Sessions** | Screen/Tmux/autres | Détectées dans wtmp |

## 🚀 Avantages de cette approche

- ✅ **Source unique** : wtmp contient toutes les connexions système
- ✅ **Fiabilité** : Pas de faux positifs ou de connexions manquées
- ✅ **Performance** : Daemon léger avec surveillance efficace
- ✅ **Simplicité** : Aucune configuration complexe requise
- ✅ **Compatibilité** : Fonctionne sur tous les systèmes Linux
- ✅ **Maintenance** : Architecture simple et robuste

## 🧪 Test et validation

### Tester le système

**1. Test de configuration :**
```bash
# Tester la notification Telegram
sudo telegram-wtmp-monitor test

# Vérifier la configuration
ls -la /etc/telegram/credentials.cfg
ls -la /etc/telegram/telegram_notif.cfg
```

**2. Vérifier le service :**
```bash
# Statut du service
sudo systemctl status telegram-wtmp-monitor

# Vérifier la version
telegram-wtmp-monitor --version
```

**3. Tester une nouvelle connexion :**
```bash
# Ouvrir une nouvelle session SSH
ssh user@server

# Ou se connecter en console
# Vous devriez recevoir une notification Telegram
```

### 🔧 Dépannage

**Problème : Pas de notification reçue**
```bash
# Vérifier les logs du service
sudo journalctl -u telegram-wtmp-monitor -f

# Vérifier les logs du daemon
sudo tail -f /var/log/telegram_wtmp_monitor.log

# Tester la connectivité Telegram
curl -s "https://api.telegram.org/bot<YOUR_TOKEN>/getMe"
```

**Problème : Service non démarré**
```bash
# Redémarrer le service
sudo systemctl restart telegram-wtmp-monitor

# Vérifier les erreurs
sudo systemctl status telegram-wtmp-monitor

# Vérifier les permissions wtmp
ls -la /var/log/wtmp
```

**Problème : Permissions**
```bash
# Corriger les permissions
sudo chmod 600 /etc/telegram/credentials.cfg
sudo chmod 644 /etc/telegram/telegram_notif.cfg
sudo chmod +x /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh
```

## 🔄 Mise à jour

Pour mettre à jour le système, réexécutez simplement le script d'installation :

```bash
# Télécharger et exécuter la dernière version
cd /tmp
wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_wtmp_notif.sh
chmod +x install_wtmp_notif.sh
sudo ./install_wtmp_notif.sh
```

Le script conservera automatiquement votre configuration existante.

## ⚙️ Compatibilité

- **Systèmes supportés :** Debian/Ubuntu (toutes versions récentes)
- **Architecture :** x86_64 (AMD64)
- **Prérequis :** curl, last (installés automatiquement)
- **Permissions :** Accès root requis pour /var/log/wtmp

## 📜 Licence

Ce projet est sous licence GNU GPLv3.

## 🗑️ Désinstallation

Pour désinstaller complètement le système :

```bash
# Arrêter et désactiver le service
sudo systemctl stop telegram-wtmp-monitor
sudo systemctl disable telegram-wtmp-monitor
sudo rm /etc/systemd/system/telegram-wtmp-monitor.service
sudo systemctl daemon-reload

# Supprimer les fichiers
sudo rm -rf /usr/local/bin/telegram_notif/
sudo rm -f /usr/local/bin/telegram-wtmp-monitor
sudo rm -rf /etc/telegram/
sudo rm -f /var/log/telegram_wtmp_monitor.log
sudo rm -rf /var/lib/telegram_wtmp_monitor/

echo "Désinstallation terminée !"
```
