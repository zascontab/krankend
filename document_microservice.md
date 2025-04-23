# Plan Maestro de Desarrollo: Microservicio de WhatsApp

## Resumen Ejecutivo

Este documento detalla el plan de desarrollo para implementar un microservicio de WhatsApp independiente que se integrará con la arquitectura existente basada en KrakenD API Gateway y el orquestador. El microservicio será diseñado para soportar casos de uso multiempresa y multiusuario, con funcionalidades para gestionar mensajería, OTP y asistencia por IA.

## 1. Visión General

### 1.1 Propósito del Microservicio

El servicio de WhatsApp actuará como un componente independiente responsable de:

1. Gestionar toda la comunicación con la API de WhatsApp (oficial y no oficial)
2. Enviar y recibir mensajes en nombre de diferentes empresas
3. Manejar webhooks entrantes de WhatsApp
4. Proporcionar interfaces consistentes para otros servicios
5. Garantizar la configuración específica por empresa para la comunicación
6. Gestionar sesiones de WhatsApp para cada número de teléfono

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
┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │
│  WhatsApp       │     │  WhatsApp Node  │
│  Business API   │     │  (Baileys)      │
│                 │     │                 │
└─────────────────┘     └─────────────────┘
```

## 2. Especificaciones Técnicas

### 2.1 Arquitectura del Microservicio

El servicio se basará en una arquitectura hexagonal (puertos y adaptadores) con dos componentes principales:

1. **Microservicio Go**: Componente principal con arquitectura hexagonal
2. **Servidor Node.js dockerizado**: Para integración con WhatsApp usando la biblioteca whiskeysockets/baileys

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
│  └──────────────┘   └──────┬───────┘              │
│                            │                       │
│                            ▼                       │
│  ┌─────────────────────────────────────────────┐  │
│  │                                             │  │
│  │  Gestor de Sesiones WhatsApp                │  │
│  │                                             │  │
│  │  - Gestión contenedores                     │  │
│  │  - Control ciclo de vida                    │  │
│  │  - Procesamiento QR                         │  │
│  │                                             │  │
│  └─────────────────────────────────────────────┘  │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 2.2 Tecnologías Propuestas

| Componente | Tecnología | Justificación |
|------------|------------|---------------|
| Lenguaje Principal | Go | Rendimiento, concurrencia, bajo consumo de recursos |
| Lenguaje Secundario | Node.js | Soporte para biblioteca whiskeysockets/baileys |
| Framework Web | Gin/Echo | Ligereza, rendimiento, middleware ecosystem |
| Base de Datos | PostgreSQL | Soporte para schemas, transacciones, queries complejas |
| Caché | Memcached | Alta performance, estructura de datos versátil, 100% opensource |
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
│ container_id           │      │ payload                │
│ server_url             │      │ processed              │
│ qr_code                │      │ process_result         │
│ session_type           │      │ created_at             │
│ status                 │      │ processed_at           │
│ expires_at             │      └────────────────────────┘
│ metadata               │
│ created_at             │
│ updated_at             │
└────────────────────────┘
```

### 2.4 Estrategia Multi-tenant

El microservicio implementará un modelo multi-tenant utilizando el enfoque de "Schema-per-tenant" para PostgreSQL:

1. **Datos Compartidos**:
   - Configuración global de cuenta WhatsApp
   - Webhooks recibidos antes de procesamiento
   - Métricas y estadísticas
   - Información de sesiones de WhatsApp
   
2. **Datos Específicos por Empresa**:
   - Conversaciones y mensajes
   - Plantillas personalizadas
   - Configuraciones específicas

**Implementación**:
- Crear schema dinámico por compañía 
- Middleware para determinar y seleccionar schema en cada solicitud
- Pool de conexiones separado por empresa para alto volumen

### 2.5 Gestión de Sesiones WhatsApp

La integración con WhatsApp se realizará a través de dos mecanismos:

1. **API oficial de WhatsApp Business**:
   - Para cuentas empresariales verificadas
   - Comunicación mediante HTTP API oficial

2. **Integración no oficial vía whiskeysockets/baileys**:
   - Para cuentas que no tienen acceso a la API oficial
   - Gestión mediante contenedores Docker con Node.js

**Gestión del ciclo de vida de sesiones**:

