# Documento Maestro: Implementación de Seguridad en KrakenD API Gateway

## 1. Introducción

Este documento proporciona una guía detallada y autónoma para la implementación de mecanismos de seguridad en KrakenD como API Gateway. La seguridad es un aspecto crítico en cualquier arquitectura de microservicios, especialmente cuando se exponen APIs a clientes externos o se gestionan datos sensibles.

KrakenD ofrece múltiples mecanismos de seguridad que permiten proteger los microservicios, autenticar usuarios, autorizar acciones y auditar el uso del sistema. Esta guía aborda cada aspecto de manera detallada para garantizar una implementación robusta y completa.

## 2. Objetivos de Seguridad

### 2.1. Objetivos Primarios

- **Autenticación**: Verificar la identidad de los usuarios y sistemas que acceden a las APIs.
- **Autorización**: Controlar el acceso a recursos específicos basado en roles y permisos.
- **Confidencialidad**: Proteger los datos en tránsito entre clientes, API Gateway y microservicios.
- **Integridad**: Garantizar que los datos no sean modificados durante la transmisión.
- **Disponibilidad**: Proteger contra ataques de denegación de servicio y garantizar acceso continuo.
- **Auditoría**: Registrar actividades relevantes para análisis forense y cumplimiento normativo.

### 2.2. Métricas de Éxito

- 100% de solicitudes no autenticadas rechazadas correctamente
- 100% de solicitudes a rutas protegidas con token inválido rechazadas
- Latencia adicional por validación de seguridad < 50ms
- Capacidad de rastrear cada solicitud mediante identificadores únicos
- Cobertura completa de pruebas de seguridad automatizadas

## 3. Arquitectura de Seguridad

### 3.1. Modelo de Seguridad

La arquitectura de seguridad se basa en un modelo de defensa en profundidad con múltiples capas:

1. **Perímetro**: Protección a nivel de red (firewalls, WAF)
2. **Transporte**: Cifrado TLS para todas las comunicaciones
3. **Gateway**: Validación, autenticación y autorización en KrakenD
4. **Microservicios**: Validaciones adicionales específicas de cada servicio

### 3.2. Flujo de Autenticación

```
┌─────────┐     ┌─────────┐     ┌─────────────┐     ┌───────────────┐
│ Cliente │────▶│ KrakenD │────▶│ Middleware  │────▶│ Microservicio │
└─────────┘     └─────────┘     │ Seguridad   │     └───────────────┘
                               └─────────────┘
                                     │
                                     ▼
                               ┌─────────────┐
                               │ Servicio    │
                               │ IAM         │
                               └─────────────┘
```

## 4. Implementación de Autenticación

### 4.1. Validación de Tokens JWT

KrakenD puede validar tokens JWT generados por el servicio IAM. Esta es la implementación más completa:

#### 4.1.1. Configuración del Middleware JWT

```json
{
  "endpoint": "/secured-endpoint",
  "extra_config": {
    "auth/validator": {
      "alg": "RS256",
      "jwk_url": "http://iam-service/jwks.json",
      "cache": true,
      "cache_duration": 3600,
      "disable_jwk_security": false,
      "operation_debug": false,
      "key_identify_strategy": "kid",
      "jwk_fingerprints": ["base64-encoded-certificate-fingerprint"],
      "propagate_claims": [
        ["sub", "x-user-id"],
        ["realm_access.roles", "x-user-roles"]
      ],
      "roles_key": "realm_access.roles",
      "roles": ["user", "admin"],
      "roles_key_is_nested": true
    }
  },
  "backend": [
    {
      "url_pattern": "/api/resource",
      "host": ["http://backend-service"]
    }
  ]
}
```

#### 4.1.2. Validación por Cookies

Para aplicaciones web que utilizan cookies en lugar de cabeceras de autorización:

```json
{
  "extra_config": {
    "auth/validator": {
      "alg": "RS256",
      "jwk_url": "http://iam-service/jwks.json",
      "cookie_key": "session_token"
    }
  }
}
```

#### 4.1.3. Propagación de Claims a Microservicios

Es fundamental transmitir la identidad del usuario a los microservicios:

```json
{
  "extra_config": {
    "auth/validator": {
      "propagate_claims": [
        ["sub", "x-user-id"],
        ["email", "x-user-email"],
        ["groups", "x-user-groups"],
        ["company_id", "x-company-id"]
      ]
    }
  }
}
```

### 4.2. Autenticación con API Keys

Para partners y sistemas externos que no utilizan JWT:

