# Plan Maestro de Desarrollo: Microservicio de WhatsApp

## Resumen Ejecutivo

Este documento detalla el plan de desarrollo para implementar un microservicio de WhatsApp independiente que se integrará con la arquitectura existente basada en KrakenD API Gateway y el orquestador. El microservicio será diseñado para soportar casos de uso multiempresa y multiusuario, con funcionalidades para gestionar mensajería, OTP y asistencia por IA.

## 1. Visión General

### 1.1 Propósito del Microservicio

El servicio de WhatsApp actuará como un componente independiente responsable de:

1. Gestionar toda la comunicación con la API de WhatsApp Business
2. Enviar y recibir mensajes en nombre de diferentes empresas
3. Manejar webhooks entrantes de WhatsApp
4. Proporcionar interfaces consistentes para otros servicios
5. Garantizar la configuración específica por empresa para la comunicación

### 1.2 Diagrama de Contexto

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  KrakenD API    │────▶│  Orquestador    │────▶│  Servicio IA    │
│  Gateway        │     │                 │     │                 │
│                 │     │                 │     │                 │
└────────┬────────┘     └────────┬────────┘     └─────────────────┘
         │                       │
         │                       │
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Servicio       │◀───▶│  Servicio       │────▶│  Servicio OTP   │
│  WhatsApp       │     │  IAM            │     │                 │
│                 │     │                 │     │                 │
└─────────┬───────┘     └─────────────────┘     └─────────────────┘
          │
          │
          ▼
┌─────────────────┐
│                 │
│  WhatsApp       │
│  Business API   │
│                 │
└─────────────────┘
```

## 2. Especificaciones Técnicas

### 2.1 Arquitectura del Microservicio

El servicio se basará en una arquitectura hexagonal (puertos y adaptadores):

```
┌────────────────────────────────────────────────────┐
│                                                    │
│  Microservicio de WhatsApp                         │
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │                                            │   │
│  │  Núcleo (Dominio)                          │   │
│  │                                            │   │
│  │  - Entidades                               │   │
│  │  - Lógica de negocio                       │   │
│  │  - Reglas de dominio                       │   │
│  │                                            │   │
│  └─────────────────┬──────────────────────────┘   │
│                    │                               │
│       ┌────────────▼────────────┐                 │
│       │                         │                 │
│       │  Puertos (Interfaces)   │                 │
│       │                         │                 │
│       └───┬─────────────────┬───┘                 │
│           │                 │                     │
│  ┌────────▼─────┐   ┌───────▼──────┐              │
│  │              │   │              │              │
│  │ Adaptadores  │   │ Adaptadores  │              │
│  │ Primarios    │   │ Secundarios  │              │
│  │ (API, gRPC)  │   │ (DB, HTTP)   │              │
│  │              │   │              │              │
│  └──────────────┘   └──────────────┘              │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 2.2 Tecnologías Propuestas

| Componente | Tecnología | Justificación |
|------------|------------|---------------|
| Lenguaje | Go | Rendimiento, concurrencia, bajo consumo de recursos |
| Framework Web | Gin/Echo | Ligereza, rendimiento, middleware ecosystem |
| Base de Datos | PostgreSQL | Soporte para schemas, transacciones, queries complejas |
| Caché | Cualquier tecnología de caché | Alta performance, estructura de datos versátil |queno se redis debe ser opensource
| Comunicación | REST + WebSockets | Compatible con WebHooks, bidireccional |
| Documentación | OpenAPI/Swagger | Estándar de la industria, facilita testing |
| Contenedores | Docker + Kubernetes | Orquestación, escalabilidad |
| Mensajería | Kafka (opcional) | Para procesamiento asíncrono de alto volumen |

### 2.3 Modelo de Datos

#### 2.3.1 Entidades Principales

```
┌────────────────────────┐
│       WhatsAppAccount  │
├────────────────────────┤
│ id                     │
│ company_id             │
│ business_id            │
│ phone_number           │
│ waba_id                │
│ api_key                │
│ webhook_secret         │
│ account_type           │
│ status                 │
│ created_at             │
│ updated_at             │
└────────────┬───────────┘
             │
             │1:n
             ▼
┌────────────────────────┐      ┌────────────────────────┐
│       Conversation     │      │       Template         │
├────────────────────────┤      ├────────────────────────┤
│ id                     │      │ id                     │
│ account_id             │      │ account_id             │
│ contact_phone          │      │ name                   │
│ contact_name           │      │ template_id            │
│ status                 │      │ language               │
│ last_message_at        │      │ content                │
│ metadata               │      │ variables              │
│ created_at             │      │ category               │
│ updated_at             │      │ status                 │
└────────────┬───────────┘      │ created_at             │
             │                   │ updated_at             │
             │1:n                └────────────────────────┘
             ▼
┌────────────────────────┐
│        Message         │
├────────────────────────┤
│ id                     │
│ conversation_id        │
│ message_type           │
│ direction              │
│ content                │
│ media_url              │
│ status                 │
│ whatsapp_message_id    │
│ metadata               │
│ sent_at                │
│ delivered_at           │
│ read_at                │
│ created_at             │
│ updated_at             │
└────────────────────────┘
```

#### 2.3.2 Modelos Adicionales

```
┌────────────────────────┐      ┌────────────────────────┐
│        Session         │      │      WebhookEvent      │
├────────────────────────┤      ├────────────────────────┤
│ id                     │      │ id                     │
│ account_id             │      │ account_id             │
│ conversation_id        │      │ event_type             │
│ session_type           │      │ payload                │
│ status                 │      │ processed              │
│ expires_at             │      │ process_result         │
│ metadata               │      │ created_at             │
│ created_at             │      │ processed_at           │
│ updated_at             │      └────────────────────────┘
└────────────────────────┘
```

### 2.4 Estrategia Multi-tenant

El microservicio implementará un modelo multi-tenant utilizando el enfoque de "Schema-per-tenant" para PostgreSQL:

1. **Datos Compartidos**:
   - Configuración global de cuenta WhatsApp
   - Webhooks recibidos antes de procesamiento
   - Métricas y estadísticas
   
2. **Datos Específicos por Empresa**:
   - Conversaciones y mensajes
   - Plantillas personalizadas
   - Configuraciones específicas

**Implementación**:
- Crear schema dinámico por compañía 
- Middleware para determinar y seleccionar schema en cada solicitud
- Pool de conexiones separado por empresa para alto volumen

## 3. API y Endpoints

### 3.1 API REST

