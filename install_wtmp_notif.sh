#!/bin/bash

###############################################################################
# Script d'installation Telegram WTMP Monitor V5.1
# Surveillance des connexions serveur via wtmp
###############################################################################

# Version du système
TELEGRAM_VERSION="5.1"
SCRIPT_NAME="install_wtmp_notif.sh"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de logging avec couleurs
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[${timestamp}] [INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} $message" ;;
        "ERROR") echo -e "${RED}[${timestamp}] [ERROR]${NC} $message" ;;
        *) echo "[$timestamp] [$level] $message" ;;
    esac
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log_message "INFO" "Vérification des prérequis..."
    
    # Vérification des droits root
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # Vérification de l'accès à wtmp
    if [ ! -r /var/log/wtmp ]; then
        log_message "ERROR" "Impossible de lire /var/log/wtmp"
        log_message "ERROR" "Vérifiez les permissions ou l'existence du fichier"
        exit 1
    fi
    
    # Vérification et installation automatique des dépendances système
    local missing_deps=()
    for dep in curl last; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_message "WARNING" "Dépendances manquantes: ${missing_deps[*]}"
        log_message "INFO" "Installation automatique des dépendances..."
        
        # Mise à jour des paquets
        log_message "INFO" "Mise à jour de la liste des paquets..."
        if ! apt update -qq; then
            log_message "ERROR" "Échec de la mise à jour des paquets"
            exit 1
        fi
        
        # Installation des dépendances
        log_message "INFO" "Installation de: ${missing_deps[*]}"
        if ! apt install -y -qq "${missing_deps[@]}"; then
            log_message "ERROR" "Échec de l'installation des dépendances"
            log_message "ERROR" "Installez-les manuellement avec: apt install -y ${missing_deps[*]}"
            exit 1
        fi
        
        log_message "SUCCESS" "Dépendances installées avec succès"
    else
        log_message "SUCCESS" "Toutes les dépendances sont présentes"
    fi
    
    # Vérification de systemd
    if ! command -v systemctl &> /dev/null; then
        log_message "WARNING" "systemd non détecté - installation manuelle du service nécessaire"
        SYSTEMD_AVAILABLE=false
    else
        SYSTEMD_AVAILABLE=true
        log_message "SUCCESS" "systemd détecté"
    fi
}

