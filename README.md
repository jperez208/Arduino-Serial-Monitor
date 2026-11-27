# Universal Serial Monitor (USM)

### A lightweight USB-to-TTL serial monitor for Windows

A standalone serial monitoring utility built with Windows Batch and PowerShell.

Designed to make connecting to, monitoring, and communicating with serial devices easier. Automatically detects connected USB-to-serial adapters, identifies likely devices, and handles COM-port selection without requiring the Arduino IDE.

Whether you're working with an Arduino, ESP32, PIC, AVR, or another UART-compatible device, USM provides a simple way to access serial communication.

## Features

- **Automatic COM Port Detection** – Scans available ports and identifies likely Arduino and USB-to-serial devices.
- **Device Identification** – Recognizes common USB-to-serial chipsets and interfaces, including CH340, CH9102, FTDI, CP210x, Prolific, and USB Serial devices.
- **Automatic Connection** – Automatically selects a matching device when only one is detected.
- **Multiple Device Selection** – Choose which device to connect to when multiple compatible devices are present.
- **Configurable Serial Settings** – Adjust baud rate, data bits, parity, and stop bits.
- **Live Serial Monitoring** – Displays incoming serial data in real time.
- **Serial Transmission** – Send commands and data directly to the connected device.
- **Arduino Reset Control** – Reset compatible boards through DTR.
- **Pause and Review** – Pause live output and review previously received data.
- **Session Logging** – Save captured serial sessions to a log file.
- **Timestamp Control** – Toggle timestamps in the serial display.
- **Color-Coded Interface** – Distinguishes status messages, errors, and transmitted data.
- **Keyboard Controls** – Access common functions without restarting the monitor.

## Keyboard Controls

| Shortcut | Function |
|---|---|
| `Ctrl + P` | Pause serial monitoring |
| `P` | Resume monitoring |
| `Ctrl + R` | Reset connected device via DTR |
| `Ctrl + T` | Toggle timestamps |
| `Ctrl + E` | Change serial settings |
| `Ctrl + X` | Exit monitor |
| `S` | Save session log (paused menu) |
| `M` | Open additional options (paused menu) |
| `Enter` | Transmit entered data |
| `Up / Down` | Navigate paused output history |

## Default Serial Settings

| Setting | Default |
|---|---|
| Baud Rate | 9600 |
| Data Bits | 8 |
| Parity | None |
| Stop Bits | 1 |

All serial settings can be changed through the interface.

## Requirements

- Windows
- Windows PowerShell
- USB-to-serial adapter or compatible USB serial device
- Appropriate device drivers

No Arduino IDE installation is required.

## Getting Started

1. Download `USB-Autoconnect.bat` from this repository.
2. Connect your Arduino, USB-to-TTL adapter, or compatible serial device.
3. Run the batch file.
4. The utility scans available COM ports and identifies potential serial devices.
5. Select a device if multiple matches are detected.
6. Confirm or configure your serial settings.
7. Start monitoring and communicating with your device.

## Compatibility

USM is designed for Windows systems using standard serial interfaces.

Potential compatible hardware includes:

- Arduino boards
- ESP32 development boards
- AVR microcontrollers
- PIC microcontrollers
- STM32 development boards
- USB-to-TTL adapters
- Other UART-compatible serial devices

Compatibility depends on the USB interface, device drivers, and serial implementation. Device identification does not guarantee compatibility with every microcontroller or development board.

## Project Status

This project is actively evolving.

It has been developed and tested against available hardware, but not every USB-to-serial adapter or microcontroller combination has been tested.

Bug reports, hardware compatibility feedback, suggestions, and contributions are welcome.

If you encounter an issue, please include your operating system, USB-to-serial chipset, connected hardware, and serial settings when possible.

## About

USM was developed as a lightweight alternative to repeatedly opening a full development environment just to access a serial connection.

The goal is simple: make serial communication easier to access, configure, and use across different embedded hardware platforms.

**Built for electronics enthusiasts, embedded developers, and anyone who works with serial hardware.**
<img width="1123" height="551" alt="Screenshot 2026-11-27 113851" src="https://github.com/user-attachments/assets/91eb03ec-8cae-4007-8f1f-20db868fb74b" />
<img width="1157" height="651" alt="Screenshot 2026-11-27 114001" src="https://github.com/user-attachments/assets/b443b510-a8fa-4db4-8ac0-76e7ceebcbd2" />
<img width="822" height="633" alt="Screenshot 2026-11-27 114031" src="https://github.com/user-attachments/assets/3b4ff506-d0cb-41dc-895a-b03af59d3abc" />
