# Azure Firewall Syslog Emulator for Sentinel Training

This project provides a complete Azure infrastructure setup to simulate firewall syslog messages for Microsoft Sentinel training purposes. It consists of an emulated firewall (containerized application) that sends realistic firewall logs as syslog messages to a VM, which can then be ingested by Microsoft Sentinel for analysis and parser development. (the Data Collection Rule is not created, you should do this as a demo)

## Architecture Overview

The solution deploys the following Azure resources:

```
┌─────────────────────────────────────────────────────────┐
│                     Azure Virtual Network               │
│                      (10.34.0.0/16)                     │
│                                                         │
│  ┌─────────────────┐        ┌─────────────────────────┐ │
│  │   FW Subnet     │        │    Monitor Subnet       │ │
│  │ (10.34.1.0/24)  │        │   (10.34.2.0/24)        │ │
│  │                 │        │                         │ │
│  │ ┌─────────────┐ │        │ ┌─────────────────────┐ │ │
│  │ │     ACI     │ │------->│ │    Ubuntu VM        │ │ │
│  │ │ (Firewall   │ │ syslog │ │   (Syslog Server)   │ │ │
│  │ │ Emulator)   │ │ UDP/TCP│ │                     │ │ │
│  │ └─────────────┘ │  :514  │ └─────────────────────┘ │ │
│  └─────────────────┘        └─────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  Microsoft Sentinel │
                    │    (via AMA DCR)    │
                    └─────────────────────┘
```

### Components

1. **Azure Container Instance (ACI)**: Runs a Python script that generates and sends realistic firewall log messages via syslog
2. **Ubuntu Virtual Machine**: Acts as a syslog server receiving the messages on port 514 (UDP/TCP)
3. **Virtual Network**: Provides secure network isolation with dedicated subnets
4. **Network Security Groups**: Allow SSH access and syslog traffic (port 514)

## Deployed Resources

### Virtual Network
- **Address Space**: 10.34.0.0/16
- **Firewall Subnet**: 10.34.1.0/24 (hosts the ACI container)
- **Monitor Subnet**: 10.34.2.0/24 (hosts the Ubuntu VM)

### Ubuntu Virtual Machine
- **Size**: Standard_B2s
- **OS**: Ubuntu 22.04 LTS
- **Network**: Private IP in monitor subnet, public IP for SSH access
- **Services**: 
  - SSH (port 22)
  - Rsyslog server (port 514 UDP/TCP)
- **Purpose**: Receives syslog messages from the firewall emulator

### Azure Container Instance
- **Image**: Custom Python application (firewall log simulator)
- **Network**: Deployed in firewall subnet
- **Function**: Continuously generates and sends firewall syslog messages to the VM

## Firewall Log Simulation

The containerized application (`simulatesyslog.py`) generates realistic firewall log entries including:

- **Connection events**: ACCEPT/DENY actions
- **Traffic details**: Source/destination IPs, ports, protocols
- **Firewall rules**: Simulated rule numbers and actions
- **Metrics**: Bytes sent, packet counts
- **Timing**: Configurable message rates

### Sample Log Format
```
<14>Oct 20 10:30:45 firewall-emulator fw-daemon[1234]: ACCEPT rule=100 src=203.0.113.45:443 dst=10.34.2.10:54321 proto=TCP bytes=1524 packets=3
```

## Deployment Instructions

### Prerequisites
- Azure CLI installed and configured
- Azure Developer CLI (azd) installed
- Appropriate Azure subscription permissions

### Deploy the Infrastructure

1. **Clone and navigate to the project**:
   ```bash
   git clone https://github.com/koenraadhaedens/azd-firewall-send-syslog-messages
   cd azd-firewall-send-syslog-messages
   ```

2. **Initialize azd environment**:
   ```bash
   azd init
   ```

3. **Deploy the infrastructure**:
   ```bash
   azd up
   ```
   
   You'll be prompted for:
   - Environment name
   - Azure location
   - VM administrator password