```json
{
  "endpoint": "/api-key-protected",
  "extra_config": {
    "auth/validator": {
      "validator": "header",
      "key": "x-api-key",
      "keys": ["key1", "key2", "key3"]
    }
  }
}
```

#### 4.2.1. Implementación con Servicio Externo

Para una gestión dinámica de API keys:

```json
{
  "extra_config": {
    "auth/validator": {
      "validator": "header",
      "key": "x-api-key",
      "jwk_url": "http://api-key-service/keys"
    }
  }
}
```

## 5. Implementación de Autorización

### 5.1. Autorización Basada en Roles

```json
{
  "extra_config": {
    "auth/validator": {
      "roles_key": "realm_access.roles",
      "roles": ["admin", "editor"],
      "roles_key_is_nested": true
    }
  }
}
```

### 5.2. Autorización Basada en Scopes OAuth2

```json
{
  "extra_config": {
    "auth/validator": {
      "scopes_key": "scope",
      "scopes": ["read:users", "write:users"],
      "scope_strategy": "any"
    }
  }
}
```

### 5.3. Autorización por Ruta y Método

```json
{
  "endpoints": [
    {
      "endpoint": "/users",
      "method": "GET",
      "extra_config": {
        "auth/validator": {
          "roles": ["user", "admin"]
        }
      }
    },
    {
      "endpoint": "/users",
      "method": "POST",
      "extra_config": {
        "auth/validator": {
          "roles": ["admin"]
        }
      }
    }
  ]
}
```

## 6. Seguridad en el Transporte

### 6.1. Configuración de TLS/SSL

```json
{
  "tls": {
    "public_key": "/etc/certificates/cert.pem",
    "private_key": "/etc/certificates/key.pem",
    "min_version": "TLS12",
    "max_version": "TLS13",
    "cipher_suites": [
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
    ],
    "curve_preferences": ["CurveP256", "CurveP384"],
    "prefer_server_cipher_suites": true
  }
}
```

### 6.2. CORS (Cross-Origin Resource Sharing)

```json
{
  "extra_config": {
    "security/cors": {
      "allow_origins": ["https://app.example.com"],
      "allow_methods": ["GET", "POST", "PUT", "DELETE"],
      "allow_headers": ["Origin", "Authorization", "Content-Type"],
      "expose_headers": ["Content-Length"],
      "max_age": 3600,
      "allow_credentials": true
    }
  }
}
```

## 7. Protección contra Ataques

### 7.1. Rate Limiting

```json
{
  "extra_config": {
    "qos/ratelimit/router": {
      "max_rate": 100,
      "strategy": "ip",
      "client_max_rate": 10,
      "capacity": 10
    }
  }
}
```

### 7.2. Configuración Avanzada por Cliente

```json
{
  "extra_config": {
    "qos/ratelimit/router": {
      "strategy": "header",
      "key": "x-api-key",
      "rates": {
        "partner1-key": {
          "max_rate": 100,
          "capacity": 100
        },
        "partner2-key": {
          "max_rate": 50,
          "capacity": 50
        }
      }
    }
  }
}
```

### 7.3. Protección contra CSRF

```json
{
  "extra_config": {
    "security/csrf": {
      "allowed_hosts": ["example.com", "*.example.com"],
      "exclude_paths": ["/public", "/webhooks"],
      "error_handler": "/csrf-error",
      "secure_cookie": true,
      "cookie_name": "csrf_token",
      "header_name": "X-CSRF-Token"
    }
  }
}
```

### 7.4. Validación de Contenido

```json
{
  "extra_config": {
    "validation/json-schema": {
      "type": "object",
      "required": ["username", "password"],
      "properties": {
        "username": {
          "type": "string",
          "minLength": 3,
          "maxLength": 50
        },
        "password": {
          "type": "string",
          "minLength": 8,
          "pattern": "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,}$"
        }
      }
    }
  }
}
```

## 8. Registro y Auditoría

### 8.1. Configuración de Logs de Seguridad

```json
{
  "extra_config": {
    "telemetry/logging": {
      "level": "INFO",
      "syslog": false,
      "stdout": true,
      "format": "json",
      "prefix": "[KRAKEND]",
      "skip_paths": ["/health"],
      "include_headers": true,
      "exclude_headers": ["Authorization", "Cookie"]
    }
  }
}
```

### 8.2. Integración con Sistemas SIEM

```json
{
  "extra_config": {
    "telemetry/gelf": {
      "address": "graylog:12201",
      "enable_tcp": false
    }
  }
}
```