| Método | Endpoint | Descripción | Permisos |
|--------|----------|-------------|----------|
| POST | `/api/accounts` | Crear cuenta WhatsApp | admin |
| GET | `/api/accounts/{id}` | Obtener detalles de cuenta | read |
| PUT | `/api/accounts/{id}` | Actualizar cuenta | admin |
| GET | `/api/accounts/{id}/metrics` | Obtener métricas | read |
| POST | `/api/messages` | Enviar mensaje | send |
| GET | `/api/messages/{id}` | Obtener mensaje | read |
| GET | `/api/conversations` | Listar conversaciones | read |
| GET | `/api/conversations/{id}` | Obtener conversación | read |
| GET | `/api/conversations/{id}/messages` | Mensajes de conversación | read |
| POST | `/api/templates` | Crear plantilla | admin |
| PUT | `/api/templates/{id}` | Actualizar plantilla | admin |
| POST | `/api/otp/send` | Enviar código OTP | send |
| POST | `/api/otp/verify` | Verificar código OTP | verify |
| POST | `/webhook` | Recibir webhook de WhatsApp | public |

### 3.2 Detalles de Endpoints Clave

#### 3.2.1 Envío de Mensaje

**Endpoint**: `POST /api/messages`

**Cuerpo de la Solicitud**:
```json
{
  "phone_number": "+593987654321",
  "type": "text",
  "content": "Hola, este es un mensaje de prueba",
  "account_id": "abc123",
  "template_id": "welcome_template",
  "variables": {
    "name": "Juan",
    "company": "MiEmpresa"
  },
  "metadata": {
    "campaign_id": "onboarding-2025",
    "context": "welcome"
  }
}
```

**Respuesta Exitosa (201 Created)**:
```json
{
  "id": "msg_12345",
  "whatsapp_message_id": "wamid.12345",
  "status": "sent",
  "sent_at": "2025-04-10T15:30:45Z",
  "account_id": "abc123",
  "phone_number": "+593987654321"
}
```

#### 3.2.2 Recepción de WebHook

**Endpoint**: `POST /webhook`

**Cuerpo de la Solicitud (desde WhatsApp)**:
```json
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "WHATSAPP_BUSINESS_ACCOUNT_ID",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "+593987654321",
              "phone_number_id": "PHONE_NUMBER_ID"
            },
            "contacts": [
              {
                "profile": {
                  "name": "Customer Name"
                },
                "wa_id": "CUSTOMER_PHONE_NUMBER"
              }
            ],
            "messages": [
              {
                "from": "CUSTOMER_PHONE_NUMBER",
                "id": "wamid.12345",
                "timestamp": "1625176958",
                "type": "text",
                "text": {
                  "body": "Hola, necesito información"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}
```

**Respuesta Exitosa (200 OK)**:
```json
{
  "status": "received"
}
```

### 3.3 Notificaciones para Orquestador

El servicio implementará un sistema de eventos para notificar al orquestador sobre eventos importantes:

**Evento de Mensaje Recibido**:
```json
{
  "event_type": "message_received",
  "timestamp": "2025-04-10T15:30:45Z",
  "data": {
    "account_id": "abc123",
    "company_id": "company_456",
    "business_id": "business_789",
    "conversation_id": "conv_12345",
    "message_id": "msg_12345",
    "from": "+593987654321",
    "to": "+14155238886",
    "content": "Hola, necesito información",
    "type": "text"
  }
}
```

## 4. Interacción con Otros Servicios

### 4.1 Integración con Orquestador

El microservicio de WhatsApp interactuará con el orquestador a través de:

1. **Patrón de Notificación**:
   - Webhook interno al orquestador cuando se recibe un mensaje
   - Soporte para confirmar procesamiento (ACK)
   - Capacidad de reintento configurable

2. **Patrón de Solicitud-Respuesta**:
   - Orquestador llama a WhatsApp para enviar mensajes
   - Respuesta síncrona con resultado inmediato (accepted/rejected)
   - Notificación asíncrona posterior sobre entrega/lectura

**Diagrama de Secuencia (Mensaje Entrante)**:
```
WhatsApp Business API    Microservicio WhatsApp    Orquestador    Servicio IA
         |                       |                     |              |
         | mensaje entrante      |                     |              |
         |---------------------->|                     |              |
         |                       | procesar webhook    |              |
         |                       |---------------------|              |
         |                       | notificar mensaje   |              |
         |                       |-------------------->|              |
         |                       |                     | procesar con IA
         |                       |                     |------------->|
         |                       |                     |              |
         |                       |                     | respuesta IA |
         |                       |                     |<-------------|
         |                       | enviar respuesta    |              |
         |                       |<--------------------|              |
         | enviar mensaje        |                     |              |
         |<----------------------|                     |              |
         |                       |                     |              |
```

### 4.2 Integración con IAM

El servicio de WhatsApp utilizará el IAM para:
1. Autenticación de las APIs
2. Autorización basada en roles para operaciones
3. Resolución de contexto multi-tenant

**Consulta de Permisos**:
```json
// Solicitud a IAM
{
  "action": "whatsapp:send_message",
  "account_id": "abc123",
  "company_id": "company_456",
  "user_id": "user_789"
}

// Respuesta de IAM
{
  "allowed": true,
  "context": {
    "company_id": "company_456",
    "business_ids": ["business_789", "business_101"],
    "role": "agent",
    "permissions": ["whatsapp:send_message", "whatsapp:read"]
  }
}
```

### 4.3 Integración con OTP

El servicio WhatsApp utilizará el servicio OTP para:
1. Solicitar generación de códigos OTP
2. Enviar dichos códigos a través de WhatsApp
3. Verificar códigos ingresados por usuarios

**Flujo típico**:
1. Aplicación solicita OTP al orquestador
2. Orquestador solicita generación al servicio OTP
3. Servicio OTP genera código y solicita envío a servicio WhatsApp
4. Servicio WhatsApp envía código al usuario
5. Usuario responde con código vía WhatsApp
6. Servicio WhatsApp notifica al orquestador
7. Orquestador verifica con servicio OTP

## 5. Plan de Desarrollo

### 5.1 Fases de Implementación

#### Fase 1: Fundación (2-3 semanas)
- Configurar entorno de desarrollo y CI/CD
- Implementar esqueleto de la aplicación con arquitectura hexagonal
- Desarrollar modelo de datos y migraciones
- Configurar soporte multi-tenant básico

#### Fase 2: Funcionalidades Core (3-4 semanas)
- Implementar integración con API de WhatsApp Business
- Desarrollar gestión de conversaciones y mensajes
- Implementar procesamiento de webhooks
- Desarrollar cliente HTTP para comunicación con servicios externos

#### Fase 3: Integración y Servicios (2-3 semanas)
- Integrar con servicio IAM para autenticación/autorización
- Implementar funcionalidades OTP
- Desarrollar notificaciones para orquestador
- Implementar gestión de plantillas