```
┌─────────────────────────────────────────────────────────┐
│                  Microservicio WhatsApp                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│    ┌─────────────┐         ┌───────────────────────┐    │
│    │             │         │                       │    │
│    │   API       │         │  Gestor de Sesiones   │    │
│    │   Gateway   │◀────────▶  WhatsApp             │    │
│    │             │         │                       │    │
│    └─────────────┘         └───────────┬───────────┘    │
│           ▲                            │                │
│           │                            │                │
│           │                            ▼                │
│    ┌─────────────┐         ┌───────────────────────┐    │
│    │             │         │                       │    │
│    │   Lógica    │         │  Pool de Instancias   │    │
│    │   Negocio   │◀────────▶  WhatsApp Node.js     │    │
│    │             │         │                       │    │
│    └─────────────┘         └───────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

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
| POST | `/api/accounts/{id}/session` | Iniciar/reiniciar sesión | admin |
| GET | `/api/accounts/{id}/session/status` | Obtener estado de sesión | read |
| GET | `/api/accounts/{id}/session/qr` | Obtener código QR | admin |
| DELETE | `/api/accounts/{id}/session` | Cerrar sesión | admin |

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

#### 3.2.3 Gestión de Sesiones WhatsApp

**Endpoint**: `POST /api/accounts/{id}/session`

**Cuerpo de la Solicitud**:
```json
{
  "session_type": "baileys",
  "restart": false,
  "metadata": {
    "client_version": "1.0.0"
  }
}
```

**Respuesta Exitosa (200 OK)**:
```json
{
  "session_id": "sess_12345",
  "status": "waiting_qr",
  "qr_url": "/api/accounts/abc123/session/qr",
  "created_at": "2025-04-10T15:30:45Z"
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

# Plan Maestro de Desarrollo: Microservicio de WhatsApp (Parte 2)

## 5. Arquitectura del Servidor Node.js de WhatsApp

### 5.1 Componentes del Servidor

El servidor Node.js se encargará de gestionar la comunicación directa con WhatsApp a través de la biblioteca whiskeysockets/baileys:

```
┌────────────────────────────────────────────────────┐
│                                                    │
│  Servidor WhatsApp Node.js                         │
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │                                            │   │
│  │  Gestor de Sesión                          │   │
│  │   - Inicio/Reconexión                      │   │
│  │   - Estado de conexión                     │   │
│  │   - Generación de QR                       │   │
│  │                                            │   │
│  └─────────────────┬──────────────────────────┘   │
│                    │                               │
│                    ▼                               │
│  ┌────────────────────────────────────────────┐   │
│  │                                            │   │
│  │  API REST                                  │   │
│  │   - Envío de mensajes                      │   │
│  │   - Recepción de eventos                   │   │
│  │   - Estado de sesión                       │   │
│  │                                            │   │
│  └─────────────────┬──────────────────────────┘   │
│                    │                               │
│                    ▼                               │
│  ┌────────────────────────────────────────────┐   │
│  │                                            │   │
│  │  Persistencia                              │   │
│  │   - Almacenamiento de sesión               │   │
│  │   - Caché de mensajes                      │   │
│  │                                            │   │
│  └────────────────────────────────────────────┘   │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 5.2 API del Servidor Node.js

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/api/session/init` | Iniciar sesión de WhatsApp |
| GET | `/api/session/status` | Verificar estado de la sesión |
| GET | `/api/session/qr` | Obtener código QR para autenticación |
| DELETE | `/api/session` | Cerrar sesión |
| POST | `/api/messages/send` | Enviar mensaje de texto |
| POST | `/api/messages/send-media` | Enviar mensaje con archivos |
| POST | `/api/messages/send-template` | Enviar mensaje con plantilla |

### 5.3 Dockerización y Gestión

Cada instancia del servidor Node.js será containerizada y gestionada por el microservicio principal:

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Instalar dependencias
COPY package*.json ./
RUN npm install

# Copiar código fuente
COPY src/ ./src/

# Variables de entorno por defecto
ENV PORT=8080
ENV SESSION_ID="default"
ENV DEBUG="true"
ENV STORE_SESSION="true"
ENV SESSION_PATH="/data/session"

# Volumen para persistencia de sesión
VOLUME ["/data/session"]

# Puerto de la API
EXPOSE ${PORT}

CMD ["node", "src/index.js"]
```

## 6. Plan de Desarrollo

### 6.1 Fases de Implementación

#### Fase 1: Servidor Node.js dockerizado (2 semanas)
- Refactorizar servidor Node.js existente para soportar containerización
- Implementar persistencia de sesión y configuración dinámica
- Desarrollar API REST completa para el servidor
- Implementar manejo de eventos (conexión, desconexión, mensajes)

#### Fase 2: Fundación del Microservicio Go (2-3 semanas)
- Configurar entorno de desarrollo y CI/CD
- Implementar esqueleto de la aplicación con arquitectura hexagonal
- Desarrollar modelo de datos y migraciones
- Configurar soporte multi-tenant básico

#### Fase 3: Gestor de Contenedores (2 semanas)
- Implementar la gestión de contenedores Docker
- Desarrollar el sistema de gestión de sesiones
- Integrar con base de datos multi-tenant
- Desarrollar sistema de monitoreo de sesiones

#### Fase 4: Funcionalidades Core (3-4 semanas)
- Implementar integración con API de WhatsApp Business
- Desarrollar gestión de conversaciones y mensajes
- Implementar procesamiento de webhooks
- Desarrollar cliente HTTP para comunicación con servicios externos

#### Fase 5: Integración y Servicios (2-3 semanas)
- Integrar con servicio IAM para autenticación/autorización
- Implementar funcionalidades OTP
- Desarrollar notificaciones para orquestador
- Implementar gestión de plantillas

#### Fase 6: Optimización y Testing (2-3 semanas)
- Desarrollar suite de pruebas automatizadas
- Implementar caching y optimización de rendimiento
- Mejorar observabilidad (logging, métricas, tracing)
- Documentación técnica completa

#### Fase 7: Despliegue y Estabilización (1-2 semanas)
- Configuración de producción
- Migraciones y onboarding iniciales
- Monitoreo en producción
- Ajustes finales

### 6.2 Cronograma Detallado

| Semana | Actividades | Entregables |
|--------|-------------|-------------|
| 1-2 | Desarrollo del servidor Node.js dockerizado | Servidor Node.js con API REST, Dockerfile |
| 3 | Configuración proyecto Go, estructura inicial | Repo, CI/CD, estructura base |
| 4 | Implementación de modelos, base de datos | Migraciones, entidades, repositorios |
| 5 | Gestión de contenedores Docker | Gestor de contenedores, sistema de aprovisionamiento |
| 6 | Gestión de sesiones WhatsApp | API de gestión de sesiones, procesamiento QR |
| 7 | Endpoints REST básicos, multi-tenant | API básica, middleware de tenant |
| 8 | Integración WhatsApp Business API | Cliente WhatsApp, envío mensajes |
| 9 | Recepción de webhooks, conversaciones | Procesamiento webhooks, gestor conversaciones |
| 10 | Desarrollo de plantillas, metadata | Sistema plantillas, gestor metadata |
| 11 | Integración con IAM | Autenticación/autorización completa |
| 12 | Funcionalidad OTP | Endpoints OTP, integración |
| 13 | Notificaciones al orquestador | Sistema eventos, notificaciones |
| 14 | Pruebas automatizadas | Suite tests unitarios e integración |
| 15 | Optimización de rendimiento | Caching, indices, mejoras rendimiento |
| 16 | Documentación y preparación | Docs técnicos, runbooks |

### 6.3 Desglose de Tareas

#### Fase 1: Servidor Node.js dockerizado

1. **Refactorización del código existente**
   - [ ] Refactorizar la aplicación actual para soportar configuración dinámica
   - [ ] Implementar sistema de persistencia de sesión
   - [ ] Desarrollar manejo de desconexiones y reconexiones
   - [ ] Implementar generación y renovación de códigos QR

2. **API REST del servidor**
   - [ ] Implementar endpoints para gestión de sesión
   - [ ] Desarrollar endpoints para envío de mensajes
   - [ ] Implementar recepción y reenvío de eventos de WhatsApp
   - [ ] Desarrollar manejo de errores y retry

3. **Dockerización**
   - [ ] Crear Dockerfile optimizado
   - [ ] Configurar volúmenes para persistencia
   - [ ] Implementar configuración mediante variables de entorno
   - [ ] Crear docker-compose para desarrollo y pruebas

4. **Pruebas y documentación**
   - [ ] Desarrollar pruebas unitarias
   - [ ] Implementar pruebas de integración
   - [ ] Crear documentación de la API
   - [ ] Desarrollar guía de uso

#### Fase 2: Fundación del Microservicio Go

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

#### Fase 3: Gestor de Contenedores

1. **Gestión de contenedores Docker**
   - [ ] Implementar cliente Docker para gestión de contenedores
   - [ ] Desarrollar función de creación de contenedores
   - [ ] Implementar monitoreo de estado de contenedores
   - [ ] Desarrollar gestión de ciclo de vida de contenedores

2. **Sistema de gestión de sesiones**
   - [ ] Desarrollar repositorio para almacenamiento de sesiones
   - [ ] Implementar lógica de descubrimiento de servicios
   - [ ] Desarrollar proceso de verificación de estado
   - [ ] Implementar rotación y reciclaje de sesiones

3. **API de gestión de sesiones**
   - [ ] Desarrollar endpoints para iniciar/detener sesiones
   - [ ] Implementar endpoint para obtención de QR
   - [ ] Desarrollar verificación de estado
   - [ ] Implementar monitoreo y reporting

4. **Integración con servidor Node.js**
   - [ ] Desarrollar cliente HTTP para API del servidor
   - [ ] Implementar manejo de errores y retries
   - [ ] Desarrollar mapeo de eventos
   - [ ] Implementar sincronización de estado

#### Fase 4: Funcionalidades Core

1. **Integración WhatsApp Business API**
   - [ ] Implementar cliente HTTP para WhatsApp API
   - [ ] Desarrollar métodos para envío de mensajes
   - [ ] Implementar manejo de respuestas y errores
   - [ ] Desarrollar funciones para gestión de media

2. **Gestión de conversaciones**
   - [ ] Implementar API para listar conversaciones
   - [ ] Desarrollar lógica para agrupar mensajes
   - [ ] Implementar búsqueda y filtrado
   - [ ] Desarrollar estado y metadata de conversaciones

3. **Procesamiento de webhooks**
   - [ ] Implementar endpoint para webhooks
   - [ ] Desarrollar parsing y validación
   - [ ] Implementar procesamiento asíncrono
   - [ ] Desarrollar sistema de retry para webhooks fallidos

4. **Sistema de mensajería**
   - [ ] Implementar cola de mensajes salientes
   - [ ] Desarrollar gestión de estados (enviado, entregado, leído)
   - [ ] Implementar mecanismos de reintento
   - [ ] Desarrollar sistema de prioridad de mensajes

#### Fase 5: Integración y Servicios

1. **Integración con IAM**
   - [ ] Implementar cliente para servicio IAM
   - [ ] Desarrollar middleware de autenticación
   - [ ] Implementar verificación de permisos
   - [ ] Desarrollar resolución de contexto de tenant

2. **Funcionalidad OTP**
   - [ ] Implementar endpoints para OTP
   - [ ] Desarrollar integración con servicio OTP
   - [ ] Implementar plantillas para mensajes OTP
   - [ ] Desarrollar verificación de respuestas OTP

3. **Notificaciones para orquestador**
   - [ ] Implementar sistema de eventos
   - [ ] Desarrollar cliente para notificaciones al orquestador
   - [ ] Implementar confirmación de procesamiento
   - [ ] Desarrollar sistema de retry para notificaciones

4. **Gestión de plantillas**
   - [ ] Implementar CRUD de plantillas
   - [ ] Desarrollar sistema de variables
   - [ ] Implementar validación según reglas de WhatsApp
   - [ ] Desarrollar versionamiento de plantillas

#### Fase 6: Optimización y Testing

1. **Pruebas automatizadas**
   - [ ] Implementar tests unitarios
   - [ ] Desarrollar tests de integración
   - [ ] Implementar mocks para servicios externos
   - [ ] Desarrollar tests de carga

2. **Optimización de rendimiento**
   - [ ] Implementar caching con Memcached
   - [ ] Optimizar consultas a base de datos
   - [ ] Desarrollar rate limiting
   - [ ] Implementar circuit breakers

3. **Observabilidad**
   - [ ] Configurar logging estructurado
   - [ ] Implementar métricas con Prometheus
   - [ ] Desarrollar tracing distribuido
   - [ ] Configurar health checks

4. **Documentación técnica**
   - [ ] Crear documentación API con OpenAPI/Swagger
   - [ ] Desarrollar guías de integración
   - [ ] Documentar arquitectura
   - [ ] Crear runbooks operacionales

#### Fase 7: Despliegue y Estabilización

1. **Configuración de producción**
   - [ ] Preparar manifiestos Kubernetes
   - [ ] Configurar variables de entorno para producción
   - [ ] Implementar políticas de seguridad
   - [ ] Configurar estrategias de deployment

2. **Migraciones iniciales**
   - [ ] Desarrollar scripts de migración para datos existentes
   - [ ] Implementar estrategia de rollback
   - [ ] Probar migraciones en ambiente staging
   - [ ] Ejecutar migraciones en producción

3. **Monitoreo en producción**
   - [ ] Configurar alertas
   - [ ] Implementar dashboards
   - [ ] Desarrollar scripts para análisis post-mortem
   - [ ] Configurar notificaciones

4. **Ajustes finales**
   - [ ] Optimizaciones basadas en uso real
   - [ ] Corrección de bugs
   - [ ] Ajustes de configuración
   - [ ] Documentación de lecciones aprendidas

## 7. Código Clave de Implementación

### 7.1 Middleware Multi-tenant

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

### 7.2 Cliente WhatsApp Business API

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

### 7.3 Gestor de Contenedores Docker

```go
// internal/infrastructure/container/manager.go
package container

import (
    "context"
    "fmt"
    
    "github.com/docker/docker/api/types"
    "github.com/docker/docker/api/types/container"
    "github.com/docker/docker/client"
)

// Manager gestiona los contenedores Docker para las sesiones de WhatsApp
type Manager struct {
    dockerClient *client.Client
    networkName  string
    imageName    string
}

// NewManager crea un nuevo gestor de contenedores
func NewManager(dockerEndpoint, networkName, imageName string) (*Manager, error) {
    cli, err := client.NewClientWithOpts(client.WithHost(dockerEndpoint), client.WithAPIVersionNegotiation())
    if err != nil {
        return nil, fmt.Errorf("error al conectar con Docker: %w", err)
    }
    
    return &Manager{
        dockerClient: cli,
        networkName:  networkName,
        imageName:    imageName,
    }, nil
}

// CreateContainer crea un contenedor para una sesión de WhatsApp
func (m *Manager) CreateContainer(ctx context.Context, accountID string, port int) (string, error) {
    sessionPath := fmt.Sprintf("/data/sessions/%s", accountID)
    
    // Configuración del contenedor
    config := &container.Config{
        Image: m.imageName,
        Env: []string{
            fmt.Sprintf("SESSION_ID=%s", accountID),
            fmt.Sprintf("PORT=%d", 8080),
            "STORE_SESSION=true",
            fmt.Sprintf("SESSION_PATH=%s", sessionPath),
        },
        ExposedPorts: nat.PortSet{
            nat.Port("8080/tcp"): struct{}{},
        },
    }
    
    // Host config (mapeo de puertos, volúmenes, etc.)
    hostConfig := &container.HostConfig{
        PortBindings: nat.PortMap{
            nat.Port("8080/tcp"): []nat.PortBinding{
                {
                    HostIP:   "0.0.0.0",
                    HostPort: fmt.Sprintf("%d", port),
                },
            },
        },
        Binds: []string{
            fmt.Sprintf("%s:%s", getVolumePath(accountID), sessionPath),
        },
    }
    
    // Crear el contenedor
    resp, err := m.dockerClient.ContainerCreate(
        ctx,
        config,
        hostConfig,
        nil,
        nil,
        fmt.Sprintf("whatsapp-%s", accountID),
    )
    if err != nil {
        return "", fmt.Errorf("error al crear contenedor: %w", err)
    }
    
    // Iniciar el contenedor
    if err := m.dockerClient.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
        return "", fmt.Errorf("error al iniciar contenedor: %w", err)
    }
    
    return resp.ID, nil
}

