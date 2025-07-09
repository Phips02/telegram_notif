# 🔔 Telegram WTMP Monitor
Version 5.1 - Surveillance complète des connexions et privilèges

## 🎯 À propos

Système de surveillance complet pour recevoir des notifications Telegram lors de :

### 🔌 **Connexions (via wtmp)**
- 🔑 **Connexions SSH** (toutes versions)
- 🖥️ **Console locale** (tty, pts)
- 📺 **Interface graphique** (X11, sessions GUI)
- 💻 **Sessions utilisateur** (screen, tmux détectées automatiquement)

### 🔐 **Élévations de privilèges (via journalctl)**
- 🔐 **Commandes su** (changement d'utilisateur)
- ⚡ **Commandes sudo** (exécution privilégiée)
- 🔑 **Sessions PAM** (ouverture/fermeture)

## 🚀 Fonctionnalités V5.1

- ✅ **Double surveillance** : wtmp + journalctl
- ✅ **Daemons robustes** avec gestion PID et logs
- ✅ **Services systemd** intégrés pour démarrage automatique
- ✅ **Détection fiable** sans faux positifs
- ✅ **Notifications temps réel** avec informations complètes
- ✅ **Interface de gestion** complète (start/stop/status/test)
- ✅ **Configuration flexible** et sécurisée
- ✅ **Anti-doublons** avec système de cache intelligent

## 📁 Fichiers du projet

| Fichier | Description |
|---------|-------------|
| `install_wtmp_notif.sh` | Script d'installation automatique |
| `telegram_wtmp_monitor.sh` | Daemon surveillance connexions (wtmp) |
| `telegram_privilege_monitor.sh` | Daemon surveillance privilèges (journalctl) |
| `telegram-wtmp-monitor.service` | Service systemd pour connexions |
| `telegram-privilege-monitor.service` | Service systemd pour privilèges |
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
├── telegram_wtmp_monitor.sh         # Daemon surveillance connexions
└── telegram_privilege_monitor.sh    # Daemon surveillance privilèges

/usr/local/bin/
├── telegram-wtmp-monitor            # Lien symbolique connexions
└── telegram-privilege-monitor       # Lien symbolique privilèges

/etc/telegram/
├── credentials.cfg                  # Identifiants Telegram (partagés)
└── telegram_notif.cfg              # Configuration du monitoring

/etc/systemd/system/
├── telegram-wtmp-monitor.service    # Service systemd connexions
└── telegram-privilege-monitor.service # Service systemd privilèges

# Logs et données
/var/log/telegram_wtmp_monitor.log       # Logs connexions
/var/log/telegram_privilege_monitor.log  # Logs privilèges
/var/lib/telegram_wtmp_monitor/          # Données daemon connexions
/var/lib/telegram_privilege_monitor/     # Données daemon privilèges
/var/run/telegram_wtmp_monitor.pid       # PID connexions
/var/run/telegram_privilege_monitor.pid  # PID privilèges
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

## 🔧 Gestion des services

### Commandes systemd
```bash
# === SERVICE CONNEXIONS ===
# Démarrer le service connexions
sudo systemctl start telegram-wtmp-monitor

# Arrêter le service connexions
sudo systemctl stop telegram-wtmp-monitor

# Voir le statut connexions
sudo systemctl status telegram-wtmp-monitor

# === SERVICE PRIVILÈGES ===
# Démarrer le service privilèges
sudo systemctl start telegram-privilege-monitor

# Arrêter le service privilèges
sudo systemctl stop telegram-privilege-monitor

# Voir le statut privilèges
sudo systemctl status telegram-privilege-monitor

# === GESTION GLOBALE ===
# Démarrer les deux services
sudo systemctl start telegram-wtmp-monitor telegram-privilege-monitor

# Arrêter les deux services
sudo systemctl stop telegram-wtmp-monitor telegram-privilege-monitor

# Redémarrer les deux services
sudo systemctl restart telegram-wtmp-monitor telegram-privilege-monitor
```

### Commandes manuelles
```bash
# === CONNEXIONS ===
# Utiliser le lien symbolique
telegram-wtmp-monitor {start|stop|restart|status|test|debug}

# Ou directement
/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh {start|stop|restart|status|test|debug}

# === PRIVILÈGES ===
# Utiliser le lien symbolique
telegram-privilege-monitor {start|stop|restart|status|test|debug}

# Ou directement
/usr/local/bin/telegram_notif/telegram_privilege_monitor.sh {start|stop|restart|status|test|debug}
```

### Logs et monitoring
```bash
# === LOGS CONNEXIONS ===
# Voir les logs systemd connexions
sudo journalctl -u telegram-wtmp-monitor -f

# Voir les logs daemon connexions
sudo tail -f /var/log/telegram_wtmp_monitor.log

# === LOGS PRIVILÈGES ===
# Voir les logs systemd privilèges
sudo journalctl -u telegram-privilege-monitor -f

# Voir les logs daemon privilèges
sudo tail -f /var/log/telegram_privilege_monitor.log

# === LOGS COMBINÉS ===
# Voir tous les logs en temps réel
sudo journalctl -u telegram-wtmp-monitor -u telegram-privilege-monitor -f

# Vérifier le processus
ps aux | grep telegram_wtmp_monitor
```

## 📱 Exemples de notifications

### 🔑 Notification de connexion SSH
```
🔑 *Nouvelle connexion SSH*

👤 **Utilisateur:** `phips`
💻 **Terminal:** `pts/0`
🌐 **IP Source:** `192.168.1.50`
🖥️ **Serveur:** `server-01`
⏰ **Heure:** `2025-07-09 11:42:01`

───────────────────────────
📈 **Sessions actives:**
• SSH (pts/0) depuis 192.168.1.50 à 11:42:01
• SSH (pts/1) depuis 192.168.1.51 à 10:30:15
```

### 🔐 Notification d'élévation de privilèges
```
🔐 *Élévation su détectée*

👤 **Utilisateur source:** `phips`
🎯 **Utilisateur cible:** `root`
💻 **Terminal:** `pts/1`
🌐 **Source IP:** `192.168.1.50`
🖥️ **Serveur:** `server-01`
⏰ **Heure:** `2025-07-09 11:42:01`

───────────────────────────
📈 **Détails système:**
• Événement: su
• Timestamp journal: jui 09 11:42:01
```

### ⚡ Notification de commande sudo
```
⚡ *Commande sudo détectée*

👤 **Utilisateur source:** `phips`
🎯 **Utilisateur cible:** `root`
💻 **Terminal:** `pts/1`
🌐 **Source IP:** `192.168.1.50`
🖥️ **Serveur:** `server-01`
⏰ **Heure:** `2025-07-09 11:45:30`

───────────────────────────
📈 **Détails système:**
• Événement: sudo
• Timestamp journal: jui 09 11:45:30
```

## 🔍 Types d'événements détectés

### 🔌 Connexions (via wtmp)
| Type | Icône | Description | Détection |
|------|------|-------------|----------|
| **SSH** | 🔑 | Connexions SSH (toutes versions) | Via wtmp - pts/* avec IP |
| **Console Proxmox** | 📺 | Console locale (tty) | Via wtmp - tty* |
| **Élévation su** | 🔐 | Su via terminal SSH | Via wtmp - pts/* sans IP |
| **GUI/X11** | 💻 | Sessions graphiques | Via wtmp - :* |
| **Login direct** | 🖥️ | Connexions console | Via wtmp - console |

### 🔐 Élévations de privilèges (via journalctl)
| Type | Icône | Description | Détection |
|------|------|-------------|----------|
| **Commande su** | 🔐 | Changement d'utilisateur | `su[PID]: (to user) source on pts/X` |
| **Commande sudo** | ⚡ | Exécution privilégiée | `sudo[PID]: user : TTY=pts/X ; USER=root` |
| **Session PAM** | 🔑 | Ouverture session su | `pam_unix(su-l:session): session opened` |

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
