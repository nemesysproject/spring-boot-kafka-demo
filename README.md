# Demo: Sistema de Notificaciones y Mensajería en Tiempo Real

Este proyecto es una demostración técnica (Demo) de una arquitectura de microservicios y mensajería distribuida de extremo a extremo. El sistema permite procesar, almacenar y monitorear eventos/notificaciones en tiempo real.

## 🚀 Arquitectura y Tecnologías Core

*   **Backend (Core):** Java 21 / Spring Boot 3.x (Spring Web, Spring Kafka, Spring Data JPA).
*   **Mensajería & Notificaciones:** Apache Kafka (Brokers, Topics, Producers y Consumers).
*   **Base de Datos (Persistencia):** PostgreSQL.
*   **Portal de Monitoreo (Frontend):** Angular 21 (v21.x) con soporte de WebSockets/Server-Sent Events (SSE) para actualización en tiempo real.
*   **Infraestructura:** Docker & Docker Compose (para despliegue local rápido).

---

## 📁 Estructura del Proyecto

```text
notification-demo-project/
├── .github/                        # Workflows de CI/CD (Opcional)
├── docker/                         # Configuraciones de infraestructura local
│   ├── docker-compose.yml          # Levanta Kafka, Zookeeper y PostgreSQL
│   └── postgres-init/              # Scripts iniciales de Base de Datos
│       └── init.sql
│
├── backend/                        # API Core en Spring Boot
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/demo/notification/
│   │   │   │   ├── config/         # Configuración de Kafka, WebSockets y CORS
│   │   │   │   ├── controller/     # Endpoints REST (para disparar eventos o consultas)
│   │   │   │   ├── model/          # Entidades JPA (PostgreSQL)
│   │   │   │   ├── repository/     # Interfaces de Spring Data JPA
│   │   │   │   ├── service/        # Lógica de negocio
│   │   │   │   │   ├── kafka/      # Productores y Consumidores de Kafka
│   │   │   │   │   └── notification/# Gestión interna de alertas
│   │   │   │   └── NotificationApplication.java
│   │   │   └── resources/
│   │   │       ├── application.yml # Propiedades de Spring, Kafka y Datasource
│   │   │       └── banner.txt
│   │   └── test/                   # Pruebas unitarias y de integración
│   ├── gradlew / mvnw
│   └── pom.xml / build.gradle
│
├── frontend/                       # Portal de Monitoreo Web en Angular 21
│   ├── src/
│   │   ├── app/
│   │   │   ├── core/               # Guardias, interceptores, servicios globales
│   │   │   │   └── services/       # Conexión WebSocket / Kafka Event Consumer
│   │   │   ├── features/           # Módulos o componentes de la aplicación
│   │   │   │   ├── dashboard/      # Panel principal de monitoreo
│   │   │   │   └── log-viewer/     # Historial de mensajes/notificaciones
│   │   │   ├── shared/             # Componentes, pipes y directivas reutilizables
│   │   │   ├── app.component.ts
│   │   │   └── app.config.ts       # Configuración global de Angular 21
│   │   ├── assets/                 # Imágenes, estilos globales y fuentes
│   │   └── index.html
│   ├── angular.json
│   └── package.json
│
└── README.md                       # Documentación principal del proyecto
```

---

## 🛠️ Requisitos Previos

Asegúrate de tener instalado:
*   [Docker y Docker Compose](https://docker.com)
*   [Java 21 JDK](https://adoptium.net)
*   [Node.js (v22+ recomendado para Angular 21)](https://nodejs.org)
*   [Angular CLI (v21+)](https://angular.dev)

---

## 🏃‍♂️ Guía de Inicio Rápido

### 1. Levantar la Infraestructura (Kafka & Postgres)
Navega a la carpeta de docker y arranca los contenedores:
```bash
cd docker
docker-compose up -d
```
*Esto iniciará un broker de Apache Kafka (puerto `9092`) y una instancia de PostgreSQL (puerto `5432`).*

### 2. Iniciar el Backend (Spring Boot)
Navega al directorio del backend y ejecuta la aplicación:
```bash
cd ../backend
# Si usas Maven
./mvnw spring-boot:run
# Si usas Gradle
./gradlew bootRun
```
El servidor backend se levantará en el puerto `8080`.

### 3. Iniciar el Portal de Monitoreo (Angular 21)
Instala las dependencias y arranca el servidor de desarrollo de Angular:
```bash
cd ../frontend
npm install
ng serve
```
Abre tu navegador en `http://localhost:4200` para ver el panel de monitoreo web.

---

## ⚙️ Flujo de Datos del Demo

1.  **Ingesta de Mensajes:** Un cliente externo envía un payload al backend a través de un endpoint REST (`POST /api/v1/notifications`).
2.  **Productor Kafka:** El componente `KafkaProducer` recibe la petición y publica el mensaje en el topic `notification-events`.
3.  **Consumidor Kafka & Persistencia:** El componente `KafkaConsumer` escucha el topic de forma asíncrona, procesa el mensaje y utiliza `Spring Data JPA` para guardarlo de forma permanente en **PostgreSQL**.
4.  **Notificación Real-Time:** Al mismo tiempo que se guarda, el backend emite el evento al frontend mediante un canal de **WebSockets** (o SSE).
5.  **Monitoreo Angular 21:** El portal web recibe el evento instantáneamente y actualiza las métricas y la tabla de logs en el Dashboard sin necesidad de refrescar la pantalla.