// StopContainer detiene un contenedor
func (m *Manager) StopContainer(ctx context.Context, containerID string) error {
    timeout := 30 // segundos para timeout
    if err := m.dockerClient.ContainerStop(ctx, containerID, container.StopOptions{
        Timeout: &timeout,
    }); err != nil {
        return fmt.Errorf("error al detener contenedor: %w", err)
    }
    return nil
}

// RemoveContainer elimina un contenedor
func (m *Manager) RemoveContainer(ctx context.Context, containerID string) error {
    if err := m.dockerClient.ContainerRemove(ctx, containerID, types.ContainerRemoveOptions{
        Force: true,
    }); err != nil {
        return fmt.Errorf("error al eliminar contenedor: %w", err)
    }
    return nil
}

// GetContainerStatus obtiene el estado de un contenedor
func (m *Manager) GetContainerStatus(ctx context.Context, containerID string) (string, error) {
    container, err := m.dockerClient.ContainerInspect(ctx, containerID)
    if err != nil {
        return "", fmt.Errorf("error al inspeccionar contenedor: %w", err)
    }
    return container.State.Status, nil
}

// Métodos auxiliares
func getVolumePath(accountID string) string {
    return fmt.Sprintf("whatsapp_session_%s", accountID)
}
```

### 7.4 Servicio de Gestión de Sesiones

```go
// internal/application/session_service.go
package application

import (
    "context"
    "fmt"
    "time"
    
    "github.com/your-org/whatsapp-service/internal/domain"
    "github.com/your-org/whatsapp-service/internal/infrastructure/container"
)

// SessionService gestiona las sesiones de WhatsApp
type SessionService struct {
    sessionRepo       domain.SessionRepository
    accountRepo       domain.AccountRepository
    containerManager  *container.Manager
    basePort          int
    portIncrement     int
}

// NewSessionService crea un nuevo servicio de sesiones
func NewSessionService(
    sessionRepo domain.SessionRepository,
    accountRepo domain.AccountRepository,
    containerManager *container.Manager,
    basePort int,
    portIncrement int,
) *SessionService {
    return &SessionService{
        sessionRepo:      sessionRepo,
        accountRepo:      accountRepo,
        containerManager: containerManager,
        basePort:         basePort,
        portIncrement:    portIncrement,
    }
}

// InitializeSession inicializa una sesión de WhatsApp para una cuenta
func (s *SessionService) InitializeSession(ctx context.Context, accountID string) (*domain.Session, error) {
    // Verificar si la cuenta existe
    account, err := s.accountRepo.GetByID(ctx, accountID)
    if err != nil {
        return nil, fmt.Errorf("error al obtener cuenta: %w", err)
    }
    
    // Verificar si ya existe una sesión
    existingSession, err := s.sessionRepo.GetByAccountID(ctx, accountID)
    if err == nil && existingSession.Status == domain.SessionStatusActive {
        return existingSession, nil
    }
    
    // Calcular puerto para este contenedor
    port := s.basePort + (account.PortIndex * s.portIncrement)
    
    // Crear contenedor para esta sesión
    containerID, err := s.containerManager.CreateContainer(ctx, accountID, port)
    if err != nil {
        return nil, fmt.Errorf("error al crear contenedor: %w", err)
    }
    
    // Crear o actualizar registro de sesión
    session := &domain.Session{
        AccountID:   accountID,
        ContainerID: containerID,
        ServerURL:   fmt.Sprintf("http://localhost:%d", port),
        Status:      domain.SessionStatusInitializing,
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }
    
    // Guardar sesión
    if existingSession != nil {
        session.ID = existingSession.ID
        if err := s.sessionRepo.Update(ctx, session); err != nil {
            return nil, fmt.Errorf("error al actualizar sesión: %w", err)
        }
    } else {
        if err := s.sessionRepo.Create(ctx, session); err != nil {
            return nil, fmt.Errorf("error al crear sesión: %w", err)
        }
    }
    
    // Iniciar proceso de obtención de código QR (asíncrono)
    go s.monitorSessionInitialization(context.Background(), session)
    
    return session, nil
}

