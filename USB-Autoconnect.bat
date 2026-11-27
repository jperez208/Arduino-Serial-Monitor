
@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Arduino Serial Monitor

for /f %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "BLUE=%ESC%[96m"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RESET=%ESC%[0m"

set "BAUD=9600"
set "DATABITS=8"
set "PARITY=None"
set "STOPBITS=One"

:SCAN_PORTS
cls
echo %BLUE%Scanning for Arduino / USB-to-TTL Devices...%RESET%
echo.

set "AUTOCOM="
set "AUTONAME="
set /a MATCHCOUNT=0
set /a TOTALCOUNT=0

for /f "tokens=1,2,* delims=|" %%A in ('powershell -NoProfile -Command "$ports=Get-CimInstance Win32_PnPEntity | Where-Object {$_.Name -match '\(COM\d+\)'}; foreach($p in $ports){if($p.Name -match '(COM\d+)'){$com=$matches[1]}else{continue}; if($p.Name -match 'Arduino|CH340|CH341|CH9102|FTDI|USB Serial|CP210|Prolific|ESP32|Espressif|UART|Silicon Labs'){Write-Output ('MATCH|'+$com+'|'+$p.Name)}else{Write-Output ('OTHER|'+$com+'|'+$p.Name)}}"') do (
    set /a TOTALCOUNT+=1
    if "%%A"=="MATCH" (
        set /a MATCHCOUNT+=1
        echo %GREEN%[!MATCHCOUNT!] [Likely Arduino] %%B -^> %%C%RESET%
        set "COM_!MATCHCOUNT!=%%B"
        set "NAME_!MATCHCOUNT!=%%C"
    ) else (
        echo %YELLOW%[-] [Other Device] %%B -^> %%C%RESET%
    )
)

if !TOTALCOUNT! EQU 0 (
    echo %RED%No COM ports found.%RESET%
    pause
    goto SCAN_PORTS
)

if !MATCHCOUNT! EQU 0 (
    echo %YELLOW%No recognized device found. Select manually:%RESET%
    set /a PORTCOUNT=0

    for /f "tokens=1,2,* delims=|" %%A in ('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object {$_.Name -match '\(COM\d+\)'} | ForEach-Object {if($_.Name -match '(COM\d+)'){'PORT|'+$matches[1]+'|'+$_.Name}}"') do (
        set /a PORTCOUNT+=1
        set "PORT_!PORTCOUNT!=%%B"
        set "PORTNAME_!PORTCOUNT!=%%C"
        echo [!PORTCOUNT!] %%B -^> %%C
    )

    set "CHOICE="
    set /p "CHOICE=Select port number: "
    echo(!CHOICE!| findstr /r "^[1-9][0-9]*$" >nul
    if errorlevel 1 goto SCAN_PORTS
    if !CHOICE! GTR !PORTCOUNT! goto SCAN_PORTS

    set "AUTOCOM=!PORT_%CHOICE%!"
    set "AUTONAME=!PORTNAME_%CHOICE%!"
)

if !MATCHCOUNT! EQU 1 (
    set "AUTOCOM=!COM_1!"
    set "AUTONAME=!NAME_1!"
)

if !MATCHCOUNT! GTR 1 (
    echo.
    echo %BLUE%Multiple matching devices found:%RESET%

    :SELECT_DEVICE
    set "CHOICE="
    set /p "CHOICE=Enter device number or R to rescan: "

    if /i "!CHOICE!"=="R" goto SCAN_PORTS

    echo(!CHOICE!| findstr /r "^[1-9][0-9]*$" >nul
    if errorlevel 1 goto SELECT_DEVICE
    if !CHOICE! GTR !MATCHCOUNT! goto SELECT_DEVICE

    call set "AUTOCOM=%%COM_!CHOICE!%%"
    call set "AUTONAME=%%NAME_!CHOICE!%%"
)

if not defined AUTOCOM goto SCAN_PORTS

echo.
echo %GREEN%Selected: %BLUE%!AUTOCOM!%RESET% (!AUTONAME!)

:SETTINGS_MENU
echo.
echo %BLUE%Current Settings:%RESET% !AUTOCOM! ^| !BAUD! baud, !DATABITS! data bits, !PARITY! parity, !STOPBITS! stop bits

set "KEEP=Y"
set /p "KEEP=Keep current settings? [Y/n] (R to rescan): "

if /i "!KEEP!"=="R" goto SCAN_PORTS
if /i "!KEEP!"=="Y" goto CONNECT
if "!KEEP!"=="" goto CONNECT

set "INPUT="
set /p "INPUT=Baud Rate [!BAUD!]: "
if defined INPUT set "BAUD=!INPUT!"

echo(!BAUD!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 goto SETTINGS_MENU
if !BAUD! LSS 50 goto SETTINGS_MENU
if !BAUD! GTR 4000000 goto SETTINGS_MENU

set "INPUT="
set /p "INPUT=Data Bits (5-8) [!DATABITS!]: "
if defined INPUT set "DATABITS=!INPUT!"

if not "!DATABITS!"=="5" if not "!DATABITS!"=="6" if not "!DATABITS!"=="7" if not "!DATABITS!"=="8" goto SETTINGS_MENU

set "INPUT="
set /p "INPUT=Parity (N/O/E/M/S) [!PARITY!]: "
if defined INPUT set "PARITY=!INPUT!"

if /i "!PARITY!"=="N" set "PARITY=None"
if /i "!PARITY!"=="O" set "PARITY=Odd"
if /i "!PARITY!"=="E" set "PARITY=Even"
if /i "!PARITY!"=="M" set "PARITY=Mark"
if /i "!PARITY!"=="S" set "PARITY=Space"

if /i not "!PARITY!"=="None" if /i not "!PARITY!"=="Odd" if /i not "!PARITY!"=="Even" if /i not "!PARITY!"=="Mark" if /i not "!PARITY!"=="Space" goto SETTINGS_MENU

set "INPUT="
set /p "INPUT=Stop Bits (1, 1.5, 2) [!STOPBITS!]: "
if defined INPUT set "STOPBITS=!INPUT!"

if "!STOPBITS!"=="1" set "STOPBITS=One"
if "!STOPBITS!"=="1.5" set "STOPBITS=OnePointFive"
if "!STOPBITS!"=="2" set "STOPBITS=Two"

if /i not "!STOPBITS!"=="One" if /i not "!STOPBITS!"=="OnePointFive" if /i not "!STOPBITS!"=="Two" goto SETTINGS_MENU

:CONNECT
set "DEFAULT_LOG_DIR=%~dp0"
set "PS_TEMP=%TEMP%\arduino_mon_%RANDOM%.ps1"
set "BAT_FILE=%~f0"

echo.
echo Extracting Arduino Serial Monitor...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop'; try { $c=[IO.File]::ReadAllText($env:BAT_FILE); $m='###PS_START###'; $i=$c.LastIndexOf($m); if($i -lt 0){throw 'PowerShell marker missing'}; $s=$c.Substring($i+$m.Length); [IO.File]::WriteAllText($env:PS_TEMP,$s,[Text.UTF8Encoding]::new($false)); exit 0 } catch { [Console]::Error.WriteLine($_.Exception.ToString()); exit 1 }"

if errorlevel 1 (
    echo ERROR: PowerShell extraction failed.
    pause
    exit /b 1
)

if not exist "%PS_TEMP%" (
    echo ERROR: Temporary PowerShell file missing.
    pause
    exit /b 1
)

echo Starting Arduino Serial Monitor...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_TEMP%"
set "MON_EXIT=%ERRORLEVEL%"

del "%PS_TEMP%" >nul 2>&1

if "%MON_EXIT%"=="3" goto SCAN_PORTS
if "%MON_EXIT%"=="2" goto SETTINGS_MENU

if not "%MON_EXIT%"=="0" (
    echo.
    echo PowerShell exited with code: %MON_EXIT%
    pause
)

endlocal
exit /b 0

###PS_START###

$ErrorActionPreference = 'Stop'

# Serial configuration
$portName = $env:AUTOCOM
$baud = [int]$env:BAUD
$dataBits = [int]$env:DATABITS
$parity = [System.IO.Ports.Parity]$env:PARITY
$stopBits = [System.IO.Ports.StopBits]$env:STOPBITS

# Logging configuration
$script:logDir = $env:DEFAULT_LOG_DIR.TrimEnd('\')
$script:logFileName = "Serial_$($portName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Application state
$script:paused = $false
$script:showTs = $true
$script:txBuffer = ''
$script:dirBuffer = ''
$script:editingDir = $false
$script:savePrompt = $false
$script:pausePage = 'menu'
$script:pauseStatus = ''
$script:quit = $false
$script:exitCode = 0

$script:sessionLog = [System.Collections.Generic.List[string]]::new()
$script:visibleLog = [System.Collections.Generic.List[object]]::new()
$script:esc = [char]27
$script:logRow = 0

$script:historyOffset = 0
$script:historyView = $false
$script:historyDirty = $true

# --------------------------------------------------
# SAFE CURSOR
# --------------------------------------------------

function Safe-Cursor([int]$x, [int]$y) {
    try {
        $w = [Console]::BufferWidth
        $h = [Console]::BufferHeight

        if ($w -lt 1 -or $h -lt 1) {
            return $false
        }

        $x = [Math]::Max(0, [Math]::Min($x, $w - 1))
        $y = [Math]::Max(0, [Math]::Min($y, $h - 1))

        [Console]::SetCursorPosition($x, $y)
        return $true
    }
    catch {
        return $false
    }
}

#TOP HEADER
function Draw-Header {
    try {
        $w = [Console]::WindowWidth
        $e = $script:esc

        $lines = @(
            '             ARDUINO SERIAL MONITOR',
            " Port: $portName | Baud: $baud | Data: $dataBits | Parity: $parity | Stop: $stopBits",
            '------------------------------------------------------------'
        )

        for ($i = 0; $i -lt 3; $i++) {
            if (Safe-Cursor 0 ([Console]::WindowTop + $i)) {
                $line = $lines[$i]

                if ($line.Length -ge $w) {
                    $line = $line.Substring(0, $w - 1)
                }

                [Console]::Write(
                    "$e[2K$e[96m$line$e[0m"
                )
            }
        }
    }
    catch {}
}


# --------------------------------------------------
# DRAW PAUSED SERIAL HISTORY
# --------------------------------------------------

function Draw-History {
    try {
        $top = [Console]::WindowTop
        $height = [Console]::WindowHeight
        $width = [Console]::WindowWidth

        $firstRow = $top + 3
        $lastRow = $top + $height - 4
        $visibleRows = $lastRow - $firstRow + 1

        if ($visibleRows -lt 1) { return }

        $total = $script:sessionLog.Count

        $maxOffset = [Math]::Max(
            0,
            $total - $visibleRows
        )

        $script:historyOffset = [Math]::Max(
            0,
            [Math]::Min(
                $script:historyOffset,
                $maxOffset
            )
        )

        $startIndex = $total - $visibleRows - $script:historyOffset

        for ($i = 0; $i -lt $visibleRows; $i++) {

            $index = $startIndex + $i
            $y = $firstRow + $i

            if (Safe-Cursor 0 $y) {

                [Console]::Write("$($script:esc)[2K")

                if ($index -ge 0 -and $index -lt $total) {

                    $line = [string]$script:sessionLog[$index]

                    if ($line.Length -ge $width) {
                        $line = $line.Substring(0, $width - 1)
                    }

                    [Console]::Write($line)
                }
            }
        }

        $script:historyDirty = $false

        Draw-Prompt
    }
    catch {}
}


# --------------------------------------------------
# DRAW INTERFACE
# --------------------------------------------------

function Draw-Prompt {
    try {
        $w = [Console]::WindowWidth
		$h = [Console]::WindowHeight
		$top = [Console]::WindowTop

		$bottom = $top + $h - 1
		$e = $script:esc

        $line1 = ''
        $line2 = ''
        $line3 = ''

        if ($script:paused) {

            $line1 = '[ PAUSED ]'

            if ($script:editingDir) {
    		$line2 = "Save file: $($script:dirBuffer)"
   		 $line3 = 'Backspace=Edit | Enter=Confirm | Esc=Cancel'
		}
		elseif ($script:savePrompt) {
 		   $line2 = "Save file: $($script:dirBuffer)"
 		   $line3 = 'Options: Y=Save | N=Cancel'
		}
            elseif ($script:pausePage -eq 'more') {
                $line2 = 'Options: R=Rescan | B=Back'
                $line3 = $script:pauseStatus
            }
            else {
                $line2 = 'Options: P=Resume | Ctrl+R=Reset | Ctrl+T=Time | Ctrl+E=Settings | Ctrl+X=Quit | S=Save | M=More'
                $line3 = $script:pauseStatus
            }
        }
        else {
            $line1 = ''
            $line2 = ''
            $line3 = "[TX] (Enter to send | Ctrl+P to pause) > $script:txBuffer"
        }

        $lines = @($line1, $line2, $line3)

        $start = $bottom - 2
        $max = [Math]::Max(1, $w - 1)

        for ($i = 0; $i -lt 3; $i++) {

            $line = [string]$lines[$i]

            if ($line.Length -gt $max) {
                $line = $line.Substring(0, $max)
            }

            if (Safe-Cursor 0 ($start + $i)) {

                $color = switch ($i) {
                    0 { '93' }
                    1 { '96' }
                    2 { '92' }
                }

                [Console]::Write(
                    "$e[2K$e[$($color)m$line$e[0m"
                )
            }
        }
    }
    catch {}
}


# --------------------------------------------------
# SERIAL LOG OUTPUT
# --------------------------------------------------


function Print-Log(
    [string]$message,
    [string]$color = '37'
) {
    try {

        $stamp = ''

        if ($script:showTs) {
            $stamp = '[' + (Get-Date -Format 'HH:mm:ss.fff') + '] '
        }

        $fullMessage = $stamp + $message

        # Preserve complete session history.
        $script:sessionLog.Add($fullMessage)

        if ($script:paused) {
            Draw-Prompt
            return
        }

        $top = [Console]::WindowTop
        $height = [Console]::WindowHeight
        $width = [Console]::WindowWidth

        # Fixed display boundaries.
        $firstLogRow = $top + 3
        $lastLogRow = $top + $height - 4

        $maxLogRows = $lastLogRow - $firstLogRow + 1

        if ($maxLogRows -lt 1) {
            return
        }

        # Store incoming message.
        $script:visibleLog.Add(
            [PSCustomObject]@{
                Text = $fullMessage
                Color = $color
            }
        )

        # Remove oldest messages when full.
        while ($script:visibleLog.Count -gt $maxLogRows) {
            $script:visibleLog.RemoveAt(0)
        }

        # Redraw ONLY the middle section.
        for ($i = 0; $i -lt $maxLogRows; $i++) {

            $y = $firstLogRow + $i

            if (-not (Safe-Cursor 0 $y)) {
                continue
            }

            if ($i -lt $script:visibleLog.Count) {

                $entry = $script:visibleLog[$i]

                $line = [string]$entry.Text
                $entryColor = [string]$entry.Color

                if ($line.Length -ge $width) {
                    $line = $line.Substring(0, $width - 1)
                }

                [Console]::Write(
                    "$($script:esc)[2K$($script:esc)[$($entryColor)m$line$($script:esc)[0m"
                )
            }
            else {

                [Console]::Write(
                    "$($script:esc)[2K"
                )
            }
        }

        $script:logRow = $script:visibleLog.Count

        # Restore fixed bottom menu.
        Draw-Prompt

    }
    catch {
        # Prevent display errors from interrupting serial monitoring.
    }
}

# --------------------------------------------------
# SAVE SESSION LOG
# --------------------------------------------------

function Save-Log {
    try {

        if (-not (Test-Path -LiteralPath $script:logDir)) {
            New-Item -ItemType Directory -Path $script:logDir -Force |
                Out-Null
        }

        $path = Join-Path $script:logDir $script:logFileName

        $script:sessionLog |
            Set-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop

        $script:pauseStatus = "Saved to $path successfully"

        Draw-Prompt
        return $true
    }
    catch {

        $script:pauseStatus = "SAVE FAILED: $($_.Exception.Message)"

        Draw-Prompt
        return $false
    }
}

# --------------------------------------------------
# WINDOWS CONSOLE MOUSE INPUT
# --------------------------------------------------

if (-not ('ConsoleMouseInput' -as [type])) {

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class ConsoleMouseInput
{
    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT_RECORD
    {
        public ushort EventType;
		public ushort Padding;

        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public byte[] EventData;
    }

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr GetStdHandle(int id);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetConsoleMode(
        IntPtr handle,
        out uint mode
    );

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetConsoleMode(
        IntPtr handle,
        uint mode
    );

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetNumberOfConsoleInputEvents(
        IntPtr handle,
        out uint count
    );

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool ReadConsoleInput(
        IntPtr handle,
        out INPUT_RECORD record,
        uint length,
        out uint read
    );
}
'@

}

$script:consoleHandle = [ConsoleMouseInput]::GetStdHandle(-10)

$mode = [uint32]0

[ConsoleMouseInput]::GetConsoleMode(
    $script:consoleHandle,
    [ref]$mode
) | Out-Null

# --------------------------------------------------
# KEYBOARD INPUT
# --------------------------------------------------

function Refresh-ConsoleLayout {

    $script:lastWidth = [Console]::WindowWidth
    $script:lastHeight = [Console]::WindowHeight
    $script:lastTop = [Console]::WindowTop

    Draw-Header

    if ($script:paused) {
        Draw-History
    }
    else {
        Draw-Prompt
    }
}
function Handle-Input($port) {

    try {

        $eventCount = [uint32]0

        if (-not [ConsoleMouseInput]::GetNumberOfConsoleInputEvents(
            $script:consoleHandle,
            [ref]$eventCount
        )) {
            return ''
        }

        if ($eventCount -eq 0) {
            return ''
        }

        $record = New-Object ConsoleMouseInput+INPUT_RECORD
        $record.EventData = New-Object byte[] 16

        $read = [uint32]0

        if (-not [ConsoleMouseInput]::ReadConsoleInput(
            $script:consoleHandle,
            [ref]$record,
            1,
            [ref]$read
        )) {
            return ''
        }

        if ($read -eq 0) {
            return ''
        }

		# ==========================================
		# MOUSE EVENTS
		# ==========================================

		if ($record.EventType -eq 2) {

			# Ignore mouse input unless paused
			if (-not $script:paused) {
				return ''
			}

			# Read mouse event information
			$buttonState = [BitConverter]::ToUInt32(
				$record.EventData, 4
			)

			$eventFlags = [BitConverter]::ToUInt32(
				$record.EventData, 12
			)

			# MOUSE_WHEELED = 0x0004
			if (($eventFlags -band 0x0004) -ne 0) {

				# Extract signed wheel delta
				$wheelRaw = ($buttonState -shr 16) -band 0xFFFF

		if ($wheelRaw -ge 32768) {
			$wheel = $wheelRaw - 65536
		}
		else {
			$wheel = $wheelRaw
		}
				if ($wheel -gt 0) {
					$script:historyOffset += 3
				}
				elseif ($wheel -lt 0) {
					$script:historyOffset -= 3
				}

			#	# Redraw history only
				Draw-History
			}

			return ''
		}

        # ==========================================
        # KEYBOARD EVENTS
        # ==========================================

        if ($record.EventType -ne 1) {
            return ''
        }

        $keyDown = [BitConverter]::ToUInt32(
            $record.EventData, 0
        )

        if ($keyDown -eq 0) {
            return ''
        }

        $keyCode = [BitConverter]::ToUInt16(
            $record.EventData, 6
        )

        $charCode = [BitConverter]::ToUInt16(
            $record.EventData, 10
        )

        $controlState = [BitConverter]::ToUInt32(
            $record.EventData, 12
        )

        $LEFT_CTRL_PRESSED  = 0x0008
		$RIGHT_CTRL_PRESSED = 0x0004

		$ctrl = (
			($controlState -band $LEFT_CTRL_PRESSED) -ne 0 -or
			($controlState -band $RIGHT_CTRL_PRESSED) -ne 0
		)
		# ==========================================
		# RUNNING MODE - CTRL+P PAUSE
		# ==========================================

		if (
			-not $script:paused -and
			$keyDown -eq 1 -and
			$ctrl -and
			$keyCode -eq 80
		) {
			return 'P'
		}
        # ==========================================
        # PAUSED MODE
        # ==========================================

        if ($script:paused) {

            # HISTORY NAVIGATION

            switch ($keyCode) {

                38 {
                    $script:historyOffset++
                    Draw-History
                    return ''
                }

                40 {
                    $script:historyOffset--
                    Draw-History
                    return ''
                }

                33 {
                    $script:historyOffset += [Console]::WindowHeight - 6
                    Draw-History
                    return ''
                }

                34 {
                    $script:historyOffset -= [Console]::WindowHeight - 6
                    Draw-History
                    return ''
                }

                36 {
                    $script:historyOffset = [int]::MaxValue
                    Draw-History
                    return ''
                }

                35 {
                    $script:historyOffset = 0
                    Draw-History
                    return ''
                }
            }

            # SAVE PATH EDITING

            if ($script:editingDir) {

                if ($keyCode -eq 27) {
                    $script:editingDir = $false
                    $script:pauseStatus = '[SAVE CANCELLED]'
                }
                elseif ($keyCode -eq 8) {
                    if ($script:dirBuffer.Length -gt 0) {
                        $script:dirBuffer = $script:dirBuffer.Substring(
                            0, $script:dirBuffer.Length - 1
                        )
                    }
                }
                elseif ($keyCode -eq 13) {

                    $path = $script:dirBuffer.Trim().Trim('"')

                    if ($path.Length -gt 0) {
                        $script:pendingSavePath = $path
                        $script:savePrompt = $true
                        $script:editingDir = $false
                    }
                }
                elseif (
                    $charCode -gt 0 -and
                    -not [char]::IsControl([char]$charCode)
                ) {
                    $script:dirBuffer += [char]$charCode
                }

                Draw-Prompt
                return ''
            }

            # SAVE CONFIRMATION

            if ($script:savePrompt) {

                if ($charCode -eq 89) {

                    $script:savePrompt = $false

                    $script:logDir = Split-Path -Parent $script:pendingSavePath
                    $script:logFileName = Split-Path -Leaf $script:pendingSavePath

                    Save-Log
                }
                elseif ($charCode -eq 78 -or $keyCode -eq 27) {

                    $script:savePrompt = $false
                    $script:pauseStatus = '[SAVE CANCELLED]'
                }

                Draw-Prompt
                return ''
            }

            # CTRL SHORTCUTS

            if ($ctrl) {

                switch ($keyCode) {
                    82 { return 'R' }
                    84 { return 'T' }
                    69 { return 'E' }
                    88 { return 'X' }
                }

                return ''
            }

            $key = [char]$charCode

            # MORE MENU

            if ($script:pausePage -eq 'more') {

                if ($key -eq 'R') {
                    $script:exitCode = 3
                    $script:quit = $true
                }
                elseif ($key -eq 'B') {
                    $script:pausePage = 'menu'
                }

                Draw-Prompt
                return ''
            }

            # MAIN PAUSED MENU

            switch ($key) {

                'P' {
                    return 'P'
                }

                'M' {
                    $script:pausePage = 'more'
                    $script:pauseStatus = ''
                }

                'S' {
                    $script:editingDir = $true
                    $script:dirBuffer = Join-Path $script:logDir $script:logFileName
                    $script:pauseStatus = ''
                }
            }

            Draw-Prompt
            return ''
        }

# ==========================================
# RUNNING MODE - CTRL+P PAUSE
# ==========================================

	if ($ctrl -and $k.Key -eq 'P') {
            return 'P'
        }

        # ENTER TRANSMITS

        if ($keyCode -eq 13) {

            $message = $script:txBuffer
            $script:txBuffer = ''

            if ($null -ne $port -and $port.IsOpen) {
                $port.Write($message + "`n")
                Print-Log "[TX] $message" '36'
            }

            Draw-Prompt
        }

        # BACKSPACE

        elseif ($keyCode -eq 8) {

            if ($script:txBuffer.Length -gt 0) {
                $script:txBuffer = $script:txBuffer.Substring(
                    0, $script:txBuffer.Length - 1
                )
            }

            Draw-Prompt
        }

        # ESCAPE

        elseif ($keyCode -eq 27) {

            $script:txBuffer = ''
            Draw-Prompt
        }

        # CHARACTER INPUT

        elseif (
            $charCode -gt 0 -and
            -not [char]::IsControl([char]$charCode)
        ) {

            $script:txBuffer += [char]$charCode
            Draw-Prompt
        }

    }
    catch {
        # Ignore console input errors
    }

    return ''
}


# --------------------------------------------------
# MAIN SERIAL MONITOR
# --------------------------------------------------

$port = $null
$buffer = ''

try {

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8

    try {
        $width = [Console]::WindowWidth
        [Console]::BufferHeight = 3000
        [Console]::BufferWidth = [Math]::Max(
            $width,
            [Console]::BufferWidth
        )
    }
    catch {}

    [Console]::Clear()

    $script:logRow = 0
    $script:visibleLog.Clear()

    # ----------------------------------------------
    # OPEN SERIAL PORT
    # ----------------------------------------------

    $port = [System.IO.Ports.SerialPort]::new(
        $portName,
        $baud,
        $parity,
        $dataBits,
        $stopBits
    )

    $port.DtrEnable = $true
    $port.ReadTimeout = 100
    $port.Open()

    # ----------------------------------------------
    # INITIALIZE DISPLAY
    # ----------------------------------------------

    Draw-Header
    Draw-Prompt

    Print-Log "[CONNECTED] $portName at $baud baud" '92'

    $timer = [Diagnostics.Stopwatch]::StartNew()

# ----------------------------------------------
# ENABLE WINDOWS CONSOLE MOUSE EVENTS
# ----------------------------------------------

$ENABLE_MOUSE_INPUT = 0x0010
$ENABLE_EXTENDED_FLAGS = 0x0080

$newMode = (
    $script:originalConsoleMode -bor
    $ENABLE_MOUSE_INPUT -bor
    $ENABLE_EXTENDED_FLAGS
)

if (-not [ConsoleMouseInput]::SetConsoleMode(
    $script:consoleHandle,
    [uint32]$newMode
)) {
    throw "Unable to enable console mouse input."
}

# Verify mouse input is enabled
$verifyMode = [uint32]0

[ConsoleMouseInput]::GetConsoleMode(
    $script:consoleHandle,
    [ref]$verifyMode
) | Out-Null


    # ----------------------------------------------
    # MAIN LOOP
    # ----------------------------------------------

    while (
        -not $script:quit -and
        $port.IsOpen
    ) {
	
		if (
			$script:lastWidth -ne [Console]::WindowWidth -or
			$script:lastHeight -ne [Console]::WindowHeight -or
			$script:lastTop -ne [Console]::WindowTop
		) {
			Refresh-ConsoleLayout
		}

        $action = Handle-Input $port

        switch ($action) {

            # ======================================
            # PAUSE / RESUME
            # ======================================

            'P' {

                $script:paused = -not $script:paused

                if ($script:paused) {

                    $script:pauseStatus = ''
                    $script:pausePage = 'menu'
                    $script:savePrompt = $false
                    $script:editingDir = $false

                    Print-Log '[PAUSED]' '93'
                }
                else {

                    $script:historyOffset = 0
                    $script:historyView = $false

                    $port.DiscardInBuffer()
                    $buffer = ''

                    Print-Log '[RESUMED]' '92'
                }

                Draw-Prompt
            }

            # ======================================
            # RESET TARGET USING DTR
            # ======================================

            'R' {

                $script:pauseStatus = '[RESETTING ARDUINO VIA DTR...]'
                Draw-Prompt

                $port.DtrEnable = $false
                Start-Sleep -Milliseconds 100
                $port.DtrEnable = $true

                Start-Sleep -Milliseconds 100

                $script:pauseStatus = '[ARDUINO RESET SUCCESSFUL]'
                Draw-Prompt
            }

            # ======================================
            # TIMESTAMP TOGGLE
            # ======================================

            'T' {

                $script:showTs = -not $script:showTs

                if ($script:showTs) {
                    $script:pauseStatus = 'Timestamps ON'
                }
                else {
                    $script:pauseStatus = 'Timestamps OFF'
                }

                Draw-Prompt
            }

            # ======================================
            # SETTINGS
            # ======================================

            'E' {

                $script:exitCode = 2
                $script:quit = $true
            }

            # ======================================
            # QUIT
            # ======================================

            'X' {

                $script:exitCode = 0
                $script:quit = $true
            }
        }

        # ==========================================
        # SERIAL RECEIVE
        # ==========================================

        if (-not $script:paused -and -not $script:quit) {

            $chunk = $port.ReadExisting()

            if ($chunk.Length -gt 0) {
                $buffer += $chunk
            }

            # Process complete lines
            while (($n = $buffer.IndexOf("`n")) -ge 0) {

                $line = $buffer.Substring(0, $n)
                $line = $line.TrimEnd("`r")
                $buffer = $buffer.Substring($n + 1)

                $color = '37'

                if ($line -match 'SUCCESS|OK|READY|DONE') {
                    $color = '92'
                }
                elseif ($line -match 'ERROR|FAIL|FAULT|WARN|TIMEOUT') {
                    $color = '91'
                }

                Print-Log $line $color
                $timer.Restart()
            }

            # Process partial lines after timeout
            if (
                $buffer.Length -ge 256 -or
                (
                    $buffer.Length -gt 0 -and
                    $timer.ElapsedMilliseconds -ge 100
                )
            ) {

                Print-Log $buffer '37'
                $buffer = ''
                $timer.Restart()
            }
        }

        Start-Sleep -Milliseconds 10
    }
}
catch {

    Write-Host "`n[POWERSHELL ERROR]" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
    Write-Host "At: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Yellow

    Read-Host "Press Enter to close"

    $script:exitCode = 1
}
finally {

    # Restore original console input mode
    if ($null -ne $script:consoleHandle) {

        try {
            [ConsoleMouseInput]::SetConsoleMode(
                $script:consoleHandle,
                $script:originalConsoleMode
            ) | Out-Null
        }
        catch {}
    }

    if ($null -ne $port) {

        try {
            if ($port.IsOpen) {
                $port.Close()
            }
        }
        catch {}

        try {
            $port.Dispose()
        }
        catch {}
    }
}

if ($script:quit) {
    exit $script:exitCode
}

exit 0
