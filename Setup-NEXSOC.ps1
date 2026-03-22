# ============================================================
# NEXSOC — One-Click SOC Setup for Windows 11/10
# Run this FIRST in PowerShell as Administrator
# ============================================================
# Prerequisites installed automatically:
#   - Docker Desktop (WSL2 backend)
#   - Windows Subsystem for Linux 2
#   - vm.max_map_count fix for OpenSearch
# ============================================================

param(
    [switch]$SkipDockerInstall,
    [switch]$SkipWSL
)

$ErrorActionPreference = "Continue"
$NexSOCDir = "$PSScriptRoot\.."

Write-Host @"
 _   _ _______  _______ ___   ____
| \ | | ____\ \/ / ____/ _ \ / ___|
|  \| |  _|  \  /|  _|| | | | |
| |\  | |___ /  \| |__| |_| | |___
|_| \_|_____/_/\_\_____\___/ \____|

NEXSOC — Full SOC Stack Setup
Windows 11/10 + Docker + Wazuh 4.7
"@ -ForegroundColor Cyan

# ── Admin check ──
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "[ERROR] Run PowerShell as Administrator!" -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════════════════════
# STEP 1: Enable WSL2
# ══════════════════════════════════════════════════════════
if (-not $SkipWSL) {
    Write-Host "`n[1/5] Enabling Windows Subsystem for Linux 2..." -ForegroundColor Yellow
    try {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>$null
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>$null
        wsl --set-default-version 2 2>$null
        Write-Host "[OK] WSL2 features enabled" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] WSL2 setup: $_" -ForegroundColor Yellow
    }
}

# ══════════════════════════════════════════════════════════
# STEP 2: Check / Install Docker Desktop
# ══════════════════════════════════════════════════════════
Write-Host "`n[2/5] Checking Docker Desktop..." -ForegroundColor Yellow

$DockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($DockerCmd) {
    $DockerVersion = docker --version 2>$null
    Write-Host "[OK] Docker found: $DockerVersion" -ForegroundColor Green
} elseif (-not $SkipDockerInstall) {
    Write-Host "[!] Docker Desktop not found. Downloading installer..." -ForegroundColor Yellow
    $DockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $DockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $DockerUrl -OutFile $DockerInstaller -UseBasicParsing
        Write-Host "[+] Running Docker Desktop installer (follow the GUI)..." -ForegroundColor Yellow
        Start-Process $DockerInstaller -ArgumentList "install --quiet --accept-license" -Wait
        Write-Host "[OK] Docker Desktop installed. You may need to RESTART Windows." -ForegroundColor Green
        Write-Host "[!] After restart, re-run this script with -SkipDockerInstall flag" -ForegroundColor Yellow
    } catch {
        Write-Host "[ERROR] Docker download failed: $_" -ForegroundColor Red
        Write-Host "Manual install: https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
        exit 1
    }
} else {
    Write-Host "[WARN] Docker not found. Install Docker Desktop manually." -ForegroundColor Yellow
    Write-Host "Download: https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
}

# ══════════════════════════════════════════════════════════
# STEP 3: Set vm.max_map_count for OpenSearch (WSL2)
# OpenSearch requires this or the indexer won't start
# ══════════════════════════════════════════════════════════
Write-Host "`n[3/5] Configuring WSL2 memory settings for OpenSearch..." -ForegroundColor Yellow

# Write to .wslconfig
$WslConfig = "$env:USERPROFILE\.wslconfig"
$WslContent = @"
[wsl2]
memory=6GB
processors=4
swap=2GB
kernelCommandLine=sysctl.vm.max_map_count=262144
"@
$WslContent | Set-Content -Path $WslConfig -Encoding UTF8
Write-Host "[OK] WSL2 config written to $WslConfig" -ForegroundColor Green

# Also try setting directly in running WSL2
try {
    wsl -u root -e sysctl -w vm.max_map_count=262144 2>$null
    Write-Host "[OK] vm.max_map_count=262144 set in WSL2" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not set vm.max_map_count directly. Will apply on restart." -ForegroundColor Yellow
}

# ══════════════════════════════════════════════════════════
# STEP 4: Set up Windows Firewall rules for Wazuh ports
# ══════════════════════════════════════════════════════════
Write-Host "`n[4/5] Adding Windows Firewall rules for SOC ports..." -ForegroundColor Yellow