#### Fase 4: Optimización y Testing (2-3 semanas)
- Desarrollar suite de pruebas automatizadas
- Implementar caching y optimización de rendimiento
- Mejorar observabilidad (logging, métricas, tracing)
- Documentación técnica completa

#### Fase 5: Despliegue y Estabilización (1-2 semanas)
- Configuración de producción
- Migraciones y onboarding iniciales
- Monitoreo en producción
- Ajustes finales

### 5.2 Cronograma Detallado

| Semana | Actividades | Entregables |
|--------|-------------|-------------|
| 1 | Configuración proyecto, estructura inicial | Repo, CI/CD, estructura base |
| 2 | Implementación de modelos, base de datos | Migraciones, entidades, repositorios |
| 3 | Endpoints REST básicos, multi-tenant | API básica, middleware de tenant |
| 4 | Integración WhatsApp Business API | Cliente WhatsApp, envío mensajes |
| 5 | Recepción de webhooks, conversaciones | Procesamiento webhooks, gestor conversaciones |
| 6 | Desarrollo de plantillas, metadata | Sistema plantillas, gestor metadata |
| 7 | Integración con IAM | Autenticación/autorización completa |
| 8 | Funcionalidad OTP | Endpoints OTP, integración |
| 9 | Notificaciones al orquestador | Sistema eventos, notificaciones |
| 10 | Pruebas automatizadas | Suite tests unitarios e integración |
| 11 | Optimización de rendimiento | Caching, indices, mejoras rendimiento |
| 12 | Documentación y preparación | Docs técnicos, runbooks |

### 5.3 Desglose de Tareas

#### Fase 1: Fundación

1. **Configuración inicial**
   - [ ] Crear repositorio y estructura de proyecto
   - [ ] Configurar Docker y Docker Compose para desarrollo
   - [ ] Configurar CI/CD (GitHub Actions/GitLab CI)
   - [ ] Configurar linting y formateo de código

2. **Arquitectura base**
   - [ ] Implementar estructura hexagonal
   - [ ] Definir interfaces principales (puertos)
   - [ ] Implementar adaptadores primarios (API REST)
   - [ ] Implementar adaptadores secundarios (base de datos)

3. **Modelo de datos**
   - [ ] Definir esquema de base de datos
   - [ ] Crear migraciones iniciales
   - [ ] Implementar entidades principales
   - [ ] Configurar ORM/Query Builder

4. **Soporte multi-tenant**
   - [ ] Implementar middleware para identificación de tenant
   - [ ] Desarrollar gestión de schemas por tenant
   - [ ] Implementar pool de conexiones por tenant
   - [ ] Configurar políticas de aislamiento

#### Fase 2: Funcionalidades Core

5. **Integración WhatsApp Business API**
   - [ ] Implementar cliente HTTP para WhatsApp API
   - [ ] Desarrollar métodos para envío de mensajes
   - [ ] Implementar manejo de respuestas y errores
   - [ ] Desarrollar funciones para gestión de media

6. **Gestión de conversaciones**
   - [ ] Implementar API para listar conversaciones
   - [ ] Desarrollar lógica para agrupar mensajes
   - [ ] Implementar búsqueda y filtrado
   - [ ] Desarrollar estado y metadata de conversaciones

7. **Procesamiento de webhooks**
   - [ ] Implementar endpoint para webhooks
   - [ ] Desarrollar parsing y validación
   - [ ] Implementar procesamiento asíncrono
   - [ ] Desarrollar sistema de retry para webhooks fallidos

8. **Sistema de mensajería**
   - [ ] Implementar cola de mensajes salientes
   - [ ] Desarrollar gestión de estados (enviado, entregado, leído)
   - [ ] Implementar mecanismos de reintento
   - [ ] Desarrollar sistema de prioridad de mensajes

#### Fase 3: Integración y Servicios

9. **Integración con IAM**
   - [ ] Implementar cliente para servicio IAM
   - [ ] Desarrollar middleware de autenticación
   - [ ] Implementar verificación de permisos
   - [ ] Desarrollar resolución de contexto de tenant

10. **Funcionalidad OTP**
    - [ ] Implementar endpoints para OTP
    - [ ] Desarrollar integración con servicio OTP
    - [ ] Implementar plantillas para mensajes OTP
    - [ ] Desarrollar verificación de respuestas OTP

11. **Notificaciones para orquestador**
    - [ ] Implementar sistema de eventos
    - [ ] Desarrollar cliente para notificaciones al orquestador
    - [ ] Implementar confirmación de procesamiento
    - [ ] Desarrollar sistema de retry para notificaciones

12. **Gestión de plantillas**
    - [ ] Implementar CRUD de plantillas
    - [ ] Desarrollar sistema de variables
    - [ ] Implementar validación según reglas de WhatsApp
    - [ ] Desarrollar versionamiento de plantillas

#### Fase 4: Optimización y Testing

13. **Pruebas automatizadas**
    - [ ] Implementar tests unitarios
    - [ ] Desarrollar tests de integración
    - [ ] Implementar mocks para servicios externos
    - [ ] Desarrollar tests de carga

14. **Optimización de rendimiento**
    - [ ] Implementar caching con Redis
    - [ ] Optimizar consultas a base de datos
    - [ ] Desarrollar rate limiting
    - [ ] Implementar circuit breakers

15. **Observabilidad**
    - [ ] Configurar logging estructurado
    - [ ] Implementar métricas con Prometheus
    - [ ] Desarrollar tracing distribuido
    - [ ] Configurar health checks

16. **Documentación técnica**
    - [ ] Crear documentación API con OpenAPI/Swagger
    - [ ] Desarrollar guías de integración
    - [ ] Documentar arquitectura
    - [ ] Crear runbooks operacionales

#### Fase 5: Despliegue y Estabilización

17. **Configuración de producción**
    - [ ] Preparar manifiestos Kubernetes
    - [ ] Configurar variables de entorno para producción
    - [ ] Implementar políticas de seguridad
    - [ ] Configurar estrategias de deployment

18. **Migraciones iniciales**
    - [ ] Desarrollar scripts de migración para datos existentes
    - [ ] Implementar estrategia de rollback
    - [ ] Probar migraciones en ambiente staging
    - [ ] Ejecutar migraciones en producción

19. **Monitoreo en producción**
    - [ ] Configurar alertas
    - [ ] Implementar dashboards
    - [ ] Desarrollar scripts para análisis post-mortem
    - [ ] Configurar notificaciones

20. **Ajustes finales**
    - [ ] Optimizaciones basadas en uso real
    - [ ] Corrección de bugs
    - [ ] Ajustes de configuración
    - [ ] Documentación de lecciones aprendidas

