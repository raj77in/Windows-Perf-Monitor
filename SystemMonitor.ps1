<#
.SYNOPSIS
    System Monitor - A comprehensive system monitoring tool for Windows

.DESCRIPTION
    This script provides a graphical interface for monitoring system performance,
    viewing system information, and managing running services. It can be run in
    both GUI and console modes.

.PARAMETER console
    Run the application in console mode without the graphical interface.

.PARAMETER help
    Display this help message.

.PARAMETER export
    Export system information to a JSON file and exit.

.PARAMETER monitor
    Start monitoring in console mode.

.EXAMPLE
    .\SystemMonitor.ps1
    Launches the System Monitor GUI.

.EXAMPLE
    .\SystemMonitor.ps1 -console
    Runs the System Monitor in console mode.

.EXAMPLE
    .\SystemMonitor.ps1 -export
    Exports system information to a JSON file and exits.

.NOTES
    File Name      : SystemMonitor.ps1
    Author         : System Monitor Team
    Prerequisite   : PowerShell 5.1 or later, .NET Framework 4.7.2 or later
    Copyright      : (c) 2025, All rights reserved
#>

# System Monitor - Main Script
# A comprehensive system monitoring tool for Windows

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "This script requires administrator privileges to access all system information."
    Write-Host "Please run this script as Administrator for full functionality." -ForegroundColor Yellow
    $response = Read-Host "Do you want to continue without admin rights? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        exit
    }
}

# Set execution policy to allow script execution
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue

# Import required modules
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules"

# Function to import a module and verify its functions
function Import-ModuleWithVerification {
    param (
        [string]$ModulePath,
        [string]$ModuleName,
        [string[]]$RequiredFunctions = @()
    )

    Write-Host "`nImporting module: $ModuleName" -ForegroundColor Cyan
    
    if (-not (Test-Path $ModulePath)) {
        Write-Error "Module file not found: $ModulePath"
        return $false
    }

    try {
        # Remove the module if it's already loaded
        if (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue) {
            Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
        }

        # Import the module and suppress the output since we don't need the module object
        $null = Import-Module $ModulePath -Force -PassThru -ErrorAction Stop -DisableNameChecking
        Write-Host "  - Successfully imported module: $ModuleName" -ForegroundColor Green

        # Verify required functions
        foreach ($func in $RequiredFunctions) {
            if (Get-Command -Name $func -ErrorAction SilentlyContinue) {
                Write-Host "  - Verified function: $func" -ForegroundColor Green
            } else {
                Write-Error "  - Required function not found: $func"
                return $false
            }
        }

        return $true
    }
    catch {
        Write-Error "  - Failed to import module $ModuleName : $_"
        return $false
    }
}

# Import modules in order of dependency
$modulesToImport = @(
    @{
        Name = "SystemInfo";
        Path = Join-Path $modulePath "SystemInfo.psm1";
        RequiredFunctions = @("Get-SystemInformation")
    },
    @{
        Name = "Export";
        Path = Join-Path $modulePath "Export.psm1";
        RequiredFunctions = @("Export-MonitoringData")
    },
    @{
        Name = "Monitor";
        Path = Join-Path $modulePath "Monitor.psm1";
        RequiredFunctions = @("Start-Monitoring", "Stop-Monitoring", "Get-MonitoringData")
    },
    @{
        Name = "GUI";
        Path = Join-Path $modulePath "GUI.psm1";
        RequiredFunctions = @("Show-SystemMonitorGUI")
    }
)

# Import all modules
foreach ($module in $modulesToImport) {
    if (-not (Import-ModuleWithVerification -ModulePath $module.Path -ModuleName $module.Name -RequiredFunctions $module.RequiredFunctions)) {
        Write-Error "Failed to load required module: $($module.Name)"
        exit 1
    }
}

# Verify all required functions are available
$requiredFunctions = @(
    "Get-SystemInformation",
    "Start-Monitoring",
    "Stop-Monitoring",
    "Export-MonitoringData"
)

Write-Host "`nVerifying all required functions:" -ForegroundColor Cyan
foreach ($func in $requiredFunctions) {
    if (Get-Command -Name $func -ErrorAction SilentlyContinue) {
        Write-Host "  - Verified function: $func" -ForegroundColor Green
    } else {
        Write-Error "  - Required function not found: $func"
        exit 1
    }
}

# Test Get-SystemInformation
try {
    Write-Host "`nTesting Get-SystemInformation..." -ForegroundColor Cyan
    $testResult = Get-SystemInformation -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if (-not $testResult) {
        throw "Get-SystemInformation returned no data"
    }
    Write-Host "  - Successfully retrieved system information" -ForegroundColor Green
}
catch {
    Write-Error "  - Failed to call Get-SystemInformation: $_"
    exit 1
}

# Define function to test required commands
function Test-RequiredCommands {
    param(
        [array]$CommandList,
        [string]$ModulePath
    )

    foreach ($cmd in $CommandList) {
        if (-not (Get-Command -Name $cmd.Name -ErrorAction SilentlyContinue)) {
            # Try to import the specific module that should contain this command
            $moduleFile = Join-Path -Path $ModulePath -ChildPath "$($cmd.Module).psm1"
            if (Test-Path $moduleFile) {
                try {
                    Import-Module $moduleFile -Force -ErrorAction Stop
                    Write-Verbose "Imported module $($cmd.Module) to load command: $($cmd.Name)"
                }
                catch {
                    Write-Warning "Failed to import module $($cmd.Module): $_"
                }
            }

            # Check again if the command is available
            if (-not (Get-Command -Name $cmd.Name -ErrorAction SilentlyContinue)) {
                Write-Error "Required command not found: $($cmd.Name) from module $($cmd.Module). The application cannot continue."
                return $false
            }
        }
        Write-Host "Verified command: $($cmd.Name) [OK]" -ForegroundColor Green
    }
    return $true
}

