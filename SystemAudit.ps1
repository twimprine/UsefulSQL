# ============================================================================
# SQL SERVER SYSTEM AUDIT - POWERSHELL COMPLEMENT
# ============================================================================
# This PowerShell script gathers operating system and hardware information
# that cannot be obtained from within SQL Server. It complements the SQL
# audit scripts by providing OS-level details about the server environment.
# 
# KEY INFORMATION GATHERED:
# - Operating system version and configuration
# - Hardware specifications (CPU, memory, disk)
# - Windows services status (SQL Server, Agent, etc.)
# - Network configuration and connectivity
# - Security settings and Windows features
# - Performance counters (optional)
# - Event log entries related to SQL Server
# 
# USAGE:
# Run this script on the Windows server hosting SQL Server
# Requires administrative privileges for complete information
# 
# EXAMPLES:
# .\SystemAudit.ps1
# .\SystemAudit.ps1 -SQLInstance "MYSERVER\INSTANCE01" -OutputPath "C:\Audit\results.txt"
# .\SystemAudit.ps1 -IncludePerformanceCounters
# 
# Author: Thomas Wimprine
# Date: $(Get-Date)
# ============================================================================

param(
    [string]$OutputPath = "C:\temp\SQLServerSystemAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",
    [string]$SQLInstance = "localhost",
    [switch]$IncludePerformanceCounters = $false
)

# Function to write output both to console and file
function Write-AuditOutput {
    param([string]$Message, [string]$Section = "")
    
    if ($Section) {
        $FormattedMessage = "`n===============================================================================`n$Section`n===============================================================================`n$Message"
    } else {
        $FormattedMessage = $Message
    }
    
    Write-Host $FormattedMessage
    $FormattedMessage | Out-File -FilePath $OutputPath -Append -Encoding UTF8
}

# Initialize audit
$StartTime = Get-Date
Write-AuditOutput -Message "SQL SERVER SYSTEM AUDIT STARTED: $StartTime" -Section "AUDIT INITIALIZATION"
Write-AuditOutput -Message "Target SQL Instance: $SQLInstance"
Write-AuditOutput -Message "Output File: $OutputPath"