## 6. Código Clave de Implementación

Este apartado incluye ejemplos de código para componentes críticos.

### 6.1 Middleware Multi-tenant

```go
// middleware/tenant.go
package middleware

import (
    "context"
    "net/http"
    
    "github.com/gin-gonic/gin"
    "github.com/your-org/whatsapp-service/internal/tenant"
)

// TenantMiddleware extrae información del tenant de la petición
func TenantMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        // 1. Extraer tenant ID de headers, token JWT o parámetros
        tenantID := extractTenantID(c)
        
        if tenantID == "" {
            c.JSON(http.StatusBadRequest, gin.H{"error": "Missing tenant information"})
            c.Abort()
            return
        }
        
        // 2. Validar tenant con IAM
        valid, err := tenant.ValidateTenant(tenantID)
        if err != nil || !valid {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid tenant"})
            c.Abort()
            return
        }
        
        // 3. Configurar contexto para este tenant
        ctx := context.WithValue(c.Request.Context(), tenant.ContextKey, tenantID)
        c.Request = c.Request.WithContext(ctx)
        
        // 4. Configurar conexión específica de base de datos
        if err := tenant.SetupDBConnection(c, tenantID); err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "Tenant setup failed"})
            c.Abort()
            return
        }
        
        c.Next()
    }
}

func extractTenantID(c *gin.Context) string {
    // Extraer de JWT si está disponible
    claims, exists := c.Get("claims")
    if exists {
        if tenantID, ok := claims.(map[string]interface{})["tenant_id"].(string); ok {
            return tenantID
        }
    }
    
    // Probar con header personalizado
    if tenantID := c.GetHeader("X-Tenant-ID"); tenantID != "" {
        return tenantID
    }
    
    // Intentar desde parámetros de ruta
    return c.Param("tenant_id")
}
```

### 6.2 Cliente WhatsApp Business API

```go
// adapters/whatsapp/client.go
package whatsapp

import (
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
    "time"
    
    "github.com/your-org/whatsapp-service/internal/domain"
)

type Client struct {
    httpClient *http.Client
    baseURL    string
    apiVersion string
}

func NewClient(apiKey, baseURL, apiVersion string) *Client {
    return &Client{
        httpClient: &http.Client{
            Timeout: 30 * time.Second,
        },
        baseURL:    baseURL,
        apiVersion: apiVersion,
    }
}

func (c *Client) SendTextMessage(accountID, phoneNumber, message string) (*domain.MessageResponse, error) {
    url := fmt.Sprintf("%s/%s/%s/messages", c.baseURL, c.apiVersion, accountID)
    
    payload := map[string]interface{}{
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": phoneNumber,
        "type": "text",
        "text": map[string]string{
            "body": message,
        },
    }
    
    jsonPayload, err := json.Marshal(payload)
    if err != nil {
        return nil, fmt.Errorf("error marshaling payload: %w", err)
    }
    
    req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonPayload))
    if err != nil {
        return nil, fmt.Errorf("error creating request: %w", err)
    }
    
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", "Bearer "+apiKey)
    
    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("error sending request: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode < 200 || resp.StatusCode >= 300 {
        var errorResp map[string]interface{}
        if err := json.NewDecoder(resp.Body).Decode(&errorResp); err != nil {
            return nil, fmt.Errorf("error decoding error response: %w", err)
        }
        return nil, fmt.Errorf("WhatsApp API error: %v", errorResp)
    }
    
    var response struct {
        Messages []struct {
            ID string `json:"id"`
        } `json:"messages"`
    }
    
    if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
        return nil, fmt.Errorf("error decoding response: %w", err)
    }
    
    if len(response.Messages) == 0 {
        return nil, fmt.Errorf("no message ID returned")
    }
    
    return &domain.MessageResponse{
        MessageID: response.Messages[0].ID,
        Status:    "sent",
        SentAt:    time.Now(),
    }, nil
}

// Otros métodos: SendTemplateMessage, SendMediaMessage, etc.
```

### 6.3 Controlador de Webhook

```go
// adapters/api/webhook_handler.go
package api

import (
    "encoding/json"
    "io/ioutil"
    "net/http"
    
    "github.com/gin-gonic/gin"
    "github.com/your-org/whatsapp-service/internal/application"
    "github.com/your-org/whatsapp-service/internal/domain"
)

type WebhookHandler struct {
    webhookService application
    
    - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: db_host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: db_port
        - name: DB_USER
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: db_user
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: whatsapp-service-secrets
              key: db_password
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: db_name
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: redis_url
        - name: ORCHESTRATOR_URL
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: orchestrator_url
        - name: OTP_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: otp_service_url
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: whatsapp-service-config
              key: log_level
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 15
          periodSeconds: 20
      imagePullSecrets:
      - name: registry-secret
```

```yaml
# kubernetes/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: whatsapp-service
  namespace: messaging
spec:
  selector:
    app: whatsapp-service
  ports:
  - port: 80
    targetPort: 8000
  type: ClusterIP
```

```yaml
# kubernetes/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: whatsapp-service-config
  namespace: messaging
data:
  db_host: "postgres.messaging"
  db_port: "5432"
  db_user: "whatsapp"
  db_name: "whatsapp"
  
  orchestrator_url: "http://orchestrator.messaging:8000"
  otp_service_url: "http://otp-service.messaging:8000"
  log_level: "info"
```

```yaml
# kubernetes/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: whatsapp-service-secrets
  namespace: messaging
type: Opaque
data:
  db_password: cGFzc3dvcmQ=  # base64 encoded "password"
```

```yaml
# kubernetes/horizontalpodautoscaler.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: whatsapp-service
  namespace: messaging
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: whatsapp-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## 8. Pruebas y Calidad

### 8.1 Estrategia de Testing

#### 8.1.1 Pruebas Unitarias

Ejemplo de prueba unitaria para el servicio de mensajes:

```go
// application/message_service_test.go
package application_test

import (
    "context"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    
    "github.com/your-org/whatsapp-service/internal/application"
    "github.com/your-org/whatsapp-service/internal/domain"
    "github.com/your-org/whatsapp-service/internal/ports/mocks"
)

