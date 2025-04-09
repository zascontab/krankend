#!/bin/bash
set -e

cd "$(dirname "$0")/.."
ENVIRONMENT=${1:-dev}

echo "Desplegando KrakenD en entorno: $ENVIRONMENT"

# Validar configuración
./scripts/check-config.sh $ENVIRONMENT

# Generar el archivo final
if [ "$ENVIRONMENT" = "dev" ]; then
  # Para desarrollo
  echo "Generando configuración de desarrollo..."
  docker run --rm -v "$PWD/config:/etc/krakend" \
    -e FC_ENABLE=1 \
    -e FC_OUT=/etc/krakend/krakend.generated.json \
    -e FC_PARTIALS="/etc/krakend/partials" \
    -e FC_SETTINGS="/etc/krakend/settings/dev.json" \
    devopsfaith/krakend check -t -d -c /etc/krakend/krakend.tmpl
  
  # Iniciar servicio en Docker Compose
  sudo docker compose -f docker-compose.yml down || true
  sudo docker compose -f docker-compose.yml up -d
  echo "KrakenD está ejecutándose en http://localhost:7081"
  echo "Panel de métricas disponible en http://localhost:7091"
  
elif [ "$ENVIRONMENT" = "prod" ]; then
  # Para producción
  echo "Generando configuración de producción..."
  docker run --rm -v "$PWD/config:/etc/krakend" \
    -e FC_ENABLE=1 \
    -e FC_OUT=/etc/krakend/krakend.generated.json \
    -e FC_PARTIALS="/etc/krakend/partials" \
    -e FC_SETTINGS="/etc/krakend/settings/prod.json" \
    devopsfaith/krakend check -t -d -c /etc/krakend/krakend.tmpl
  
  # Aquí el código de despliegue para producción
  # Por ejemplo, con docker swarm o kubernetes
  echo "Desplegando en producción..."
else
  echo "Entorno no válido. Use 'dev' o 'prod'"
  exit 1
fi