# System Monitor

A comprehensive system monitoring tool for Windows that provides real-time performance metrics, system information, and service management through both GUI and console interfaces.

## Features

* **Real-time Monitoring**: Track CPU and Memory usage with live charts
* **System Information**: View detailed hardware and software information
* **Service Management**: Monitor and manage Windows services
* **Data Export**: Save system information and monitoring data to JSON format
* **User-Friendly Interface**: Intuitive tabbed interface with dark theme support
* **Lightweight**: Built with PowerShell for minimal resource usage

## Screenshots

**Note:** Screenshots will be added in a future update.

## Prerequisites

* Windows 10/11 or Windows Server 2016+
* PowerShell 5.1 or later
* .NET Framework 4.7.2 or later
* Administrative privileges (for full functionality)

## Installation

1. Clone the repository or download the latest release
2. Navigate to the project directory
3. Run the script:

   ```powershell
   .\SystemMonitor.ps1
   ```

## Usage

### GUI Mode (Default)

```powershell
.\SystemMonitor.ps1
```

### Console Mode

```powershell
.\SystemMonitor.ps1 -console
```

### Export System Information

```powershell
.\SystemMonitor.ps1 -export
```

### Command-line Options

| Parameter  | Description                                      |
|------------|--------------------------------------------------|
| `-console` | Run in console mode without GUI                  |
| `-export`  | Export system information to JSON and exit      |
| `-monitor` | Start monitoring in console mode                 |
| `-help`    | Show help message                               |

## Project Structure

```text
SystemMonitor/
├── modules/
│   ├── GUI.psm1           # Graphical user interface
│   ├── Monitor.psm1        # Performance monitoring functions
│   ├── SystemInfo.psm1     # System information collection
│   └── Export.psm1         # Data export functionality
├── exports/                # Default export directory
├── SystemMonitor.ps1       # Main script
└── README.md               # This file
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

* Built with PowerShell and Windows Forms
* Icons from [Font Awesome](https://fontawesome.com/)
* Inspired by various system monitoring tools

## Support

For issues and feature requests, please [open an issue](../../issues).

---

Created with ❤️ by the System Monitor Team