// GetSessionQR obtiene el código QR para autenticación
func (s *SessionService) GetSessionQR(ctx context.Context, accountID string) (string, error) {
    session, err := s.sessionRepo.GetByAccountID(ctx, accountID)
    if err != nil {
        return "", fmt.Errorf("sesión no encontrada: %w", err)
    }
    
    if session.Status != domain.SessionStatusWaitingQR {
        return "", fmt.Errorf("sesión no está en espera de escaneo QR")
    }
    
    // Llamar al API del contenedor para obtener el QR actual
    qrCode, err := s.getQRFromContainer(ctx, session)
    if err != nil {
        return "", fmt.Errorf("error al obtener código QR: %w", err)
    }
    
    return qrCode, nil
}

// CloseSession cierra una sesión de WhatsApp
func (s *SessionService) CloseSession(ctx context.Context, accountID string) error {
    session, err := s.sessionRepo.GetByAccountID(ctx, accountID)
    if err != nil {
        return fmt.Errorf("sesión no encontrada: %w", err)
    }
    
    // Detener y eliminar contenedor
    if err := s.containerManager.StopContainer(ctx, session.ContainerID); err != nil {
        return fmt.Errorf("error al detener contenedor: %w", err)
    }
    
    if err := s.containerManager.RemoveContainer(ctx, session.ContainerID); err != nil {
        return fmt.Errorf("error al eliminar contenedor: %w", err)
    }
    
    // Actualizar estado de la sesión
    session.Status = domain.SessionStatusClosed
    session.UpdatedAt = time.Now()
    
    if err := s.sessionRepo.Update(ctx, session); err != nil {
        return fmt.Errorf("error al actualizar sesión: %w", err)
    }
    
    return nil
}

## 7. Código Clave de Implementación (Continuación)

### 7.4 Servicio de Gestión de Sesiones (Continuación)

```go
// monitorSessionInitialization monitorea el proceso de inicialización
func (s *SessionService) monitorSessionInitialization(ctx context.Context, session *domain.Session) {
    // Esperar a que el contenedor esté listo
    time.Sleep(5 * time.Second)
    
    // Verificar si el contenedor está corriendo
    status, err := s.containerManager.GetContainerStatus(ctx, session.ContainerID)
    if err != nil || status != "running" {
        s.handleSessionError(ctx, session, fmt.Errorf("contenedor no está corriendo: %s", status))
        return
    }
    
    // Inicializar sesión en el servidor Node.js
    qrCode, err := s.initializeSessionInContainer(ctx, session)
    if err != nil {
        s.handleSessionError(ctx, session, err)
        return
    }
    
    // Actualizar sesión con código QR
    session.QRCode = qrCode
    session.Status = domain.SessionStatusWaitingQR
    session.UpdatedAt = time.Now()
    
    if err := s.sessionRepo.Update(ctx, session); err != nil {
        s.handleSessionError(ctx, session, err)
        return
    }
    
    // Iniciar monitoreo de estado (en un loop)
    go s.monitorSessionStatus(ctx, session)
}

// Métodos auxiliares para interactuar con el contenedor
func (s *SessionService) initializeSessionInContainer(ctx context.Context, session *domain.Session) (string, error) {
    // Implementación para inicializar sesión y obtener QR
    // ...
    return "QR-CODE-DATA", nil
}

func (s *SessionService) getQRFromContainer(ctx context.Context, session *domain.Session) (string, error) {
    // Implementación para obtener QR de un contenedor
    // ...
    return session.QRCode, nil
}

func (s *SessionService) handleSessionError(ctx context.Context, session *domain.Session, err error) {
    // Manejar error de sesión, actualizar estado, etc.
    // ...
}

func (s *SessionService) monitorSessionStatus(ctx context.Context, session *domain.Session) {
    // Monitorear estado de la sesión
    // ...
}
```

### 7.5 Servidor Node.js (index.js)

```javascript
// src/index.js
const express = require('express');
const { default: makeWASocket, DisconnectReason, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const fs = require('fs');
const path = require('path');

// Configuración
const PORT = process.env.PORT || 8080;
const SESSION_ID = process.env.SESSION_ID || 'default';
const SESSION_PATH = process.env.SESSION_PATH || './sessions';
const STORE_SESSION = process.env.STORE_SESSION === 'true';
const DEBUG = process.env.DEBUG === 'true';

// Asegurar que el directorio de sesiones existe
const sessionDir = path.join(SESSION_PATH, SESSION_ID);
if (!fs.existsSync(sessionDir)) {
    fs.mkdirSync(sessionDir, { recursive: true });
}

// Estado global
let sock = null;
let connectionState = 'disconnected';
let qrCode = null;

// Inicializar Express
const app = express();
app.use(express.json());

// Middleware de logging
if (DEBUG) {
    app.use((req, res, next) => {
        console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
        next();
    });
}

// Función para inicializar la conexión WhatsApp
async function connectToWhatsApp() {
    const { state, saveCreds } = await useMultiFileAuthState(sessionDir);
    
    sock = makeWASocket({
        auth: state,
        printQRInTerminal: DEBUG,
        logger: DEBUG ? console : undefined,
    });
    
    // Manejar conexión
    sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;
        
        if (qr) {
            qrCode = qr;
            console.log('QR Code generado');
        }
        
        if (connection) {
            connectionState = connection;
            console.log('Estado de conexión:', connection);
        }
        
        if (connection === 'open') {
            console.log('Conexión establecida!');
        }
        
        if (connection === 'close') {
            const shouldReconnect = lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
            console.log('Conexión cerrada debido a:', lastDisconnect?.error?.message);
            
            if (shouldReconnect) {
                console.log('Reconectando...');
                connectToWhatsApp();
            } else {
                console.log('No reconectando, sesión cerrada');
            }
        }
    });
    
    // Guardar credenciales cuando se actualizan
    sock.ev.on('creds.update', saveCreds);
    
    // Manejar mensajes entrantes
    sock.ev.on('messages.upsert', async (m) => {
        if (m.type === 'notify') {
            for (const msg of m.messages) {
                if (!msg.key.fromMe) {
                    console.log('Mensaje recibido:', msg.message);
                    // Aquí puedes implementar webhook para notificar al microservicio Go
                }
            }
        }
    });
}

// Endpoints de la API

// Iniciar/reiniciar sesión
app.post('/api/session/init', async (req, res) => {
    try {
        if (sock && connectionState === 'open') {
            await sock.logout();
        }
        
        await connectToWhatsApp();
        
        res.status(200).json({
            status: 'initializing',
            sessionId: SESSION_ID
        });
    } catch (error) {
        console.error('Error al inicializar sesión:', error);
        res.status(500).json({ error: 'Error al inicializar sesión' });
    }
});

// Obtener estado de la sesión
app.get('/api/session/status', (req, res) => {
    res.status(200).json({
        status: connectionState,
        sessionId: SESSION_ID,
        hasQR: !!qrCode
    });
});

// Obtener código QR
app.get('/api/session/qr', (req, res) => {
    if (!qrCode) {
        return res.status(404).json({ error: 'Código QR no disponible' });
    }
    
    res.status(200).json({
        qr: qrCode
    });
});

// Cerrar sesión
app.delete('/api/session', async (req, res) => {
    try {
        if (sock) {
            await sock.logout();
            sock = null;
            connectionState = 'disconnected';
            qrCode = null;
        }
        
        res.status(200).json({
            status: 'disconnected',
            sessionId: SESSION_ID
        });
    } catch (error) {
        console.error('Error al cerrar sesión:', error);
        res.status(500).json({ error: 'Error al cerrar sesión' });
    }
});

// Enviar mensaje de texto
app.post('/api/messages/send', async (req, res) => {
    try {
        const { to, message } = req.body;
        
        if (!to || !message) {
            return res.status(400).json({ error: 'Se requieren los campos "to" y "message"' });
        }
        
        if (!sock || connectionState !== 'open') {
            return res.status(503).json({ error: 'No hay sesión activa' });
        }
        
        const normalizedNumber = `${to.replace(/\D/g, '')}@s.whatsapp.net`;
        
        const result = await sock.sendMessage(normalizedNumber, { text: message });
        
        res.status(200).json({
            status: 'sent',
            messageId: result.key.id,
            to: to
        });
    } catch (error) {
        console.error('Error al enviar mensaje:', error);
        res.status(500).json({ error: 'Error al enviar mensaje' });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'ok',
        connectionState,
        sessionId: SESSION_ID
    });
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`Servidor WhatsApp iniciado en puerto ${PORT}`);
    
    // Iniciar conexión WhatsApp si STORE_SESSION está habilitado
    if (STORE_SESSION) {
        connectToWhatsApp().catch(err => {
            console.error('Error al iniciar conexión automática:', err);
        });
    }
});
```