4. **Access the VM** (optional for verification):
   ```bash
   ssh linadmin@<vm-public-ip>
   sudo tail -f /var/log/syslog
   ```

## Microsoft Sentinel Integration

### Setting up Sentinel to Collect Syslog Data

1. **Navigate to Microsoft Sentinel** in your Azure portal
2. **Add a Syslog Data Connector**:
   - Go to Data connectors
   - Search for "Syslog"
   - Select "Syslog via AMA (Azure Monitor Agent)"

3. **Create a Data Collection Rule (DCR)**:
   - Click "Create data collection rule"
   - Name: `DCR-FirewallSyslog`
   - Select your resource group and region
   - Add the Ubuntu VM as a resource
   - Configure syslog facilities (select relevant ones like `LOG_USER`, `info`)

4. **Verify Data Flow**:
   - Wait 5-10 minutes for data to start flowing
   - Go to Logs in Sentinel workspace
   - Query: `Syslog | where Computer contains "vm-ubuntu" | take 10`

### Sample Queries

**Basic syslog ingestion verification**:
```kusto
Syslog
| where TimeGenerated > ago(1h)
| where Computer contains "vm-ubuntu"
| take 10
```

**Firewall-specific messages**:
```kusto
Syslog
| where SyslogMessage contains "ACCEPT" or SyslogMessage contains "DENY"
| project TimeGenerated, Computer, SyslogMessage
| order by TimeGenerated desc
```

## Creating a Custom Parser Function

Once data is flowing into Sentinel, create a parser function to structure the firewall logs:

### Sample Parser Function (KQL)
```kusto
// Function: ParseFirewallLogs
Syslog
| where Computer == "fw-simulator"  // Filter only this device
| extend msg = SyslogMessage
| parse msg with * "action=" action " proto=" proto " src=" src " spt=" spt:int " dst=" dst " dpt=" dpt:int " bytes=" bytes:int " pkts=" pkts:int " rule=" rule
| project TimeGenerated, action, proto, src, spt, dst, dpt, bytes, pkts, rule
```

### Creating the Function in Sentinel

1. **Go to Logs** in your Sentinel workspace
2. **Create a new function**:
   - Click "Save" → "Save as function"
   - Function name: `ParseFirewallLogs`
   - Category: `Custom`
   - Paste the parser function above

3. **Test the parser**:
   ```kusto
   ParseFirewallLogs
   | take 10
   ```

## Monitoring and Troubleshooting

### Verify Container is Running
```bash
az container show --resource-group rg-<environment-name> --name aci-fwsyslog-<environment-name>
```

### Check Container Logs
```bash
az container logs --resource-group rg-<environment-name> --name aci-fwsyslog-<environment-name>
```

### Verify VM Syslog Service
```bash
ssh linadmin@<vm-public-ip>
sudo systemctl status rsyslog
sudo tail -f /var/log/syslog
```

### Common Issues
- **No data in Sentinel**: Check DCR configuration and VM connectivity
- **Container not sending**: Verify network connectivity between subnets
- **Permission issues**: Ensure Sentinel workspace has proper permissions to VM

## Clean Up

To remove all resources:
```bash
azd down
```

## Training Scenarios

This setup enables various Sentinel training scenarios:

1. **Data Ingestion**: Understanding how syslog data flows into Sentinel
2. **Parser Development**: Creating custom parsers for firewall logs
3. **Analytics Rules**: Building detection rules based on firewall events
4. **Workbook Creation**: Visualizing firewall traffic patterns
5. **Incident Investigation**: Practicing security investigations with firewall data

## Customization

### Modify Log Generation
Edit `Docker/simulatesyslog.py` to:
- Change log formats
- Adjust message rates
- Add new log types
- Modify IP ranges or ports

### Scale the Solution
- Deploy multiple ACI instances for higher volume
- Modify VM size for better performance
- Add additional log sources or formats

## Security Considerations

- VM has public IP for SSH access (restrict source IPs as needed)
- Network Security Groups limit traffic to required ports only
- Consider using Azure Bastion for enhanced security in production scenarios
- Default VM credentials should be changed in production environments