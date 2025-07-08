#!/bin/bash

###############################################################################
# Script d'installation Telegram Notification de Connexion V3.0
# Compatible avec Phips Logger V3
# Architecture moderne avec configuration séparée
###############################################################################

# Version du système
TELEGRAM_VERSION="3.0"
SCRIPT_NAME="install_telegram_notif.sh"

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
    
    # Vérification et installation automatique des dépendances système
    local missing_deps=()
    for dep in curl wget; do
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
    
    # Vérification du Phips Logger
    if [ ! -f "/usr/local/bin/phips_logger" ] || [ ! -f "/usr/local/bin/logger.sh" ]; then
        log_message "WARNING" "Phips Logger V3 non détecté"
        log_message "INFO" "Installation automatique du Phips Logger..."
        
        # Sauvegarder le répertoire actuel
        local current_dir=$(pwd)
        
        # Aller dans /tmp pour l'installation
        cd /tmp
        
        # Nettoyer les anciens fichiers
        rm -rf Phips_logger_v3
        
        # Cloner et installer le Phips Logger V3
        if git clone https://github.com/Phips02/Phips_logger_v3.git; then
            cd Phips_logger_v3
            chmod +x install.sh
            if ./install.sh; then
                log_message "SUCCESS" "Phips Logger V3 installé avec succès"
            else
                log_message "WARNING" "Échec de l'installation du Phips Logger"
                log_message "INFO" "Le script fonctionnera avec un logging de base"
            fi
            cd /tmp
            rm -rf Phips_logger_v3
        else
            log_message "WARNING" "Échec du téléchargement du Phips Logger"
            log_message "INFO" "Le script fonctionnera avec un logging de base"
        fi
        
        # Retourner au répertoire original
        cd "$current_dir"
    else
        log_message "SUCCESS" "Phips Logger V3 détecté"
    fi
}