## 8. Configuración de Infraestructura

### 8.1 Docker Compose para Desarrollo

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:14-alpine
    environment:
      POSTGRES_USER: whatsapp
      POSTGRES_PASSWORD: whatsapp123
      POSTGRES_DB: whatsapp_service
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U whatsapp"]
      interval: 10s
      timeout: 5s
      retries: 5

  memcached:
    image: memcached:1.6-alpine
    ports:
      - "11211:11211"

  whatsapp-service:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - DB_HOST=postgres
      - DB_USER=whatsapp
      - DB_PASSWORD=whatsapp123
      - DB_NAME=whatsapp_service
      - DB_PORT=5432
      - MEMCACHED_SERVERS=memcached:11211
      - DOCKER_HOST=unix:///var/run/docker.sock
      - CONTAINER_NETWORK=whatsapp-network
      - BASE_PORT=8500
      - LOG_LEVEL=debug
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - whatsapp-sessions:/data/sessions
    depends_on:
      - postgres
      - memcached

networks:
  default:
    name: whatsapp-network

volumes:
  postgres-data:
  whatsapp-sessions:
```

### 8.2 Kubernetes para Producción

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whatsapp-service
  namespace: messaging
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whatsapp-service
  template:
    metadata:
      labels:
        app: whatsapp-service
    spec:
      containers:
      - name: whatsapp-service
        image: your-registry/whatsapp-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: whatsapp-config
              key: db_host
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: whatsapp-secrets
              key: db_user
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: whatsapp-secrets
              key: db_password
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: whatsapp-config
              key: db_name
        - name: MEMCACHED_SERVERS
          valueFrom:
            configMapKeyRef:
              name: whatsapp-config
              key: memcached_servers
        - name: CONTAINER_NETWORK
          value: "whatsapp-network"
        - name: LOG_LEVEL
          value: "info"
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run/docker.sock
        - name: whatsapp-sessions
          mountPath: /data/sessions
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
      - name: whatsapp-sessions
        persistentVolumeClaim:
          claimName: whatsapp-sessions-pvc
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
    targetPort: 8080
  type: ClusterIP
```

```yaml
# kubernetes/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: whatsapp-config
  namespace: messaging
data:
  db_host: "postgres.database.svc.cluster.local"
  db_name: "whatsapp_service_prod"
  memcached_servers: "memcached.cache.svc.cluster.local:11211"
```

```yaml
# kubernetes/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: whatsapp-sessions-pvc
  namespace: messaging
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: nfs-client
```

### 8.3 Dockerfile para el Servicio Principal

```dockerfile
FROM golang:1.20-alpine AS builder

WORKDIR /app

# Instalar dependencias
RUN apk add --no-cache git

# Copiar módulos Go
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o whatsapp-service ./cmd/api

# Imagen final
FROM alpine:3.17

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache ca-certificates tzdata docker-cli

# Copiar binario compilado
COPY --from=builder /app/whatsapp-service .

# Copiar archivos de configuración
COPY config /app/config

# Crear directorio para sesiones
RUN mkdir -p /data/sessions

# Exponer puerto
EXPOSE 8080

# Comando de inicio
CMD ["/app/whatsapp-service"]
```

### 8.4 Esquema de Base de Datos (Migración)

```sql
-- Migración inicial para la base de datos

-- Tabla de cuentas WhatsApp
CREATE TABLE whatsapp_accounts (
    id VARCHAR(36) PRIMARY KEY,
    company_id VARCHAR(36) NOT NULL,
    business_id VARCHAR(36) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    waba_id VARCHAR(36),
    api_key VARCHAR(255),
    webhook_secret VARCHAR(255) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    port_index INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE (phone_number)
);

CREATE INDEX idx_whatsapp_accounts_company_id ON whatsapp_accounts(company_id);
CREATE INDEX idx_whatsapp_accounts_business_id ON whatsapp_accounts(business_id);

-- Tabla de sesiones
CREATE TABLE whatsapp_sessions (
    id VARCHAR(36) PRIMARY KEY,
    account_id VARCHAR(36) NOT NULL,
    container_id VARCHAR(255),
    server_url VARCHAR(255),
    qr_code TEXT,
    session_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    expires_at TIMESTAMP,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    FOREIGN KEY (account_id) REFERENCES whatsapp_accounts(id) ON DELETE CASCADE,
    UNIQUE (account_id)
);

-- Tabla de plantillas
CREATE TABLE whatsapp_templates (
    id VARCHAR(36) PRIMARY KEY,
    account_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    template_id VARCHAR(255),
    language VARCHAR(10) NOT NULL,
    content TEXT NOT NULL,
    variables JSONB,
    category VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    FOREIGN KEY (account_id) REFERENCES whatsapp_accounts(id) ON DELETE CASCADE,
    UNIQUE (account_id, name)
);

CREATE INDEX idx_whatsapp_templates_account_id ON whatsapp_templates(account_id);

-- Tabla de eventos webhook recibidos
CREATE TABLE webhook_events (
    id VARCHAR(36) PRIMARY KEY,
    account_id VARCHAR(36) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    processed BOOLEAN NOT NULL DEFAULT FALSE,
    process_result JSONB,
    created_at TIMESTAMP NOT NULL,
    processed_at TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES whatsapp_accounts(id) ON DELETE CASCADE
);

CREATE INDEX idx_webhook_events_account_id ON webhook_events(account_id);
CREATE INDEX idx_webhook_events_processed ON webhook_events(processed);
CREATE INDEX idx_webhook_events_created_at ON webhook_events(created_at);

-- Función para crear esquema de tenant
CREATE OR REPLACE FUNCTION create_tenant_schema(tenant_id VARCHAR)
RETURNS VOID AS $$
BEGIN
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS tenant_%s', tenant_id);
    
    -- Crear tablas específicas del tenant
    EXECUTE format('
        CREATE TABLE tenant_%s.conversations (
            id VARCHAR(36) PRIMARY KEY,
            account_id VARCHAR(36) NOT NULL,
            contact_phone VARCHAR(20) NOT NULL,
            contact_name VARCHAR(255),
            status VARCHAR(20) NOT NULL,
            last_message_at TIMESTAMP,
            metadata JSONB,
            created_at TIMESTAMP NOT NULL,
            updated_at TIMESTAMP NOT NULL
        )', tenant_id);
    
    EXECUTE format('
        CREATE INDEX idx_conversations_account_id ON tenant_%s.conversations(account_id)', tenant_id);
    
    EXECUTE format('
        CREATE INDEX idx_conversations_contact_phone ON tenant_%s.conversations(contact_phone)', tenant_id);
    
    EXECUTE format('
        CREATE TABLE tenant_%s.messages (
            id VARCHAR(36) PRIMARY KEY,
            conversation_id VARCHAR(36) NOT NULL,
            message_type VARCHAR(20) NOT NULL,
            direction VARCHAR(10) NOT NULL,
            content TEXT,
            media_url VARCHAR(255),
            status VARCHAR(20) NOT NULL,
            whatsapp_message_id VARCHAR(255),
            metadata JSONB,
            sent_at TIMESTAMP,
            delivered_at TIMESTAMP,
            read_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL,
            updated_at TIMESTAMP NOT NULL,
            FOREIGN KEY (conversation_id) REFERENCES tenant_%s.conversations(id) ON DELETE CASCADE
        )', tenant_id, tenant_id);
    
    EXECUTE format('
        CREATE INDEX idx_messages_conversation_id ON tenant_%s.messages(conversation_id)', tenant_id);
    
    EXECUTE format('
        CREATE INDEX idx_messages_created_at ON tenant_%s.messages(created_at)', tenant_id);
END;
$$ LANGUAGE plpgsql;
```

