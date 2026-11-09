#!/usr/bin/env bash
# ==============================================================================
# Script de automatización para compilar, probar, desplegar y administrar
# el sistema Spring Kafka Demo en Linux / macOS / WSL.
#
# Uso:
#   ./deploy.sh up        - Levanta Docker (Kafka, Postgres, Kafka-UI), compila y arranca el backend
#   ./deploy.sh down      - Detiene el backend y baja los contenedores de Docker
#   ./deploy.sh test      - Ejecuta los tests unitarios y de integración
#   ./deploy.sh build     - Compila y empaqueta el backend (bootJar) y frontend
#   ./deploy.sh status    - Muestra el estado de contenedores, procesos y puertos
#   ./deploy.sh restart   - Detiene todo y vuelve a levantar
#   ./deploy.sh logs      - Muestra los logs en tiempo real
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/docker"
BACKEND_DIR="${SCRIPT_DIR}/backend"
FRONTEND_DIR="${SCRIPT_DIR}/frontend"
PID_FILE="${BACKEND_DIR}/backend.pid"
LOG_FILE="${BACKEND_DIR}/backend.log"
FRONTEND_PID_FILE="${FRONTEND_DIR}/frontend.pid"
FRONTEND_LOG_FILE="${FRONTEND_DIR}/frontend.log"
COMPOSE_FILE="${DOCKER_DIR}/docker-compose.yml"
ENV_FILE="${SCRIPT_DIR}/.env"

if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

load_env() {
    if [ -f "${ENV_FILE}" ]; then
        print_info "Cargando variables de ambiente desde .env..."
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
    fi
}

compose_exec() {
    if [ -f "${ENV_FILE}" ]; then
        ${COMPOSE_CMD} --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
    else
        ${COMPOSE_CMD} -f "${COMPOSE_FILE}" "$@"
    fi
}

# Colores de salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "  ${YELLOW}$1${NC}"
    echo -e "${CYAN}======================================================================${NC}"
}

print_success() { echo -e "${GREEN}[OK] $1${NC}"; }
print_info()    { echo -e "${CYAN}[INFO] $1${NC}"; }
print_warn()    { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_error()   { echo -e "${RED}[ERROR] $1${NC}"; }

check_prerequisites() {
    print_info "Verificando herramientas requeridas..."
    
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker no se encuentra instalado o en el PATH."
        exit 1
    fi

    if ! command -v java >/dev/null 2>&1; then
        print_error "Java 21+ no se encuentra instalado o en el PATH."
        exit 1
    fi

    print_success "Prerrequisitos OK (Docker y Java detectados)."
}

invoke_build() {
    print_header "COMPILANDO Y EMPAQUETANDO EL PROYECTO"
    
    cd "${BACKEND_DIR}"
    print_info "Ejecutando compilación del backend Spring Boot..."
    if [ -x "./gradlew" ] || [ -f "./gradlew" ]; then
        chmod +x ./gradlew 2>/dev/null || true
        ./gradlew bootJar -x test
    elif [ -x "./mvnw" ] || [ -f "./mvnw" ]; then
        chmod +x ./mvnw 2>/dev/null || true
        ./mvnw clean package -DskipTests
    else
        print_error "No se encontró gradlew ni mvnw en ${BACKEND_DIR}"
        exit 1
    fi
    print_success "Backend compilado y empaquetado exitosamente."

    if [ -f "${FRONTEND_DIR}/package.json" ]; then
        print_info "Detectado proyecto frontend. Verificando dependencias..."
        cd "${FRONTEND_DIR}"
        if [ ! -d "node_modules" ]; then
            print_info "Instalando dependencias de frontend con npm..."
            npm install
        fi
        print_info "Compilando frontend..."
        npm run build --if-present || true
        print_success "Frontend procesado."
    fi
}

invoke_test() {
    print_header "EJECUTANDO TESTS UNITARIOS Y DE INTEGRACIÓN"
    
    cd "${BACKEND_DIR}"
    print_info "Corriendo suite de pruebas con Gradle..."
    if [ -f "./gradlew" ]; then
        chmod +x ./gradlew 2>/dev/null || true
        ./gradlew test --info
    elif [ -f "./mvnw" ]; then
        chmod +x ./mvnw 2>/dev/null || true
        ./mvnw test
    fi
    print_success "Todos los tests pasaron exitosamente."
}

wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-40}"
    local count=0

    print_info "Esperando a que ${host}:${port} esté disponible (timeout: ${timeout}s)..."
    while ! (echo > "/dev/tcp/${host}/${port}") >/dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
        if [ "$count" -ge "$timeout" ]; then
            print_warn "Tiempo agotado esperando ${host}:${port}"
            return 1
        fi
    done
    print_success "Conexión establecida con ${host}:${port}"
    return 0
}

