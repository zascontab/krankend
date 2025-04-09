#!/bin/bash

# Este script genera tokens JWT para pruebas
# Requiere jq y openssl

# Generar clave privada temporal si no existe
if [ ! -f /tmp/private_key.pem ]; then
  openssl genrsa -out /tmp/private_key.pem 2048
  openssl rsa -in /tmp/private_key.pem -pubout -out /tmp/public_key.pem
fi

# Crear header
header=$(echo -n '{"alg":"RS256","typ":"JWT","kid":"test-key"}' | base64 | tr -d '=' | tr '/+' '_-')

# Crear payload
now=$(date +%s)
exp=$((now + 3600))

payload=$(cat <<EOF
{
  "sub": "test-user",
  "iat": $now,
  "exp": $exp,
  "iss": "test-issuer",
  "aud": "test-audience",
  "realm_access": {
    "roles": ["user", "admin"]
  }
}