### 8.5 Script de Inicialización para Memcached

```bash
#!/bin/bash
# Este script configura los espacios de Memcached para distintos tenants

# Host de Memcached
MEMCACHED_HOST=${MEMCACHED_HOST:-"localhost"}
MEMCACHED_PORT=${MEMCACHED_PORT:-"11211"}

# Lista de tenants a configurar
declare -a TENANTS=("company_1" "company_2" "company_3")

# Función para verificar si Memcached está funcionando
function check_memcached() {
    echo "stats" | nc $MEMCACHED_HOST $MEMCACHED_PORT > /dev/null
    return $?
}

# Esperar a que Memcached esté disponible
echo "Esperando a que Memcached esté disponible..."
while ! check_memcached; do
    echo "Memcached aún no está disponible, reintentando en 5 segundos..."
    sleep 5
done

# Configurar claves iniciales para cada tenant
for tenant in "${TENANTS[@]}"; do
    echo "Configurando tenant: $tenant"
    
    # Configurar contador de sesiones (inicializar en 0)
    echo "set ${tenant}:session_count 0 0 1" | nc $MEMCACHED_HOST $MEMCACHED_PORT
    echo "0" | nc $MEMCACHED_HOST $MEMCACHED_PORT
    
    # Configurar contador de mensajes enviados (inicializar en 0)
    echo "set ${tenant}:messages_sent 0 0 1" | nc $MEMCACHED_HOST $MEMCACHED_PORT
    echo "0" | nc $MEMCACHED_HOST $MEMCACHED_PORT
    
    # Configurar contador de mensajes recibidos (inicializar en 0)
    echo "set ${tenant}:messages_received 0 0 1" | nc $MEMCACHED_HOST $MEMCACHED_PORT
    echo "0" | nc $MEMCACHED_HOST $MEMCACHED_PORT
    
    echo "Tenant $tenant configurado correctamente."
done

echo "Inicialización de Memcached completada."
```

# Plan Maestro de Desarrollo: Microservicio de WhatsApp (Parte 3)

## 9. Documentación Operativa

### 9.1 Guía de Instalación

1. **Requisitos previos**:
   - Go 1.20+
   - Docker y Docker Compose
   - PostgreSQL 14+
   - Memcached 1.6+
   - Node.js 18+ (solo para desarrollo)

2. **Configuración de desarrollo**:
   ```bash
   # Clonar repositorio
   git clone https://github.com/your-org/whatsapp-service.git
   cd whatsapp-service
   
   # Construir imagen del servidor Node.js
   cd whatsapp-node
   docker build -t whatsapp-node:latest .
   cd ..
   
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
   # Construir imágenes Docker
   docker build -t your-registry/whatsapp-node:latest ./whatsapp-node
   docker build -t your-registry/whatsapp-service:latest .
   
   # Enviar imágenes al registro
   docker push your-registry/whatsapp-node:latest
   docker push your-registry/whatsapp-service:latest
   
   # Aplicar configuración de Kubernetes
   kubectl apply -f kubernetes/
   ```

### 9.2 Guía de Monitoreo

1. **Métricas clave**:
   - Tasa de mensajes enviados/recibidos
   - Tiempo de procesamiento de webhook
   - Latencia de API WhatsApp
   - Número de sesiones activas
   - Estado de contenedores WhatsApp
   - Uso de memoria/CPU por tenant
   - Errores de envío

2. **Endpoints de salud**:
   - `/health` - Estado general del servicio
   - `/health/whatsapp` - Conectividad con WhatsApp API
   - `/health/whatsapp-node` - Estado de sesiones WhatsApp Node.js
   - `/health/db` - Estado de base de datos
   - `/health/memcached` - Estado de caché
   - `/metrics` - Métricas en formato Prometheus

3. **Alertas recomendadas**:
   - Alto porcentaje de errores en envío (>5%)
   - Aumento repentino en latencia (>500ms)
   - Fallas en webhook (>3 consecutivas)
   - Alta utilización de memoria (>80%)
   - Contenedores crasheando
   - Sesiones inactivas o desconectadas

### 9.3 Troubleshooting

1. **Problemas comunes y soluciones**:

   **Error en envío de mensajes**:
   - Verificar conectividad con API de WhatsApp
   - Comprobar credenciales y permisos
   - Revisar logs para errores específicos
   - Verificar estado del contenedor para esa sesión
   - Verificar rate limits de WhatsApp

   **Webhook no procesa mensajes**:
   - Verificar firma de webhook
   - Comprobar procesamiento asíncrono
   - Revisar logs de errores
   - Verificar conexión a base de datos

   **Problemas de sesión WhatsApp**:
   - Verificar estado del contenedor Docker
   - Reiniciar sesión en caso de problema persistente
   - Comprobar QR code y autenticación
   - Revisar logs del contenedor de sesión

   **Problemas de multi-tenant**:
   - Verificar que tenant_id se propaga correctamente
   - Comprobar esquemas de base de datos
   - Revisar conexiones a base de datos

2. **Comandos útiles**:
   ```bash
   # Ver logs del microservicio
   kubectl logs -f deploy/whatsapp-service -n messaging
   
   # Ver logs de un contenedor de sesión WhatsApp
   docker logs whatsapp-{account_id}
   
   # Verificar estado de un contenedor
   docker inspect --format='{{.State.Status}}' whatsapp-{account_id}
   
   # Reiniciar un contenedor de sesión
   docker restart whatsapp-{account_id}
   
   # Verificar conectividad con base de datos
   kubectl exec -it deploy/whatsapp-service -n messaging -- bash -c "pg_isready -h \$DB_HOST -p \$DB_PORT -U \$DB_USER"
   
   # Verificar conectividad con Memcached
   kubectl exec -it deploy/whatsapp-service -n messaging -- bash -c "echo stats | nc \$MEMCACHED_SERVERS"
   
   # Obtener métricas
   curl http://whatsapp-service.messaging/metrics
   
   # Reiniciar servicio
   kubectl rollout restart deploy/whatsapp-service -n messaging
   ```

### 9.4 Gestión de Sesiones WhatsApp

1. **Inicializar una sesión**:
   ```bash
   # Usando curl
   curl -X POST "http://whatsapp-service.messaging/api/accounts/{id}/session" \
     -H "Content-Type: application/json" \
     -d '{"session_type": "baileys", "restart": false}'
   ```

2. **Obtener QR Code para autenticar**:
   ```bash
   # Obtener el QR code (accesible vía navegador)
   curl "http://whatsapp-service.messaging/api/accounts/{id}/session/qr"
   ```

3. **Verificar estado de sesión**:
   ```bash
   # Comprobar estado actual
   curl "http://whatsapp-service.messaging/api/accounts/{id}/session/status"
   ```

4. **Cerrar sesión**:
   ```bash
   # Cerrar sesión y detener contenedor
   curl -X DELETE "http://whatsapp-service.messaging/api/accounts/{id}/session"
   ```

