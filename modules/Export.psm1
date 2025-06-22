<#
.SYNOPSIS
    Export Module for System Monitor

.DESCRIPTION
    This module provides functions for exporting system monitoring data to various formats
    including JSON and ZIP files. It supports both local and remote export options.

.NOTES
    File Name      : Export.psm1
    Author         : System Monitor Team
    Prerequisite   : PowerShell 5.1
    Dependencies   : None
    Copyright      : (c) 2025, All rights reserved
#>

<#
.SYNOPSIS
    Exports monitoring data to a file with optional compression and remote storage.

.DESCRIPTION
    This function exports the provided monitoring data to a JSON file. It supports
    optional compression to ZIP format and can copy the file to a remote location.

.PARAMETER Data
    The data to be exported, typically in JSON format.

.PARAMETER OutputPath
    The local file path where the data should be saved.

.PARAMETER Compress
    If specified, the output file will be compressed as a ZIP archive.

.PARAMETER Credential
    Optional credentials for accessing remote locations.

.PARAMETER RemotePath
    Optional network path where the file should be copied after export.

.EXAMPLE
    Export-MonitoringData -Data $jsonData -OutputPath 'C:\exports\data.json'
    Exports data to a JSON file.

.EXAMPLE
    Export-MonitoringData -Data $jsonData -OutputPath 'C:\exports\data.json' -Compress
    Exports and compresses the data to a ZIP file.

.EXAMPLE
    $cred = Get-Credential
    Export-MonitoringData -Data $jsonData -OutputPath 'C:\exports\data.json' -RemotePath '\\server\share' -Credential $cred
    Exports data and copies it to a remote share with authentication.
#>
function Export-MonitoringData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Data,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,
        
        [switch]$Compress,
        
        [PSCredential]$Credential,
        
        [string]$RemotePath
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $exportDir = Join-Path -Path $PSScriptRoot -ChildPath "..\exports"
    
    # Ensure exports directory exists
    if (-not (Test-Path -Path $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    }

    # Save data to local file
    $localFilePath = Join-Path -Path $exportDir -ChildPath "monitoring_data_${timestamp}.json"
    $Data | Out-File -FilePath $localFilePath -Force
    
    # If compression is requested, create a zip file
    if ($Compress) {
        $zipPath = Join-Path -Path $exportDir -ChildPath "monitoring_data_${timestamp}.zip"
        Compress-Archive -Path $localFilePath -DestinationPath $zipPath -Force
        $localFilePath = $zipPath
    }

    # If remote path is specified, copy to remote location
    if ($RemotePath) {
        try {
            if ($RemotePath.StartsWith("\\")) {
                # Handle Windows share
                if ($Credential) {
                    New-PSDrive -Name "TempExport" -PSProvider FileSystem -Root (Split-Path -Path $RemotePath -Parent) -Credential $Credential -ErrorAction Stop | Out-Null
                    Copy-Item -Path $localFilePath -Destination $RemotePath -Force -ErrorAction Stop
                    Remove-PSDrive -Name "TempExport" -Force -ErrorAction SilentlyContinue
                } else {
                    # Try without credentials if not provided
                    Copy-Item -Path $localFilePath -Destination $RemotePath -Force -ErrorAction Stop
                }
                Write-Host "Data successfully exported to $RemotePath" -ForegroundColor Green
            } else {
                # Handle other remote protocols (e.g., SFTP would need additional modules)
                Write-Warning "Only Windows share paths (\\server\share) are currently supported for remote export."
            }
        } catch {
            Write-Error "Failed to export to remote location: $_"
            # Continue to return local path even if remote export fails
        }
    }

    return $localFilePath
}

# Export the module's public functions
Export-ModuleMember -Function Export-MonitoringData -Verbose
