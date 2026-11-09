<#
.SYNOPSIS
    Script de automatización para compilar, probar, desplegar y administrar Spring Kafka Demo.
.DESCRIPTION
    Comandos disponibles:
      .\deploy.ps1 up        - Levanta Docker (Kafka, Postgres, Kafka-UI), compila y arranca el backend
      .\deploy.ps1 down      - Detiene el backend y baja los contenedores de Docker
      .\deploy.ps1 test      - Ejecuta los tests unitarios y de integración
      .\deploy.ps1 build     - Compila y empaqueta el backend (bootJar) y frontend
      .\deploy.ps1 status    - Muestra el estado de los contenedores y puertos activos
      .\deploy.ps1 restart   - Detiene todo y vuelve a levantar
      .\deploy.ps1 logs      - Muestra los logs de los contenedores Docker
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("up", "down", "test", "build", "status", "restart", "logs", "help")]
    [string]$Command = "up",

    [switch]$Foreground,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DockerDir = Join-Path $ScriptDir "docker"
$BackendDir = Join-Path $ScriptDir "backend"
$FrontendDir = Join-Path $ScriptDir "frontend"
$PidFile = Join-Path $BackendDir "backend.pid"
$LogFile = Join-Path $BackendDir "backend.log"
$ErrLogFile = Join-Path $BackendDir "backend.err.log"
$FrontendPidFile = Join-Path $FrontendDir "frontend.pid"
$FrontendLogFile = Join-Path $FrontendDir "frontend.log"
$FrontendErrLogFile = Join-Path $FrontendDir "frontend.err.log"
$ComposeFile = Join-Path $DockerDir "docker-compose.yml"
$ComposeCmd = if (Get-Command docker-compose -ErrorAction SilentlyContinue) { "docker-compose" } else { "docker compose" }
$EnvFile = Join-Path $ScriptDir ".env"

function Import-EnvFile {
    if (Test-Path $EnvFile) {
        Print-Info "Cargando variables de ambiente desde .env..."
        Get-Content $EnvFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $idx = $line.IndexOf("=")
                $key = $line.Substring(0, $idx).Trim()
                $val = $line.Substring($idx + 1).Trim().Trim('"').Trim("'")
                [System.Environment]::SetEnvironmentVariable($key, $val, [System.EnvironmentVariableTarget]::Process)
            }
        }
    }
}

function Get-ComposeArgs {
    $args = @()
    if (Test-Path $EnvFile) {
        $args += @("--env-file", $EnvFile)
    }
    $args += @("-f", $ComposeFile)
    return ,$args
}

function Print-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Cyan
}

function Print-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Print-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Print-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Print-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Check-Prerequisites {
    Print-Info "Verificando herramientas requeridas..."
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Print-Error "Docker no se encuentra instalado o no esta en el PATH."
        exit 1
    }
    
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        Print-Error "Java 21+ no se encuentra en el PATH."
        exit 1
    }
    
    Print-Success "Prerrequisitos OK (Docker y Java detectados)."
}

function Invoke-Build {
    Print-Header "COMPILANDO Y EMPAQUETANDO EL PROYECTO"
    
    Push-Location $BackendDir
    try {
        Print-Info "Ejecutando compilacion del backend Spring Boot..."
        if (Test-Path ".\gradlew.bat") {
            & ".\gradlew.bat" bootJar -x test
        } elseif (Test-Path ".\mvnw.cmd") {
            & ".\mvnw.cmd" clean package -DskipTests
        } else {
            Print-Error "No se encontro gradlew.bat ni mvnw.cmd en $BackendDir"
            exit 1
        }
        
        if ($LASTEXITCODE -ne 0) {
            Print-Error "La compilacion del backend ha fallado."
            exit 1
        }
        Print-Success "Backend compilado y empaquetado exitosamente."
    } finally {
        Pop-Location
    }

    if (Test-Path (Join-Path $FrontendDir "package.json")) {
        Print-Info "Detectado proyecto frontend. Verificando dependencias..."
        Push-Location $FrontendDir
        try {
            if (-not (Test-Path "node_modules")) {
                Print-Info "Instalando dependencias de frontend..."
                npm install
            }
            Print-Info "Compilando frontend para produccion..."
            npm run build --if-present
            Print-Success "Frontend procesado."
        } catch {
            Print-Warn "Advertencia durante el build de frontend: $_"
        } finally {
            Pop-Location
        }
    }
}