## 9. Plan de Implementación

### 9.1. Fase 1: Preparación (Semana 1-2)

1. **Día 1-3: Análisis de Requisitos**
   - Identificar todos los endpoints y sus requisitos de seguridad
   - Documentar roles, permisos y políticas de acceso
   - Definir estrategia de tokens y claves

2. **Día 4-7: Configuración del Entorno**
   - Instalar KrakenD en entorno de desarrollo
   - Configurar certificados SSL/TLS para desarrollo
   - Preparar herramientas de prueba (Postman, JMeter)

3. **Día 8-10: Preparación de Servicios IAM**
   - Configurar endpoints JWKS para validación de tokens
   - Implementar generación de tokens de prueba
   - Documentar flujos de autenticación

### 9.2. Fase 2: Implementación Básica (Semana 3-4)

1. **Día 1-5: Configuración de Autenticación**
   - Implementar validación JWT para rutas críticas
   - Configurar propagación de identidad a servicios backend
   - Implementar manejo de errores de autenticación

2. **Día 6-10: Configuración de Autorización**
   - Implementar control de acceso basado en roles
   - Configurar rutas públicas y protegidas
   - Probar escenarios de permisos insuficientes

### 9.3. Fase 3: Configuración Avanzada (Semana 5-6)

1. **Día 1-4: Protección contra Ataques**
   - Implementar rate limiting por IP y por token
   - Configurar CORS para dominios permitidos
   - Implementar validación de esquemas JSON

2. **Día 5-8: Auditoría y Monitoreo**
   - Configurar logging detallado de eventos de seguridad
   - Implementar headers de rastreo de solicitudes
   - Integrar con sistemas de monitoreo

3. **Día 9-10: Pruebas de Seguridad**
   - Ejecutar pruebas de penetración básicas
   - Verificar comportamiento ante tokens manipulados
   - Probar escenarios de sobrecarga y ataques DoS

### 9.4. Fase 4: Optimización y Despliegue (Semana 7-8)

1. **Día 1-3: Refinamiento**
   - Optimizar configuración para rendimiento
   - Ajustar tiempos de cache de tokens
   - Implementar mejoras basadas en pruebas iniciales

2. **Día 4-7: Despliegue Parcial**
   - Desplegar en entorno de staging
   - Realizar pruebas de integración completas
   - Documentar resultados y problemas encontrados

3. **Día 8-10: Despliegue Completo**
   - Migrar gradualmente el tráfico a la nueva configuración
   - Monitorear errores y rendimiento
   - Implementar ajustes finales

## 10. Verificación y Validación

### 10.1. Matriz de Pruebas de Seguridad

| Prueba | Descripción | Criterio de Éxito |
|--------|-------------|-------------------|
| Autenticación Básica | Solicitudes con y sin token | Rechazo de solicitudes sin token válido |
| Expiración de Token | Probar con tokens caducados | Rechazo con código 401 |
| Manipulación de Token | Modificar claims del token | Rechazo con código 401 |
| Escalada de Privilegios | Intentar acceder a rutas no autorizadas | Rechazo con código 403 |
| Rate Limiting | Enviar solicitudes por encima del límite | Rechazo con código 429 |
| Validación de Entrada | Enviar datos malformados | Rechazo con código 400 |
| CORS | Solicitudes desde orígenes no permitidos | Rechazo apropiado de preflight |

### 10.2. Herramientas de Prueba

- **OWASP ZAP**: Para análisis automatizado de vulnerabilidades
- **Postman/Newman**: Para pruebas de API automatizadas
- **JMeter**: Para pruebas de carga y rendimiento
- **jwt-cli**: Para generación y manipulación de tokens de prueba

## 11. Gestión y Mantenimiento

### 11.1. Rotación de Claves

Proceso para la rotación periódica de claves de firma JWT:

1. Generar nuevo par de claves en el servicio IAM
2. Actualizar el endpoint JWKS para incluir ambas claves (antigua y nueva)
3. Configurar KrakenD para recuperar las claves actualizadas
4. Comenzar a firmar nuevos tokens con la nueva clave
5. Esperar a que todos los tokens antiguos expiren
6. Retirar la clave antigua del endpoint JWKS

### 11.2. Gestión de Incidentes

Procedimiento ante detección de intrusiones:

1. Revocar tokens comprometidos
2. Actualizar reglas de rate limiting
3. Bloquear IPs maliciosas en firewall
4. Registrar incidente y causa raíz
5. Implementar mejoras para prevenir futuros incidentes