func TestSendTextMessage(t *testing.T) {
    // Arrange
    ctx := context.Background()
    
    messageRepo := new(mocks.MockMessageRepository)
    conversationRepo := new(mocks.MockConversationRepository)
    whatsappClient := new(mocks.MockWhatsAppClient)
    eventPublisher := new(mocks.MockEventPublisher)
    
    service := application.NewMessageService(
        messageRepo,
        conversationRepo,
        whatsappClient,
        eventPublisher,
    )
    
    // Mock de conversación existente
    conversation := &domain.Conversation{
        ID:           "conv123",
        AccountID:    "acc123",
        ContactPhone: "+123456789",
        Status:       domain.ConversationStatusActive,
    }
    
    // Configuración de mocks
    conversationRepo.On("GetByAccountAndPhone", ctx, "acc123", "+123456789").
        Return(conversation, nil)
    
    messageRepo.On("Create", ctx, mock.AnythingOfType("*domain.Message")).
        Return(nil).
        Run(func(args mock.Arguments) {
            msg := args.Get(1).(*domain.Message)
            msg.ID = "msg123"
        })
    
    whatsappClient.On("SendTextMessage", "acc123", "+123456789", "Test message").
        Return(&domain.MessageResponse{
            MessageID: "wamid.123",
            Status:    "sent",
            SentAt:    time.Now(),
        }, nil)
    
    messageRepo.On("Update", ctx, mock.AnythingOfType("*domain.Message")).
        Return(nil)
    
    conversationRepo.On("Update", ctx, mock.AnythingOfType("*domain.Conversation")).
        Return(nil)
    
    eventPublisher.On("PublishEvent", mock.AnythingOfType("domain.Event")).
        Return(nil)
    
    // Act
    req := application.SendMessageRequest{
        AccountID:   "acc123",
        PhoneNumber: "+123456789",
        Content:     "Test message",
    }
    
    message, err := service.SendTextMessage(ctx, req)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, message)
    assert.Equal(t, "msg123", message.ID)
    assert.Equal(t, "wamid.123", message.WhatsAppMessageID)
    assert.Equal(t, domain.MessageStatusSent, message.Status)
    
    // Verify mocks
    messageRepo.AssertExpectations(t)
    conversationRepo.AssertExpectations(t)
    whatsappClient.AssertExpectations(t)
    eventPublisher.AssertExpectations(t)
}
```

#### 8.1.2 Pruebas de Integración

Ejemplo de prueba de integración para el endpoint de webhook:

```go
// tests/integration/webhook_test.go
package integration

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
    
    "github.com/your-org/whatsapp-service/internal/adapters/api"
    "github.com/your-org/whatsapp-service/tests/helpers"
)

func TestWebhookEndpoint(t *testing.T) {
    // Skip if not running integration tests
    if testing.Short() {
        t.Skip("Skipping integration test")
    }
    
    // Setup
    router, deps := helpers.SetupTestServer()
    
    // Test data
    webhookData := map[string]interface{}{
        "object": "whatsapp_business_account",
        "entry": []map[string]interface{}{
            {
                "id": "123456789",
                "changes": []map[string]interface{}{
                    {
                        "value": map[string]interface{}{
                            "messaging_product": "whatsapp",
                            "metadata": map[string]interface{}{
                                "display_phone_number": "+123456789",
                                "phone_number_id": "987654321",
                            },
                            "contacts": []map[string]interface{}{
                                {
                                    "profile": map[string]interface{}{
                                        "name": "Test User",
                                    },
                                    "wa_id": "123456789",
                                },
                            },
                            "messages": []map[string]interface{}{
                                {
                                    "from": "123456789",
                                    "id": "wamid.123",
                                    "timestamp": "1634567890",
                                    "type": "text",
                                    "text": map[string]interface{}{
                                        "body": "Test message",
                                    },
                                },
                            },
                        },
                        "field": "messages",
                    },
                },
            },
        },
    }
    
    // Crear firma mock
    signature := helpers.GenerateMockSignature(webhookData)
    
    // Serializar payload
    payload, _ := json.Marshal(webhookData)
    
    // Crear request
    req, _ := http.NewRequest("POST", "/webhook", bytes.NewBuffer(payload))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Hub-Signature-256", signature)
    
    // Crear recorder para capturar respuesta
    w := httptest.NewRecorder()
    
    // Ejecutar request
    router.ServeHTTP(w, req)
    
    // Verify
    assert.Equal(t, http.StatusOK, w.Code)
    
    var response map[string]string
    err := json.Unmarshal(w.Body.Bytes(), &response)
    assert.NoError(t, err)
    assert.Equal(t, "received", response["status"])
    
    // Verificar que el webhook se procesó correctamente (esto puede requerir esperar un poco)
    // ya que el procesamiento es asíncrono
    helpers.WaitForWebhookProcessing()
    
    // Verificar que se registró el mensaje en la base de datos
    messages, err := deps.MessageRepository.GetByConversationWithPhone(
        context.Background(), "+123456789", 10, 0)
    assert.NoError(t, err)
    assert.Len(t, messages, 1)
    assert.Equal(t, "Test message", messages[0].Content)
}
```

#### 8.1.3 Pruebas de Carga

Ejemplo de script de prueba de carga con k6:

```javascript
// tests/load/webhook_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

// Métricas personalizadas
const successfulWebhooks = new Counter('successful_webhooks');
const failedWebhooks = new Counter('failed_webhooks');

// Configuración de la prueba
export const options = {
    stages: [
        { duration: '30s', target: 50 },  // Ramp-up a 50 usuarios
        { duration: '1m', target: 50 },   // Mantener 50 usuarios por 1 minuto
        { duration: '30s', target: 100 }, // Ramp-up a 100 usuarios
        { duration: '1m', target: 100 },  // Mantener 100 usuarios por 1 minuto
        { duration: '30s', target: 0 },   // Ramp-down a 0 usuarios
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],  // 95% de las solicitudes deben completarse en menos de 500ms
        'successful_webhooks': ['count>1000'],  // Al menos 1000 webhooks exitosos
    },
};

// Función auxiliar para generar datos de webhook
function generateWebhookData(userNumber) {
    return {
        object: "whatsapp_business_account",
        entry: [
            {
                id: "123456789",
                changes: [
                    {
                        value: {
                            messaging_product: "whatsapp",
                            metadata: {
                                display_phone_number: "+123456789",
                                phone_number_id: "987654321",
                            },
                            contacts: [
                                {
                                    profile: {
                                        name: `Load Test User ${userNumber}`,
                                    },
                                    wa_id: `${9000000000 + userNumber}`,
                                },
                            ],
                            messages: [
                                {
                                    from: `${9000000000 + userNumber}`,
                                    id: `wamid.load.${userNumber}.${Date.now()}`,
                                    timestamp: `${Math.floor(Date.now() / 1000)}`,
                                    type: "text",
                                    text: {
                                        body: `Load test message from user ${userNumber} at ${new Date().toISOString()}`,
                                    },
                                },
                            ],
                        },
                        field: "messages",
                    },
                ],
            },
        ],
    };
}

