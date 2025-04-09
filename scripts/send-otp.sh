#!/bin/bash

echo "=== Verificando que KrakenD esté corriendo ==="
docker ps | grep krakend

echo "=== Verificando el puerto en el que está escuchando KrakenD ==="
docker-compose ps

echo "=== Probando el endpoint de salud ==="
curl -v http://localhost:8080/health

echo "=== Probando el envío de mensaje directamente al servicio OTP ==="
curl -v -X POST http://localhost:8089/api/messages/send-message \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+593983606090",
    "user_id": 1,
    "message": "Mensaje de prueba directa",
    "channel": "whatsapp"
  }'

echo "=== Probando el envío de mensaje a través de KrakenD ==="
curl -v -X POST http://localhost:8080/api/whatsapp/send-message \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+593983606090",
    "user_id": 1,
    "message": "Mensaje de prueba a través de KrakenD",
    "channel": "whatsapp"
  }'

echo "=== Verificando los logs de KrakenD ==="
docker-compose logs --tail=20 krakend