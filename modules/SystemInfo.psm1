<#
.SYNOPSIS
    System Information Module for System Monitor

.DESCRIPTION
    This module provides functions for retrieving detailed system information
    including CPU, memory, disk, network, and service information.

.NOTES
    File Name      : SystemInfo.psm1
    Author         : System Monitor Team
    Prerequisite   : PowerShell 5.1, Administrative privileges for full functionality
    Dependencies   : None
    Copyright      : (c) 2025, All rights reserved
#>

<#
.SYNOPSIS
    Retrieves comprehensive system information in JSON format.

.DESCRIPTION
    This function collects detailed system information including hardware, operating system,
    memory, disk, network, and service information. The data is returned as a JSON string.

.OUTPUTS
    System.String
    Returns a JSON-formatted string containing system information.

.EXAMPLE
    $systemInfo = Get-SystemInformation | ConvertFrom-Json
    Retrieves system information and converts it to a PowerShell object.

.EXAMPLE
    Get-SystemInformation | Out-File -FilePath 'system_info.json'
    Saves system information to a JSON file.

.NOTES
    This function requires administrative privileges to access all system information.
    Some properties might be null or empty if the current user doesn't have sufficient permissions.
#>
function Get-SystemInformation {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        # Get basic system information
        Write-Verbose "Retrieving operating system information..."
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        
        Write-Verbose "Retrieving processor information..."
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        
        Write-Verbose "Retrieving memory information..."
        $memory = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        
        Write-Verbose "Retrieving disk information..."
        $disks = Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.OperationalStatus -eq 'Online' }
        
        Write-Verbose "Retrieving network adapter information..."
        $networkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
        
        Write-Verbose "Retrieving service information..."
        $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }
        
        Write-Verbose "Retrieving process information..."
        $processes = Get-Process -ErrorAction SilentlyContinue | 
            Select-Object Name, CPU, PM, WS, Id, StartTime -First 20

        $systemInfo = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Hostname = $env:COMPUTERNAME
            OS = @{
                Name = $os.Caption
                Version = $os.Version
                InstallDate = $os.InstallDate
                LastBootTime = $os.LastBootUpTime
            }
            CPU = @{
                Name = $cpu.Name
                Cores = $cpu.NumberOfCores
                Threads = $cpu.NumberOfLogicalProcessors
                LoadPercentage = (Get-CimInstance -ClassName CIM_Processor | Measure-Object -Property LoadPercentage -Average).Average
            }
            Memory = @{
                TotalGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
                FreeGB = [math]::Round(($os.FreePhysicalMemory / 1MB), 2)
            }
            Disks = @()
            Network = @()
            Services = @()
            TopProcesses = $processes
        }

        # Add disk information
        foreach ($disk in $disks) {
            try {
                $partition = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
                if ($partition) {
                    $volume = Get-Volume -Partition $partition -ErrorAction SilentlyContinue
                    $diskInfo = @{
                        Drive = "$($partition.DriveLetter):"
                        SizeGB = [math]::Round($disk.Size / 1GB, 2)
                        FreeSpaceGB = if ($volume) { [math]::Round(($volume.SizeRemaining / 1GB), 2) } else { $null }
                        UsedSpaceGB = if ($volume) { [math]::Round((($disk.Size - $volume.SizeRemaining) / 1GB), 2) } else { $null }
                        HealthStatus = $disk.HealthStatus
                        BusType = $disk.BusType
                    }
                    $systemInfo.Disks += $diskInfo
                }
            }
            catch {
                Write-Warning "Error processing disk $($disk.Number): $_"
                continue
            }
        }

        # Add network information
        foreach ($adapter in $networkAdapters) {
            try {
                $stats = Get-NetAdapterStatistics -Name $adapter.Name -ErrorAction SilentlyContinue
                $ipAddress = (Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
                
                $networkInfo = @{
                    Name = $adapter.Name
                    InterfaceDescription = $adapter.InterfaceDescription
                    Status = $adapter.Status
                    Speed = if ($adapter.LinkSpeed) { "$($adapter.LinkSpeed) Mbps" } else { $null }
                    ReceivedBytes = if ($stats) { $stats.ReceivedBytes } else { $null }
                    SentBytes = if ($stats) { $stats.SentBytes } else { $null }
                    IPAddress = $ipAddress
                }
                $systemInfo.Network += $networkInfo
            }
            catch {
                Write-Warning "Error processing network adapter $($adapter.Name): $_"
                continue
            }
        }

        # Add service information
        foreach ($service in $services) {
            try {
                $dependentServices = (Get-Service -Name $service.Name -DependentServices -ErrorAction SilentlyContinue | 
                    Select-Object -ExpandProperty Name) -join ', '
                
                $serviceInfo = @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = $service.Status
                    StartType = $service.StartType
                    DependentServices = $dependentServices
                }
                $systemInfo.Services += $serviceInfo
            }
            catch {
                Write-Warning "Error processing service $($service.Name): $_"
                continue
            }
        }

        # Convert to JSON and handle any serialization errors
        try {
            Write-Verbose "Converting system information to JSON..."
            $json = $systemInfo | ConvertTo-Json -Depth 10 -ErrorAction Stop
            return $json
        }
        catch {
            $errorMessage = "Failed to convert system information to JSON: $_"
            Write-Error $errorMessage
            return $null
        }
    }
    catch {
        $errorMessage = "Failed to retrieve system information: $_"
        Write-Error $errorMessage
        return $null
    }
}

# Export the function
Export-ModuleMember -Function Get-SystemInformation -Verbose