# Define and verify required commands
$requiredCommands = @(
    @{Name = "Get-SystemInformation"; Module = "SystemInfo" },
    @{Name = "Start-Monitoring"; Module = "Monitor" },
    @{Name = "Stop-Monitoring"; Module = "Monitor" },
    @{Name = "Export-MonitoringData"; Module = "Export" }
)

# Verify all required commands are available
if (-not (Test-RequiredCommands -CommandList $requiredCommands -ModulePath $modulePath)) {
    exit 1
}

# Verify Get-SystemInformation works
try {
    $testResult = Get-SystemInformation -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if (-not $testResult) {
        throw "Get-SystemInformation returned no data"
    }
    Write-Host "Successfully tested Get-SystemInformation [OK]" -ForegroundColor Green
}
catch {
    Write-Error "Failed to call Get-SystemInformation: $_"
    exit 1
}

# Function verification is now handled above

# Check if GUI mode is requested
$guiMode = $true
if ($args.Count -gt 0) {
    switch ($args[0].ToLower()) {
        "-console" { $guiMode = $false }
        "-help" {
            Write-Host @"
System Monitor - Usage:
  .\SystemMonitor.ps1 [options]

Options:
  -console   Run in console mode (no GUI)
  -help      Show this help message
  -export    Export system information and exit
  -monitor   Start monitoring in console mode
"@
            exit
        }
        "-export" {
            $data = Get-SystemInformation
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $outputFile = Join-Path -Path $PSScriptRoot -ChildPath "exports\system_info_${timestamp}.json"

            # Ensure exports directory exists
            $exportDir = Join-Path -Path $PSScriptRoot -ChildPath "exports"
            if (-not (Test-Path -Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }

            $data | Out-File -FilePath $outputFile -Force
            Write-Host "System information exported to: $outputFile" -ForegroundColor Green
            exit
        }
        "-monitor" {
            $guiMode = $false
            $duration = 300  # 5 minutes default
            if ($args.Count -gt 1 -and $args[1] -match '^\d+$') {
                $duration = [int]$args[1]
            }

            Write-Host "Starting system monitoring for $duration seconds..." -ForegroundColor Green
            Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow

            try {
                Start-Monitoring -Duration $duration
                while ($script:isMonitoring) {
                    Start-Sleep -Seconds 1
                }
            }
            finally {
                Stop-Monitoring
                $data = Get-MonitoringData

                # Save monitoring data
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $outputFile = Join-Path -Path $PSScriptRoot -ChildPath "exports\monitoring_data_${timestamp}.json"
                $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Force

                Write-Host "`nMonitoring completed. Data saved to: $outputFile" -ForegroundColor Green

                # Show summary
                $cpuAvg = ($data | ForEach-Object { $_.Counters | Where-Object { $_.Path -like '*% Processor Time' } | Select-Object -ExpandProperty Value } | Measure-Object -Average).Average
                $memAvg = ($data | ForEach-Object { $_.Counters | Where-Object { $_.Path -like '*% Committed Bytes*' } | Select-Object -ExpandProperty Value } | Measure-Object -Average).Average

                Write-Host "`n=== Monitoring Summary ===" -ForegroundColor Cyan
                Write-Host "Duration: $duration seconds"
                Write-Host "Average CPU Usage: $([math]::Round($cpuAvg, 2))%"
                Write-Host "Average Memory Usage: $([math]::Round($memAvg, 2))%"
            }
            exit
        }
    }
}

# Main execution
if ($guiMode) {
    try {
        # Load Windows Forms assemblies
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        # Show the GUI
        Show-SystemMonitorGUI
    }
    catch {
        Write-Error "Failed to start GUI mode: $_"
        Write-Host "Falling back to console mode..." -ForegroundColor Yellow
        $guiMode = $false
    }
}

# If not in GUI mode or GUI failed, show console menu
if (-not $guiMode) {
    Clear-Host
    Write-Host "=== System Monitor - Console Mode ===" -ForegroundColor Cyan
    Write-Host "1. View System Information"
    Write-Host "2. Start Monitoring"
    Write-Host "3. List Running Services"
    Write-Host "4. Export Data"
    Write-Host "5. Exit"

    $choice = Read-Host "`nSelect an option (1-5)"

    switch ($choice) {
        "1" {
            Clear-Host
            $systemInfo = Get-SystemInformation | ConvertFrom-Json
            $systemInfo | Format-List *
        }
        "2" {
            $duration = Read-Host "Enter monitoring duration in seconds (default: 300)"
            if (-not $duration -or -not ($duration -as [int])) {
                $duration = 300
            }
            & $PSCommandPath -monitor $duration
        }
        "3" {
            Clear-Host
            Get-Service | Where-Object { $_.Status -eq 'Running' } |
            Format-Table -AutoSize -Property Name, DisplayName, Status, StartType
        }
        "4" {
            $data = Get-SystemInformation
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $outputFile = Join-Path -Path $PSScriptRoot -ChildPath "exports\system_info_${timestamp}.json"

            # Ensure exports directory exists
            $exportDir = Join-Path -Path $PSScriptRoot -ChildPath "exports"
            if (-not (Test-Path -Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }

            $data | Out-File -FilePath $outputFile -Force
            Write-Host "System information exported to: $outputFile" -ForegroundColor Green
        }
        "5" {
            exit
        }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
        }
    }
}
