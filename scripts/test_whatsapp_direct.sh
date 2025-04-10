#!/bin/bash

echo "==== Probando integración WhatsApp + IA ===="

echo -e "\n1. Verificando estado de KrakenD"
curl -s http://localhost:7081/health
echo

echo -e "\n2. Probando envío directo de mensaje"
curl -v -X POST http://localhost:7081/api/whatsapp/send-message \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+593983606090",
    "message": "Mensaje de prueba directo"
  }'
echo

echo -e "\n3. Probando procesamiento de bot"
curl -v -X POST http://localhost:7081/api/bot/process-message \
  -H "Content-Type: application/json" \
  -d '{
    "messageId": "TEST-ID-78910",
    "sender": "593983606090",
    "content": "¿Qué servicios ofrecen?",
    "type": "text"
  }'
echo