// Función principal
export default function() {
    const userNumber = __VU;  // Virtual User number
    
    // Generar datos de webhook
    const payload = JSON.stringify(generateWebhookData(userNumber));
    
    // Headers de la solicitud
    const headers = {
        'Content-Type': 'application/json',
        'X-Hub-Signature-256': 'mock_signature_for_load_test', // En producción, esto debe ser válido
    };
    
    // Enviar solicitud
    const response = http.post('http://localhost:8000/webhook', payload, {
        headers: headers,
    });
    
    // Verificar respuesta
    const success = check(response, {
        'status is 200': (r) => r.status === 200,
        'response has status': (r) => r.json().status === 'received',
    });
    
    if (success) {
        successfulWebhooks.add(1);
    } else {
        failedWebhooks.add(1);
        console.log(`Failed webhook: ${response.status} - ${response.body}`);
    }
    
    // Esperar un poco entre solicitudes para simular llegada de webhooks
    sleep(Math.random() * 0.5);
}
```

### 8.2 Configuración de CI/CD

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:14-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: whatsapp_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:6-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Go
      uses: actions/setup-go@v3
      with:
        go-version: '1.20'
    
    - name: Install dependencies
      run: go mod download
    
    - name: Lint
      uses: golangci/golangci-lint-action@v3
      with:
        version: latest
    
    - name: Unit tests
      run: go test -v ./internal/... -cover
    
    - name: Integration tests
      run: go test -v ./tests/integration/... -tags=integration
      env:
        DB_HOST: localhost
        DB_PORT: 5432
        DB_USER: postgres
        DB_PASSWORD: postgres
        DB_NAME: whatsapp_test
        REDIS_URL: redis://localhost:6379/0
        ORCHESTRATOR_URL: http://localhost:8001
        OTP_SERVICE_URL: http://localhost:8001
        LOG_LEVEL: debug
  
  build:
    name: Build
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ secrets.REGISTRY_URL }}
        username: ${{ secrets.REGISTRY_USERNAME }}
        password: ${{ secrets.REGISTRY_PASSWORD }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ secrets.REGISTRY_URL }}/whatsapp-service
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=sha,format=short
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=registry,ref=${{ secrets.REGISTRY_URL }}/whatsapp-service:buildcache
        cache-to: type=registry,ref=${{ secrets.REGISTRY_URL }}/whatsapp-service:buildcache,mode=max
  
  deploy-dev:
    name: Deploy to Development
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set Kubernetes context
      uses: azure/k8s-set-context@v2
      with:
        kubeconfig: ${{ secrets.KUBE_CONFIG_DEV }}
    
    - name: Deploy to Kubernetes
      run: |
        TAG=$(echo $GITHUB_SHA | head -c7)
        sed -i "s|\${REGISTRY}|${{ secrets.REGISTRY_URL }}|g" kubernetes/deployment.yaml
        sed -i "s|\${TAG}|$TAG|g" kubernetes/deployment.yaml
        kubectl apply -f kubernetes/configmap.yaml
        kubectl apply -f kubernetes/secret.yaml
        kubectl apply -f kubernetes/service.yaml
        kubectl apply -f kubernetes/deployment.yaml
        kubectl apply -f kubernetes/horizontalpodautoscaler.yaml
    
    - name: Verify deployment
      run: |
        kubectl rollout status deployment/whatsapp-service -n messaging
```

## 9. Gestión del Proyecto

### 9.1 Estructura de Repositorio

```
whatsapp-service/
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── adapters/
│   │   ├── api/
│   │   │   ├── handlers.go
│   │   │   ├── middleware.go
│   │   │   ├── router.go
│   │   │   └── server.go
│   │   ├── orchestrator/
│   │   │   └── client.go
│   │   ├── otpclient/
│   │   │   └── client.go
│   │   ├── repository/
│   │   │   └── postgres/
│   │   │       ├── message_repository.go
│   │   │       ├── conversation_repository.go
│   │   │       └── session_repository.go
│   │   └── whatsapp/
│   │       └── client.go
│   ├── application/
│   │   ├── message_service.go
│   │   ├── otp_service.go
│   │   ├── template_service.go
│   │   └── webhook_service.go
│   ├── domain/
│   │   ├── conversation.go
│   │   ├── events.go
│   │   ├── message.go
│   │   ├── session.go
│   │   └── template.go
│   ├── ports/
│   │   ├── repositories.go
│   │   └── services.go
│   └── tenant/
│       └── db_provider.go
├── pkg/
│   ├── config/
│   │   └── config.go
│   ├── logger/
│   │   └── logger.go
│   └── validator/
│       └── validator.go
├── tests/
│   ├── integration/
│   │   ├── webhook_test.go
│   │   └── message_test.go
│   ├── load/
│   │   └── webhook_test.js
│   └── helpers/
│       └── test_server.go
├── mocks/
│   └── Dockerfile
├── kubernetes/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   └── horizontalpodautoscaler.yaml
├── migrations/
│   ├── 000001_create_schema.up.sql
│   ├── 000001_create_schema.down.sql
│   ├── 000002_create_tables.up.sql
│   └── 000002_create_tables.down.sql
├── .github/
│   └── workflows/
│       └── ci.yml
├── docker-compose.yml
├── Dockerfile
├── go.mod
├── go.sum
└── README.md
```

### 9.2 Planificación por Sprints

#### Sprint 1: Configuración y Fundamentos
**Objetivo**: Establecer la infraestructura base y arquitectura hexagonal

**Tareas**:
- Configurar repositorio y estructura de proyecto
- Implementar arquitectura hexagonal (puertos y adaptadores)
- Configurar Docker y Docker Compose
- Configurar CI/CD inicial
- Implementar modelo de datos básico

**Entregables**:
- Repositorio con estructura base
- Docker Compose funcional
- Modelo de datos implementado

**Estimación**: 1 semana

#### Sprint 2: Core del Servicio
**Objetivo**: Implementar las funcionalidades principales del servicio

**Tareas**:
- Implementar cliente WhatsApp Business API
- Desarrollar gestión de conversaciones
- Implementar envío de mensajes
- Desarrollar sistema de eventos

**Entregables**:
- API para envío de mensajes
- Gestión básica de conversaciones
- Cliente WhatsApp funcional

**Estimación**: 1 semana

#### Sprint 3: Webhooks y Multi-tenant
**Objetivo**: Implementar procesamiento de webhooks y soporte multi-tenant

**Tareas**:
- Desarrollar endpoint de webhook
- Implementar procesamiento de mensajes entrantes
- Configurar soporte multi-tenant
- Implementar proveedor de base de datos por tenant

**Entregables**:
- Endpoint de webhook funcional
- Procesamiento asíncrono de webhooks
- Arquitectura multi-tenant implementada

**Estimación**: 1 semana

#### Sprint 4: Integración con Servicios Externos
**Objetivo**: Integrar con orquestador y servicio OTP