function Invoke-Test {
    Print-Header "EJECUTANDO TESTS UNITARIOS Y DE INTEGRACION"
    
    Push-Location $BackendDir
    try {
        Print-Info "Corriendo suite de pruebas con Gradle..."
        if (Test-Path ".\gradlew.bat") {
            & ".\gradlew.bat" test --info
        } elseif (Test-Path ".\mvnw.cmd") {
            & ".\mvnw.cmd" test
        }
        
        if ($LASTEXITCODE -ne 0) {
            Print-Error "Uno o mas tests fallaron."
            exit 1
        }
        Print-Success "Todos los tests pasaron exitosamente."
    } finally {
        Pop-Location
    }
}

function Wait-For-Port {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutSeconds = 40
    )
    Print-Info "Esperando a que ${HostName}:${Port} este disponible (timeout: ${TimeoutSeconds}s)..."
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($Stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        try {
            $AsyncResult = $TcpClient.BeginConnect($HostName, $Port, $null, $null)
            $WaitHandle = $AsyncResult.AsyncWaitHandle.WaitOne(1000, $false)
            if ($WaitHandle -and $TcpClient.Connected) {
                $TcpClient.EndConnect($AsyncResult)
                $TcpClient.Close()
                Print-Success "Conexion establecida con ${HostName}:${Port}"
                return $true
            }
        } catch {
            # Continuar esperando
        } finally {
            $TcpClient.Dispose()
        }
        Start-Sleep -Seconds 1
    }
    Print-Warn "Tiempo agotado esperando ${HostName}:${Port}"
    return $false
}

