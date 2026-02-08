#!/bin/bash
# Script de collecte des données de sync pour l'onglet Claudia
# Génère claudia-status.json avec les données en temps réel

# Configuration
OUTPUT_FILE="$(dirname "$0")/claudia-status.json"
LOG_FILE="/tmp/clawdbot/clawdbot-$(date +%Y-%m-%d).log"

# Fonction pour debug
log_debug() {
    echo "[DEBUG] $1" >&2
}

# Fonction pour calculer le temps écoulé en minutes
calculate_minutes_ago() {
    local timestamp_ms=$1
    local current_ms=$(date +%s%3N)
    local diff_ms=$((current_ms - timestamp_ms))
    local diff_minutes=$((diff_ms / 60000))
    echo $diff_minutes
}

# Fonction pour formater la date ISO
to_iso_date() {
    local timestamp_ms=$1
    date -r $((timestamp_ms / 1000)) -Iseconds
}

log_debug "Début de la collecte de données..."

# 1. Récupérer le statut Clawdbot
log_debug "Récupération du statut Clawdbot..."
# Filtrer les lignes de debug pour ne garder que le JSON
STATUS_JSON=$(clawdbot status --json 2>/dev/null | grep -A 99999 '^{')
if [ $? -ne 0 ] || [ -z "$STATUS_JSON" ]; then
    log_debug "Erreur lors de la récupération du statut"
    STATUS_JSON="{}"
fi

# 2. Extraire les données de heartbeat
log_debug "Extraction des données de heartbeat..."
HEARTBEAT_DATA="{}"
if echo "$STATUS_JSON" | jq -e '.heartbeat.agents' >/dev/null 2>&1; then
    # Extraire les agents actifs avec leurs dernières activités
    MAIN_AGENT=$(echo "$STATUS_JSON" | jq -r '.agents.agents[] | select(.id == "main")')
    PLAZA_AGENT=$(echo "$STATUS_JSON" | jq -r '.agents.agents[] | select(.id == "plaza-marketing")')
    CLEA_AGENT=$(echo "$STATUS_JSON" | jq -r '.agents.agents[] | select(.id == "clea")')
    
    if [ -n "$MAIN_AGENT" ]; then
        MAIN_LAST_UPDATE=$(echo "$MAIN_AGENT" | jq -r '.lastUpdatedAt // empty')
        MAIN_STATUS="ok"
        if [ -n "$MAIN_LAST_UPDATE" ]; then
            MAIN_LAST_CHECK=$(to_iso_date "$MAIN_LAST_UPDATE")
        else
            MAIN_LAST_CHECK="unknown"
        fi
    else
        MAIN_LAST_CHECK="unknown"
        MAIN_STATUS="unknown"
    fi
    
    if [ -n "$PLAZA_AGENT" ]; then
        PLAZA_LAST_UPDATE=$(echo "$PLAZA_AGENT" | jq -r '.lastUpdatedAt // empty')
        PLAZA_STATUS="ok"
        if [ -n "$PLAZA_LAST_UPDATE" ]; then
            PLAZA_LAST_CHECK=$(to_iso_date "$PLAZA_LAST_UPDATE")
        else
            PLAZA_LAST_CHECK="unknown"
        fi
    else
        PLAZA_LAST_CHECK="unknown"
        PLAZA_STATUS="unknown"
    fi
    
    if [ -n "$CLEA_AGENT" ]; then
        CLEA_LAST_UPDATE=$(echo "$CLEA_AGENT" | jq -r '.lastUpdatedAt // empty')
        CLEA_STATUS="ok"
        if [ -n "$CLEA_LAST_UPDATE" ]; then
            CLEA_LAST_CHECK=$(to_iso_date "$CLEA_LAST_UPDATE")
        else
            CLEA_LAST_CHECK="unknown"
        fi
    else
        CLEA_LAST_CHECK="unknown"
        CLEA_STATUS="unknown"
    fi
    
    HEARTBEAT_DATA=$(jq -n \
        --arg main_check "$MAIN_LAST_CHECK" \
        --arg main_status "$MAIN_STATUS" \
        --arg plaza_check "$PLAZA_LAST_CHECK" \
        --arg plaza_status "$PLAZA_STATUS" \
        --arg clea_check "$CLEA_LAST_CHECK" \
        --arg clea_status "$CLEA_STATUS" \
        '{
            "main": {
                "lastCheck": $main_check,
                "status": $main_status
            },
            "plaza-marketing": {
                "lastCheck": $plaza_check,
                "status": $plaza_status
            },
            "clea": {
                "lastCheck": $clea_check,
                "status": $clea_status
            }
        }'
    )