try {
    # ============================================================================
    # SECTION 1: SYSTEM INFORMATION
    # 
    # This section gathers basic operating system and hardware information
    # that provides context for SQL Server performance and capacity planning.
    # 
    # Key concepts:
    # - OS Version: Determines available SQL Server features and support
    # - Physical Memory: Total RAM available to all applications
    # - Processors: CPU count affects SQL Server threading and performance
    # - System Architecture: 32-bit vs 64-bit affects memory limitations
    # ============================================================================
    $SystemInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory, 
                                                  CsProcessors, CsNumberOfProcessors, CsNumberOfLogicalProcessors
    
    $SystemOutput = @"
Operating System: $($SystemInfo.WindowsProductName)
OS Version: $($SystemInfo.WindowsVersion)
Total Physical Memory: $([math]::Round($SystemInfo.TotalPhysicalMemory / 1GB, 2)) GB
Physical Processors: $($SystemInfo.CsNumberOfProcessors)
Logical Processors: $($SystemInfo.CsNumberOfLogicalProcessors)
Processor Details: $($SystemInfo.CsProcessors -join ', ')
"@
    
    Write-AuditOutput -Message $SystemOutput -Section "SYSTEM INFORMATION"    # ============================================================================
    # SECTION 2: DISK INFORMATION
    # 
    # Disk space and performance are critical for SQL Server operations.
    # This section examines disk capacity and usage patterns.
    # 
    # Key concepts:
    # - Drive Letters: Windows disk partitions (C:, D:, E:, etc.)
    # - Free Space: Available storage for database growth
    # - NTFS vs FAT32: File system types (NTFS recommended for SQL Server)
    # - Disk Performance: Speed affects query performance and backup times
    # ============================================================================
    $DiskInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | 
                Select-Object DeviceID, VolumeName, 
                @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}},
                @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}},
                @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}}

    $DiskOutput = "DISK SPACE INFORMATION:`n" + ($DiskInfo | Format-Table -AutoSize | Out-String)
    Write-AuditOutput -Message $DiskOutput -Section "DISK INFORMATION"    # ============================================================================
    # SECTION 3: SQL SERVER SERVICES
    # 
    # SQL Server runs as Windows services. This section checks service status,
    # startup configuration, and identifies all SQL Server-related services.
    # 
    # Key concepts:
    # - SQL Server Engine: Core database service
    # - SQL Server Agent: Job scheduling and automation service  
    # - Analysis Services: OLAP and data mining service
    # - Integration Services: ETL (Extract, Transform, Load) service
    # - Reporting Services: Report generation and delivery service
    # ============================================================================
    $SQLServices = Get-Service | Where-Object { $_.Name -like "*SQL*" -or $_.DisplayName -like "*SQL*" } |
                   Select-Object Name, DisplayName, Status, StartType
    
    if ($SQLServices) {
        $ServiceOutput = "SQL SERVER SERVICES:`n" + ($SQLServices | Format-Table -AutoSize | Out-String)
    } else {
        $ServiceOutput = "No SQL Server services detected on this system."
    }
    Write-AuditOutput -Message $ServiceOutput -Section "SQL SERVER SERVICES"    # ============================================================================
    # SECTION 4: NETWORK CONFIGURATION
    # 
    # Network connectivity is essential for SQL Server client connections,
    # backups to network locations, and high availability configurations.
    # 
    # Key concepts:
    # - Network Adapters: Physical/virtual network interfaces
    # - TCP/IP Ports: Communication endpoints (default SQL Server port is 1433)
    # - Named Pipes: Alternative communication protocol for local connections
    # - Network Performance: Bandwidth affects backup times and replication
    # ============================================================================
    $NetworkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | 
                       Select-Object Name, InterfaceDescription, LinkSpeed
    
    $NetworkOutput = "ACTIVE NETWORK ADAPTERS:`n" + ($NetworkAdapters | Format-Table -AutoSize | Out-String)
    Write-AuditOutput -Message $NetworkOutput -Section "NETWORK CONFIGURATION"

    # ============================================================================
    # SECTION 5: WINDOWS FIREWALL STATUS
    # ============================================================================
    try {
        $FirewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled
        $FirewallOutput = "WINDOWS FIREWALL STATUS:`n" + ($FirewallProfiles | Format-Table -AutoSize | Out-String)
    } catch {
        $FirewallOutput = "Unable to retrieve Windows Firewall status: $($_.Exception.Message)"
    }
    Write-AuditOutput -Message $FirewallOutput -Section "WINDOWS FIREWALL"    # ============================================================================
    # SECTION 6: RUNNING PROCESSES (SQL SERVER RELATED)
    # 
    # This section examines SQL Server processes running on the system,
    # including memory usage and CPU consumption patterns.
    # 
    # Key concepts:
    # - sqlservr.exe: Main SQL Server database engine process
    # - sqlagent.exe: SQL Server Agent service process
    # - Working Set: Physical memory currently used by process
    # - CPU Time: Total processor time consumed since process start
    # - Process ID: Unique identifier for each running process
    # ============================================================================
    $SQLProcesses = Get-Process | Where-Object { $_.ProcessName -like "*sql*" } | 
                    Select-Object ProcessName, Id, @{Name="WorkingSet(MB)";Expression={[math]::Round($_.WorkingSet/1MB,2)}}, 
                    @{Name="CPU(s)";Expression={$_.TotalProcessorTime.TotalSeconds}}, StartTime
    
    if ($SQLProcesses) {
        $ProcessOutput = "SQL SERVER RELATED PROCESSES:`n" + ($SQLProcesses | Format-Table -AutoSize | Out-String)
    } else {
        $ProcessOutput = "No SQL Server related processes found."
    }
    Write-AuditOutput -Message $ProcessOutput -Section "SQL SERVER PROCESSES"    # ============================================================================
    # SECTION 7: EVENT LOG ERRORS (LAST 24 HOURS)
    # 
    # Windows Event Logs contain important system and application error messages
    # that can indicate hardware problems, configuration issues, or failures.
    # 
    # Key concepts:
    # - System Log: Hardware, driver, and OS-level events
    # - Application Log: Software application events (including SQL Server)
    # - Error Levels: Critical, Error, Warning, Information
    # - Event IDs: Specific error codes that identify problem types
    # ============================================================================
    $Yesterday = (Get-Date).AddDays(-1)
    try {
        $SystemErrors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3; StartTime=$Yesterday} -MaxEvents 50 -ErrorAction SilentlyContinue |
                        Select-Object TimeCreated, LevelDisplayName, Id, ProviderName, @{Name="Message";Expression={$_.Message.Substring(0,[Math]::Min(100,$_.Message.Length))}}
        
        if ($SystemErrors) {
            $ErrorOutput = "RECENT SYSTEM ERRORS (Last 24 hours):`n" + ($SystemErrors | Format-Table -AutoSize | Out-String)
        } else {
            $ErrorOutput = "No system errors found in the last 24 hours."
        }
    } catch {
        $ErrorOutput = "Unable to retrieve system event log: $($_.Exception.Message)"
    }
    Write-AuditOutput -Message $ErrorOutput -Section "SYSTEM EVENT LOG"

    # ============================================================================
    # SECTION 8: PERFORMANCE COUNTERS (OPTIONAL)
    # ============================================================================
    if ($IncludePerformanceCounters) {
        try {
            $PerfCounters = @(
                "\Processor(_Total)\% Processor Time",
                "\Memory\Available MBytes",
                "\Memory\Pages/sec",
                "\PhysicalDisk(_Total)\Avg. Disk Queue Length",
                "\PhysicalDisk(_Total)\% Disk Time"
            )
            
            $PerfData = @()
            foreach ($Counter in $PerfCounters) {
                try {
                    $Value = (Get-Counter -Counter $Counter -SampleInterval 1 -MaxSamples 3 | 
                             Select-Object -ExpandProperty CounterSamples | 
                             Measure-Object -Property CookedValue -Average).Average
                    $PerfData += [PSCustomObject]@{
                        Counter = $Counter
                        Value = [math]::Round($Value, 2)
                    }
                } catch {
                    $PerfData += [PSCustomObject]@{
                        Counter = $Counter
                        Value = "Error: $($_.Exception.Message)"
                    }
                }
            }
            
            $PerfOutput = "PERFORMANCE COUNTERS (3-sample average):`n" + ($PerfData | Format-Table -AutoSize | Out-String)
        } catch {
            $PerfOutput = "Unable to retrieve performance counters: $($_.Exception.Message)"
        }
        Write-AuditOutput -Message $PerfOutput -Section "PERFORMANCE COUNTERS"
    }

    # ============================================================================
    # SECTION 9: WINDOWS UPDATES STATUS
    # ============================================================================
    try {
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Import-Module PSWindowsUpdate
            $Updates = Get-WUList | Select-Object Title, Size, @{Name="SizeKB";Expression={$_.Size}}
            if ($Updates) {
                $UpdateOutput = "PENDING WINDOWS UPDATES:`n" + ($Updates | Format-Table -AutoSize | Out-String)
            } else {
                $UpdateOutput = "No pending Windows updates found."
            }
        } else {
            $UpdateOutput = "PSWindowsUpdate module not available. Install with: Install-Module PSWindowsUpdate"
        }
    } catch {
        $UpdateOutput = "Unable to check Windows Updates: $($_.Exception.Message)"
    }
    Write-AuditOutput -Message $UpdateOutput -Section "WINDOWS UPDATES"

    # ============================================================================
    # COMPLETION
    # ============================================================================
    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    
    Write-AuditOutput -Message "AUDIT COMPLETED: $EndTime" -Section "AUDIT COMPLETION"
    Write-AuditOutput -Message "Total Duration: $($Duration.TotalMinutes.ToString('F2')) minutes"
    Write-AuditOutput -Message "Report saved to: $OutputPath"

} catch {
    $ErrorMessage = "CRITICAL ERROR during audit execution: $($_.Exception.Message)"
    Write-AuditOutput -Message $ErrorMessage -Section "ERROR"
    Write-Error $ErrorMessage
    exit 1
}

# Display summary
Write-Host "`n===============================================================================" -ForegroundColor Green
Write-Host "SQL SERVER SYSTEM AUDIT COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Green
Write-Host "Report saved to: $OutputPath" -ForegroundColor Yellow
Write-Host "Duration: $($Duration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor Yellow

if ($IncludePerformanceCounters) {
    Write-Host "Performance counters were included in this audit." -ForegroundColor Cyan
} else {
    Write-Host "To include performance counters, run with -IncludePerformanceCounters switch." -ForegroundColor Cyan
}

Write-Host "`nTo run the complete audit:" -ForegroundColor White
Write-Host "1. Execute the SQL scripts (SystemAudit.sql, DatabaseInformation.sql, etc.)" -ForegroundColor White
Write-Host "2. Review this PowerShell system audit report" -ForegroundColor White
Write-Host "3. Combine findings for comprehensive analysis" -ForegroundColor White