## 10. Documentación para Desarrolladores
# Plan Maestro de Desarrollo: Microservicio de WhatsApp (Parte 3 - Continuación)

## 10. Documentación para Desarrolladores (Continuación)

### 10.1 Estructura del Proyecto (Continuación)

```
whatsapp-service/
├── cmd/
│   ├── api/             # Punto de entrada para el servidor API
│   └── migrate/         # Herramienta para migraciones de base de datos
├── config/              # Configuraciones por entorno
├── docs/                # Documentación adicional
├── internal/
│   ├── adapters/        # Adaptadores (implementaciones de puertos)
│   │   ├── db/          # Repositorios para base de datos
│   │   ├── http/        # Controladores HTTP
│   │   ├── whatsapp/    # Cliente para WhatsApp API
│   │   └── memcached/   # Cliente para Memcached
│   ├── application/     # Servicios de aplicación
│   ├── domain/          # Entidades de dominio y reglas de negocio
│   ├── ports/           # Interfaces (puertos)
│   │   ├── repositories/  # Interfaces para repositorios
│   │   └── services/      # Interfaces para servicios
│   └── infrastructure/  # Configuración de infraestructura
│       ├── config/      # Configuración de la aplicación
│       ├── container/   # Gestión de contenedores Docker
│       ├── server/      # Configuración del servidor HTTP
│       └── tenant/      # Gestión de multi-tenant
├── kubernetes/          # Manifiestos Kubernetes
├── migrations/          # Migraciones de base de datos
├── whatsapp-node/       # Servidor Node.js para WhatsApp
│   ├── src/
│   ├── Dockerfile
│   └── package.json
├── docker-compose.yml   # Configuración para desarrollo
├── Dockerfile           # Construcción de imagen principal
├── go.mod               # Dependencias Go
└── README.md            # Documentación principal
```

### 10.2 Flujo de Desarrollo

1. **Configuración del Entorno**:
   - Instalar Go, Docker, Docker Compose
   - Configurar acceso a la base de datos
   - Instalar extensiones y herramientas de desarrollo recomendadas

2. **Clonación y Configuración Inicial**:
   ```bash
   # Clonar repositorio
   git clone https://github.com/your-org/whatsapp-service.git
   cd whatsapp-service
   
   # Instalar dependencias Go
   go mod download
   
   # Configurar variables de entorno
   cp .env.example .env
   # Modificar .env según sea necesario
   ```

3. **Ciclo de Desarrollo**:
   - Escribir tests para la nueva funcionalidad
   - Implementar código
   - Ejecutar tests locales
   - Verificar funcionamiento en entorno de desarrollo
   - Enviar PR para revisión

4. **Contribución al Proyecto**:
   - Crear una rama a partir de `develop`
   - Hacer commit de los cambios siguiendo el formato de commit
   - Asegurar que todos los tests pasan
   - Crear PR para `develop`
   - Resolver comentarios en la revisión de código

### 10.3 Interacción con WhatsApp

#### 10.3.1 API de WhatsApp Business

Para interactuar con la API oficial de WhatsApp Business:

1. **Envío de Mensaje de Texto**:
   ```go
   client := whatsapp.NewClient(apiKey, baseURL, apiVersion)
   response, err := client.SendTextMessage(accountID, phoneNumber, "Hola, este es un mensaje de prueba")
   if err != nil {
       log.Errorf("Error al enviar mensaje: %v", err)
       return err
   }
   log.Infof("Mensaje enviado: %s", response.MessageID)
   ```

2. **Envío de Plantilla**:
   ```go
   variables := map[string]string{
       "name": "Juan",
       "code": "12345"
   }
   response, err := client.SendTemplateMessage(accountID, phoneNumber, templateName, language, variables)
   ```

3. **Envío de Archivos**:
   ```go
   response, err := client.SendMediaMessage(accountID, phoneNumber, mediaType, url, caption)
   ```

#### 10.3.2 API del Servidor Node.js (Baileys)

Para interactuar con el servidor Node.js que usa Baileys:

1. **Iniciar Sesión**:
   ```go
   client := nodejsapi.NewClient(serverURL)
   err := client.InitSession()
   if err != nil {
       log.Errorf("Error al iniciar sesión: %v", err)
       return err
   }
   ```

2. **Obtener QR Code**:
   ```go
   qrCode, err := client.GetQRCode()
   if err != nil {
       log.Errorf("Error al obtener QR: %v", err)
       return err
   }
   ```

3. **Enviar Mensaje**:
   ```go
   response, err := client.SendMessage(phoneNumber, "Hola, este es un mensaje de prueba")
   if err != nil {
       log.Errorf("Error al enviar mensaje: %v", err)
       return err
   }
   ```

### 10.4 Extensión del Servicio

Para extender el servicio con nuevas funcionalidades, seguir estos patrones:

1. **Agregar un nuevo Endpoint**:
   - Definir el endpoint en la interfaz del puerto correspondiente
   - Implementar la lógica en el servicio de aplicación
   - Agregar el controlador HTTP en los adaptadores
   - Registrar la ruta en el servidor

   Ejemplo:
   ```go
   // Definir puerto
   type MessageService interface {
       SendBulkMessages(ctx context.Context, req domain.BulkMessageRequest) ([]domain.MessageResponse, error)
   }
   
   // Implementar en servicio
   func (s *messageService) SendBulkMessages(ctx context.Context, req domain.BulkMessageRequest) ([]domain.MessageResponse, error) {
       // Implementación
   }
   
   // Agregar controlador
   func (h *MessageHandler) SendBulkMessages(c *gin.Context) {
       // Implementación del controlador
   }
   
   // Registrar ruta
   router.POST("/api/messages/bulk", handler.SendBulkMessages)
   ```

2. **Agregar soporte para nuevo Tipo de Mensaje**:
   - Extender el modelo de dominio
   - Actualizar el cliente de WhatsApp
   - Implementar mapeo entre formatos
   - Actualizar documentación

3. **Agregar una nueva Integración**:
   - Definir interfaces en los puertos
   - Implementar el cliente en adaptadores
   - Configurar inyección de dependencias
   - Actualizar configuración

## 11. Conclusiones y Siguientes Pasos

### 11.1 Resumen del Plan

El plan de desarrollo presentado establece una ruta clara para implementar un microservicio de WhatsApp independiente y robusto que se integrará perfectamente con la arquitectura actual basada en KrakenD API Gateway y el orquestador. 

La solución propuesta se basa en dos componentes principales:

1. **Microservicio en Go**: Que implementa una arquitectura hexagonal para gestionar la lógica de negocio, interfaces con otros servicios y la orquestación de contenedores Docker.

2. **Servidor Node.js dockerizado**: Que maneja la comunicación directa con WhatsApp a través de la biblioteca whiskeysockets/baileys, permitiendo la gestión de sesiones individuales por número.

Este enfoque combina la robustez, rendimiento y capacidades de concurrencia de Go con la compatibilidad directa de Node.js con la API no oficial de WhatsApp, ofreciendo una solución flexible que puede adaptarse tanto a la API oficial de WhatsApp Business como a la alternativa no oficial cuando sea necesario.

### 11.2 Ventajas de la Arquitectura

1. **Escalabilidad independiente**: El servicio puede escalar independientemente de otros componentes, con capacidad para gestionar múltiples instancias de WhatsApp.

2. **Responsabilidad clara**: Gestión dedicada de toda la comunicación con WhatsApp, abstrayendo detalles de implementación para otros servicios.

3. **Flexibilidad en la implementación**: Soporte para diferentes mecanismos de conexión con WhatsApp (API oficial y no oficial).

4. **Mantenibilidad mejorada**: Separación de preocupaciones y arquitectura hexagonal que facilita el mantenimiento y la evolución.

5. **Preparado para multiempresa**: Diseño que soporta nativamente múltiples organizaciones y números de teléfono.

6. **Aislamiento de sesiones**: Cada sesión de WhatsApp se ejecuta en su propio contenedor, garantizando aislamiento y resiliencia.

7. **Observabilidad integrada**: Métricas, logs y trazabilidad incorporados desde el diseño para ambos componentes.