### 11.3. Monitoreo Continuo

Métricas a monitorear:

- Tasa de rechazo de autenticación
- Patrones de uso sospechosos
- Latencia de validación de tokens
- Tasas de error por tipo (401, 403, 429)
- Caducidad de certificados

## 12. Documentación Adicional

### 12.1. Ejemplos de Configuración Completa

Archivo de configuración completo con todos los aspectos de seguridad implementados:

```json
{
  "version": 3,
  "name": "KrakenD Enterprise API Gateway",
  "port": 8080,
  "cache_ttl": "3600s",
  "timeout": "3s",
  "extra_config": {
    "telemetry/logging": {
      "level": "INFO",
      "prefix": "[KRAKEND]",
      "format": "json"
    },
    "telemetry/metrics": {
      "collection_time": "60s",
      "listen_address": ":8090"
    },
    "security/cors": {
      "allow_origins": ["https://app.example.com"],
      "allow_methods": ["GET", "POST", "PUT", "DELETE"],
      "allow_headers": ["Origin", "Authorization", "Content-Type"],
      "expose_headers": ["Content-Length"],
      "max_age": 3600,
      "allow_credentials": true
    }
  },
  "endpoints": [
    {
      "endpoint": "/public/health",
      "method": "GET",
      "backend": [
        {
          "url_pattern": "/health",
          "host": ["http://internal-service"]
        }
      ]
    },
    {
      "endpoint": "/api/users",
      "method": "GET",
      "extra_config": {
        "auth/validator": {
          "alg": "RS256",
          "jwk_url": "http://iam-service/jwks.json",
          "cache": true,
          "cache_duration": 3600,
          "propagate_claims": [
            ["sub", "x-user-id"],
            ["realm_access.roles", "x-user-roles"]
          ],
          "roles_key": "realm_access.roles",
          "roles": ["user", "admin"],
          "roles_key_is_nested": true
        },
        "qos/ratelimit/router": {
          "max_rate": 100,
          "strategy": "header",
          "key": "x-user-id",
          "capacity": 10
        }
      },
      "backend": [
        {
          "url_pattern": "/users",
          "host": ["http://user-service"],
          "extra_config": {
            "modifier/martian": {
              "header.Modifier": {
                "scope": ["request"],
                "name": "X-Request-ID",
                "value": "{{.request_id}}"
              }
            }
          }
        }
      ]
    }
  ]
}
```

### 12.2. Referencias y Recursos

- Documentación oficial de KrakenD: [https://www.krakend.io/docs/](https://www.krakend.io/docs/)
- Guía de seguridad JWT: [https://www.krakend.io/docs/authorization/jwt-validation/](https://www.krakend.io/docs/authorization/jwt-validation/)
- Mejores prácticas OWASP para API Security: [https://owasp.org/www-project-api-security/](https://owasp.org/www-project-api-security/)

## 13. Glosario

| Término | Definición |
|---------|------------|
| JWT | JSON Web Token, estándar para transmitir información de identidad de forma segura |
| JWKS | JSON Web Key Set, conjunto de claves utilizadas para verificar tokens JWT |
| OAuth 2.0 | Framework de autorización que permite a aplicaciones acceder a recursos protegidos |
| CORS | Cross-Origin Resource Sharing, mecanismo que permite solicitudes HTTP desde orígenes diferentes |
| Rate Limiting | Técnica para limitar el número de solicitudes que un cliente puede realizar en un período |
| Claims | Declaraciones o afirmaciones sobre una entidad contenidas en un token JWT |

## 14. Apéndices

### 14.1. Lista de Comprobación de Seguridad

- [ ] Validación JWT configurada correctamente
- [ ] Verificación de algoritmos seguros (RS256, ES256)
- [ ] Validación de emisor (iss) y audiencia (aud)
- [ ] Comprobación de caducidad del token
- [ ] Propagación de identidad a servicios backend
- [ ] Rate limiting configurado por IP y token
- [ ] CORS configurado para orígenes permitidos
- [ ] TLS configurado con cifrados seguros
- [ ] Logs de seguridad configurados correctamente
- [ ] Plan de rotación de claves documentado
- [ ] Pruebas de penetración ejecutadas



## comando para enviar el whatsapp

curl -v -X POST http://localhost:7081/api/whatsapp/send-message \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+593983606090",
    "user_id": 1,
    "purpose": "login",
    "channel": "whatsapp"
  }'

  