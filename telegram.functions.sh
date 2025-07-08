#!/bin/bash

# Configuration de l'API Telegram
API="https://api.telegram.org/bot${BOT_TOKEN}"

# Fonction d'envoi de message Telegram
function telegram_text_send() {
    local TEXT="$1"
    if [[ -z "$CHAT_ID" || -z "$TEXT" ]]; then
        log_error "Chat ID ou texte manquant"
        return 1
    fi

    local response
    response=$(curl -s -d "chat_id=${CHAT_ID}&text=${TEXT}&parse_mode=markdown" "${API}/sendMessage" 2>/tmp/curl_error.log)
    local curl_status=$?

    if [ $curl_status -ne 0 ]; then
        local error=$(cat /tmp/curl_error.log)
        log_error "Échec de l'envoi du message: $error"
        rm -f /tmp/curl_error.log
        return 1
    fi

    if ! echo "$response" | grep -q '"ok":true'; then
        log_error "Réponse API invalide: $response"
        return 1
    fi

    rm -f /tmp/curl_error.log
    return 0
}

# Fonction simplifiée pour obtenir l'IP source
get_source_ip() {
    if [ -n "$SSH_CONNECTION" ]; then
        echo "$SSH_CONNECTION" | awk '{print $1}'
    else
        echo "Local"
    fi
} 