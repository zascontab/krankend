#!/bin/bash

echo "Generando configuración KrakenD..."

# Asegúrate que estás en el directorio raíz del proyecto
cd "$(dirname "$0")/.."

# Genera la configuración final
docker run --rm -v "$(pwd)/config:/etc/krakend" \
  -e FC_ENABLE=1 \
  -e FC_PARTIALS="/etc/krakend/partials" \
  -e FC_SETTINGS="/etc/krakend/settings/dev.json" \
  -e FC_OUT="/etc/krakend/krakend.json" \
  devopsfaith/krakend check -t -d -c /etc/krakend/krakend.tmpl

if [ $? -ne 0 ]; then
  echo "Error al generar la configuración"
  exit 1
fi

# Verifica que la configuración generada es válida
docker run --rm -v "$(pwd)/config:/etc/krakend" \
  devopsfaith/krakend check -c /etc/krakend/krakend.json

if [ $? -ne 0 ]; then
  echo "Error: la configuración generada no es válida"
  exit 1
fi

echo "✅ Configuración generada exitosamente en config/krakend.json"