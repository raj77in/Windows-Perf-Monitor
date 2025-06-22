<#
.SYNOPSIS
    GUI Module for System Monitor

.DESCRIPTION
    This module provides the graphical user interface for the System Monitor application.
    It includes forms, controls, and event handlers for displaying system information,
    performance metrics, and service management.

.NOTES
    File Name      : GUI.psm1
    Author         : System Monitor Team
    Prerequisite   : PowerShell 5.1, .NET Framework 4.7.2 or later
    Dependencies   : SystemInfo.psm1, Monitor.psm1, Export.psm1
    Copyright      : (c) 2025, All rights reserved
#>

#region Load Required Assemblies
Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
Add-Type -AssemblyName System.Drawing -ErrorAction Stop
Add-Type -AssemblyName System.Windows.Forms.DataVisualization -ErrorAction Stop
#endregion

# Required functions that should be available from other modules
$requiredFunctions = @(
    "Get-SystemInformation",
    "Start-Monitoring",
    "Stop-Monitoring",
    "Export-MonitoringData"
)

# Verify required functions are available
foreach ($func in $requiredFunctions) {
    if (-not (Get-Command -Name $func -ErrorAction SilentlyContinue)) {
        Write-Error "Required function not found: $func. Make sure all required modules are properly imported."
        throw "Missing required function: $func"
    }
}

$script:mainForm = $null
$script:chart = $null
$script:dataGridView = $null
$script:monitoringData = $null
$script:monitoringThread = $null