stop_backend_process() {
    if [ -f "${PID_FILE}" ]; then
        local pid
        pid=$(cat "${PID_FILE}" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            print_info "Deteniendo proceso backend (PID ${pid})..."
            kill "$pid" 2>/dev/null || true
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                print_warn "Forzando terminación del proceso (PID ${pid})..."
                kill -9 "$pid" 2>/dev/null || true
            fi
            print_success "Proceso backend detenido."
        fi
        rm -f "${PID_FILE}"
    fi

    # Liberación defensiva del puerto 8080 si estuviera ocupado
    if command -v fuser >/dev/null 2>&1; then
        fuser -k 8080/tcp 2>/dev/null || true
    elif command -v lsof >/dev/null 2>&1; then
        local pids
        pids=$(lsof -ti :8080 2>/dev/null || true)
        if [ -n "$pids" ]; then
            print_warn "Liberando puerto 8080 (PIDs: $pids)..."
            kill -9 $pids 2>/dev/null || true
        fi
    fi
}

stop_frontend_process() {
    if [ -f "${FRONTEND_PID_FILE}" ]; then
        local pid
        pid=$(cat "${FRONTEND_PID_FILE}" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            print_info "Deteniendo proceso frontend (PID ${pid})..."
            kill "$pid" 2>/dev/null || true
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                print_warn "Forzando terminación del frontend (PID ${pid})..."
                kill -9 "$pid" 2>/dev/null || true
            fi
            print_success "Proceso frontend detenido."
        fi
        rm -f "${FRONTEND_PID_FILE}"
    fi

    # Liberación del puerto 4200
    if command -v fuser >/dev/null 2>&1; then
        fuser -k 4200/tcp 2>/dev/null || true
    elif command -v lsof >/dev/null 2>&1; then
        local pids
        pids=$(lsof -ti :4200 2>/dev/null || true)
        if [ -n "$pids" ]; then
            print_warn "Liberando puerto 4200 (PIDs: $pids)..."
            kill -9 $pids 2>/dev/null || true
        fi
    fi
}

invoke_up() {
    load_env
    check_prerequisites
    print_header "INICIANDO INFRAESTRUCTURA Y SERVICIOS"
    
    # 1. Levantar Docker Compose
    print_info "Levantando contenedores de Docker (PostgreSQL, Kafka KRaft, Kafka-UI)..."
    compose_exec up -d
    
    # 2. Esperar por PostgreSQL y Kafka
    local db_port="${POSTGRES_PORT:-5433}"
    wait_for_port "127.0.0.1" "${db_port}" 30 || true
    wait_for_port "127.0.0.1" 29092 40 || true
    
    # 3. Compilar backend si no existe el JAR
    local jar_file
    jar_file=$(find "${BACKEND_DIR}/build/libs" -name "*.jar" ! -name "*-plain.jar" 2>/dev/null | head -n 1 || true)
    
    if [ -z "$jar_file" ] || [ ! -f "$jar_file" ]; then
        print_info "No se detectó un JAR previo. Compilando..."
        invoke_build
        jar_file=$(find "${BACKEND_DIR}/build/libs" -name "*.jar" ! -name "*-plain.jar" 2>/dev/null | head -n 1 || true)
    fi

    if [ -z "$jar_file" ]; then
        print_error "No se pudo localizar el archivo JAR ejecutable en build/libs"
        exit 1
    fi

    # 4. Detener instancia previa si existe
    stop_backend_process

    # 5. Arrancar Spring Boot en background
    print_header "ARRANCANDO BACKEND SPRING BOOT"
    print_info "Ejecutando $(basename "$jar_file")..."

    if [ "${FOREGROUND:-false}" = "true" ]; then
        print_info "Iniciando en primer plano (Ctrl+C para salir)..."
        java -jar "$jar_file"
    else
        nohup java -jar "$jar_file" > "${LOG_FILE}" 2>&1 &
        local new_pid=$!
        echo "$new_pid" > "${PID_FILE}"
        print_success "Backend iniciado en segundo plano con PID ${new_pid}"
        print_info "Salida de logs en: ${LOG_FILE}"

        # Esperar respuesta en puerto 8080
        wait_for_port "127.0.0.1" 8080 45 || true

        # 6. Arrancar Frontend Angular
        if [ -f "${FRONTEND_DIR}/package.json" ]; then
            print_header "ARRANCANDO PORTAL DE MONITOREO (ANGULAR)"
            stop_frontend_process
            print_info "Iniciando servidor frontend en puerto 4200..."
            cd "${FRONTEND_DIR}"
            nohup npm start > "${FRONTEND_LOG_FILE}" 2>&1 &
            local front_pid=$!
            echo "$front_pid" > "${FRONTEND_PID_FILE}"
            print_success "Portal Frontend iniciado en segundo plano con PID ${front_pid}"
            wait_for_port "127.0.0.1" 4200 30 || true
        fi

        local nginx_port="${NGINX_PORT:-80}"
        wait_for_port "127.0.0.1" "${nginx_port}" 15 || true

        print_header "SISTEMA DESPLEGADO Y OPERATIVO"
        echo -e "  * [Seguridad] Reverse Proxy NGINX: ${CYAN}http://localhost:${nginx_port}${NC}"
        echo -e "  * Portal Monitoreo (vía NGINX):    ${GREEN}http://localhost:${nginx_port}${NC}"
        echo -e "  * Portal Monitoreo (Directo Dev):  ${GREEN}http://localhost:4200${NC}"
        echo -e "  * Swagger UI (vía NGINX):          ${GREEN}http://localhost:${nginx_port}/api/v1/swagger-ui.html${NC}"
        echo -e "  * WebSocket STOMP (vía NGINX):     ${GREEN}ws://localhost:${nginx_port}/api/v1/ws-notifications${NC}"
        echo -e "  * SSE Stream (vía NGINX):          ${GREEN}http://localhost:${nginx_port}/api/v1/notifications/stream${NC}"
        echo -e "  * Kafka UI:                        ${GREEN}http://localhost:8089 (o http://localhost:${nginx_port}/kafka-ui/)${NC}"
        echo -e "  * PostgreSQL Database:             ${GREEN}localhost:5433 (DB: notification_db)${NC}"
        echo ""
        print_info "Logs Backend:  tail -f '${LOG_FILE}'"
        print_info "Logs Frontend: tail -f '${FRONTEND_LOG_FILE}'"
        print_info "Logs Nginx:    ${COMPOSE_CMD} -f '${COMPOSE_FILE}' logs -f nginx"
        print_info "Para detener el sistema ejecuta: ./deploy.sh down"
    fi
}

invoke_down() {
    load_env
    print_header "DETENIENDO SERVICIOS Y CONTENEDORES"
    
    # 1. Detener Frontend y Backend
    stop_frontend_process
    stop_backend_process
    
    # 2. Detener Docker Compose
    print_info "Deteniendo infraestructura Docker..."
    if [ "${CLEAN:-false}" = "true" ]; then
        print_warn "Modo Clean activado: eliminando contenedores y volúmenes persistentes..."
        compose_exec down -v
    else
        compose_exec down
    fi
    print_success "Todos los servicios han sido detenidos correctamente."
}

invoke_status() {
    load_env
    print_header "ESTADO DEL SISTEMA"
    
    echo -e "\n${CYAN}--- Contenedores Docker ---${NC}"
    compose_exec ps
    
    echo -e "\n${CYAN}--- Proceso Backend (Spring Boot) ---${NC}"
    if [ -f "${PID_FILE}" ]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}Backend ACTIVO (PID ${pid})${NC}"
        else
            echo -e "${RED}Backend INACTIVO (PID huérfano ${pid})${NC}"
        fi
    else
        echo -e "${YELLOW}Backend INACTIVO${NC}"
    fi

    echo -e "\n${CYAN}--- Proceso Frontend (Angular) ---${NC}"
    if [ -f "${FRONTEND_PID_FILE}" ]; then
        local fpid
        fpid=$(cat "${FRONTEND_PID_FILE}")
        if kill -0 "$fpid" 2>/dev/null; then
            echo -e "${GREEN}Frontend ACTIVO (PID ${fpid})${NC}"
        else
            echo -e "${RED}Frontend INACTIVO (PID huérfano ${fpid})${NC}"
        fi
    else
        echo -e "${YELLOW}Frontend INACTIVO${NC}"
    fi

    echo -e "\n${CYAN}--- Verificación de Puertos ---${NC}"
    local nginx_port="${NGINX_PORT:-80}"
    for port in "${nginx_port}" 4200 8080 8089 5433 29092; do
        if (echo > "/dev/tcp/127.0.0.1/${port}") >/dev/null 2>&1; then
            echo -e "Puerto ${port} : ${GREEN}ACTIVO (Escuchando)${NC}"
        else
            echo -e "Puerto ${port} : \033[0;90mINACTIVO\033[0m"
        fi
    done
}

invoke_logs() {
    load_env
    print_header "LOGS DEL SISTEMA"
    echo -e "${CYAN}1) Logs Backend:  tail -f '${LOG_FILE}'${NC}"
    echo -e "${CYAN}2) Logs Frontend: tail -f '${FRONTEND_LOG_FILE}'${NC}"
    echo -e "${CYAN}3) Logs Docker:   ${COMPOSE_CMD} -f '${COMPOSE_FILE}' logs -f${NC}\n"
    compose_exec logs --tail=20
}

# Procesar argumentos
COMMAND="${1:-up}"
case "${COMMAND,,}" in
    up)
        invoke_up
        ;;
    down)
        invoke_down
        ;;
    test)
        invoke_test
        ;;
    build)
        invoke_build
        ;;
    status)
        invoke_status
        ;;
    restart)
        invoke_down
        sleep 2
        invoke_up
        ;;
    logs)
        invoke_logs
        ;;
    help|--help|-h)
        print_header "AYUDA DE COMANDOS"
        echo "Uso: ./deploy.sh [up|down|test|build|status|restart|logs]"
        echo ""
        echo "  up       - Inicia PostgreSQL, Kafka, Kafka-UI y el backend Spring Boot"
        echo "  down     - Detiene el backend y los contenedores"
        echo "  test     - Corre la suite de tests automatizados"
        echo "  build    - Compila y genera el JAR ejecutable de Spring Boot"
        echo "  status   - Muestra el estado de contenedores y servicios"
        echo "  restart  - Detiene y vuelve a iniciar el entorno completo"
        echo "  logs     - Muestra los logs de contenedores"
        ;;
    *)
        print_error "Comando desconocido: '$1'"
        echo "Ejecuta './deploy.sh help' para ver los comandos disponibles."
        exit 1
        ;;
esac