### 11.3 Siguientes Pasos Recomendados

Una vez implementado el microservicio base, se recomiendan los siguientes pasos para expansión y mejora:

1. **Capacidades Analíticas**:
   - Implementar dashboard de análisis de conversaciones
   - Desarrollar detección de sentimiento en mensajes
   - Crear sistema de etiquetado automático de conversaciones
   - Implementar estadísticas de uso por empresa/número

2. **Mejoras en Experiencia de Usuario**:
   - Implementar respuestas rápidas preconfiguradas
   - Desarrollar sistema de transferencia entre agentes humanos e IA
   - Crear biblioteca de respuestas comunes por empresa
   - Implementar interfaz web para gestión de sesiones WhatsApp

3. **Capacidades Avanzadas**:
   - Reconocimiento y procesamiento de adjuntos (imágenes, documentos)
   - Integración con sistemas CRM
   - Campañas masivas programadas con seguimiento
   - Chatbots específicos por empresa/caso de uso

4. **Optimizaciones**:
   - Implementar bases de conocimiento específicas por empresa
   - Desarrollar sistemas de aprendizaje por feedback
   - Optimizar costos de operación con modelos predictivos
   - Implementar sistema de caché más sofisticado para mensajes frecuentes

## 12. Apéndices

### 12.1 Glosario de Términos

- **WABA**: WhatsApp Business API Account - Cuenta oficial de la API de WhatsApp Business
- **HSM**: Highly Structured Message - Plantillas de mensajes estructurados en WhatsApp
- **Tenant**: Empresa o entidad organizacional en un sistema multi-tenant
- **Webhook**: Mecanismo de notificación HTTP para eventos
- **OTP**: One-Time Password - Código de un solo uso para verificación
- **SLA**: Service Level Agreement - Acuerdo de nivel de servicio
- **Circuit Breaker**: Patrón para prevenir fallos en cascada
- **Baileys**: Biblioteca no oficial para interactuar con WhatsApp desde Node.js
- **QR Code**: Código QR utilizado para autenticar sesiones de WhatsApp Web/Desktop
- **WhatsApp Session**: Sesión autenticada de WhatsApp para un número específico

### 12.2 Referencias y Documentación

1. [Documentación de WhatsApp Business API](https://developers.facebook.com/docs/whatsapp/api/reference)
2. [Biblioteca whiskeysockets/baileys](https://github.com/whiskeysockets/baileys)
3. [Arquitectura Hexagonal (Puertos y Adaptadores)](https://alistair.cockburn.us/hexagonal-architecture/)
4. [Patrones Multi-tenant](https://docs.microsoft.com/en-us/azure/architecture/guide/multitenant/overview)
5. [Docker SDK para Go](https://docs.docker.com/engine/api/sdk/)
6. [Go Gin Framework](https://github.com/gin-gonic/gin)
7. [Patrones de Resiliencia para Microservicios](https://docs.microsoft.com/en-us/azure/architecture/patterns/category/resiliency)
8. [Memcached - Servidor de caché distribuido](https://memcached.org/)

### 12.3 Diagramas Adicionales

#### 12.3.1 Diagrama de Flujo para Inicialización de Sesión WhatsApp

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │     │                 │
│  Cliente API    │     │  Microservicio  │     │  Gestor de      │     │  Servidor       │
│                 │     │  WhatsApp       │     │  Contenedores   │     │  Node.js        │
│                 │     │                 │     │                 │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │                       │
         │  1. Iniciar sesión    │                       │                       │
         │──────────────────────>│                       │                       │
         │                       │                       │                       │
         │                       │  2. Crear contenedor  │                       │
         │                       │──────────────────────>│                       │
         │                       │                       │                       │
         │                       │                       │  3. Iniciar contenedor│
         │                       │                       │──────────────────────>│
         │                       │                       │                       │
         │                       │                       │  4. Confirmar inicio  │
         │                       │                       │<─────────────────────┤
         │                       │                       │                       │
         │                       │  5. Contenedor listo  │                       │
         │                       │<─────────────────────│                       │
         │                       │                       │                       │
         │                       │  6. Iniciar sesión    │                       │
         │                       │─────────────────────────────────────────────>│
         │                       │                       │                       │
         │                       │                       │                       │  7. Generar QR
         │                       │                       │                       │─────┐
         │                       │                       │                       │     │
         │                       │                       │                       │<────┘
         │                       │                       │                       │
         │                       │  8. Sesión inicializada con QR                │
         │                       │<─────────────────────────────────────────────│
         │                       │                       │                       │
         │  9. URL para QR       │                       │                       │
         │<─────────────────────│                       │                       │
         │                       │                       │                       │
```

#### 12.3.2 Diagrama de Estado para Sesiones WhatsApp

```
┌──────────────┐
│              │
│   CREADA     │
│              │
└──────┬───────┘
       │
       │ Inicializar sesión
       │
       ▼
┌──────────────┐
│              │
│INICIALIZANDO │
│              │
└──────┬───────┘
       │
       │ QR generado
       │
       ▼
┌──────────────┐           ┌──────────────┐
│              │           │              │
│ ESPERANDO QR │           │    ERROR     │
│              │           │              │
└──────┬───────┘           └──────────────┘
       │                           ▲
       │ QR escaneado              │
       │                           │ Error en inicialización
       ▼                           │ o autenticación
┌──────────────┐                   │
│              │                   │
│ CONECTANDO   │───────────────────┘
│              │
└──────┬───────┘
       │
       │ Conexión establecida
       │
       ▼
┌──────────────┐
│              │
│   ACTIVA     │◄───────┐
│              │        │
└──────┬───────┘        │ Reconexión
       │                │ exitosa
       │ Desconexión    │
       │                │
       ▼                │
┌──────────────┐        │
│              │        │
│ RECONECTANDO │────────┘
│              │
└──────┬───────┘
       │
       │ Cierre de sesión
       │ o error fatal
       ▼
┌──────────────┐
│              │
│   CERRADA    │
│              │
└──────────────┘
```

#### 12.3.3 Diagrama de Despliegue

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Cluster Kubernetes                          │
│                                                                     │
│  ┌─────────────────┐      ┌─────────────────┐    ┌───────────────┐  │
│  │                 │      │                 │    │               │  │
│  │  KrakenD API    │      │  Orquestador    │    │  Servicio IA  │  │
│  │  Gateway        │      │                 │    │               │  │
│  │                 │      │                 │    │               │  │
│  └─────────┬───────┘      └─────────┬───────┘    └───────────────┘  │
│            │                        │                               │
│            │                        │                               │
│            ▼                        ▼                               │
│  ┌─────────────────┐      ┌─────────────────┐    ┌───────────────┐  │
│  │                 │      │                 │    │               │  │
│  │ Microservicio   │◄────►│ Servicio IAM    │    │ Servicio OTP  │  │
│  │ WhatsApp        │      │                 │    │               │  │
│  │ (Go)            │      │                 │    │               │  │
│  └─────────┬───────┘      └─────────────────┘    └───────────────┘  │
│            │                                                        │
│            │ Gestión Docker                                         │
│            ▼                                                        │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                                                               │  │
│  │                    Docker Host / Node Pool                    │  │
│  │                                                               │  │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │  │
│  │  │             │   │             │   │             │          │  │
│  │  │ WhatsApp    │   │ WhatsApp    │   │ WhatsApp    │   ...    │  │
│  │  │ Node 1      │   │ Node 2      │   │ Node 3      │          │  │
│  │  │             │   │             │   │             │          │  │
│  │  └─────────────┘   └─────────────┘   └─────────────┘          │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────┐      ┌─────────────────┐    ┌───────────────┐  │
│  │                 │      │                 │    │               │  │
│  │  PostgreSQL     │      │  Memcached      │    │  Volúmenes    │  │
│  │  Database       │      │  Cache          │    │  Persistentes │  │
│  │                 │      │                 │    │               │  │
│  └─────────────────┘      └─────────────────┘    └───────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

*Plan de desarrollo preparado: 10 de abril de 2025*  
*Versión del documento: 1.1*