function Show-SystemMonitorGUI {
    # Create main form
    $script:mainForm = New-Object System.Windows.Forms.Form
    $script:mainForm.Text = "System Monitor"
    $script:mainForm.Size = New-Object System.Drawing.Size(1000, 700)
    $script:mainForm.StartPosition = "CenterScreen"
    $script:mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $script:mainForm.MaximizeBox = $false

    # Create menu strip
    $menuStrip = New-Object System.Windows.Forms.MenuStrip
    $fileMenu = $menuStrip.Items.Add("File")
    $monitorMenu = $menuStrip.Items.Add("Monitor")
    # File menu items
    $exportMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Export Data...")
    $exportMenuItem.Add_Click({ Export-Data })
    $exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
    $exitMenuItem.Add_Click({ $script:mainForm.Close() })
    $fileMenu.DropDownItems.AddRange(@($exportMenuItem, $exitMenuItem))

    # Monitor menu items
    $startMonitorItem = New-Object System.Windows.Forms.ToolStripMenuItem("Start Monitoring")
    $startMonitorItem.Add_Click({ Start-MonitoringGUI })
    $stopMonitorItem = New-Object System.Windows.Forms.ToolStripMenuItem("Stop Monitoring")
    $stopMonitorItem.Add_Click({ Stop-MonitoringGUI })
    $monitorMenu.DropDownItems.AddRange(@($startMonitorItem, $stopMonitorItem))

    # Create tab control
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tabControl.Padding = New-Object System.Drawing.Point(10, 10)

    # System Info Tab
    $systemInfoTab = New-Object System.Windows.Forms.TabPage
    $systemInfoTab.Text = "System Information"
    $systemInfoTab.Padding = New-Object System.Windows.Forms.Padding(3)

    $systemInfoTextBox = New-Object System.Windows.Forms.RichTextBox
    $systemInfoTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $systemInfoTextBox.ReadOnly = $true
    $systemInfoTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $systemInfoTab.Controls.Add($systemInfoTextBox)

    # Performance Tab
    $perfTab = New-Object System.Windows.Forms.TabPage
    $perfTab.Text = "Performance"
    $perfTab.Padding = New-Object System.Windows.Forms.Padding(3)

    $script:chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $script:chart.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:chart.BackColor = [System.Drawing.Color]::WhiteSmoke

    $chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea("ChartArea1")
    $chartArea.AxisX.Title = "Time (seconds)"
    $chartArea.AxisY.Title = "Usage %"
    $chartArea.AxisY.Minimum = 0
    $chartArea.AxisY.Maximum = 100
    $chartArea.AxisX.Interval = 5
    $script:chart.ChartAreas.Add($chartArea)

    # Add CPU Series
    $cpuSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series("CPU %")
    $cpuSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $cpuSeries.BorderWidth = 2
    $cpuSeries.Color = [System.Drawing.Color]::Red
    $script:chart.Series.Add($cpuSeries)

    # Add Memory Series
    $memSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series("Memory %")
    $memSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $memSeries.BorderWidth = 2
    $memSeries.Color = [System.Drawing.Color]::Blue
    $script:chart.Series.Add($memSeries)

    # Add legend
    $legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
    $legend.Name = "Legend1"
    $legend.Docking = [System.Windows.Forms.DataVisualization.Charting.Docking]::Top
    $script:chart.Legends.Add($legend)

    $perfTab.Controls.Add($script:chart)

    # Add a label for instructions
    $lblInstructions = New-Object System.Windows.Forms.Label
    $lblInstructions.Text = "Start monitoring to see performance data"
    $lblInstructions.Dock = [System.Windows.Forms.DockStyle]::Top
    $lblInstructions.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lblInstructions.Height = 30
    $lblInstructions.BackColor = [System.Drawing.Color]::LightYellow
    $perfTab.Controls.Add($lblInstructions)
    $script:lblPerfInstructions = $lblInstructions

    # Services Tab
    $servicesTab = New-Object System.Windows.Forms.TabPage
    $servicesTab.Text = "Services"
    $servicesTab.Padding = New-Object System.Windows.Forms.Padding(3)

    # Create a panel to hold the DataGridView and buttons
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill

    # Create DataGridView
    $script:dataGridView = New-Object System.Windows.Forms.DataGridView
    $script:dataGridView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $script:dataGridView.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $script:dataGridView.ReadOnly = $true
    $script:dataGridView.AllowUserToAddRows = $false
    $script:dataGridView.AllowUserToDeleteRows = $false
    $script:dataGridView.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $script:dataGridView.MultiSelect = $false
    $script:dataGridView.AutoGenerateColumns = $false

    # Add columns
    $columns = @(
        @{Name = "Name"; HeaderText = "Service Name"; Expression = { $_.Name } },
        @{Name = "DisplayName"; HeaderText = "Display Name"; Expression = { $_.DisplayName } },
        @{Name = "Status"; HeaderText = "Status"; Expression = { $_.Status } },
        @{Name = "StartType"; HeaderText = "Startup Type"; Expression = { $_.StartType } },
        @{Name = "DependentServices"; HeaderText = "Dependent Services"; Expression = { $_.DependentServices } }
    )

    foreach ($col in $columns) {
        $gridCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $gridCol.HeaderText = $col.HeaderText
        $gridCol.DataPropertyName = $col.Name
        $gridCol.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
        $script:dataGridView.Columns.Add($gridCol) | Out-Null
    }

    # Add refresh button
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refresh"
    $btnRefresh.Dock = [System.Windows.Forms.DockStyle]::Top
    $btnRefresh.Height = 30
    $btnRefresh.Add_Click({ Update-ServicesGrid })

    # Add controls to panel
    $panel.Controls.Add($script:dataGridView)
    $panel.Controls.Add($btnRefresh)

    # Add panel to tab
    $servicesTab.Controls.Add($panel)

    # Add tabs to tab control
    $tabControl.TabPages.AddRange(@($systemInfoTab, $perfTab, $servicesTab))

    # Status strip
    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = "Ready"
    $statusStrip.Items.Add($statusLabel) | Out-Null

    # Add controls to form
    $script:mainForm.Controls.Add($tabControl)
    $script:mainForm.Controls.Add($menuStrip)
    $script:mainForm.Controls.Add($statusStrip)

    # Initial data load
    Update-SystemInfo -TextBox $systemInfoTextBox
    Update-ServicesGrid

    # Show form
    $script:mainForm.Add_FormClosing({
            Stop-MonitoringGUI
        })

    $script:mainForm.ShowDialog() | Out-Null
}

