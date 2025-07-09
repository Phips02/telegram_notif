# 🔔 Telegram Notification System
Version 5.3 - Surveillance complète des connexions et privilèges

## 🎯 À propos

Système de surveillance complet pour recevoir des notifications Telegram lors de :

### 🔌 **Connexions (via wtmp)**
- 🔑 **Connexions SSH** (toutes versions)
- 🖥️ **Console locale** (tty, pts)
- 📺 **Interface graphique** (X11, sessions GUI)
- 💻 **Sessions utilisateur** (screen, tmux détectées automatiquement)

### 🔐 **Élévations de privilèges (2 systèmes)**

#### **Système complet (journalctl)**
- 🔐 **Commandes su** (changement d'utilisateur)
- ⚡ **Commandes sudo** (exécution privilégiée)
- 🔑 **Sessions PAM** (ouverture/fermeture)

#### **Système simplifié (su uniquement)**
- 🔐 **Détection su ultra-rapide** via journalctl
- ⚡ **Timer systemd** (30 secondes)
- 💾 **Cache intelligent** anti-doublons

## 🚀 Fonctionnalités V5.3

### 🔧 **Système complet**
- ✅ **Double surveillance** : wtmp + journalctl
- ✅ **Daemons robustes** avec gestion PID et logs
- ✅ **Services systemd** intégrés pour démarrage automatique
- ✅ **Détection fiable** sans faux positifs
- ✅ **Interface de gestion** complète (start/stop/status/test)

### ⚡ **Système simplifié (telegram_su_simple.sh V1.1)**
- ✅ **Ultra-rapide** : Détection su/sudo en 45 secondes
- ✅ **Code minimal** : 125 lignes optimisées Debian/Ubuntu
- ✅ **Timer systemd** : Exécution automatique toutes les 30s
- ✅ **Cache intelligent** : Anti-doublons basé sur PID + timestamp
- ✅ **Regex étendue** : Support su ET sudo avec variantes PAM
- ✅ **Messages enrichis** : Icônes distinctives (🔐 su, ⚡ sudo)

### 🔧 **Commun aux deux systèmes**
- ✅ **Notifications temps réel** avec informations complètes
- ✅ **Configuration flexible** et sécurisée
- ✅ **Logs détaillés** pour diagnostic
- ✅ **Installation automatique** avec tests intégrés

## 📁 Fichiers du projet

### 🔧 **Système complet (wtmp + journalctl)**
| Fichier | Description |
|---------|-------------|
| `install_wtmp_notif.sh` | Script d'installation automatique |
| `telegram_wtmp_monitor.sh` | Daemon surveillance connexions (wtmp) |
| `telegram_privilege_monitor.sh` | Daemon surveillance privilèges (journalctl) |
| `telegram-wtmp-monitor.service` | Service systemd pour connexions |
| `telegram-privilege-monitor.service` | Service systemd pour privilèges |

### ⚡ **Système simplifié (su/sudo optimisé Debian/Ubuntu)**
| Fichier | Description |
|---------|-------------|
| `telegram_su_simple.sh` | Script détection su/sudo V1.1 (125 lignes) |
| `install_su_simple.sh` | Installation avec timer systemd |

### 🔧 **Configuration commune**
| Fichier | Description |
|---------|-------------|
| `credentials_example.cfg` | Exemple configuration identifiants Telegram |
| `telegram_notif_example.cfg` | Exemple configuration système |
| `README.md` | Documentation complète |

## 🚀 Installation

### Prérequis

**Exigences système :**
- 🐧 **OS** : Debian/Ubuntu
- 🔑 **Permissions** : Accès root requis (pour /var/log/wtmp et systemd)
- 🌐 **Réseau** : Connexion internet pour téléchargement et API Telegram
- 🤖 **Bot Telegram** : Token bot + Chat ID (voir [guide création bot](https://core.telegram.org/bots#6-botfather))

**Dépendances (installées automatiquement) :**
- `curl` - Envoi des notifications
- `last` - Lecture des logs wtmp
- `journalctl` - Lecture des logs système
- `systemd` - Gestion des services

---

### 🎯 Installation automatique complète (RECOMMANDÉE)

**Une seule commande installe tout le système complet !** 🎉

```bash
su -c "cd /tmp && wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_wtmp_notif.sh && chmod +x install_wtmp_notif.sh && ./install_wtmp_notif.sh"
```

**Ce que fait cette commande :**
- ✅ **Télécharge** automatiquement tous les fichiers nécessaires
- ✅ **Configure** les identifiants Telegram (BOT_TOKEN + CHAT_ID)
- ✅ **Installe** les deux daemons (connexions + privilèges)
- ✅ **Démarre** les services systemd automatiquement
- ✅ **Teste** la configuration avec notification de test
- ✅ **Vérifie** toutes les dépendances (curl, last, journalctl)

**Résultat :** Système complet fonctionnel en 2 minutes !

---

### 🔧 Installation manuelle du système complet

**Si vous préférez installer étape par étape :**

```bash
# 1. Télécharger les fichiers
cd /tmp
wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_wtmp_notif.sh
chmod +x install_wtmp_notif.sh

# 2. Exécuter l'installation
sudo ./install_wtmp_notif.sh

# 3. Vérifier l'installation
sudo systemctl status telegram-wtmp-monitor telegram-privilege-monitor
```

**Ou via git :**
```bash
# Cloner le dépôt complet
cd /tmp
git clone https://github.com/Phips02/telegram_notif.git
cd telegram_notif

# Exécuter l'installation
chmod +x install_wtmp_notif.sh
sudo ./install_wtmp_notif.sh
```

---

### ⚡ Installation du système simplifié (su/sudo optimisé)

**Alternative légère pour détection su/sudo uniquement :**

**Installation automatique :**
```bash
su -c "cd /tmp && wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_su_simple.sh && chmod +x install_su_simple.sh && ./install_su_simple.sh"
```

**Installation manuelle :**
```bash
# 1. Télécharger les fichiers
cd /tmp
wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_su_simple.sh
chmod +x install_su_simple.sh

# 2. Exécuter l'installation
sudo ./install_su_simple.sh

# 3. Vérifier le timer
sudo systemctl status telegram-su-simple.timer
```

**Ou via git :**
```bash
# Cloner le dépôt complet
cd /tmp
git clone https://github.com/Phips02/telegram_notif.git
cd telegram_notif

# Installer le système simplifié
chmod +x install_su_simple.sh
sudo ./install_su_simple.sh
```

**Pourquoi choisir le système simplifié V1.1 ?**
- 🚀 **Ultra-rapide** : Détection en 45 secondes (fenêtre étendue)
- 🔧 **Robuste** : Regex étendue pour su ET sudo
- 💾 **Léger** : 125 lignes de code optimisées
- ⚙️ **Autonome** : Timer systemd intégré (30s)
- 🎯 **Optimisé** : Spécialement conçu pour Debian/Ubuntu
- 📱 **Messages riches** : Informations complètes avec émojis distinctifs

## Structure des fichiers

### 🔧 **Système complet**
```
/usr/local/bin/telegram_notif/
├── telegram_wtmp_monitor.sh         # Daemon surveillance connexions
└── telegram_privilege_monitor.sh    # Daemon surveillance privilèges

/usr/local/bin/
├── telegram-wtmp-monitor            # Lien symbolique connexions
└── telegram-privilege-monitor       # Lien symbolique privilèges

/etc/systemd/system/
├── telegram-wtmp-monitor.service    # Service systemd connexions
└── telegram-privilege-monitor.service # Service systemd privilèges

# Logs et données
/var/log/telegram_wtmp_monitor.log       # Logs connexions
/var/log/telegram_privilege_monitor.log  # Logs privilèges
/var/lib/telegram_wtmp_monitor/          # Données daemon connexions
/var/lib/telegram_privilege_monitor/     # Données daemon privilèges
```

### ⚡ **Système simplifié**
```
/usr/local/bin/telegram_notif/
└── telegram_su_simple.sh           # Script détection su ultra-simple

/usr/local/bin/
└── telegram-su-simple               # Lien symbolique

/etc/systemd/system/
├── telegram-su-simple.service       # Service systemd (oneshot)
└── telegram-su-simple.timer         # Timer systemd (30s)

# Logs et données
/var/log/telegram_su_simple.log          # Logs détection su
/var/lib/telegram_su_simple/cache        # Cache anti-doublons
```

### 🔧 **Configuration commune**
```
/etc/telegram/
├── credentials.cfg                  # Identifiants Telegram (partagés)
└── telegram_notif.cfg              # Configuration du monitoring
```

## 🔧 Configuration Telegram

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

## ⚡ Gestion du système simplifié (su)

### Commandes systemd (timer)
```bash
# Démarrer le timer
sudo systemctl start telegram-su-simple.timer

# Arrêter le timer
sudo systemctl stop telegram-su-simple.timer

# Voir le statut du timer
sudo systemctl status telegram-su-simple.timer

# Voir les exécutions récentes
sudo systemctl list-timers telegram-su-simple.timer
```

## 🔧 Gestion du système simplifié V1.1

### Commandes systemd
```bash
# === TIMER SYSTEMD ===
# Démarrer le timer
sudo systemctl start telegram-su-simple.timer

# Arrêter le timer
sudo systemctl stop telegram-su-simple.timer

# Redémarrer le timer
sudo systemctl restart telegram-su-simple.timer

# Statut du timer
sudo systemctl status telegram-su-simple.timer

# Activer au démarrage
sudo systemctl enable telegram-su-simple.timer

# Désactiver au démarrage
sudo systemctl disable telegram-su-simple.timer
```

### Commandes manuelles
```bash
# Exécution manuelle
telegram-su-simple

# Ou directement
/usr/local/bin/telegram_notif/telegram_su_simple.sh
```

### Logs et monitoring
```bash
# Voir les logs du timer
sudo journalctl -u telegram-su-simple.timer -f

# Voir les logs du service
sudo journalctl -u telegram-su-simple.service -f

# Voir les logs du script
sudo tail -f /var/log/telegram_su_simple.log

# Vérifier le cache
sudo cat /var/lib/telegram_su_simple/cache

# Vérifier les prochaines exécutions
sudo systemctl list-timers telegram-su-simple.timer
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

### 🚀 Notifications système simplifié V1.1

**Notification su :**
```
🔐 *Élévation su détectée*

👤 **Utilisateur source:** `phips` (UID: 1000)
🎯 **Utilisateur cible:** `root` (UID: 0)
⏰ **Heure:** Jul 9 11:45:30
🔢 **PID:** 12345
🖥️ **Serveur:** `server-01`

📋 **Commande:** su
📄 **Ligne complète:**
`Jul 9 11:45:30 server-01 su[12345]: pam_unix(su-l:session): session opened for user root(uid=0) by phips(uid=1000)`
```

**Notification sudo :**
```
⚡ *Commande sudo détectée*

👤 **Utilisateur source:** `phips` (UID: 1000)
🎯 **Utilisateur cible:** `root` (UID: 0)
⏰ **Heure:** Jul 9 11:45:30
🔢 **PID:** 12346
🖥️ **Serveur:** `server-01`

📋 **Commande:** sudo
📄 **Ligne complète:**
`Jul 9 11:45:30 server-01 sudo[12346]: pam_unix(sudo:session): session opened for user root(uid=0) by phips(uid=1000)`
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

**Système complet :**
| Type | Icône | Description | Détection |
|------|------|-------------|----------|
| **Commande su** | 🔐 | Changement d'utilisateur | `su[PID]: (to user) source on pts/X` |
| **Commande sudo** | ⚡ | Exécution privilégiée | `sudo[PID]: user : TTY=pts/X ; USER=root` |
| **Session PAM** | 🔑 | Ouverture session su | `pam_unix(su-l:session): session opened` |

**Système simplifié V1.1 (optimisé Debian/Ubuntu) :**
| Type | Icône | Description | Détection |
|------|------|-------------|----------|
| **Élévation su** | 🔐 | Changement utilisateur | `pam_unix(su-l:session): session opened for user X by Y` |
| **Commande sudo** | ⚡ | Exécution privilégiée | `pam_unix(sudo:session): session opened for user X by Y` |
| **Cache intelligent** | 💾 | Anti-doublons | Basé sur `PID_timestamp` unique |
| **Regex étendue** | 🎯 | Support variantes | `(su|sudo)(-l)?:(session|auth)` |

## 🚀 Avantages de cette approche

- ✅ **Source unique** : wtmp contient toutes les connexions système
- ✅ **Fiabilité** : Pas de faux positifs ou de connexions manquées
- ✅ **Performance** : Daemon léger avec surveillance efficace
- ✅ **Simplicité** : Aucune configuration complexe requise
- ✅ **Compatibilité** : Optimisé pour Debian/Ubuntu
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

### 🔧 **Système complet**
Pour mettre à jour le système complet, réexécutez simplement le script d'installation :

```bash
# Télécharger et exécuter la dernière version
cd /tmp
wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_wtmp_notif.sh
chmod +x install_wtmp_notif.sh
sudo ./install_wtmp_notif.sh
```

### ⚡ **Système simplifié V1.1**
Pour mettre à jour le système simplifié :

```bash
# Télécharger et exécuter la dernière version
cd /tmp
wget https://raw.githubusercontent.com/Phips02/telegram_notif/main/install_su_simple.sh
chmod +x install_su_simple.sh
sudo ./install_su_simple.sh
```

Les scripts conserveront automatiquement votre configuration existante.

## ⚙️ Compatibilité

### 🔧 **Système complet (WTMP + journalctl)**
- **Systèmes supportés :** Debian/Ubuntu
- **Architecture :** x86_64 (AMD64)
- **Prérequis :** curl, last (installés automatiquement)
- **Permissions :** Accès root requis pour /var/log/wtmp

### ⚡ **Système simplifié V1.1**
- **Systèmes supportés :** Debian/Ubuntu (optimisé spécifiquement)
- **Architecture :** x86_64 (AMD64)
- **Prérequis :** curl, journalctl (installés automatiquement)
- **Permissions :** Accès root requis pour journalctl
- **Locales :** Forcées LC_ALL=C et LANG=C pour compatibilité maximale

## 📜 Licence

Ce projet est sous licence GNU GPLv3.

## 🗑️ Désinstallation

### 🔧 **Système complet**
Pour désinstaller complètement le système complet :

```bash
# Arrêter et désactiver les services
sudo systemctl stop telegram-wtmp-monitor telegram-privilege-monitor
sudo systemctl disable telegram-wtmp-monitor telegram-privilege-monitor
sudo rm /etc/systemd/system/telegram-wtmp-monitor.service
sudo rm /etc/systemd/system/telegram-privilege-monitor.service
sudo systemctl daemon-reload

# Supprimer les fichiers
sudo rm -rf /usr/local/bin/telegram_notif/
sudo rm -f /usr/local/bin/telegram-wtmp-monitor
sudo rm -f /usr/local/bin/telegram-privilege-monitor
sudo rm -rf /etc/telegram/
sudo rm -f /var/log/telegram_wtmp_monitor.log
sudo rm -f /var/log/telegram_privilege_monitor.log
sudo rm -rf /var/lib/telegram_wtmp_monitor/

echo "Désinstallation système complet terminée !"
```

### ⚡ **Système simplifié V1.1**
Pour désinstaller complètement le système simplifié :

```bash
# Arrêter et désactiver le timer
sudo systemctl stop telegram-su-simple.timer
sudo systemctl disable telegram-su-simple.timer
sudo rm /etc/systemd/system/telegram-su-simple.timer
sudo rm /etc/systemd/system/telegram-su-simple.service
sudo systemctl daemon-reload

# Supprimer les fichiers
sudo rm -f /usr/local/bin/telegram_notif/telegram_su_simple.sh
sudo rm -f /usr/local/bin/telegram-su-simple
sudo rm -f /var/log/telegram_su_simple.log
sudo rm -rf /var/lib/telegram_su_simple/

# Conserver /etc/telegram/ si le système complet est installé
# Sinon, supprimer aussi :
# sudo rm -rf /etc/telegram/

echo "Désinstallation système simplifié terminée !"
```
