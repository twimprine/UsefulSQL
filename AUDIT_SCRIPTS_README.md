# SQL Server Comprehensive Audit Scripts

This repository contains a complete set of SQL Server audit scripts designed to gather comprehensive information about SQL Server instances, databases, configuration, and operational health.

## Audit Scripts Overview

### 1. **SystemAudit.sql**
**Purpose**: Comprehensive system and instance-level audit
**Information Gathered**:
- Server hardware and system information
- SQL Server version, edition, and service pack details
- Memory configuration and usage
- CPU information and usage statistics
- Storage configuration and file locations
- Network configuration and security settings
- Login and authentication information
- Database file locations and sizes
- Performance counter statistics
- Wait statistics and performance metrics

### 2. **DatabaseInformation.sql**
**Purpose**: Database inventory and configuration analysis
**Information Gathered**:
- Complete database inventory with sizes and growth settings
- Recovery models and backup compatibility levels
- Database options and configurations
- File group information and data file details
- Database criticality assessment
- Risk analysis based on recovery model and backup frequency
- Backup recommendations per database

### 3. **BackupSolution.sql**
**Purpose**: Backup strategy and solution analysis
**Information Gathered**:
- Current backup methods and frequencies
- Backup file locations and retention policies
- Recovery objectives analysis
- Backup job schedules and success rates
- Point-in-time recovery capabilities
- Disaster recovery readiness assessment
- Backup solution recommendations

### 4. **ConfigurationMaintenance.sql**
**Purpose**: Configuration optimization and maintenance analysis
**Information Gathered**:
- Memory configuration analysis and recommendations
- TempDB configuration assessment
- Monitoring tools and alerting setup
- Maintenance plan status and job analysis
- Configuration issues identification
- Operational health summary

### 5. **SystemAudit.ps1** (PowerShell Complement)
**Purpose**: System-level information gathering from Windows perspective
**Information Gathered**:
- Operating system and hardware details
- Disk space and storage analysis
- SQL Server service status
- Network configuration
- Windows Firewall settings
- Running processes and resource usage
- System event log errors
- Performance counter snapshots (optional)
- Windows update status

## Usage Instructions

### Prerequisites
- SQL Server with appropriate permissions (sysadmin role recommended)
- PowerShell execution policy allowing script execution (for PowerShell script)
- Access to system DMVs and msdb database

### Running the SQL Scripts

#### Option 1: SQL Server Management Studio (SSMS)
1. Open SQL Server Management Studio
2. Connect to the target SQL Server instance
3. Open each .sql file
4. Execute the scripts in any order (they are independent)
5. Review results and save output as needed

#### Option 2: Command Line (sqlcmd)
```bash
# Run individual scripts
sqlcmd -S ServerName -E -i "SystemAudit.sql" -o "SystemAudit_Output.txt"
sqlcmd -S ServerName -E -i "DatabaseInformation.sql" -o "DatabaseInfo_Output.txt"
sqlcmd -S ServerName -E -i "BackupSolution.sql" -o "BackupSolution_Output.txt"
sqlcmd -S ServerName -E -i "ConfigurationMaintenance.sql" -o "ConfigMaint_Output.txt"

# Or run all scripts in sequence
for %f in (*.sql) do sqlcmd -S ServerName -E -i "%f" -o "%~nf_Output.txt"
```

### Running the PowerShell Script

#### Basic Usage
```powershell
# Run with default settings
.\SystemAudit.ps1

# Specify custom output path
.\SystemAudit.ps1 -OutputPath "C:\Audits\MyServerAudit.txt"

# Include performance counters (longer execution time)
.\SystemAudit.ps1 -IncludePerformanceCounters

# Target specific SQL instance
.\SystemAudit.ps1 -SQLInstance "ServerName\InstanceName"
```

#### Advanced Usage
```powershell
# Complete audit with all options
.\SystemAudit.ps1 -OutputPath "C:\Audits\CompleteAudit_$(Get-Date -Format 'yyyyMMdd').txt" -SQLInstance "PROD-SQL01\MSSQLSERVER" -IncludePerformanceCounters
```