# Fonction pour demander les identifiants Telegram
get_telegram_credentials() {
    log_message "INFO" "Configuration des identifiants Telegram..."
    
    # Vérifier si les identifiants existent déjà
    if [ -f "/etc/telegram/credentials.cfg" ]; then
        log_message "INFO" "Fichier d'identifiants existant trouvé"
        read -p "Voulez-vous le remplacer ? (y/N): " replace_creds
        if [[ ! "$replace_creds" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Conservation des identifiants existants"
            # Charger les identifiants existants
            source "/etc/telegram/credentials.cfg"
            
            # Vérifier si les variables sont bien chargées
            if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
                log_message "SUCCESS" "Identifiants existants chargés avec succès"
                
                # Vérifier si le fichier a le bon format (avec export)
                if ! grep -q "export BOT_TOKEN CHAT_ID" "/etc/telegram/credentials.cfg"; then
                    log_message "INFO" "Mise à jour du format du fichier credentials.cfg"
                    # Marquer pour mise à jour du format
                    UPDATE_CREDENTIALS_FORMAT=true
                fi
                return 0
            else
                log_message "WARNING" "Fichier d'identifiants corrompu, reconfiguration nécessaire"
            fi
        fi
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    CONFIGURATION TELEGRAM BOT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Pour obtenir vos identifiants Telegram :"
    echo "1. Créez un bot via @BotFather sur Telegram"
    echo "2. Obtenez votre Chat ID via @userinfobot"
    echo ""
    
    # Demander le token du bot
    while true; do
        read -p "Token du bot Telegram: " BOT_TOKEN
        if [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            break
        else
            log_message "ERROR" "Format de token invalide. Format attendu: 123456789:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
        fi
    done
    
    # Demander le Chat ID
    while true; do
        read -p "Chat ID Telegram: " CHAT_ID
        if [[ "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
            break
        else
            log_message "ERROR" "Format de Chat ID invalide. Doit être un nombre (ex: 123456789 ou -123456789)"
        fi
    done
    
    # Test de la configuration
    log_message "INFO" "Test de la configuration Telegram..."
    local test_message="🔧 Test d'installation Telegram Notif V$TELEGRAM_VERSION"
    local response=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$test_message")
    
    if echo "$response" | grep -q '"ok":true'; then
        log_message "SUCCESS" "Configuration Telegram validée !"
    else
        log_message "ERROR" "Échec du test Telegram. Vérifiez vos identifiants."
        log_message "ERROR" "Réponse: $response"
        exit 1
    fi
}

# Fonction pour créer les répertoires
create_directories() {
    log_message "INFO" "Création des répertoires..."
    
    # Créer le répertoire Telegram
    mkdir -p /etc/telegram
    chmod 755 /etc/telegram
    chown root:root /etc/telegram
    
    # Créer le répertoire des scripts
    mkdir -p /usr/local/bin/telegram_notif
    chmod 755 /usr/local/bin/telegram_notif
    chown root:root /usr/local/bin/telegram_notif
    
    log_message "SUCCESS" "Répertoires créés"
}

# Fonction pour télécharger les scripts
download_scripts() {
    log_message "INFO" "Téléchargement des scripts..."
    
    local base_url="https://raw.githubusercontent.com/Phips02/telegram_notif/main"
    local script_dir="/usr/local/bin/telegram_notif"
    
    # Télécharger le script principal
    if ! wget -q "$base_url/telegram_connection_notif.sh" -O "$script_dir/telegram_connection_notif.sh"; then
        log_message "ERROR" "Échec du téléchargement du script principal"
        exit 1
    fi
    
    # Télécharger les fonctions
    if ! wget -q "$base_url/telegram.functions.sh" -O "$script_dir/telegram.functions.sh"; then
        log_message "ERROR" "Échec du téléchargement des fonctions"
        exit 1
    fi
    
    # Permissions des scripts
    chmod 755 "$script_dir/telegram_connection_notif.sh"
    chmod 644 "$script_dir/telegram.functions.sh"
    chown root:root "$script_dir/telegram_connection_notif.sh"
    chown root:root "$script_dir/telegram.functions.sh"
    
    log_message "SUCCESS" "Scripts téléchargés et configurés"
}

# Fonction pour créer les fichiers de configuration
create_config_files() {
    log_message "INFO" "Création des fichiers de configuration..."
    
    # 1. Fichier des identifiants Telegram (partagé)
    # Vérifier si le fichier existe déjà avec des identifiants valides
    if [ -f "/etc/telegram/credentials.cfg" ] && [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ] && [ "$UPDATE_CREDENTIALS_FORMAT" != "true" ]; then
        log_message "INFO" "Fichier credentials.cfg existant conservé"
    else
        if [ "$UPDATE_CREDENTIALS_FORMAT" = "true" ]; then
            log_message "INFO" "Mise à jour du format du fichier credentials.cfg"
        else
            log_message "INFO" "Création du fichier credentials.cfg"
        fi
        cat > "/etc/telegram/credentials.cfg" << EOF
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
    fi
    
    # 2. Fichier de configuration spécifique
    cat > "/etc/telegram/telegram_notif.cfg" << EOF
###############################################################################
# Configuration Telegram Notification de Connexion
# Fichier: /etc/telegram/telegram_notif.cfg
###############################################################################

# Configuration pour le logger Phips
TELEGRAM_NOTIFICATION_LEVEL="WARNING"  # Niveau minimum pour les notifications
TELEGRAM_MESSAGE_FORMAT="simple"       # Format: simple, detailed, json

# Configuration pour telegram_notif
CURL_TIMEOUT=10
DATE_FORMAT="%Y-%m-%d %H:%M:%S"

# Options de performance (pour éviter les lags de connexion)
SKIP_PUBLIC_IP="false"          # Mettre à "true" pour désactiver la récupération IP publique
                                # Recommandé si vous avez des lags lors des connexions

# Export des variables pour compatibilité
export TELEGRAM_NOTIFICATION_LEVEL TELEGRAM_MESSAGE_FORMAT
export CURL_TIMEOUT DATE_FORMAT SKIP_PUBLIC_IP
EOF
    
    # Permissions des fichiers de configuration
    chmod 600 /etc/telegram/credentials.cfg      # Sécurisé (identifiants)
    chmod 644 /etc/telegram/telegram_notif.cfg   # Lecture pour tous
    chown root:root /etc/telegram/credentials.cfg
    chown root:root /etc/telegram/telegram_notif.cfg
    
    log_message "SUCCESS" "Fichiers de configuration créés"
}

# Fonction pour configurer l'intégration système
configure_system_integration() {
    log_message "INFO" "Configuration de l'intégration système..."
    
    local script_path="/usr/local/bin/telegram_notif/telegram_connection_notif.sh"
    
    # Configuration bash.bashrc pour les connexions SSH
    if ! grep -q "telegram_connection_notif" /etc/bash.bashrc; then
        cat >> /etc/bash.bashrc << 'EOF'

# Notification Telegram pour connexions SSH
if [ -n "$PS1" ] && [ "$TERM" != "unknown" ] && [ -z "$PAM_TYPE" ]; then
    if [ -r "/etc/telegram/credentials.cfg" ] && [ -r "/etc/telegram/telegram_notif.cfg" ]; then
        nohup /usr/local/bin/telegram_notif/telegram_connection_notif.sh --background >/dev/null 2>&1 &
    fi
fi
EOF
        log_message "SUCCESS" "Configuration bash.bashrc ajoutée"
    else
        log_message "INFO" "Configuration bash.bashrc déjà présente"
    fi
    
    # Configuration PAM pour les commandes su/sudo
    local pam_file="/etc/pam.d/su"
    if [ -f "$pam_file" ]; then
        # Nettoyer les anciennes configurations
        sed -i '/telegram/d' "$pam_file"
        
        # Ajouter la nouvelle configuration
        echo "session optional pam_exec.so seteuid /bin/bash -c 'nohup /usr/local/bin/telegram_notif/telegram_connection_notif.sh --background >/dev/null 2>&1 &'" >> "$pam_file"
        log_message "SUCCESS" "Configuration PAM ajoutée"
    else
        log_message "WARNING" "Fichier PAM su non trouvé, configuration manuelle nécessaire"
    fi
}

# Fonction pour effectuer un test final
final_test() {
    log_message "INFO" "Test final du système..."
    
    # Test d'exécution du script
    if /usr/local/bin/telegram_notif/telegram_connection_notif.sh --test; then
        log_message "SUCCESS" "Test d'exécution réussi"
    else
        log_message "WARNING" "Test d'exécution échoué, vérifiez la configuration"
    fi
    
    # Envoi d'une notification de test
    local test_message="✅ Installation Telegram Notif V$TELEGRAM_VERSION terminée avec succès !

🔔 Types de connexion surveillés :
• SSH (standard et legacy)
• Console Proxmox
• Console locale
• Sessions Screen/Tmux
• Commandes su/sudo
• Exécutions non-interactives

📁 Configuration :
• Identifiants : /etc/telegram/credentials.cfg
• Paramètres : /etc/telegram/telegram_notif.cfg

🚀 Le système est maintenant opérationnel !"

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$test_message" > /dev/null
    
    log_message "SUCCESS" "Notification d'installation envoyée"
}

# Fonction principale
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "           INSTALLATION TELEGRAM NOTIFICATION DE CONNEXION V$TELEGRAM_VERSION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    check_prerequisites
    get_telegram_credentials
    create_directories
    download_scripts
    create_config_files
    configure_system_integration
    final_test
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message "SUCCESS" "Installation terminée avec succès !"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📁 Fichiers installés :"
    echo "   • Scripts : /usr/local/bin/telegram_notif/"
    echo "   • Configuration : /etc/telegram/"
    echo ""
    echo "🔧 Configuration :"
    echo "   • Identifiants : /etc/telegram/credentials.cfg"
    echo "   • Paramètres : /etc/telegram/telegram_notif.cfg"
    echo ""
    echo "🚀 Le système surveille maintenant toutes les connexions !"
    echo "   Testez en vous connectant via SSH ou console."
    echo ""
}

# Exécution du script principal
main "$@"
