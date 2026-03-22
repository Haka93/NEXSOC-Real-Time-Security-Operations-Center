# ============================================================
# NEXSOC — Wazuh Agent Installer for Windows 11/10
# Run this as ADMINISTRATOR in PowerShell
# ============================================================
# What this does:
#   1. Downloads Wazuh agent MSI
#   2. Installs and registers with your local SOC manager
#   3. Installs Sysmon with SwiftOnSecurity config
#   4. Enables advanced Windows audit policy
#   5. Enables PowerShell script block logging
# ============================================================

param(
    [string]$ManagerIP = "127.0.0.1",
    [string]$AgentName = $env:COMPUTERNAME,
    [string]$WazuhVersion = "4.7.3"
)

$ErrorActionPreference = "Stop"

Write-Host @"
  _   _ _______  ______ _____  ___   ____
 | \ | | ____\ \/ / ___/ _ \ / __|  / ___|  ___   ___
 |  \| |  _|  \  /\__ \ | | | |    \___ \ / _ \ / __|
 | |\  | |___ /  \ ___) |_| | |___  ___) | (_) | (__
 |_| \_|_____/_/\_\____/\___/ \____||____/ \___/ \___|

  NEXSOC Windows Agent Installer v1.0
  Manager: $ManagerIP
  Agent:   $AgentName
"@ -ForegroundColor Cyan

# ── Admin check ──
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "[ERROR] Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

$TempDir = "$env:TEMP\nexsoc-install"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# ══════════════════════════════════════════════════════════
# STEP 1: Install Wazuh Agent
# ══════════════════════════════════════════════════════════
Write-Host "`n[1/5] Downloading Wazuh Agent $WazuhVersion..." -ForegroundColor Yellow

$MsiUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WazuhVersion-1.msi"
$MsiPath = "$TempDir\wazuh-agent.msi"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $MsiUrl -OutFile $MsiPath -UseBasicParsing
    Write-Host "[OK] Downloaded Wazuh agent MSI" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "Manual download: $MsiUrl" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/5] Installing Wazuh Agent..." -ForegroundColor Yellow
$InstallArgs = @(
    "/i", $MsiPath,
    "/q",
    "WAZUH_MANAGER=`"$ManagerIP`"",
    "WAZUH_MANAGER_PORT=`"1514`"",
    "WAZUH_PROTOCOL=`"tcp`"",
    "WAZUH_AGENT_NAME=`"$AgentName`"",
    "WAZUH_REGISTRATION_SERVER=`"$ManagerIP`"",
    "WAZUH_REGISTRATION_PORT=`"1515`""
)
Start-Process msiexec.exe -ArgumentList $InstallArgs -Wait -NoNewWindow

