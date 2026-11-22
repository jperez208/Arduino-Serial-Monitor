# Arduino Auto Serial Monitor

Alternative to the Serial Monitor in the Arduino IDE.

A lightweight Windows-based Arduino Serial Monitor built using Batch scripting and PowerShell.

Designed for Arduino developers, electronics enthusiasts, and embedded systems hobbyists who want a convenient way to connect to and monitor serial devices without manually searching for COM ports.

## Features

- **Automatic COM Port Detection** – Scans connected devices and identifies likely Arduino and USB-to-TTL adapters.
- **Device Identification** – Recognizes Arduino, CH340, CH9102, FTDI, CP210x, Prolific, and USB Serial devices.
- **Automatic Device Selection** – Automatically selects a device when only one matching device is detected.
- **Multiple Device Support** – Allows manual selection when multiple matching devices are connected.
- **Custom Serial Configuration** – Configure baud rate, data bits, parity, and stop bits.
- **Live Serial Monitoring** – Displays incoming serial data in real time.
- **Color-Coded Output** – Highlights success messages and errors for easier debugging.
- **Arduino Reset Control** – Reset the connected Arduino through DTR.
- **Live Keyboard Controls** – Change settings, reset the device, or exit without restarting the script.

## Keyboard Controls

| Key | Function |
| :--- | :--- |
| `Ctrl + R` | Reset Arduino via DTR |
| `Ctrl + E` | Change serial settings |
| `Ctrl + X` | Quit serial monitor |

## Default Settings

- **Baud Rate:** 9600
- **Data Bits:** 8
- **Parity:** None
- **Stop Bits:** One

## Requirements

- Windows operating system
- PowerShell
- Arduino or compatible USB-to-TTL serial device
- USB cable and appropriate device drivers

## How to Use

1. Download the `.bat` file.
2. Connect your Arduino or USB-to-TTL device.
3. Run the batch file.
4. Select your device if multiple compatible devices are detected.
5. Confirm or customize serial settings.
6. Start monitoring serial output.

## Compatibility

Designed for Windows systems with PowerShell and `.NET` serial-port support.

---

Suggestions, bug reports, and improvements are welcome!
