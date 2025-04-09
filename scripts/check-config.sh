#!/bin/bash
set -e

cd "$(dirname "$0")/.."
echo "Validando configuración de KrakenD..."

# Comprobar si el archivo krakend.tmpl existe
if [ -f "$PWD/config/krakend.tmpl" ]; then
  KRAKEND_CONFIG="$PWD/config/krakend.tmpl"
else
  KRAKEND_CONFIG="$PWD/config/krakend.json"
fi

# Validar el archivo de configuración directamente
docker run --rm -v "$PWD/config:/etc/krakend" \
  devopsfaith/krakend check -c /etc/krakend/krakend.json

if [ $? -eq 0 ]; then
  echo "✅ Configuración válida"
else
  echo "❌ Configuración inválida"
  exit 1
fi