## Required Permissions

### SQL Server Permissions
- **sysadmin** server role (recommended for complete access)
- **Minimum required permissions**:
  - VIEW SERVER STATE
  - VIEW ANY DEFINITION
  - Access to msdb database for backup and job information
  - SELECT permissions on system DMVs

### Windows Permissions
- **PowerShell script**: Local Administrator rights recommended
- **Minimum required permissions**:
  - Read access to system information
  - Access to Windows Event Logs
  - Permission to query WMI objects
  - Access to performance counters

## Output Interpretation

### Critical Issues to Look For

#### From SQL Scripts:
- **Memory**: Unlimited max server memory settings
- **TempDB**: Single data file configuration
- **Backups**: Databases without recent backups
- **Recovery**: Full recovery model without log backups
- **Storage**: Low disk space or file growth issues
- **Performance**: High wait times or blocking

#### From PowerShell Script:
- **Hardware**: Insufficient memory or CPU resources
- **Storage**: Low disk space or slow storage
- **Services**: SQL Server services not running
- **Security**: Firewall or network configuration issues
- **System Health**: Recent critical errors in event logs

### Recommendations Priority

1. **CRITICAL** (Fix Immediately):
   - Databases in FULL recovery without log backups
   - Unlimited memory configuration on shared servers
   - Critical system errors or service failures
   - Storage space below 10% free

2. **HIGH** (Fix Soon):
   - Single TempDB data file
   - Missing backup jobs
   - Excessive wait statistics
   - Outdated SQL Server versions

3. **MEDIUM** (Plan to Fix):
   - Suboptimal configuration settings
   - Missing monitoring alerts
   - Inefficient maintenance plans

## Customization

### Modifying Scripts
All scripts are designed to be easily customizable:

- **Add custom databases**: Modify WHERE clauses to include/exclude specific databases
- **Change thresholds**: Update percentage values for warnings and recommendations
- **Add custom metrics**: Include additional DMV queries or performance counters
- **Modify output format**: Change column names or add calculated fields

### Example Customizations

```sql
-- Add custom database filter to DatabaseInformation.sql
WHERE d.name NOT IN ('tempdb', 'model', 'msdb', 'master', 'ReportServer', 'ReportServerTempDB')

-- Modify memory threshold in ConfigurationMaintenance.sql
WHEN MaxServerMemoryMB > TotalPhysicalMemoryMB * 0.8  -- Changed from 0.9 to 0.8

-- Add custom performance counter in SystemAudit.ps1
$CustomCounters = @(
    "\SQLServer:Buffer Manager\Buffer cache hit ratio",
    "\SQLServer:SQL Statistics\Batch Requests/sec"
)
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Solution: Run as administrator or request sysadmin permissions

2. **Object Not Found Errors**
   - Solution: Check SQL Server version compatibility
   - Some DMVs may not exist in older versions

3. **PowerShell Execution Policy**
   - Solution: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

4. **Network Connectivity**
   - Solution: Verify SQL Server instance name and network connectivity
   - Check firewall settings and SQL Server network configuration

### Version Compatibility

- **SQL Server 2008 and later**: All scripts compatible
- **SQL Server 2005**: Some DMVs may not be available
- **Earlier versions**: Significant modifications required

## Best Practices

1. **Schedule Regular Audits**: Run monthly or quarterly
2. **Document Changes**: Track configuration changes over time
3. **Automate Where Possible**: Use SQL Agent jobs for regular execution
4. **Security**: Store output files securely and limit access
5. **Follow-up**: Create action plans based on audit findings

## Support and Updates

These scripts are designed to be self-contained and require no external dependencies. For updates or issues:

1. Check script comments for version information
2. Test scripts in development environment first
3. Backup current configurations before making changes
4. Document any customizations for future reference

---

**Note**: Always test these scripts in a development environment before running in production. While designed to be read-only, they do query system tables and DMVs which may have minimal performance impact during execution.
