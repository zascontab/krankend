#!/bin/bash

echo "==== Diagnóstico de conexiones a servicios ====="

echo -e "\n1. Verificando servidor local"
curl -v http://localhost:7081/health
echo

echo -e "\n2. Probando conexión al servicio de mensajería (8089)"
nc -zv 172.17.0.1 8089
nc -zv localhost 8089
echo

echo -e "\n3. Probando conexión al servicio IA (8086)"
nc -zv 172.17.0.1 8086
nc -zv localhost 8086
echo

echo -e "\n4. Probando envío simple de WhatsApp"
curl -v -X POST http://localhost:7081/test-whatsapp \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+593983606090",
    "message": "Prueba de conexión directa"
  }'
echo

echo -e "\n5. Obteniendo información de la red Docker"
docker network ls
docker network inspect krakend-project_default
echo

echo -e "\n6. Probando llamada directa al servicio de mensajería"
curl -v -X POST http://localhost:8089/api/messages/send-message \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+593983606090",
    "message": "Prueba de conexión directa sin KrakenD"
  }'
echo

echo "==== Diagnóstico completado ====="