function Stop-Backend-Process {
    if (Test-Path $PidFile) {
        $SavedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($SavedPid) {
            $Proc = Get-Process -Id $SavedPid -ErrorAction SilentlyContinue
            if ($Proc) {
                Print-Info "Deteniendo proceso backend (PID $SavedPid)..."
                Stop-Process -Id $SavedPid -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Print-Success "Proceso backend detenido."
            }
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }

    $PortOccupied = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    if ($PortOccupied) {
        foreach ($Conn in $PortOccupied) {
            if ($Conn.OwningProcess -gt 0) {
                Print-Warn "Liberando puerto 8080 (PID $($Conn.OwningProcess))..."
                Stop-Process -Id $Conn.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Stop-Frontend-Process {
    if (Test-Path $FrontendPidFile) {
        $SavedPid = Get-Content $FrontendPidFile -ErrorAction SilentlyContinue
        if ($SavedPid) {
            $Proc = Get-Process -Id $SavedPid -ErrorAction SilentlyContinue
            if ($Proc) {
                Print-Info "Deteniendo proceso frontend (PID $SavedPid)..."
                Stop-Process -Id $SavedPid -Force -ErrorAction SilentlyContinue
            }
        }
        Remove-Item $FrontendPidFile -Force -ErrorAction SilentlyContinue
    }

    $PortOccupied = Get-NetTCPConnection -LocalPort 4200 -State Listen -ErrorAction SilentlyContinue
    if ($PortOccupied) {
        foreach ($Conn in $PortOccupied) {
            if ($Conn.OwningProcess -gt 0) {
                Print-Warn "Liberando puerto 4200 (PID $($Conn.OwningProcess))..."
                Stop-Process -Id $Conn.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Invoke-Up {
    Import-EnvFile
    Check-Prerequisites
    Print-Header "INICIANDO INFRAESTRUCTURA Y SERVICIOS"
    
    Print-Info "Levantando contenedores de Docker (PostgreSQL, Kafka KRaft, Kafka-UI)..."
    $cArgs = Get-ComposeArgs
    & $ComposeCmd $cArgs up -d
    if ($LASTEXITCODE -ne 0) {
        Print-Error "Fallo al iniciar los contenedores de Docker."
        exit 1
    }
    
    $DbPort = if ($env:POSTGRES_PORT) { [int]$env:POSTGRES_PORT } else { 5433 }
    Wait-For-Port -HostName "127.0.0.1" -Port $DbPort -TimeoutSeconds 30 | Out-Null
    Wait-For-Port -HostName "127.0.0.1" -Port 29092 -TimeoutSeconds 40 | Out-Null
    
    $Jar = Get-ChildItem -Path (Join-Path $BackendDir "build\libs") -Filter "*.jar" -ErrorAction SilentlyContinue | 
           Where-Object { $_.Name -notmatch "-plain\.jar$" } | Select-Object -First 1

    if (-not $Jar) {
        Print-Info "No se detecto un JAR previo. Compilando..."
        Invoke-Build
        $Jar = Get-ChildItem -Path (Join-Path $BackendDir "build\libs") -Filter "*.jar" | 
               Where-Object { $_.Name -notmatch "-plain\.jar$" } | Select-Object -First 1
    }

    if (-not $Jar) {
        Print-Error "No se pudo localizar el archivo JAR ejecutable en build/libs"
        exit 1
    }

    Stop-Backend-Process

    Print-Header "ARRANCANDO BACKEND SPRING BOOT"
    Print-Info "Ejecutando $($Jar.Name)..."

    if ($Foreground) {
        Print-Info "Iniciando en primer plano (Ctrl+C para salir)..."
        java -jar $Jar.FullName
    } else {
        $Process = Start-Process -FilePath "java" -ArgumentList "-jar", "`"$($Jar.FullName)`"" `
                                 -RedirectStandardOutput $LogFile `
                                 -RedirectStandardError $ErrLogFile `
                                 -PassThru
        $Process.Id | Out-File -FilePath $PidFile -Encoding ascii
        Print-Success "Backend iniciado en segundo plano con PID $($Process.Id)"
        Print-Info "Salida de logs en: $LogFile"
        
        Wait-For-Port -HostName "127.0.0.1" -Port 8080 -TimeoutSeconds 45 | Out-Null
        
        # 6. Arrancar Portal de Monitoreo (Angular)
        if (Test-Path (Join-Path $FrontendDir "package.json")) {
            Print-Header "ARRANCANDO PORTAL DE MONITOREO (ANGULAR)"
            Stop-Frontend-Process
            Print-Info "Iniciando servidor frontend en puerto 4200..."
            $FrontProc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c npm start" `
                                       -WorkingDirectory $FrontendDir `
                                       -RedirectStandardOutput $FrontendLogFile `
                                       -RedirectStandardError $FrontendErrLogFile `
                                       -PassThru
            $FrontProc.Id | Out-File -FilePath $FrontendPidFile -Encoding ascii
            Print-Success "Portal Frontend iniciado en segundo plano con PID $($FrontProc.Id)"
            Wait-For-Port -HostName "127.0.0.1" -Port 4200 -TimeoutSeconds 30 | Out-Null
        }

        $NginxPort = if ($env:NGINX_PORT) { [int]$env:NGINX_PORT } else { 80 }
        Wait-For-Port -HostName "127.0.0.1" -Port $NginxPort -TimeoutSeconds 15 | Out-Null

        Print-Header "SISTEMA DESPLEGADO Y OPERATIVO"
        Write-Host "  * [Seguridad] Reverse Proxy NGINX: http://localhost:$NginxPort" -ForegroundColor Cyan
        Write-Host "  * Portal Monitoreo (vía NGINX):    http://localhost:$NginxPort" -ForegroundColor Green
        Write-Host "  * Portal Monitoreo (Directo Dev):  http://localhost:4200" -ForegroundColor Green
        Write-Host "  * Swagger UI (vía NGINX):          http://localhost:$NginxPort/api/v1/swagger-ui.html" -ForegroundColor Green
        Write-Host "  * WebSocket STOMP (vía NGINX):     ws://localhost:$NginxPort/api/v1/ws-notifications" -ForegroundColor Green
        Write-Host "  * SSE Stream (vía NGINX):          http://localhost:$NginxPort/api/v1/notifications/stream" -ForegroundColor Green
        Write-Host "  * Kafka UI:                        http://localhost:8089 (o http://localhost:$NginxPort/kafka-ui/)" -ForegroundColor Green
        Write-Host "  * PostgreSQL Database:             localhost:5433 (DB: notification_db)" -ForegroundColor Green
        Write-Host ""
        Print-Info "Logs Backend:  Get-Content '$LogFile' -Wait -Tail 30"
        Print-Info "Logs Frontend: Get-Content '$FrontendLogFile' -Wait -Tail 30"
        Print-Info "Logs Nginx:    docker compose -f '$ComposeFile' logs -f nginx"
        Print-Info "Para detener el sistema ejecuta: .\deploy.ps1 down"
    }
}

function Invoke-Down {
    Import-EnvFile
    Print-Header "DETENIENDO SERVICIOS Y CONTENEDORES"
    
    # 1. Detener Frontend y Backend
    Stop-Frontend-Process
    Stop-Backend-Process
    
    Print-Info "Deteniendo infraestructura Docker..."
    $cArgs = Get-ComposeArgs
    if ($Clean) {
        Print-Warn "Modo Clean activado: eliminando contenedores y volumenes persistentes..."
        & $ComposeCmd $cArgs down -v
    } else {
        & $ComposeCmd $cArgs down
    }
    
    Print-Success "Todos los servicios han sido detenidos correctamente."
}

function Invoke-Status {
    Import-EnvFile
    Print-Header "ESTADO DEL SISTEMA"
    
    Write-Host "`n--- Contenedores Docker ---" -ForegroundColor Cyan
    $cArgs = Get-ComposeArgs
    & $ComposeCmd $cArgs ps
    
    Write-Host "`n--- Proceso Backend (Spring Boot) ---" -ForegroundColor Cyan
    if (Test-Path $PidFile) {
        $SavedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $Proc = Get-Process -Id $SavedPid -ErrorAction SilentlyContinue
        if ($Proc) {
            Write-Host "Backend ACTIVO (PID $SavedPid) - Memoria: $([math]::Round($Proc.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Green
        } else {
            Write-Host "Backend INACTIVO (PID huerfano $SavedPid)" -ForegroundColor Red
        }
    } else {
        $PortOccupied = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
        if ($PortOccupied) {
            Write-Host "Puerto 8080 escuchando (PID $($PortOccupied[0].OwningProcess))" -ForegroundColor Green
        } else {
            Write-Host "Backend INACTIVO" -ForegroundColor Yellow
        }
    }

    Write-Host "`n--- Proceso Frontend (Angular) ---" -ForegroundColor Cyan
    if (Test-Path $FrontendPidFile) {
        $SavedFrontPid = Get-Content $FrontendPidFile -ErrorAction SilentlyContinue
        $FrontProc = Get-Process -Id $SavedFrontPid -ErrorAction SilentlyContinue
        if ($FrontProc) {
            Write-Host "Frontend ACTIVO (PID $SavedFrontPid)" -ForegroundColor Green
        } else {
            Write-Host "Frontend INACTIVO (PID huerfano $SavedFrontPid)" -ForegroundColor Red
        }
    } else {
        $FrontPort = Get-NetTCPConnection -LocalPort 4200 -State Listen -ErrorAction SilentlyContinue
        if ($FrontPort) {
            Write-Host "Puerto 4200 escuchando (PID $($FrontPort[0].OwningProcess))" -ForegroundColor Green
        } else {
            Write-Host "Frontend INACTIVO" -ForegroundColor Yellow
        }
    }

    Write-Host "`n--- Puertos Core ---" -ForegroundColor Cyan
    $NginxPort = if ($env:NGINX_PORT) { [int]$env:NGINX_PORT } else { 80 }
    @($NginxPort, 4200, 8080, 8089, 5433, 29092) | ForEach-Object {
        $Conn = Get-NetTCPConnection -LocalPort $_ -State Listen -ErrorAction SilentlyContinue
        if ($Conn) {
            Write-Host "Puerto $_ : ACTIVO (Escuchando)" -ForegroundColor Green
        } else {
            Write-Host "Puerto $_ : INACTIVO" -ForegroundColor DarkGray
        }
    }
}

function Invoke-Logs {
    Import-EnvFile
    Print-Header "LOGS DEL SISTEMA"
    Write-Host "1. Logs del Backend:  Get-Content '$LogFile' -Wait -Tail 50" -ForegroundColor Cyan
    Write-Host "2. Logs del Frontend: Get-Content '$FrontendLogFile' -Wait -Tail 50" -ForegroundColor Cyan
    Write-Host "3. Logs de Docker:    $ComposeCmd -f '$ComposeFile' logs -f" -ForegroundColor Cyan
    Write-Host ""
    $cArgs = Get-ComposeArgs
    & $ComposeCmd $cArgs logs --tail=20
}

# Enrutador de comandos
switch ($Command.ToLower()) {
    "up"      { Invoke-Up }
    "down"    { Invoke-Down }
    "test"    { Invoke-Test }
    "build"   { Invoke-Build }
    "status"  { Invoke-Status }
    "restart" { Invoke-Down; Start-Sleep -Seconds 2; Invoke-Up }
    "logs"    { Invoke-Logs }
    "help"    {
        Get-Help $MyInvocation.MyCommand.Path -Detailed
    }
}