if (Test-Path "C:\Program Files (x86)\ossec-agent\ossec-agent.exe") {
    Write-Host "[OK] Wazuh Agent installed successfully" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Wazuh Agent installation failed" -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════════════════════
# STEP 2: Install Sysmon (critical for process monitoring)
# ══════════════════════════════════════════════════════════
Write-Host "`n[2/5] Installing Sysmon with SwiftOnSecurity config..." -ForegroundColor Yellow

$SysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
$SysmonConfigUrl = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"
$SysmonZip = "$TempDir\Sysmon.zip"
$SysmonDir = "$TempDir\Sysmon"
$SysmonConfig = "$TempDir\sysmon-config.xml"

try {
    Invoke-WebRequest -Uri $SysmonUrl -OutFile $SysmonZip -UseBasicParsing
    Invoke-WebRequest -Uri $SysmonConfigUrl -OutFile $SysmonConfig -UseBasicParsing
    Expand-Archive -Path $SysmonZip -DestinationPath $SysmonDir -Force

    $SysmonExe = if ([Environment]::Is64BitOperatingSystem) { "$SysmonDir\Sysmon64.exe" } else { "$SysmonDir\Sysmon.exe" }

    # Install Sysmon with config (accept EULA)
    Start-Process $SysmonExe -ArgumentList @("-accepteula", "-i", $SysmonConfig, "-n", "-l") -Wait -NoNewWindow
    Write-Host "[OK] Sysmon installed with SwiftOnSecurity config" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Sysmon install failed (non-critical): $_" -ForegroundColor Yellow
}

# ══════════════════════════════════════════════════════════
# STEP 3: Configure Advanced Windows Audit Policy
# ══════════════════════════════════════════════════════════
Write-Host "`n[3/5] Configuring Windows Advanced Audit Policy..." -ForegroundColor Yellow

$AuditCategories = @{
    # Account Logon
    "Account Logon\Credential Validation" = "Success,Failure"
    "Account Logon\Kerberos Authentication Service" = "Success,Failure"
    "Account Logon\Kerberos Service Ticket Operations" = "Success,Failure"
    # Account Management
    "Account Management\Security Group Management" = "Success,Failure"
    "Account Management\User Account Management" = "Success,Failure"
    "Account Management\Computer Account Management" = "Success,Failure"
    # Detailed Tracking
    "Detailed Tracking\Process Creation" = "Success"
    "Detailed Tracking\Process Termination" = "Success"
    "Detailed Tracking\DPAPI Activity" = "Success,Failure"
    # Logon/Logoff
    "Logon/Logoff\Logon" = "Success,Failure"
    "Logon/Logoff\Logoff" = "Success"
    "Logon/Logoff\Special Logon" = "Success,Failure"
    "Logon/Logoff\Other Logon/Logoff Events" = "Success,Failure"
    # Object Access
    "Object Access\File System" = "Success,Failure"
    "Object Access\Registry" = "Success,Failure"
    "Object Access\SAM" = "Success,Failure"
    # Policy Change
    "Policy Change\Audit Policy Change" = "Success,Failure"
    "Policy Change\Authentication Policy Change" = "Success,Failure"
    # Privilege Use
    "Privilege Use\Sensitive Privilege Use" = "Success,Failure"
    # System
    "System\Security State Change" = "Success,Failure"
    "System\Security System Extension" = "Success,Failure"
    "System\System Integrity" = "Success,Failure"
    # DS Access
    "DS Access\Directory Service Access" = "Success,Failure"
    # Network Policy Server
    "Logon/Logoff\Network Policy Server" = "Success,Failure"
}

foreach ($Category in $AuditCategories.Keys) {
    $Success = if ($AuditCategories[$Category] -match "Success") { "enable" } else { "disable" }
    $Failure = if ($AuditCategories[$Category] -match "Failure") { "enable" } else { "disable" }
    auditpol /set /subcategory:"$Category" /success:$Success /failure:$Failure 2>$null | Out-Null
}

Write-Host "[OK] Advanced audit policy configured (${($AuditCategories.Count)} categories)" -ForegroundColor Green

# ══════════════════════════════════════════════════════════
# STEP 4: Enable PowerShell Script Block Logging
# ══════════════════════════════════════════════════════════
Write-Host "`n[4/5] Enabling PowerShell Script Block + Module Logging..." -ForegroundColor Yellow

$PSLogPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell"

# Script Block Logging
$ScriptBlockPath = "$PSLogPath\ScriptBlockLogging"
if (!(Test-Path $ScriptBlockPath)) { New-Item -Path $ScriptBlockPath -Force | Out-Null }
Set-ItemProperty -Path $ScriptBlockPath -Name "EnableScriptBlockLogging" -Value 1 -Type DWord
Set-ItemProperty -Path $ScriptBlockPath -Name "EnableScriptBlockInvocationLogging" -Value 1 -Type DWord

# Module Logging
$ModuleLogPath = "$PSLogPath\ModuleLogging"
if (!(Test-Path $ModuleLogPath)) { New-Item -Path $ModuleLogPath -Force | Out-Null }
Set-ItemProperty -Path $ModuleLogPath -Name "EnableModuleLogging" -Value 1 -Type DWord
Set-ItemProperty -Path "$ModuleLogPath\ModuleNames" -Name "*" -Value "*" -Type String -ErrorAction SilentlyContinue

# Transcription
$TranscriptPath = "$PSLogPath\Transcription"
if (!(Test-Path $TranscriptPath)) { New-Item -Path $TranscriptPath -Force | Out-Null }
Set-ItemProperty -Path $TranscriptPath -Name "EnableTranscripting" -Value 1 -Type DWord
Set-ItemProperty -Path $TranscriptPath -Name "OutputDirectory" -Value "C:\PSTranscripts" -Type String
Set-ItemProperty -Path $TranscriptPath -Name "EnableInvocationHeader" -Value 1 -Type DWord
New-Item -ItemType Directory -Force -Path "C:\PSTranscripts" | Out-Null

Write-Host "[OK] PowerShell logging enabled — transcripts at C:\PSTranscripts" -ForegroundColor Green

# ══════════════════════════════════════════════════════════
# STEP 5: Configure Wazuh Agent ossec.conf for Windows
# ══════════════════════════════════════════════════════════
Write-Host "`n[5/5] Writing Windows agent ossec.conf..." -ForegroundColor Yellow

$AgentConfig = @'
<ossec_config>
  <client>
    <server>
      <address>MANAGER_IP_PLACEHOLDER</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>windows, windows11</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
  </client>

  <client_buffer>
    <disabled>no</disabled>
    <queue_size>5000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>

  <!-- Windows Event Log collection -->
  <localfile>
    <location>Security</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>System</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Application</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-PowerShell/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-Windows Defender/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-TaskScheduler/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-WMI-Activity/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-TerminalServices-LocalSessionManager/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>

  <!-- FIM: File Integrity Monitoring -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    <scan_on_start>yes</scan_on_start>
    <directories realtime="yes" report_changes="yes" check_all="yes">%WINDIR%\System32\drivers\etc</directories>
    <directories realtime="yes" report_changes="yes" check_all="yes">%WINDIR%\System32\Tasks</directories>
    <directories realtime="yes" report_changes="yes">%USERPROFILE%\Desktop</directories>
    <directories realtime="yes" report_changes="yes">%USERPROFILE%\Downloads</directories>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Lsa</windows_registry>
    <ignore type="sregex">.log$|.tmp$|.etl$|.evtx$</ignore>
  </syscheck>

  <!-- Rootcheck -->
  <rootcheck>
    <disabled>no</disabled>
    <windows_apps>yes</windows_apps>
    <windows_malware>yes</windows_malware>
  </rootcheck>

  <!-- System inventory -->
  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="no">yes</ports>
    <processes>yes</processes>
    <hotfixes>yes</hotfixes>
  </wodle>

  <active-response>
    <disabled>no</disabled>
  </active-response>

</ossec_config>
'@

$AgentConfig = $AgentConfig -replace "MANAGER_IP_PLACEHOLDER", $ManagerIP
$AgentConfigPath = "C:\Program Files (x86)\ossec-agent\ossec.conf"
$AgentConfig | Set-Content -Path $AgentConfigPath -Encoding UTF8

Write-Host "[OK] Agent config written" -ForegroundColor Green

# ── Start the agent ──
Write-Host "`n[+] Starting Wazuh Agent service..." -ForegroundColor Yellow
try {
    Start-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
    Set-Service -Name "WazuhSvc" -StartupType Automatic
    Write-Host "[OK] Wazuh Agent service started and set to auto-start" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not start service automatically. Run: net start WazuhSvc" -ForegroundColor Yellow
}

# ── Cleanup ──
Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue

Write-Host @"

╔══════════════════════════════════════════════════════════╗
║            NEXSOC AGENT INSTALLATION COMPLETE            ║
╠══════════════════════════════════════════════════════════╣
║  Agent Name:  $AgentName
║  Manager IP:  $ManagerIP
║  Protocol:    TCP/1514
║                                                          ║
║  Monitoring:                                             ║
║  ✓ Windows Security / System / Application logs          ║
║  ✓ Sysmon (process, network, file events)                ║
║  ✓ PowerShell script block logging                       ║
║  ✓ Windows Defender events                               ║
║  ✓ File Integrity Monitoring (FIM)                       ║
║  ✓ Registry monitoring                                   ║
║  ✓ Vulnerability detection                               ║
║  ✓ Active Response (auto-block brute force)              ║
║                                                          ║
║  Verify agent in dashboard:                              ║
║  https://localhost → Agents → $AgentName
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
