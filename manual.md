# Documentación: Integración de KrakenD con Servicios de IA y WhatsApp

## Descripción General de la Arquitectura

Esta documentación describe la implementación de un API Gateway basado en KrakenD que integra servicios de IA y WhatsApp, con un servicio orquestador que coordina la comunicación entre ellos.

![Diagrama de Arquitectura](https://i.imgur.com/example.png)

## Componentes Principales

### 1. KrakenD API Gateway

KrakenD actúa como un punto de entrada único para todas las comunicaciones con los servicios backend. Gestiona el enrutamiento de solicitudes, agregación de respuestas y aplica políticas consistentes de seguridad y monitoreo.

**Configuración**: `/config/krakend-full-flow.json`

### 2. Servicio Orquestador

Implementa el flujo de integración entre los servicios de IA y WhatsApp, gestionando la coordinación de solicitudes y respuestas entre ambos sistemas.

**Ubicación**: Contenedor Docker `ia-whatsapp-orchestrator`  
**Puerto**: 8000

### 3. Servicio de IA
Ver codig0irrvM
Procesa consultas y genera respuestas utilizando capacidades de inteligencia artificial.

**Ubicación**: `http://172.17.0.1:8086`  
**Endpoint principal**: `/api/v1/conversation`

### 4. Servicio de WhatsApp

Gestiona el envío de mensajes a través del canal de WhatsApp.

**Ubicación**: `http://172.17.0.1:8089`  
**Endpoint principal**: `/send-otp`

## Endpoints Disponibles

### Endpoint de Salud

**Ruta**: `/health`  
**Método**: GET  
**Descripción**: Verifica el estado del sistema.  
**Servicio Backend**: Servicio de IA (`/api/v1/health`)

```bash
curl -X GET http://localhost:7081/health
```

### Acceso Directo al Servicio de IA

**Ruta**: `/api/ia/conversation`  
**Método**: POST  
**Descripción**: Permite la comunicación directa con el servicio de IA para procesar consultas.

**Cuerpo de Solicitud**:
```json
{
  "text": "Texto de la consulta",
  "session_id": "identificador-de-sesión",
  "language": "es",
  "data": {"forceMode": "customer_service"},
  "agent_id": 1
}
```

**Ejemplo de Uso**:
```bash
curl -X POST http://localhost:7081/api/ia/conversation \
     -H "Content-Type: application/json" \
     -d '{"text": "Necesito ayuda con mi pedido", "session_id": "session-456", "language": "es", "data": {"forceMode": "customer_service"}, "agent_id": 1}'
```

**Respuesta Esperada**:
```json
{
  "metadata": {
    "intent": "conversacion_general",
    "source": "ai_assistant"
  },
  "session_id": "session-456",
  "text": "Por favor, proporciona más detalles sobre tu pedido. ¿Cuál es el número de pedido, la tienda o empresa, y cuál es el problema?\n"
}
```

### Acceso Directo al Servicio de WhatsApp

**Ruta**: `/api/whatsapp/send-message`  
**Método**: POST  
**Descripción**: Permite enviar mensajes directamente a través del servicio de WhatsApp.

**Cuerpo de Solicitud**:
```json
{
  "phone_number": "+593983606090",
  "user_id": 1,
  "message": "Mensaje a enviar",
  "channel": "whatsapp",
  "purpose": "notification"
}
```

**Ejemplo de Uso**:
```bash
curl -X POST http://localhost:7081/api/whatsapp/send-message \
     -H "Content-Type: application/json" \
     -d '{"phone_number": "+593983606090", "user_id": 1, "message": "Tu pedido ha sido enviado", "channel": "whatsapp", "purpose": "notification"}'
```

**Respuesta Esperada**:
```json
{
  "otp": "ec8d356e-fe98-45ed-b270-8332a5a926c8",
  "signature": "firma-simulada",
  "timestamp": 1699483400
}
```

### Orquestación de Servicios IA y WhatsApp

**Ruta**: `/api/process-and-respond`  
**Método**: POST  
**Descripción**: Procesa una consulta con el servicio de IA y envía la respuesta a través de WhatsApp en un solo flujo.

**Cuerpo de Solicitud**:
```json
{
  "text": "Texto de la consulta",
  "session_id": "identificador-de-sesión",
  "language": "es",
  "data": {"forceMode": "customer_service"},
  "agent_id": 1,
  "phone_number": "+593983606090",
  "user_id": 1,
  "purpose": "test",
  "channel": "whatsapp"
}
```

**Ejemplo de Uso**:
```bash
curl -X POST http://localhost:7081/api/process-and-respond \
     -H "Content-Type: application/json" \
     -d '{"text": "Hola, ¿cómo estás?", "session_id": "test-session-123", "language": "es", "data": {"forceMode": "customer_service"}, "agent_id": 1, "phone_number": "+593983606090", "user_id": 1, "purpose": "test", "channel": "whatsapp"}'
```

**Respuesta Esperada**:
```json
{
  "ia_response": {
    "metadata": {
      "intent": "saludo",
      "source": "ai_assistant"
    },
    "session_id": "test-session-123",
    "text": "Hola, ¿cómo estás?\n"
  },
  "whatsapp_response": {
    "otp": "f5606514-ebc0-468c-81bb-349fda47629c",
    "signature": "firma-simulada",
    "timestamp": 1744257549
  }
}
```

### Webhook para WhatsApp

**Ruta**: `/api/whatsapp/webhook`  
**Método**: POST  
**Descripción**: Recibe notificaciones de WhatsApp y las procesa automáticamente a través del orquestador.

**Cuerpo de Solicitud**:
```json
{
  "messageId": "msg-id",
  "sender": "número@s.whatsapp.net",
  "pushName": "Nombre del Remitente",
  "timestamp": 1699483400,
  "type": "text",
  "content": "Contenido del mensaje",
  "mediaUrl": ""
}
```

**Ejemplo de Uso**:
```bash
curl -X POST http://localhost:7081/api/whatsapp/webhook \
     -H "Content-Type: application/json" \
     -d '{"messageId": "msg-789", "sender": "593983606090@s.whatsapp.net", "pushName": "Juan Pérez", "timestamp": 1699483400, "type": "text", "content": "Quiero cancelar mi suscripción", "mediaUrl": ""}'
```

**Respuesta Esperada**:
```json
{
  "status": "recibido"
}
```

## Arquitectura Detallada del Orquestador

El orquestador está implementado siguiendo la arquitectura hexagonal, que proporciona una clara separación de responsabilidades:

1. **Capa de Dominio** (Puertos y Adaptadores)
   - Define las interfaces (`IAService`, `WhatsAppService`, `MessageOrchestrator`)
   - Contiene la lógica de negocio central

2. **Capa de Aplicación**
   - Handlers HTTP que reciben las solicitudes y delegan el procesamiento a los servicios

3. **Capa de Infraestructura**
   - Adaptadores para comunicarse con servicios externos
   - Implementaciones concretas de los repositorios

## Guía de Despliegue

### Requisitos Previos

- Docker y Docker Compose instalados
- Acceso a los servicios de IA y WhatsApp

### Pasos para Desplegar

1. Clonar el repositorio

2. Configurar las variables de entorno en `.env` si es necesario

3. Iniciar los servicios con Docker Compose:
   ```bash
   docker-compose up -d
   ```

4. Verificar el estado de los servicios:
   ```bash
   docker-compose ps
   ```

## Resolución de Problemas Comunes

### Error de Conexión con el Orquestador

**Síntoma**: KrakenD devuelve un error "invalid status code" al intentar comunicarse con el orquestador.

**Solución**:
1. Asegurarse de que el orquestador esté ejecutándose: `docker ps | grep orchestrator`
2. Verificar que ambos contenedores estén en la misma red Docker: `docker network inspect app-network`
3. Probar la comunicación directa con el orquestador: `curl -X POST http://localhost:8000/api/process`

### Error en la Respuesta del Servicio de IA o WhatsApp

**Síntoma**: El orquestador devuelve un error relacionado con la comunicación con los servicios externos.

**Solución**:
1. Verificar que los servicios externos estén disponibles y acepten conexiones
2. Revisar los logs del orquestador para identificar errores específicos: `docker logs ia-whatsapp-orchestrator`

## Consideraciones de Seguridad

Esta configuración básica no incluye mecanismos de seguridad. Para entornos de producción, considere:

1. Implementar **autenticación JWT** en KrakenD
2. Configurar **CORS** adecuadamente
3. Establecer **límites de tasa** para prevenir abusos
4. Añadir **cifrado TLS/SSL** para todas las comunicaciones

## Próximos Pasos

1. Implementar mecanismos de seguridad (JWT, rate limiting, CORS)
2. Añadir monitoreo con Prometheus y Grafana
3. Configurar alta disponibilidad y escalabilidad

---

Documentación generada el 10 de abril de 2025.