function Update-SystemInfo {
    param($TextBox)

    try {
        # Check if the function is available
        if (-not (Get-Command -Name Get-SystemInformation -ErrorAction SilentlyContinue)) {
            Import-Module "$PSScriptRoot\SystemInfo.psm1" -Force -ErrorAction Stop
        }

        $systemInfo = Get-SystemInformation | ConvertFrom-Json -ErrorAction Stop

        if (-not $systemInfo) {
            throw "Failed to retrieve system information"
        }

        $output = @"
=== System Information ===
Computer Name: $($systemInfo.Hostname)
OS: $($systemInfo.OS.Name) (Version: $($systemInfo.OS.Version))

=== CPU ===
Name: $($systemInfo.CPU.Name)
Cores: $($systemInfo.CPU.Cores)
Threads: $($systemInfo.CPU.Threads)
Current Load: $([math]::Round($systemInfo.CPU.LoadPercentage, 2))%

=== Memory ===
Total: $($systemInfo.Memory.TotalGB) GB
Free: $($systemInfo.Memory.FreeGB) GB

=== Disks ===
"@

        if ($systemInfo.Disks -and $systemInfo.Disks.Count -gt 0) {
            foreach ($disk in $systemInfo.Disks) {
                $output += "`nDrive: $($disk.Drive)`n"
                $output += "  Size: $($disk.SizeGB) GB`n"
                $output += "  Free: $($disk.FreeSpaceGB) GB`n"
                $output += "  Used: $($disk.UsedSpaceGB) GB`n"
            }
        }
        else {
            $output += "`nNo disk information available`n"
        }

        $output += "`n=== Network ===`n"
        if ($systemInfo.Network -and $systemInfo.Network.Count -gt 0) {
            foreach ($adapter in $systemInfo.Network) {
                $output += "`n$($adapter.Name) ($($adapter.InterfaceDescription))`n"
                $output += "  Status: $($adapter.Status)`n"
                $output += "  Speed: $($adapter.Speed)`n"
                $output += "  IP: $($adapter.IPAddress)`n"
            }
        }
        else {
            $output += "`nNo network adapter information available`n"
        }

        $TextBox.Text = $output
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        $errorMsg = "The required command 'Get-SystemInformation' was not found. " +
        "Please ensure the SystemInfo module is properly installed.`n`nError: $_"
        $TextBox.Text = $errorMsg
        Write-Error $errorMsg
    }
    catch {
        $errorMsg = "Error retrieving system information: $_`n`nStack Trace:`n$($_.ScriptStackTrace)"
        $TextBox.Text = $errorMsg
        Write-Error $errorMsg
    }
}