fi

# 3. Extraire l'activité récente depuis les logs
log_debug "Extraction de l'activité récente..."
RECENT_ACTIVITY="[]"
if [ -f "$LOG_FILE" ]; then
    # Extraire les dernières activités pertinentes (dernières heures)
    RECENT_ACTIVITY=$(tail -n 500 "$LOG_FILE" 2>/dev/null | \
        grep -E "(executing|completed|heartbeat|cron|Update Control Center|Stripe check|brief|recap)" | \
        tail -n 8 | \
        while IFS= read -r line; do
            # Extraire l'heure depuis le timestamp du log
            TIMESTAMP=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
            if [ -n "$TIMESTAMP" ]; then
                TIME=$(echo "$TIMESTAMP" | cut -d'T' -f2 | cut -d':' -f1,2)
                
                # Déterminer l'agent et l'action depuis le contenu du log
                AGENT="Claudia"
                ACTION="Activité système"
                
                if echo "$line" | grep -q "Update Control Center"; then
                    ACTION="Update Control Center execute"
                elif echo "$line" | grep -q "Stripe check"; then
                    AGENT="Valentina"
                    ACTION="Stripe check - 0 nouvelle vente"
                elif echo "$line" | grep -q "brief"; then
                    ACTION="Brief matinal envoyé"
                elif echo "$line" | grep -q "recap"; then
                    ACTION="Recap journalier"
                elif echo "$line" | grep -q "heartbeat"; then
                    ACTION="Heartbeat check"
                elif echo "$line" | grep -q "cron"; then
                    ACTION="Tâche automatisée"
                fi
                
                jq -n \
                    --arg time "$TIME" \
                    --arg agent "$AGENT" \
                    --arg action "$ACTION" \
                    '{time: $time, agent: $agent, action: $action}'
            fi
        done | jq -s '.')
else
    log_debug "Fichier de log non trouvé: $LOG_FILE"
fi

# 4. Calculer l'usage des tokens
log_debug "Calcul de l'usage des tokens..."
TOKEN_USAGE='{
    "today": {
        "input": 0,
        "output": 0,
        "cost": 0
    }
}'

if echo "$STATUS_JSON" | jq -e '.sessions.recent' >/dev/null 2>&1; then
    # Calculer la somme des tokens utilisés aujourd'hui
    TOTAL_INPUT=$(echo "$STATUS_JSON" | jq '[.sessions.recent[].inputTokens // 0] | add // 0')
    TOTAL_OUTPUT=$(echo "$STATUS_JSON" | jq '[.sessions.recent[].outputTokens // 0] | add // 0')
    
    # Estimation du coût (approximatif pour Claude Opus)
    # Input: $15/1M tokens, Output: $75/1M tokens
    COST_INPUT=$(echo "$TOTAL_INPUT * 15 / 1000000" | bc -l 2>/dev/null || echo "0")
    COST_OUTPUT=$(echo "$TOTAL_OUTPUT * 75 / 1000000" | bc -l 2>/dev/null || echo "0")
    TOTAL_COST=$(echo "$COST_INPUT + $COST_OUTPUT" | bc -l 2>/dev/null || echo "0")
    
    TOKEN_USAGE=$(jq -n \
        --argjson input "$TOTAL_INPUT" \
        --argjson output "$TOTAL_OUTPUT" \
        --argjson cost "$TOTAL_COST" \
        '{
            "today": {
                "input": $input,
                "output": $output,
                "cost": $cost
            }
        }'
    )
fi

# 5. Générer le fichier final
log_debug "Génération du fichier de statut..."
LAST_SYNC=$(date -Iseconds)

jq -n \
    --arg lastSync "$LAST_SYNC" \
    --argjson heartbeats "$HEARTBEAT_DATA" \
    --argjson recentActivity "$RECENT_ACTIVITY" \
    --argjson tokenUsage "$TOKEN_USAGE" \
    '{
        "lastSync": $lastSync,
        "heartbeats": $heartbeats,
        "recentActivity": $recentActivity,
        "tokenUsage": $tokenUsage
    }' > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    log_debug "Fichier généré avec succès: $OUTPUT_FILE"
    echo "Sync terminé avec succès à $(date)"
else
    log_debug "Erreur lors de la génération du fichier"
    exit 1
fi