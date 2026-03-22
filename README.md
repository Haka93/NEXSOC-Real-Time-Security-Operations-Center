<div align="center">

# ⬡ NEXSOC
### Real-Time Security Operations Center
**Wazuh 4.7 · OpenSearch · Docker · Windows 11/10**

![License](https://img.shields.io/badge/license-MIT-blue)
![Wazuh](https://img.shields.io/badge/Wazuh-4.7.3-00d4ff)
![Platform](https://img.shields.io/badge/platform-Windows%2011%2F10-0078d4)
![Docker](https://img.shields.io/badge/deploy-Docker-2496ED)
![MITRE](https://img.shields.io/badge/MITRE%20ATT%26CK-mapped-red)
![OT](https://img.shields.io/badge/OT%2FICS-IEC%2062443-orange)

*A production-ready, self-hosted SOC stack that turns your Windows laptop 
into a fully monitored, threat-detecting security operations center.*

</div>

---

## 🔍 What is NEXSOC?

NEXSOC is a **fully functional, real SOC deployment** — not a simulation. It 
installs a complete SIEM stack on your Windows machine via Docker and enrolls 
your laptop as a monitored endpoint. Every real process, logon, file change, 
registry modification, and PowerShell command on your machine is collected, 
correlated, and matched against 100+ custom detection rules.

Built for security professionals, OT/ICS engineers, and blue teamers who want 
a serious home lab or lightweight enterprise SOC without the enterprise price tag.

---

## 🏗️ Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    Windows 11/10 Host                    │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Docker Desktop (WSL2)               │    │
│  │                                                  │    │
│  │  ┌──────────────┐  ┌──────────────────────────┐ │    │
│  │  │ Wazuh Manager│  │   Wazuh Indexer           │ │    │
│  │  │ (SIEM Engine)│◄─│   (OpenSearch 2.x)        │ │    │
│  │  │ Port 1514    │  │   Port 9200               │ │    │
│  │  │ Port 55000   │  └──────────────────────────┘ │    │
│  │  └──────┬───────┘              ▲                 │    │
│  │         │              ┌───────┴──────────────┐  │    │
│  │         │              │  Wazuh Dashboard      │  │    │
│  │         │              │  (OpenSearch Dashbrd) │  │    │
│  │         │              │  https://localhost    │  │    │
│  │         │              └──────────────────────┘  │    │
│  └─────────┼────────────────────────────────────────┘    │
│            │ TCP/1514                                     │
│  ┌─────────▼──────────────────────────────────────┐      │
│  │           Wazuh Agent (your laptop)             │      │
│  │  + Sysmon · Advanced Audit · PS Logging · FIM  │      │
│  └────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

---

## ✨ Features

### 🔴 Real-Time Threat Detection
- **100+ custom detection rules** mapped to MITRE ATT&CK
- Alerts stream live into the dashboard with severity levels
- Auto-correlation across multiple log sources

### 🖥️ Windows 11/10 Endpoint Monitoring
- Windows Security / System / Application event logs
- **Sysmon** — process creation, network connections, file creation, registry changes
- **PowerShell** script block logging + transcription
- Windows Defender, Task Scheduler, WMI activity logs
- 50+ advanced audit policy categories enabled automatically

### 🔒 File Integrity Monitoring (FIM)
- Real-time monitoring of System32, Downloads, Desktop, Tasks
- Registry key monitoring (Run, RunOnce, LSA, Services)
- Instant alerts on unauthorized file/registry changes

### 🏭 OT/ICS Detection (IEC 62443)
- Modbus unauthorized write detection (FC05/FC06/FC15/FC16)
- S7comm Stop CPU command detection
- DNP3 control/operate anomalies
- IT-to-OT Purdue model zone crossing alerts
- ICS malware signatures (Industroyer, TRITON, CrashOverride)
- SCADA historian data exfiltration detection

### 🌐 Network Threat Detection
- C2 beacon pattern recognition
- DNS tunneling detection (long query analysis)
- Port scan detection (20+ ports/10s)
- TOR exit node traffic
- Large data exfiltration (100MB+ outbound)
- Known malicious IOC IP matching

### 🦠 Ransomware Detection
- Shadow copy deletion (vssadmin, wmic, bcdedit)
- Security/backup service termination
- Mass file encryption pattern (FIM correlation)
- Ransom note file creation detection
- Backup destruction commands

### 🤖 Active Response
- **Automatic IP blocking** on brute force detection
- Firewall rule injection on confirmed threats
- Configurable block duration (default 10 minutes)

### 🔍 Vulnerability Management
- Real CVE detection against installed software
- Windows hotfix/patch status tracking
- CVSS scoring per asset
- NVD + Microsoft MSU feed integration

---

## 📦 What's Included
```
nexsoc/
├── docker-compose.yml              # Full Wazuh stack (Manager + Indexer + Dashboard)
├── .env                            # Passwords and config
├── README.md                       # This file
├── config/
│   └── wazuh/
│       ├── ossec/
│       │   └── ossec.conf          # Manager config (FIM, rootcheck, active response)
│       ├── rules/
│       │   ├── nexsoc_windows_rules.xml    # Windows threat detection (13 rules)
│       │   ├── nexsoc_ot_rules.xml         # OT/ICS detection (12 rules)
│       │   ├── nexsoc_network_rules.xml    # Network threats (8 rules)
│       │   └── nexsoc_ransomware_rules.xml # Ransomware detection (4 rules)
│       └── certs.yml               # SSL certificate config
└── scripts/
    ├── Setup-NEXSOC.ps1            # One-click SOC deployment
    └── Install-WazuhAgent.ps1      # Windows agent + Sysmon installer
```

---

## ⚡ Quick Start

### Prerequisites
- Windows 11 or 10 (64-bit)
- 8GB RAM (6GB assigned to Docker)
- 20GB free disk space
- PowerShell 5.1+ (pre-installed on Windows 10/11)

### 1. Clone the repo
```powershell
git clone https://github.com/YOURUSERNAME/nexsoc.git
cd nexsoc
```

### 2. Deploy the SOC stack
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Setup-NEXSOC.ps1
```
Installs Docker Desktop, enables WSL2, configures memory, adds firewall rules, 
and launches the full Wazuh stack. **~5 minutes.**

### 3. Enroll your laptop
```powershell
.\scripts\Install-WazuhAgent.ps1 -ManagerIP 127.0.0.1
```
Installs Wazuh Agent, Sysmon, advanced audit policy, and PowerShell logging.

### 4. Open your SOC
```
https://localhost
Username: admin
Password: SecureP@ss2024!
```

> ⚠️ Change the default password in `.env` before deploying in any shared environment.

---

## 🎯 Detection Rules

### Windows Rules (`nexsoc_windows_rules.xml`)

| Rule ID | Detection | Severity | MITRE |
|---------|-----------|----------|-------|
| 100200 | Brute force — 5+ failures/60s | High | T1110 |
| 100210 | LSASS memory access (Mimikatz) | Critical | T1003.001 |
| 100220 | Shadow copy deletion | Critical | T1490 |
| 100221 | Ransomware file extension detected | Critical | T1486 |
| 100230 | PsExec / WMI lateral movement | High | T1021.002 |
| 100240 | SeDebug privilege use | High | T1134 |
| 100250 | Encoded PowerShell execution | High | T1059.001 |
| 100251 | AMSI bypass attempt | Critical | T1562 |
| 100260 | LOLBin abuse (certutil/mshta) | High | T1218 |
| 100270 | Scheduled task created | Medium | T1053 |
| 100280 | Windows Defender disabled | High | T1562 |
| 100295 | Process injection API calls | Critical | T1055 |
| 100296 | User added to Administrators | High | T1136 |

### OT/ICS Rules (`nexsoc_ot_rules.xml`)

| Rule ID | Detection | Severity | MITRE ICS |
|---------|-----------|----------|-----------|
| 100300 | Modbus write from unauthorized IP | Critical | T0855 |
| 100302 | Modbus command storm (ICS DoS) | Critical | T0814 |
| 100311 | S7comm Stop CPU command | Critical | T0881 |
| 100320 | DNP3 control/operate command | High | T0803 |
| 100330 | IT-to-OT Purdue zone crossing | Medium | T0886 |
| 100350 | ICS malware filename match | Critical | T0853 |
| 100360 | SCADA historian exfiltration | High | T0882 |

### Network Rules (`nexsoc_network_rules.xml`)

| Rule ID | Detection | Severity | MITRE |
|---------|-----------|----------|-------|
| 100400 | C2 beacon pattern | High | T1071 |
| 100401 | DNS tunneling | High | T1048.003 |
| 100410 | Port scan (20+ ports/10s) | Medium | T1046 |
| 100420 | TOR exit node traffic | High | T1090.003 |
| 100430 | Large outbound transfer 100MB+ | High | T1041 |
| 100440 | Known malicious IOC IP | Critical | T1071 |

---

## 🛠️ Useful Commands
```powershell
# Check all containers
docker-compose ps

# Live alert stream
docker-compose logs -f wazuh.manager

# Check enrolled agents
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# Restart full stack
docker-compose restart

# Stop everything
docker-compose down

# Check agent status on laptop
Get-Service WazuhSvc

# View active firewall blocks (active response)
netsh advfirewall firewall show rule name="wazuh-*"
```

---

## 🔧 Configuration

### Change passwords
Edit `.env`:
```env
INDEXER_PASSWORD=YourStrongPassword
API_PASSWORD=YourStrongPassword
DASHBOARD_PASSWORD=YourStrongPassword
```
Then restart: `docker-compose down && docker-compose up -d`

### Add threat intel feeds
1. Get a free API key at [otx.alienvault.com](https://otx.alienvault.com)
2. Dashboard → Settings → Integrations → AlienVault OTX
3. Wazuh auto-matches IOCs against all incoming alerts

### Tune active response block time
In `config/wazuh/ossec/ossec.conf`:
```xml
<active-response>
  <command>firewall-drop</command>
  <timeout>3600</timeout>  <!-- seconds — change to your preference -->
</active-response>
```

---

## 📊 Dashboard Sections

| Section | What You See |
|---------|-------------|
| **Overview** | Real-time alert feed, severity breakdown, agent status |
| **Threat Hunting** | Search across all events with KQL |
| **MITRE ATT&CK** | Live technique coverage heatmap |
| **Vulnerabilities** | CVEs on your actual installed software |
| **Integrity Monitoring** | Real file and registry change alerts |
| **Security Events** | Raw Windows event logs, filterable |
| **Agents** | Your enrolled laptop with health status |

---

## 🚨 Troubleshooting

**OpenSearch won't start:**
```powershell
wsl -u root -e sysctl -w vm.max_map_count=262144
docker-compose restart wazuh.indexer
```

**Dashboard shows no agents:**
```powershell
Get-Service WazuhSvc          # Should show Running
docker-compose logs wazuh.manager | Select-String "connected"
```

**Port 443 conflict (IIS or other service):**
Change in `docker-compose.yml`: `"8443:5601"` → access at `https://localhost:8443`

**Low RAM — containers crashing:**
In `docker-compose.yml` reduce heap:
```yaml
OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
```

---

## 🗺️ Roadmap

- [ ] Suricata IDS/IPS integration (network packet inspection)
- [ ] Zeek network traffic analysis
- [ ] MISP threat intel platform integration
- [ ] Grafana dashboards for executive reporting
- [ ] TheHive incident response platform
- [ ] Cortex automated analysis
- [ ] OT protocol deep packet inspection (Modbus/S7/DNP3 via Zeek)
- [ ] Automated VAPT report generation (DOCX/PDF)

---

## 📚 References

- [Wazuh Documentation](https://documentation.wazuh.com)
- [MITRE ATT&CK Framework](https://attack.mitre.org)
- [MITRE ATT&CK for ICS](https://attack.mitre.org/matrices/ics/)
- [IEC 62443 Standard](https://www.iec.ch/iec62443)
- [Sysmon Configuration](https://github.com/SwiftOnSecurity/sysmon-config)
- [CISA ICS-CERT Advisories](https://www.cisa.gov/ics-advisories)

---

## 📄 License

MIT License — free to use, modify, and distribute.

---

## 👤 Author

Built by a Rail OT Cybersecurity Engineer (Harish Karthikeya A.) with hands-on VAPT experience 
across IT and OT/ICS/SCADA environments.

---

<div align="center">
  <b>If this helped you, drop a ⭐ on the repo</b>
</div>
