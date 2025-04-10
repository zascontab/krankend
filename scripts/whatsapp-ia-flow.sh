#!/bin/bash

# Script para el flujo completo de WhatsApp-IA
set -e

echo "=== Iniciando flujo WhatsApp-IA ==="

# Datos para el mensaje
PHONE="+593983606090"
MESSAGE="¿Cuáles son tus horarios de atención?"

# 1. Procesar el mensaje con IA
echo -e "\nPaso 1: Procesando mensaje con IA"
IA_RESPONSE=$(curl -s -X POST http://localhost:7081/api/ia/ask \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"$MESSAGE\",
    \"session_id\": \"whatsapp-$PHONE\",
    \"language\": \"es\",
    \"data\": {\"forceMode\": \"customer_service\"},
    \"agent_id\": 1
  }")

echo "Respuesta IA: $IA_RESPONSE"

# Extraer el texto de la respuesta de IA
IA_TEXT=$(echo $IA_RESPONSE | jq -r '.text')
echo "Texto extraído: $IA_TEXT"

# 2. Enviar la respuesta por WhatsApp
echo -e "\nPaso 2: Enviando respuesta por WhatsApp"
WHATSAPP_RESPONSE=$(curl -s -v -X POST http://localhost:7081/api/whatsapp/send \
  -H "Content-Type: application/json" \
  -d "{
    \"phone_number\": \"$PHONE\",
    \"message\": \"$IA_TEXT\"
  }")

echo "Respuesta WhatsApp: $WHATSAPP_RESPONSE"

echo -e "\n=== Flujo completado ==="
