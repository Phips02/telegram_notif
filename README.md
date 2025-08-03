# 🔔 Telegram Notification System

Système de notification Telegram pour la surveillance des connexions et élévations de privilèges sur serveurs Linux.

## 📋 Fonctionnalités

- **Surveillance des connexions** : Notifications pour toutes les connexions SSH, console, etc.
- **Surveillance des privilèges** : Notifications pour les commandes `sudo` et `su`
- **Déduplication intelligente** : Évite les notifications en double
- **Configuration sécurisée** : Permissions strictes sur les fichiers de configuration
- **Installation automatisée** : Déploiement en une commande

## 🚀 Installation rapide

### Prérequis

- Serveur Debian/Ubuntu
- Accès root
- Connexion internet

### Déploiement automatique

```bash
curl -sSL https://raw.githubusercontent.com/Phips02/telegram_notif/main/deploy_telegram_notif.sh | bash
```

**Ou avec wget :**
```bash
wget -O- https://raw.githubusercontent.com/Phips02/telegram_notif/main/deploy_telegram_notif.sh | bash
```

Le script vous demandera interactivement vos credentials Telegram et configurera tout automatiquement.

## 🤖 Configuration Telegram

### 1. Créer un bot Telegram

1. Ouvrez Telegram et cherchez `@BotFather`
2. Envoyez `/newbot` 
3. Suivez les instructions pour créer votre bot
4. Récupérez le **BOT_TOKEN** fourni

### 2. Obtenir votre CHAT_ID

1. Envoyez un message à votre bot
2. Allez sur : `https://api.telegram.org/bot<VOTRE_BOT_TOKEN>/getUpdates`
3. Cherchez la valeur `"id"` dans la section `"chat"`
4. C'est votre **CHAT_ID**

## 🔧 Services installés

Après installation, deux services systemd seront actifs :

- `telegram-wtmp-monitor.service` : Surveillance des connexions
- `telegram-privilege-monitor.service` : Surveillance des privilèges

## 📋 Commandes utiles

```bash
# Vérifier le statut des services
systemctl status telegram-wtmp-monitor
systemctl status telegram-privilege-monitor

# Tester les notifications
telegram-wtmp-monitor test
telegram-privilege-monitor test

# Voir les logs
tail -f /var/log/telegram_wtmp_monitor.log
tail -f /var/log/telegram_privilege_monitor.log

# Redémarrer les services
systemctl restart telegram-wtmp-monitor
systemctl restart telegram-privilege-monitor
```

## 📁 Structure des fichiers

```
/usr/local/bin/telegram_notif/
├── telegram_wtmp_monitor.sh      # Script de surveillance des connexions
└── telegram_privilege_monitor.sh # Script de surveillance des privilèges

/etc/telegram/
├── credentials.cfg                # Configuration Telegram (BOT_TOKEN, CHAT_ID)
└── telegram_notif.cfg            # Configuration optionnelle

/etc/systemd/system/
├── telegram-wtmp-monitor.service
└── telegram-privilege-monitor.service
```

## 🔒 Sécurité

- Les fichiers de configuration sont protégés avec des permissions `600`
- Propriétaire : `root:root`
- Seuls les processus root peuvent accéder aux credentials

## 📱 Types de notifications

### Connexions surveillées
- Connexions SSH
- Connexions console/TTY
- Connexions X11/GUI

### Privilèges surveillés
- Commandes `sudo`
- Élévations `su`

## ⚙️ Configuration avancée

Le fichier `/etc/telegram/telegram_notif.cfg` permet de personnaliser :

```bash
# Intervalle de vérification (secondes)
CHECK_INTERVAL=5

# Taille du cache
MAX_CACHE_SIZE=1000

# Timeout des requêtes
CURL_TIMEOUT=10

# Désactiver la récupération d'IP publique
SKIP_PUBLIC_IP=true
```

## 🐛 Dépannage

### Les notifications ne fonctionnent pas

1. Vérifiez vos credentials :
   ```bash
   telegram-wtmp-monitor test
   ```

2. Vérifiez les logs :
   ```bash
   journalctl -u telegram-wtmp-monitor -f
   ```

3. Vérifiez la connectivité :
   ```bash
   curl -s "https://api.telegram.org/bot<VOTRE_TOKEN>/getMe"
   ```

### Services qui ne démarrent pas

```bash
# Vérifier les erreurs systemd
systemctl status telegram-wtmp-monitor
journalctl -u telegram-wtmp-monitor --no-pager
```

## 📄 Licence

Ce projet est sous licence libre. Utilisez et modifiez selon vos besoins.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Signaler des bugs
- Proposer des améliorations
- Soumettre des pull requests

## 📞 Support

Pour toute question ou problème, ouvrez une issue sur ce repository.