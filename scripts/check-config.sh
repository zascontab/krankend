#!/bin/bash
set -e

cd "$(dirname "$0")/.."
echo "Validando configuración de KrakenD..."
docker run --rm -v "$PWD/config:/etc/krakend" \
  -e FC_ENABLE=1 \
  -e FC_SETTINGS=./settings/dev.json \
  -e FC_PARTIALS=./partials \
  -e FC_OUT=/tmp/krakend-check.json \
  devopsfaith/krakend check -d -c /etc/krakend/krakend.json

if [ $? -eq 0 ]; then
  echo "✅ Configuración válida"
else
  echo "❌ Configuración inválida"
  exit 1
fi
