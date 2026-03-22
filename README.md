# NEXSOC — Real SOC Stack for Windows 11/10
## Wazuh 4.7 + OpenSearch + Custom Rules + Sysmon

---

## What You Get

| Component | Purpose | Port |
|---|---|---|
| **Wazuh Manager** | SIEM engine — collects, correlates, alerts | 1514, 1515, 55000 |
| **Wazuh Indexer** | OpenSearch — stores all events/alerts | 9200 |
| **Wazuh Dashboard** | Web UI — your SOC screen | **443 (https://localhost)** |
| **Wazuh Agent** | Installed on your laptop — sends real events | - |
| **Sysmon** | Deep Windows process/network telemetry | - |

**Your laptop becomes a monitored endpoint.** Every real process, logon, file change, registry modification, and PowerShell command is sent to the SIEM and matched against 100+ detection rules including the custom NEXSOC rules tuned for your setup.

---

## Prerequisites

- Windows 11 or 10 (64-bit)
- 8GB RAM minimum (6GB assigned to Docker)
- 20GB free disk space
- Internet connection (for downloads)

---

## STEP 1 — Run the Master Setup Script

Open **PowerShell as Administrator** and run:

```powershell
cd C:\path\to\nexsoc
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Setup-NEXSOC.ps1
```

This will:
1. Enable WSL2
2. Install Docker Desktop (if not present)
3. Configure memory for OpenSearch
4. Add firewall rules
5. Launch the full Docker stack

> **If Windows asks to restart after WSL2 install — restart, then re-run the script.**

---

## STEP 2 — Enroll Your Laptop as an Agent

After the stack is up, open a new **Admin PowerShell**:

```powershell
.\scripts\Install-WazuhAgent.ps1 -ManagerIP 127.0.0.1
```

This installs:
- Wazuh Agent (collects real Windows events)
- Sysmon (deep process/network telemetry)
- Advanced audit policy (50+ event categories)
- PowerShell script block logging

---

## STEP 3 — Open Your SOC Dashboard

```
https://localhost
Username: admin
Password: SecureP@ss2024!
```

Accept the self-signed certificate warning.

### Key Dashboard Sections:

| Section | What You'll See |
|---|---|
| **Overview** | Real alerts from your laptop |
| **Agents** | Your enrolled laptop |
| **MITRE ATT&CK** | Real technique coverage map |
| **Vulnerabilities** | CVEs on your actual software |
| **Integrity Monitoring** | Real file/registry changes |
| **Security Events** | Raw Windows logs, filtered |

---

## Custom Detection Rules (What Gets Detected)

### Windows Threats (`nexsoc_windows_rules.xml`)
| Rule ID | Detection | Severity | MITRE |
|---|---|---|---|
| 100200 | Brute force login (5+ failures/60s) | High | T1110 |
| 100210 | LSASS memory access (Mimikatz) | Critical | T1003.001 |
| 100220 | Shadow copy deletion | Critical | T1490 |
| 100221 | Ransomware file extension | Critical | T1486 |
| 100230 | PsExec / WMI lateral movement | High | T1021.002 |
| 100240 | SeDebug privilege use | High | T1134 |
| 100250 | Encoded PowerShell execution | High | T1059.001 |
| 100251 | AMSI bypass attempt | Critical | T1562 |
| 100260 | LOLBin abuse (certutil, mshta) | High | T1218 |
| 100270 | Scheduled task created | Medium | T1053 |
| 100280 | Windows Defender disabled | High | T1562 |
| 100295 | Process injection API calls | Critical | T1055 |
| 100296 | User added to Administrators | High | T1136 |

### OT/ICS (`nexsoc_ot_rules.xml`)
| Rule ID | Detection | MITRE ICS |
|---|---|---|
| 100300 | Modbus write from unauthorized IP | T0855 |
| 100302 | Modbus command storm (ICS DoS) | T0814 |
| 100311 | S7comm Stop CPU command | T0881 |
| 100320 | DNP3 control/operate command | T0803 |
| 100330 | IT-to-OT zone crossing | T0886 |
| 100350 | ICS malware filename (Industroyer/TRITON) | T0853 |
| 100360 | SCADA historian data exfiltration | T0882 |

### Network (`nexsoc_network_rules.xml`)
| Rule ID | Detection | MITRE |
|---|---|---|
| 100400 | C2 beacon pattern | T1071 |
| 100401 | DNS tunneling (long queries) | T1048.003 |
| 100410 | Port scan (20+ ports/10s) | T1046 |
| 100420 | TOR exit node traffic | T1090.003 |
| 100430 | Large outbound transfer (100MB+) | T1041 |
| 100440 | Known malicious IOC IP match | T1071 |

---

## Useful Commands

```powershell
# Check all containers
docker-compose ps

# Follow manager logs (real-time alerts)
docker-compose logs -f wazuh.manager

# Follow dashboard logs
docker-compose logs -f wazuh.dashboard

# Stop everything
docker-compose down

# Restart everything
docker-compose restart

# Check agent status on your laptop
Get-Service WazuhSvc
C:\Progra~2\ossec-agent\agent_control.exe -l

# Manually send test alert
C:\Progra~2\ossec-agent\ossec-logtest.exe
```

---

## Changing Passwords

Edit `.env` and change:
```
INDEXER_PASSWORD=YourNewPassword
API_PASSWORD=YourNewPassword
DASHBOARD_PASSWORD=YourNewPassword
```

Then restart: `docker-compose down && docker-compose up -d`

---

## Integrating External Threat Feeds

In the Wazuh Dashboard:
1. Go to **Settings → Integrations**
2. Add AlienVault OTX (free API key at otx.alienvault.com)
3. Add VirusTotal (free tier: 4 lookups/min)
4. Wazuh will automatically match IOCs against your alerts

---

## Active Response (Auto-Block)

By default, if an IP triggers rule `100200` (brute force) or `100201` (mass brute force), Wazuh will **automatically add a firewall rule to block that IP for 10 minutes**.

To check blocked IPs:
```powershell
# On your laptop
netsh advfirewall firewall show rule name="wazuh-*"
```

---

## Troubleshooting

**OpenSearch won't start:**
```powershell
wsl -u root -e sysctl -w vm.max_map_count=262144
```

**Dashboard says "no agents":**
- Make sure Wazuh Agent service is running: `Get-Service WazuhSvc`
- Check agent enrollment: `docker-compose logs wazuh.manager | Select-String "connected"`

**Port 443 conflict:**
- Change dashboard port in `docker-compose.yml`: `"8443:5601"` then access `https://localhost:8443`

**Docker memory issues:**
- Edit `.wslconfig` and reduce memory: `memory=4GB`
- Reduce OpenSearch heap in docker-compose: `OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m`
