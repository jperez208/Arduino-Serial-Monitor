
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
$script:esc = [char]27
$script:logRow = 0

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

# --------------------------------------------------
# DRAW INTERFACE
# --------------------------------------------------

function Draw-Prompt {
    try {
        $w = [Console]::WindowWidth
        $bottom = [Console]::WindowTop + [Console]::WindowHeight - 1
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
                $line2 = 'Options: P=Resume | Ctrl+R=Reset | Ctrl+T=Time | Ctrl+E=Settings | Ctrl+X=Quit | M=More | S=Save'
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

        $script:sessionLog.Add($fullMessage)

        if ($script:paused) {
            Draw-Prompt
            return
        }

        $windowTop = [Console]::WindowTop
        $windowHeight = [Console]::WindowHeight

        # Reserve the bottom three rows for the interface.
        $maxLogRows = $windowHeight - 3

        if ($maxLogRows -lt 1) {
            return
        }

        # Reset the visible log area when full.
        if ($script:logRow -ge $maxLogRows) {

            for ($i = 0; $i -lt $maxLogRows; $i++) {
                if (Safe-Cursor 0 ($windowTop + $i)) {
                    [Console]::Write(
                        "$($script:esc)[2K"
                    )
                }
            }

            $script:logRow = 0
        }

        $line = $fullMessage
        $maxWidth = [Math]::Max(1, [Console]::WindowWidth - 1)

        if ($line.Length -gt $maxWidth) {
            $line = $line.Substring(0, $maxWidth)
        }

        $y = $windowTop + $script:logRow

        if (Safe-Cursor 0 $y) {

            [Console]::Write(
                "$($script:esc)[$($color)m$line$($script:esc)[0m$($script:esc)[K"
            )
        }

        $script:logRow++

        Draw-Prompt
    }
    catch {}
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
# KEYBOARD INPUT
# --------------------------------------------------

function Handle-Input($port) {

    try {

        if (-not [Console]::KeyAvailable) {
            return ''
        }

        $k = [Console]::ReadKey($true)

        $ctrl = (
            ($k.Modifiers -band [ConsoleModifiers]::Control) -ne 0
        )

        # ==========================================
        # PAUSED MODE
        # ==========================================

        if ($script:paused) {

            # --------------------------------------
            # DIRECTORY EDITING
            # --------------------------------------

# --------------------------------------
# EDIT COMPLETE SAVE PATH
# --------------------------------------

if ($script:editingDir) {

    if ($k.Key -eq 'Escape') {
        $script:editingDir = $false
        $script:pauseStatus = '[SAVE CANCELLED]'
    }
    elseif ($k.Key -eq 'Backspace') {
        if ($script:dirBuffer.Length -gt 0) {
            $script:dirBuffer = $script:dirBuffer.Substring(
                0, $script:dirBuffer.Length - 1
            )
        }
    }
    elseif ($k.Key -eq 'Enter') {
        $path = $script:dirBuffer.Trim().Trim('"')

        if ($path.Length -gt 0) {
            $script:pendingSavePath = $path
            $script:savePrompt = $true
            $script:editingDir = $false
        }
    }
    elseif (
        $k.KeyChar -ne [char]0 -and
        -not [char]::IsControl($k.KeyChar)
    ) {
        $script:dirBuffer += $k.KeyChar
    }

    Draw-Prompt
    return ''
}

# --------------------------------------
# SAVE CONFIRMATION
# --------------------------------------

if ($script:savePrompt) {

    if ($k.Key -eq 'Y') {

        $script:savePrompt = $false

        $script:logDir = Split-Path -Parent $script:pendingSavePath
        $script:logFileName = Split-Path -Leaf $script:pendingSavePath

        Save-Log
    }
    elseif ($k.Key -eq 'N' -or $k.Key -eq 'Escape') {

        $script:savePrompt = $false
        $script:pauseStatus = '[SAVE CANCELLED]'
    }

    Draw-Prompt
    return ''
}

            # --------------------------------------
            # CTRL SHORTCUTS
            # --------------------------------------

            if ($ctrl) {

                switch ($k.Key) {

                    'R' { return 'R' }
                    'T' { return 'T' }
                    'E' { return 'E' }
                    'X' { return 'X' }
                }

                return ''
            }

            # --------------------------------------
            # MORE MENU
            # --------------------------------------

            if ($script:pausePage -eq 'more') {

                switch ($k.Key) {

                    'R' {
                        $script:exitCode = 3
                        $script:quit = $true
                    }

                    'B' {
                        $script:pausePage = 'menu'
                    }
                }

                Draw-Prompt
                return ''
            }

            # --------------------------------------
            # MAIN PAUSED MENU
            # --------------------------------------

            switch ($k.Key) {

                'P' {
                    return 'P'
                }

                'M' {
                    $script:pausePage = 'more'
                    $script:pauseStatus = ''
                }

                'S' {
    $script:editingDir = $true
    $script:savePrompt = $false

    $script:dirBuffer = Join-Path $script:logDir $script:logFileName

    $script:pauseStatus = ''
}
            }

            Draw-Prompt
            return ''
        }

        # ==========================================
        # RUNNING MODE
        # ==========================================

        # Ctrl+P pauses
        if ($ctrl -and $k.Key -eq 'P') {
            return 'P'
        }

        # Enter transmits
        if ($k.Key -eq 'Enter') {

            $message = $script:txBuffer
            $script:txBuffer = ''

            if ($null -ne $port -and $port.IsOpen) {

                $port.Write($message + "`n")

                Print-Log "[TX] $message" '36'
            }

            Draw-Prompt
        }

        # Backspace
        elseif ($k.Key -eq 'Backspace') {

            if ($script:txBuffer.Length -gt 0) {

                $script:txBuffer = $script:txBuffer.Substring(
                    0,
                    $script:txBuffer.Length - 1
                )

                Draw-Prompt
            }
        }

        # Escape clears TX
        elseif ($k.Key -eq 'Escape') {

            $script:txBuffer = ''
            Draw-Prompt
        }

        # Character input
        elseif (
            $k.KeyChar -ne [char]0 -and
            -not [char]::IsControl($k.KeyChar)
        ) {

            $script:txBuffer += $k.KeyChar
            Draw-Prompt
        }
    }
    catch {
        # Ignore console input/display errors.
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

    Draw-Prompt

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

    Print-Log "[CONNECTED] $portName at $baud baud" '92'

    $timer = [Diagnostics.Stopwatch]::StartNew()

    # ----------------------------------------------
    # MAIN LOOP
    # ----------------------------------------------

    while (
        -not $script:quit -and
        $port.IsOpen
    ) {

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

