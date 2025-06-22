<#
.SYNOPSIS
    Monitoring Module for System Monitor

.DESCRIPTION
    This module provides functions for real-time system monitoring including
    CPU, memory, and disk performance metrics collection and analysis.

.NOTES
    File Name      : Monitor.psm1
    Author         : System Monitor Team
    Prerequisite   : PowerShell 5.1, Administrative privileges
    Dependencies   : SystemInfo.psm1
    Copyright      : (c) 2025, All rights reserved
#>

# Performance counters for real-time monitoring
$counters = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\% Committed Bytes In Use",
    "\LogicalDisk(*)\% Free Space",
    "\Network Interface(*)\Bytes Total/sec",
    "\System\Processor Queue Length"
)

$monitoringData = @()
$isMonitoring = $false
$monitorJob = $null

<#
.SYNOPSIS
    Starts the system monitoring process.

.DESCRIPTION
    This function initiates the monitoring of system performance counters in a background job.
    It collects data at specified intervals for a specified duration.

.PARAMETER Interval
    The interval in seconds between data collection points. Default is 5 seconds.

.PARAMETER Duration
    The total duration in seconds for the monitoring session. Default is 300 seconds (5 minutes).

.EXAMPLE
    Start-Monitoring -Interval 2 -Duration 60
    Starts monitoring with 2-second intervals for 1 minute.
#>
function Start-Monitoring {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [ValidateRange(1, 3600)]
        [int]$Interval = 5,
        
        [Parameter(Position=1)]
        [ValidateRange(10, 86400)]
        [int]$Duration = 300
    )

    $script:isMonitoring = $true
    $endTime = (Get-Date).AddSeconds($Duration)
    $script:monitoringData = @()

    Write-Host "Starting system monitoring for $Duration seconds with $Interval second intervals..." -ForegroundColor Green

    $script:monitorJob = Start-Job -ScriptBlock {
        param($counters, $interval, $endTime)
        
        $data = @()
        while ((Get-Date) -lt $endTime) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $sample = @{
                Timestamp = $timestamp
                Counters = @()
            }

            foreach ($counter in $counters) {
                try {
                    $counterData = Get-Counter -Counter $counter -ErrorAction SilentlyContinue
                    $sample.Counters += @{
                        Path = $counter
                        Value = $counterData.CounterSamples.CookedValue
                    }
                } catch {
                    Write-Warning "Failed to read counter $counter : $_"
                }
            }
            $data += $sample
            Start-Sleep -Seconds $interval
        }
        return $data
    } -ArgumentList $counters, $Interval, $endTime

    # Start a background job to collect system info periodically
    Start-Job -ScriptBlock {
        param($endTime, $interval)
        while ((Get-Date) -lt $endTime) {
            $systemInfo = Get-SystemInformation
            $outputPath = Join-Path -Path $PSScriptRoot -ChildPath "..\exports\system_info_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $systemInfo | Out-File -FilePath $outputPath -Force
            Start-Sleep -Seconds $interval
        }
    } -ArgumentList $endTime, ($Interval * 5) | Out-Null
}

<#
.SYNOPSIS
    Stops the system monitoring process.

.DESCRIPTION
    This function stops the background monitoring job and returns the collected data.
    It also performs cleanup of resources used during monitoring.

.OUTPUTS
    System.Array
    Returns an array of collected performance counter samples.

.EXAMPLE
    $data = Stop-Monitoring
    Stops monitoring and stores the collected data in $data.
#>
function Stop-Monitoring {
    if ($script:monitorJob) {
        $script:monitoringData = Receive-Job -Job $script:monitorJob -Keep
        $script:monitorJob | Remove-Job -Force
        $script:monitorJob = $null
    }
    $script:isMonitoring = $false
    return $script:monitoringData
}

<#
.SYNOPSIS
    Retrieves the current monitoring data.

.DESCRIPTION
    This function returns the performance data collected during the monitoring session.
    If monitoring is active, it retrieves the latest data from the background job.

.OUTPUTS
    System.Array
    Returns an array of collected performance counter samples, or $null if monitoring is not active.

.EXAMPLE
    $currentData = Get-MonitoringData
    Retrieves the current monitoring data without stopping the monitoring process.
#>
function Get-MonitoringData {
    if (-not $script:isMonitoring) {
        Write-Warning "Monitoring is not running. Call Start-Monitoring first."
        return $null
    }
    
    if ($script:monitorJob) {
        $currentData = Receive-Job -Job $script:monitorJob -Keep
        return $currentData
    }
    return $script:monitoringData
}

# Export the module's public functions
Export-ModuleMember -Function Start-Monitoring, Stop-Monitoring, Get-MonitoringData -Verbose