$FirewallRules = @(
    @{ Name="NEXSOC-Wazuh-Agent-TCP"; Port=1514; Protocol="TCP"; Description="Wazuh agent communication" },
    @{ Name="NEXSOC-Wazuh-Agent-UDP"; Port=1514; Protocol="UDP"; Description="Wazuh agent communication" },
    @{ Name="NEXSOC-Wazuh-Enrollment"; Port=1515; Protocol="TCP"; Description="Wazuh agent enrollment" },
    @{ Name="NEXSOC-Wazuh-API"; Port=55000; Protocol="TCP"; Description="Wazuh REST API" },
    @{ Name="NEXSOC-OpenSearch"; Port=9200; Protocol="TCP"; Description="OpenSearch API" },
    @{ Name="NEXSOC-Dashboard"; Port=443; Protocol="TCP"; Description="Wazuh Dashboard HTTPS" },
    @{ Name="NEXSOC-Syslog-UDP"; Port=514; Protocol="UDP"; Description="Syslog ingestion" },
    @{ Name="NEXSOC-Syslog-TCP"; Port=514; Protocol="TCP"; Description="Syslog ingestion" }
)

foreach ($Rule in $FirewallRules) {
    try {
        # Remove old rule if exists
        Remove-NetFirewallRule -DisplayName $Rule.Name -ErrorAction SilentlyContinue
        New-NetFirewallRule `
            -DisplayName $Rule.Name `
            -Direction Inbound `
            -Protocol $Rule.Protocol `
            -LocalPort $Rule.Port `
            -Action Allow `
            -Profile Any `
            -Description $Rule.Description | Out-Null
        Write-Host "  [+] FW Rule: $($Rule.Name) ($($Rule.Protocol)/$($Rule.Port))" -ForegroundColor DarkCyan
    } catch {
        Write-Host "  [WARN] FW rule '$($Rule.Name)': $_" -ForegroundColor Yellow
    }
}
Write-Host "[OK] Firewall rules configured" -ForegroundColor Green

# ══════════════════════════════════════════════════════════
# STEP 5: Launch the SOC Stack
# ══════════════════════════════════════════════════════════
Write-Host "`n[5/5] Launching NEXSOC Docker stack..." -ForegroundColor Yellow

Set-Location $NexSOCDir

# Check Docker is running
$DockerRunning = docker info 2>$null
if (-not $DockerRunning) {
    Write-Host "[!] Docker Desktop is not running. Please start it and re-run step 5." -ForegroundColor Yellow
    Write-Host "    After Docker starts, run: docker-compose up -d" -ForegroundColor Cyan
} else {
    Write-Host "[+] Generating SSL certificates..." -ForegroundColor DarkCyan
    docker-compose run --rm wazuh-certs-generator 2>$null
    Start-Sleep -Seconds 3

    Write-Host "[+] Starting Wazuh Indexer (OpenSearch)..." -ForegroundColor DarkCyan
    docker-compose up -d wazuh.indexer
    Write-Host "[+] Waiting 60s for indexer to become healthy..." -ForegroundColor DarkCyan
    Start-Sleep -Seconds 60

    Write-Host "[+] Starting Wazuh Manager..." -ForegroundColor DarkCyan
    docker-compose up -d wazuh.manager
    Start-Sleep -Seconds 15

    Write-Host "[+] Starting Wazuh Dashboard..." -ForegroundColor DarkCyan
    docker-compose up -d wazuh.dashboard

    Write-Host "`n[+] Checking container status..." -ForegroundColor Yellow
    docker-compose ps
}

# ══════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                  NEXSOC SETUP COMPLETE                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Dashboard:    https://localhost                             ║
║  Username:     admin                                         ║
║  Password:     SecureP@ss2024!  (change in .env)            ║
║                                                              ║
║  Wazuh API:    https://localhost:55000                       ║
║  OpenSearch:   https://localhost:9200                        ║
║                                                              ║
║  NEXT STEPS:                                                 ║
║  1. Open https://localhost (accept self-signed cert)         ║
║  2. Login and verify the stack is healthy                    ║
║  3. Run Install-WazuhAgent.ps1 to enroll this laptop:        ║
║     .\scripts\Install-WazuhAgent.ps1 -ManagerIP 127.0.0.1   ║
║  4. Go to Dashboard > Agents to confirm enrollment           ║
║  5. Go to Dashboard > MITRE ATT&CK to see detections        ║
║                                                              ║
║  USEFUL COMMANDS:                                            ║
║  View logs:   docker-compose logs -f wazuh.manager           ║
║  Stop SOC:    docker-compose down                            ║
║  Restart:     docker-compose restart                         ║
║  Check status:docker-compose ps                              ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