# Fonction pour demander les identifiants Telegram
get_telegram_credentials() {
    log_message "INFO" "Configuration des identifiants Telegram..."
    
    # Vérifier si la configuration existe déjà
    if [ -f "/etc/telegram/credentials.cfg" ]; then
        log_message "INFO" "Configuration Telegram existante détectée"
        echo -n "Voulez-vous conserver la configuration existante ? (O/n): "
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            log_message "INFO" "Reconfiguration des identifiants..."
        else
            log_message "SUCCESS" "Configuration existante conservée"
            # Charger les variables existantes
            source "/etc/telegram/credentials.cfg"
            if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
                log_message "ERROR" "Configuration existante corrompue - reconfiguration nécessaire"
            else
                # Afficher les identifiants masqués pour vérification
                local masked_token="${BOT_TOKEN:0:10}...${BOT_TOKEN: -10}"
                local masked_chat="${CHAT_ID:0:3}...${CHAT_ID: -3}"
                log_message "INFO" "Variables chargées - BOT_TOKEN: $masked_token, CHAT_ID: $masked_chat"
                return 0
            fi
        fi
    fi
    
    # Demander le token du bot
    while true; do
        echo -n "Entrez le token de votre bot Telegram: "
        read -r BOT_TOKEN
        if [[ -n "$BOT_TOKEN" && "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            break
        else
            log_message "ERROR" "Format de token invalide. Format attendu: 123456789:ABCdefGHIjklMNOpqrSTUvwxyz"
        fi
    done
    
    # Demander le chat ID
    while true; do
        echo -n "Entrez votre Chat ID Telegram: "
        read -r CHAT_ID
        if [[ -n "$CHAT_ID" && "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
            break
        else
            log_message "ERROR" "Format de Chat ID invalide. Doit être un nombre (ex: 123456789 ou -123456789)"
        fi
    done
    
    # Test de la configuration
    log_message "INFO" "Test de la configuration Telegram..."
    local test_response=$(curl -s --max-time 10 \
        "https://api.telegram.org/bot${BOT_TOKEN}/getChat?chat_id=${CHAT_ID}")
    
    if echo "$test_response" | grep -q '"ok":true'; then
        log_message "SUCCESS" "Configuration Telegram validée"
    else
        log_message "WARNING" "Impossible de valider la configuration Telegram"
        log_message "WARNING" "Vérifiez vos identifiants après l'installation"
    fi
}

# Fonction pour créer les répertoires
create_directories() {
    log_message "INFO" "Création des répertoires..."
    
    # Créer le répertoire de configuration avec permissions sécurisées
    mkdir -p /etc/telegram
    chown root:root /etc/telegram
    chmod 755 /etc/telegram
    
    # Répertoire d'installation
    mkdir -p /usr/local/bin/telegram_notif
    chmod 755 /usr/local/bin/telegram_notif
    
    # Répertoire de données
    mkdir -p /var/lib/telegram_wtmp_monitor
    chmod 755 /var/lib/telegram_wtmp_monitor
    
    # Répertoire de logs
    mkdir -p /var/log
    touch /var/log/telegram_wtmp_monitor.log
    chmod 644 /var/log/telegram_wtmp_monitor.log
    
    log_message "SUCCESS" "Répertoires créés"
}

# Fonction pour télécharger/copier les scripts
install_scripts() {
    log_message "INFO" "Installation des scripts..."
    
    # Vérifier si le script daemon existe dans le répertoire courant
    if [ -f "./telegram_wtmp_monitor.sh" ]; then
        log_message "INFO" "Copie du script daemon depuis le répertoire local"
        cp "./telegram_wtmp_monitor.sh" "/usr/local/bin/telegram_notif/"
        chmod +x "/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh"
    else
        log_message "INFO" "Téléchargement du script daemon depuis GitHub..."
        if ! curl -s -L "https://raw.githubusercontent.com/Phips02/telegram_notif/main/telegram_wtmp_monitor.sh" \
             -o "/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh"; then
            log_message "ERROR" "Échec du téléchargement du script daemon"
            exit 1
        fi
        chmod +x "/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh"
    fi
    
    # Créer un lien symbolique pour faciliter l'utilisation
    ln -sf "/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh" "/usr/local/bin/telegram-wtmp-monitor"
    
    log_message "SUCCESS" "Scripts installés"
}

# Fonction pour créer les fichiers de configuration
create_config_files() {
    log_message "INFO" "Création des fichiers de configuration..."
    
    # Fichier des identifiants Telegram
    cat > /etc/telegram/credentials.cfg << EOF
###############################################################################
# Identifiants Telegram partagés
# Fichier: /etc/telegram/credentials.cfg
###############################################################################

# Identifiants Telegram (OBLIGATOIRE)
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"

# Export des variables pour compatibilité
export BOT_TOKEN CHAT_ID
EOF
    
    # Sécuriser les permissions du fichier credentials
    chown root:root /etc/telegram/credentials.cfg
    chmod 600 /etc/telegram/credentials.cfg
    
    # Fichier de configuration spécifique
    cat > /etc/telegram/telegram_notif.cfg << EOF
###############################################################################
# Configuration Telegram WTMP Monitor
# Fichier: /etc/telegram/telegram_notif.cfg
###############################################################################

# Configuration pour le monitoring WTMP
CHECK_INTERVAL=5                    # Intervalle de vérification en secondes
MAX_ENTRIES=50                      # Nombre maximum d'entrées à vérifier
CURL_TIMEOUT=10                     # Timeout pour les requêtes HTTP
DATE_FORMAT="%Y-%m-%d %H:%M:%S"     # Format de date

# Options de performance
SKIP_PUBLIC_IP="true"               # Désactiver la récupération IP publique (recommandé)

# Export des variables
export CHECK_INTERVAL MAX_ENTRIES CURL_TIMEOUT DATE_FORMAT SKIP_PUBLIC_IP
EOF
    
    # Sécuriser les permissions du fichier de configuration
    chown root:root /etc/telegram/telegram_notif.cfg
    chmod 644 /etc/telegram/telegram_notif.cfg
    
    log_message "SUCCESS" "Fichiers de configuration créés avec permissions sécurisées"
}

# Fonction pour créer le service systemd
create_systemd_service() {
    if [ "$SYSTEMD_AVAILABLE" != true ]; then
        log_message "WARNING" "systemd non disponible - service non créé"
        return 0
    fi
    
    log_message "INFO" "Création du service systemd..."
    
    cat > /etc/systemd/system/telegram-wtmp-monitor.service << EOF
[Unit]
Description=Telegram WTMP Monitor - Surveillance des connexions
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh start
ExecStop=/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh stop
ExecReload=/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh restart
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Sécurité
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log /var/lib/telegram_wtmp_monitor /var/run /tmp

[Install]
WantedBy=multi-user.target
EOF
    
    # Recharger systemd et activer le service
    systemctl daemon-reload
    systemctl enable telegram-wtmp-monitor.service
    
    log_message "SUCCESS" "Service systemd créé et activé"
}

# Fonction pour installer le moniteur de privilèges
install_privilege_monitor() {
    log_message "INFO" "Installation du moniteur de privilèges..."
    
    # Vérifier si le script existe dans le répertoire courant
    if [ -f "./telegram_privilege_monitor.sh" ]; then
        log_message "INFO" "Copie du script moniteur de privilèges depuis le répertoire local"
        cp "./telegram_privilege_monitor.sh" "/usr/local/bin/telegram_notif/"
        chmod +x "/usr/local/bin/telegram_notif/telegram_privilege_monitor.sh"
    else
        log_message "INFO" "Téléchargement du script moniteur de privilèges depuis GitHub"
        if ! curl -fsSL "https://raw.githubusercontent.com/Phips02/telegram_notif/main/telegram_privilege_monitor.sh" \
             -o "/usr/local/bin/telegram_notif/telegram_privilege_monitor.sh"; then
            log_message "ERROR" "Échec du téléchargement du moniteur de privilèges"
            return 1
        fi
        chmod +x "/usr/local/bin/telegram_notif/telegram_privilege_monitor.sh"
    fi
    
    # Créer un lien symbolique pour faciliter l'utilisation
    ln -sf "/usr/local/bin/telegram_notif/telegram_privilege_monitor.sh" "/usr/local/bin/telegram-privilege-monitor"
    
    log_message "SUCCESS" "Moniteur de privilèges installé"
}

# Fonction pour créer le service systemd du moniteur de privilèges
create_privilege_service() {
    if [ "$SYSTEMD_AVAILABLE" != true ]; then
        log_message "WARNING" "systemd non disponible - service privilèges non créé"
        return 0
    fi
    
    log_message "INFO" "Création du service systemd pour le moniteur de privilèges..."
    
    # Vérifier si le fichier service existe dans le répertoire courant
    if [ -f "./telegram-privilege-monitor.service" ]; then
        log_message "INFO" "Copie du service depuis le répertoire local"
        cp "./telegram-privilege-monitor.service" "/etc/systemd/system/"
    else
        log_message "INFO" "Téléchargement du fichier service depuis GitHub"
        if ! curl -fsSL "https://raw.githubusercontent.com/Phips02/telegram_notif/main/telegram-privilege-monitor.service" \
             -o "/etc/systemd/system/telegram-privilege-monitor.service"; then
            log_message "ERROR" "Échec du téléchargement du service privilèges"
            return 1
        fi
    fi
    
    # Recharger systemd et activer le service
    systemctl daemon-reload
    systemctl enable telegram-privilege-monitor.service
    
    log_message "SUCCESS" "Service moniteur de privilèges créé et activé"
}

# Fonction pour effectuer un test final
final_test() {
    log_message "INFO" "Test final du système..."
    
    # Vérifier que le script existe et est exécutable
    if [ -x "/usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh" ]; then
        log_message "SUCCESS" "Script installé et exécutable"
    else
        log_message "ERROR" "Problème avec l'installation du script"
        exit 1
    fi
    
    # Test de la configuration
    log_message "INFO" "Test de la configuration..."
    if /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh test; then
        log_message "SUCCESS" "Test de configuration réussi"
    else
        log_message "WARNING" "Test de configuration échoué - vérifiez les identifiants"
    fi
}

# Fonction pour démarrer les services
start_service() {
    log_message "INFO" "Démarrage des services..."
    
    if [ "$SYSTEMD_AVAILABLE" = true ]; then
        # Démarrer le service WTMP
        if systemctl start telegram-wtmp-monitor.service; then
            log_message "SUCCESS" "Service WTMP démarré via systemd"
        else
            log_message "ERROR" "Échec du démarrage du service WTMP systemd"
            log_message "INFO" "Démarrage manuel WTMP..."
            /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh start &
        fi
        
        # Démarrer le service de privilèges
        if systemctl start telegram-privilege-monitor.service; then
            log_message "SUCCESS" "Service privilèges démarré via systemd"
        else
            log_message "ERROR" "Échec du démarrage du service privilèges systemd"
            log_message "INFO" "Démarrage manuel privilèges..."
            /usr/local/bin/telegram_notif/telegram_privilege_monitor.sh start &
        fi
        
        # Afficher le statut des services
        sleep 2
        echo ""
        log_message "INFO" "Statut des services :"
        systemctl status telegram-wtmp-monitor.service --no-pager -l
        echo ""
        systemctl status telegram-privilege-monitor.service --no-pager -l
    else
        log_message "INFO" "Démarrage manuel des daemons..."
        /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh start &
        /usr/local/bin/telegram_notif/telegram_privilege_monitor.sh start &
        sleep 2
        /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh status
        /usr/local/bin/telegram_notif/telegram_privilege_monitor.sh status
    fi
}



# Fonction principale
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "           INSTALLATION TELEGRAM WTMP MONITOR V$TELEGRAM_VERSION"
    echo "                    🚀 SURVEILLANCE DES CONNEXIONS WTMP"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    log_message "INFO" "Démarrage de l'installation..."
    
    check_prerequisites
    get_telegram_credentials
    create_directories
    install_scripts
    create_config_files
    create_systemd_service
    install_privilege_monitor
    create_privilege_service
    final_test
    start_service
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message "SUCCESS" "Installation terminée avec succès !"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📁 Fichiers installés :"
    echo "   • Script WTMP : /usr/local/bin/telegram_notif/telegram_wtmp_monitor.sh"
    echo "   • Script privilèges : /usr/local/bin/telegram_notif/telegram_privilege_monitor.sh"
    echo "   • Liens rapides : /usr/local/bin/telegram-wtmp-monitor | telegram-privilege-monitor"
    echo "   • Configuration : /etc/telegram/"
    echo "   • Logs : /var/log/telegram_wtmp_monitor.log | telegram_privilege_monitor.log"
    echo ""
    echo "🔧 Commandes utiles :"
    echo "   • Statut WTMP : systemctl status telegram-wtmp-monitor"
    echo "   • Statut privilèges : systemctl status telegram-privilege-monitor"
    echo "   • Logs WTMP : journalctl -u telegram-wtmp-monitor -f"
    echo "   • Logs privilèges : journalctl -u telegram-privilege-monitor -f"
    echo "   • Manuel : telegram-wtmp-monitor {start|stop|restart|status|test}"
    echo "   • Manuel : telegram-privilege-monitor {start|stop|restart|status|test}"
    echo ""
    echo "🚀 Fonctionnalités :"
    echo "   ✅ Surveillance connexions via wtmp"
    echo "   ✅ Surveillance élévations de privilèges via journalctl"
    echo "   ✅ Détection SSH, console, su, sudo"
    echo "   ✅ Services systemd intégrés"
    echo "   ✅ Notifications Telegram en temps réel"
    echo "   ✅ Interface de gestion complète"
    echo ""
    echo "🔔 Le système surveille maintenant :"
    echo "   • Connexions SSH/console via wtmp"
    echo "   • Élévations su/sudo via journalctl"
    echo "   Testez en vous connectant ou en utilisant su/sudo."
    echo ""
}

# Gestion des arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0 [--help]"
        echo ""
        echo "Script d'installation Telegram WTMP Monitor V$TELEGRAM_VERSION"
        echo "Surveillance des connexions serveur via wtmp"
        echo ""
        echo "Options:"
        echo "  --help, -h    Afficher cette aide"
        echo ""
        exit 0
        ;;
esac

# Exécution du script principal
main "$@"