**Tareas**:
- Implementar cliente para orquestador
- Desarrollar integración con servicio OTP
- Implementar sistema de notificaciones
- Desarrollar funcionalidades OTP específicas

**Entregables**:
- Integración funcional con orquestador
- Sistema completo de OTP
- Notificaciones para eventos importantes

**Estimación**: 1 semana

#### Sprint 5: Pruebas y Optimización
**Objetivo**: Mejorar calidad y rendimiento

**Tareas**:
- Implementar tests unitarios completos
- Desarrollar tests de integración
- Configurar pruebas de carga
- Optimizar rendimiento

**Entregables**:
- Suite de pruebas completa
- Optimizaciones implementadas
- Documentación de pruebas

**Estimación**: 1 semana

#### Sprint 6: Despliegue y Documentación
**Objetivo**: Preparar para producción y completar documentación

**Tareas**:
- Configurar manifiestos Kubernetes
- Desarrollar scripts de migración
- Completar documentación técnica
- Preparar runbooks operacionales

**Entregables**:
- Configuración lista para producción
- Documentación técnica completa
- API documentada con OpenAPI

**Estimación**: 1 semana

### 9.3 Riesgos y Mitigaciones

| Riesgo | Impacto | Probabilidad | Mitigación |
|--------|---------|--------------|------------|
| Cambios en la API de WhatsApp | Alto | Media | Implementar adaptador que aísle cambios, monitoreo de actualizaciones |
| Sobrecarga por alto volumen de mensajes | Alto | Alta | Implementar procesamiento asíncrono, circuit breakers, rate limiting |
| Problemas de concurrencia con multi-tenant | Medio | Media | Pruebas exhaustivas, revisión de código, monitoreo específico |
| Mal funcionamiento del webhook | Alto | Baja | Sistema de reintentos, monitoreo dedicado, alertas |
| Fallos en integración con orquestador | Alto | Media | Mocks para desarrollo, pruebas de integración automatizadas |
| Latencia en base de datos | Medio | Alta | Optimización de consultas, índices adecuados, caché |

## 10. Documentación Operativa

### 10.1 Guía de Instalación

1. **Requisitos previos**:
   - Go 1.20+
   - Docker y Docker Compose
   - PostgreSQL 14+
   - Redis 6+
   - Acceso a API de WhatsApp Business

2. **Configuración de desarrollo**:
   ```bash
   # Clonar repositorio
   git clone https://github.com/your-org/whatsapp-service.git
   cd whatsapp-service
   
   # Configurar variables de entorno
   cp .env.example .env
   # Editar .env con los valores correctos
   
   # Iniciar servicios de desarrollo
   docker-compose up -d
   
   # Ejecutar migraciones
   go run cmd/migrate/main.go up
   
   # Iniciar servicio en modo desarrollo
   go run cmd/api/main.go
   ```

3. **Configuración de producción**:
   ```bash
   # Construir imagen Docker
   docker build -t your-registry/whatsapp-service:latest .
   
   # Aplicar configuración de Kubernetes
   kubectl apply -f kubernetes/
   ```

### 10.2 Guía de Monitoreo

1. **Métricas clave**:
   - Tasa de mensajes enviados/recibidos
   - Tiempo de procesamiento de webhook
   - Latencia de API WhatsApp
   - Uso de memoria/CPU por tenant
   - Errores de envío

2. **Endpoints de salud**:
   - `/health` - Estado general del servicio
   - `/health/whatsapp` - Conectividad con WhatsApp API
   - `/health/db` - Estado de base de datos
   - `/health/redis` - Estado de cache
   - `/metrics` - Métricas en formato Prometheus

3. **Alertas recomendadas**:
   - Alto porcentaje de errores en envío (>5%)
   - Aumento repentino en latencia (>500ms)
   - Fallas en webhook (>3 consecutivas)
   - Alta utilización de memoria (>80%)

### 10.3 Troubleshooting

1. **Problemas comunes y soluciones**:

   **Error en envío de mensajes**:
   - Verificar conectividad con API de WhatsApp
   - Comprobar credenciales y permisos
   - Revisar logs para errores específicos
   - Verificar rate limits de WhatsApp

   **Webhook no procesa mensajes**:
   - Verificar firma de webhook
   - Comprobar procesamiento asíncrono
   - Revisar logs de errores
   - Verificar conexión a base de datos

   **Problemas de multi-tenant**:
   - Verificar que tenant_id se propaga correctamente
   - Comprobar esquemas de base de datos
   - Revisar conexiones a base de datos

   **Errores de integración**:
   - Verificar conectividad con otros servicios
   - Comprobar formatos de mensajes
   - Revisar configuración de reintentos

2. **Comandos útiles**:
   ```bash
   # Ver logs de servicio
   kubectl logs -f deploy/whatsapp-service -n messaging
   
   # Verificar conectividad con base de datos
   kubectl exec -it deploy/whatsapp-service -n messaging -- bash -c "pg_isready -h \$DB_HOST -p \$DB_PORT -U \$DB_USER"
   
   # Verificar conectividad con Redis
   kubectl exec -it deploy/whatsapp-service -n messaging -- bash -c "redis-cli -u \$REDIS_URL ping"
   
   # Obtener métricas
   curl http://whatsapp-service.messaging/metrics
   
   # Reiniciar servicio
   kubectl rollout restart deploy/whatsapp-service -n messaging
   ```

## 11. Conclusiones y Siguientes Pasos

### 11.1 Resumen del Plan

El plan de desarrollo presentado establece una ruta clara para implementar un microservicio de WhatsApp independiente y robusto que se integrará perfectamente con la arquitectura actual basada en KrakenD API Gateway y el orquestador. El enfoque hexagonal garantiza una separación limpia de responsabilidades y facilita las pruebas, mientras que la arquitectura multi-tenant permitirá gestionar múltiples empresas y usuarios de manera eficiente.

### 11.2 Ventajas de la Arquitectura

1. **Escalabilidad independiente**: El servicio puede escalar independientemente de otros componentes
2. **Responsabilidad clara**: Gestión dedicada de toda la comunicación con WhatsApp
3. **Mantenibilidad mejorada**: Separación de preocupaciones y arquitectura hexagonal que facilita el mantenimiento
4. **Preparado para multiempresa**: Diseño que soporta nativamente múltiples organizaciones
5. **Observabilidad integrada**: Métricas, logs y trazabilidad incorporados desde el diseño

### 11.3 Siguientes Pasos Recomendados

Una vez implementado el microservicio base, se recomiendan los siguientes pasos para expansión y mejora:

1. **Capacidades Analíticas**:
   - Implementar dashboard de análisis de conversaciones
   - Desarrollar detección de sentimiento en mensajes
   - Crear sistema de etiquetado automático de conversaciones

2. **Mejoras en Experiencia de Usuario**:
   - Implementar respuestas rápidas preconfiguradas
   - Desarrollar sistema de transferencia entre agentes humanos e IA
   - Crear biblioteca de respuestas comunes por empresa

3. **Capacidades Avanzadas**:
   - Reconocimiento y procesamiento de adjuntos (imágenes, documentos)
   - Integración con sistemas CRM
   - Campañas masivas programadas con seguimiento

4. **Optimizaciones**:
   - Implementar bases de conocimiento específicas por empresa
   - Desarrollar sistemas de aprendizaje por feedback
   - Optimizar costos de operación con modelos predictivos

## 12. Apéndices

### 12.1 Glosario de Términos

- **WABA**: WhatsApp Business API Account
- **HSM**: Highly Structured Message (Plantillas de WhatsApp)
- **Tenant**: Empresa o entidad organizacional en un sistema multi-tenant
- **Webhook**: Mecanismo de notificación HTTP para eventos
- **OTP**: One-Time Password (Código de un solo uso)
- **SLA**: Service Level Agreement (Acuerdo de nivel de servicio)
- **Circuit Breaker**: Patrón para prevenir fallos en cascada

### 12.2 Referencias y Documentación

1. [Documentación de WhatsApp Business API](https://developers.facebook.com/docs/whatsapp/api/reference)
2. [Arquitectura Hexagonal (Puertos y Adaptadores)](https://alistair.cockburn.us/hexagonal-architecture/)
3. [Patrones Multi-tenant](https://docs.microsoft.com/en-us/azure/architecture/guide/multitenant/overview)
4. [Cloud Native Pattern - Sidecar](https://www.oreilly.com/library/view/cloud-native-infrastructure/9781492036142/)
5. [Patrones de Resiliencia para Microservicios](https://docs.microsoft.com/en-us/azure/architecture/patterns/category/resiliency)

### 12.3 Diagramas Adicionales

#### 12.3.1 Diagrama de Flujo para Procesamiento de Webhook

```
┌─────────────────┐     ┌────────────────┐     ┌─────────────────┐
│  WhatsApp API   │     │ Webhook Handler│     │  Procesador     │
│                 │     │                │     │  Asíncrono      │
└────────┬────────┘     └───────┬────────┘     └────────┬────────┘
         │                      │                       │
         │  1. Envía Webhook    │                       │
         │─────────────────────>│                       │
         │                      │                       │
         │  2. Respuesta 200 OK │                       │
         │<─────────────────────│                       │
         │                      │  3. Encola Tarea      │
         │                      │──────────────────────>│
         │                      │                       │
         │                      │                       │  4. Procesa
         │                      │                       │───┐
         │                      │                       │   │
         │                      │                       │<──┘
         │                      │                       │
         │                      │                       │  5. Actualiza BD
         │                      │                       │───┐
         │                      │                       │   │
         │                      │                       │<──┘
         │                      │                       │
         │                      │                       │  6. Notifica
         │                      │                       │───┐
         │                      │                       │   │
         │                      │                       │<──┘
```

#### 12.3.2 Diagrama de Estado para Mensajes

```
┌──────────────┐
│              │
│  PENDIENTE   │───────────────┐
│              │               │
└──────┬───────┘               │ Error de envío
       │                       │
       │ Enviado a WhatsApp    │
       │                       │
       ▼                       ▼
┌──────────────┐        ┌──────────────┐
│              │        │              │
│   ENVIADO    │        │    ERROR     │
│              │        │              │
└──────┬───────┘        └──────────────┘
       │
       │ Confirmación de entrega
       │
       ▼
┌──────────────┐
│              │
│  ENTREGADO   │
│              │
└──────┬───────┘
       │
       │ Confirmación de lectura
       │
       ▼
┌──────────────┐
│              │
│    LEÍDO     │
│              │
└──────────────┘
```

#### 12.3.3 Diagrama de Componentes con Multi-tenant

```
┌────────────────────────────────────────────────────┐
│                                                    │
│  Microservicio de WhatsApp                         │
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │ API Layer                                    │  │
│  │                                              │  │
│  │ ┌─────────────┐    ┌─────────────────┐       │  │
│  │ │ Webhook     │    │ Message         │       │  │
│  │ │ Handler     │    │ Controller      │       │  │
│  │ └─────────────┘    └─────────────────┘       │  │
│  │                                              │  │
│  └──────────────────────────────────────────────┘  │
│                      │                              │
│                      ▼                              │
│  ┌──────────────────────────────────────────────┐  │
│  │ Tenant Manager                               │  │
│  │                                              │  │
│  │ ┌─────────────┐    ┌─────────────────┐       │  │
│  │ │ Tenant      │    │ DB Connection   │       │  │
│  │ │ Resolver    │    │ Provider        │       │  │
│  │ └─────────────┘    └─────────────────┘       │  │
│  │                                              │  │
│  └──────────────────────────────────────────────┘  │
│                      │                              │
│                      ▼                              │
│  ┌──────────────────────────────────────────────┐  │
│  │ Application Services                          │  │
│  │                                              │  │
│  │ ┌─────────────┐    ┌─────────────────┐       │  │
│  │ │ Message     │    │ Conversation    │       │  │
│  │ │ Service     │    │ Service         │       │  │
│  │ └─────────────┘    └─────────────────┘       │  │
│  │                                              │  │
│  │ ┌─────────────┐    ┌─────────────────┐       │  │
│  │ │ Template    │    │ OTP             │       │  │
│  │ │ Service     │    │ Service         │       │  │
│  │ └─────────────┘    └─────────────────┘       │  │
│  │                                              │  │
│  └──────────────────────────────────────────────┘  │
│                      │                              │
│                      ▼                              │
│  ┌──────────────────────────────────────────────┐  │
│  │ Infrastructure Adapters                       │  │
│  │                                              │  │
│  │ ┌─────────────┐    ┌─────────────────┐       │  │
│  │ │ WhatsApp    │    │ PostgreSQL      │       │  │
│  │ │ Client      │    │ Repository      │       │  │
│  │ └─────────────┘    └─────────────────┘       │  │
│  │                                              │  │
│  │ ┌─────────────┐    ┌─────────────────┐       │  │
│  │ │ Redis       │    │ Orchestrator    │       │  │
│  │ │ Cache       │    │ Client          │       │  │
│  │ └─────────────┘    └─────────────────┘       │  │
│  │                                              │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

*Plan de desarrollo preparado: 10 de abril de 2025*  
*Versión del documento: 1.0*// adapters/api/webhook_handler.go
