#!/bin/bash
set -e

cd "$(dirname "$0")/.."
ENVIRONMENT=${1:-dev}

echo "Desplegando KrakenD en entorno: $ENVIRONMENT"

# Validar configuración
./scripts/check-config.sh

# Iniciar o reiniciar el servicio
if [ "$ENVIRONMENT" = "dev" ]; then
  sudo docker compose -f docker-compose.yml down || true
  sudo docker compose -f docker-compose.yml up -d
  echo "KrakenD está ejecutándose en http://localhost:7081"
  echo "Panel de métricas disponible en http://localhost:7091"
else
  echo "Despliegue en entorno $ENVIRONMENT no implementado"
  # Aquí implementaríamos el despliegue en producción o staging
fi