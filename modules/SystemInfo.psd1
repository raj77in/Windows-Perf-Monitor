@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'SystemInfo.psm1'
    
    # Version number of this module.
    ModuleVersion     = '1.0.0'
    
    # ID used to uniquely identify this module
    GUID              = 'a5c3e4d2-8b1f-4e9c-9d8a-7b6c5d4e3f2a1'
    
    # Author of this module
    Author            = 'System Monitor'
    
    # Company or vendor of this module
    CompanyName       = 'System Monitor'
    
    # Copyright statement for this module
    Copyright         = '(c) 2023. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description       = 'Provides system information collection functionality for System Monitor'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = @('Get-SystemInformation')
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('System', 'Monitoring', 'Information')
            
            # A URL to the main website for this project
            # ProjectUri = ''
            
            # License URI
            # LicenseUri = ''
            
            # Release notes
            # ReleaseNotes = ''
        }
    }
}