function Update-ServicesGrid {
    try {
        # Show loading message
        $script:dataGridView.DataSource = $null
        $script:dataGridView.Rows.Clear()
        $script:dataGridView.Columns.Clear()

        # Recreate columns
        $columns = @(
            @{Name = "Name"; HeaderText = "Service Name" },
            @{Name = "DisplayName"; HeaderText = "Display Name" },
            @{Name = "Status"; HeaderText = "Status" },
            @{Name = "StartType"; HeaderText = "Startup Type" },
            @{Name = "DependentServices"; HeaderText = "Dependent Services" }
        )

        foreach ($col in $columns) {
            $gridCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $gridCol.HeaderText = $col.HeaderText
            $gridCol.Name = $col.Name
            $gridCol.ReadOnly = $true
            $script:dataGridView.Columns.Add($gridCol) | Out-Null
        }

        # Get services data
        $services = Get-Service |
        Where-Object { $_.Status -eq 'Running' } |
        Select-Object Name, DisplayName, Status, StartType,
        @{Name = "DependentServices"; Expression = {
                $deps = Get-Service -Name $_.Name -DependentServices -ErrorAction SilentlyContinue
                if ($deps) {
                        ($deps | Select-Object -ExpandProperty Name) -join ", "
                }
                else {
                    "None"
                }
            }
        }

        # Add data to grid
        foreach ($service in $services) {
            $row = @(
                $service.Name,
                $service.DisplayName,
                $service.Status,
                $service.StartType,
                $service.DependentServices
            )
            $script:dataGridView.Rows.Add($row) | Out-Null
        }

        # Auto-size columns
        $script:dataGridView.AutoResizeColumns([System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::AllCells)

    }
    catch {
        Write-Warning "Error updating services grid: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to update services: $_", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Start-MonitoringGUI {
    if (-not $script:monitoringThread) {
        # Hide the instructions label
        if ($script:lblPerfInstructions) {
            $script:lblPerfInstructions.Visible = $false
        }

        # Create a new PowerShell instance
        $ps = [PowerShell]::Create()

        # Add the script block and parameters separately
        [void]$ps.AddScript({
                param($chart, $form, $lblInstructions)

                $counter = 0
                $maxPoints = 60  # Show last 60 data points

                # Initialize chart if needed
                $form.Invoke([Action] {
                        if ($chart.Series.Count -eq 0) {
                            # Add CPU Series
                            $cpuSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series("CPU %")
                            $cpuSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
                            $cpuSeries.BorderWidth = 2
                            $cpuSeries.Color = [System.Drawing.Color]::Red
                            $chart.Series.Add($cpuSeries)

                            # Add Memory Series
                            $memSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series("Memory %")
                            $memSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
                            $memSeries.BorderWidth = 2
                            $memSeries.Color = [System.Drawing.Color]::Blue
                            $chart.Series.Add($memSeries)

                            # Set chart area properties
                            $chart.ChartAreas[0].AxisX.Interval = 5
                            $chart.ChartAreas[0].AxisX.Title = "Time (seconds)"
                            $chart.ChartAreas[0].AxisY.Title = "Usage %"
                            $chart.ChartAreas[0].AxisY.Minimum = 0
                            $chart.ChartAreas[0].AxisY.Maximum = 100
                        }

                        # Clear existing data points
                        foreach ($series in $chart.Series) {
                            $series.Points.Clear()
                        }

                        # Hide instructions
                        if ($lblInstructions) {
                            $lblInstructions.Visible = $false
                        }
                    })

                while ($true) {
                    try {
                        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop).CounterSamples.CookedValue
                        $mem = (Get-Counter '\Memory\% Committed Bytes In Use' -ErrorAction Stop).CounterSamples.CookedValue

                        $form.Invoke([Action] {
                                try {
                                    # Add data points
                                    $chart.Series["CPU %"].Points.AddXY($counter, $cpu) | Out-Null
                                    $chart.Series["Memory %"].Points.AddXY($counter, $mem) | Out-Null

                                    # Limit the number of points
                                    foreach ($series in $chart.Series) {
                                        if ($series.Points.Count -gt $maxPoints) {
                                            $series.Points.RemoveAt(0)
                                        }
                                    }

                                    # Update Y-axis scale
                                    $chart.ChartAreas[0].RecalculateAxesScale()
                                    $chart.Update()
                                }
                                catch {
                                    Write-Warning "Error updating chart: $_"
                                }
                            })

                        $counter++
                        Start-Sleep -Seconds 1
                    }
                    catch {
                        Write-Warning "Error in monitoring thread: $_"
                        Start-Sleep -Seconds 5
                    }
                }
            })

        # Add parameters
        [void]$ps.AddParameter("chart", $script:chart)
        [void]$ps.AddParameter("form", $script:mainForm)

        # Store the PowerShell instance
        $script:monitoringThread = $ps.BeginInvoke()

        Write-Host "Monitoring started" -ForegroundColor Green
    }
    else {
        Write-Warning "Monitoring is already running"
    }
}

function Stop-MonitoringGUI {
    if ($script:monitoringThread) {
        try {
            # Get the PowerShell instance from the async result
            $ps = [System.Management.Automation.PowerShell]::Create().AddScript({
                    param($asyncResult)
                    $asyncResult.AsyncWaitHandle.WaitOne() | Out-Null
                }).AddArgument($script:monitoringThread)

            # Stop any running commands
            $ps.BeginInvoke() | Out-Null

            # Clean up resources
            $ps.Runspace.Close()
            $ps.Dispose()

            # Clear the thread reference
            $script:monitoringThread = $null

            Write-Host "Monitoring stopped" -ForegroundColor Yellow
        }
        catch {
            Write-Warning "Error stopping monitoring: $_"
        }
        finally {
            if ($null -ne $script:monitoringThread) {
                try { $script:monitoringThread.AsyncWaitHandle.Dispose() } catch {}
                $script:monitoringThread = $null
            }
        }
    }
}

function Export-Data {
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "JSON files (*.json)|*.json|ZIP files (*.zip)|*.zip"
    $saveFileDialog.Title = "Save Monitoring Data"
    $saveFileDialog.FileName = "system_monitor_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $data = Get-SystemInformation
            $data | Out-File -FilePath $saveFileDialog.FileName -Force
            [System.Windows.Forms.MessageBox]::Show("Data exported successfully to $($saveFileDialog.FileName)", "Export Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to export data: $_", "Export Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
}

# Export the module's public functions
Export-ModuleMember -Function Show-SystemMonitorGUI -Verbose
