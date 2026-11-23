@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Arduino Serial Monitor

:: Generate ESC character for ANSI colors
for /f %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "BLUE=%ESC%[96m"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RESET=%ESC%[0m"

:: Default Serial Settings
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

for /f "tokens=1,2,* delims=|" %%A in ('powershell -NoProfile -Command ^
 "$ports = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\(COM\d+\)' }; " ^
 "foreach ($p in $ports) { " ^
 "  if ($p.Name -match '(COM\d+)') { $com = $matches[1] } else { continue }; " ^
 "  if ($p.Name -match 'Arduino|CH340|CH341|CH9102|FTDI|USB Serial|CP210|Prolific|ESP32|Espressif|UART|Silicon Labs') { " ^
 "    Write-Output ('MATCH|' + $com + '|' + $p.Name); " ^
 "  } else { Write-Output ('OTHER|' + $com + '|' + $p.Name) } " ^
 "}"') do (
    set /a TOTALCOUNT+=1

    if "%%A"=="MATCH" (
        set /a MATCHCOUNT+=1
        echo %GREEN%[!MATCHCOUNT!] [Likely Arduino] %%B -^> %%C%RESET%
        set "COM_!MATCHCOUNT!=%%B"
        set "NAME_!MATCHCOUNT!=%%C"
    ) else (
        echo %YELLOW%[-] [Other Device] %%B -^> %%C%RESET%
        set "PORT_!TOTALCOUNT!=%%B"
        set "PORTNAME_!TOTALCOUNT!=%%C"
    )
)

echo.

if !TOTALCOUNT! EQU 0 (
    echo %RED%No COM ports found.%RESET%
    pause
    goto SCAN_PORTS
)

if !MATCHCOUNT! EQU 0 (
    echo %YELLOW%No recognized device found. Select manually:%RESET%
    set /a PORTCOUNT=0
    for /f "tokens=1,2,* delims=|" %%A in ('powershell -NoProfile -Command ^
      "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\(COM\d+\)' } | ForEach-Object { if ($_.Name -match '(COM\d+)') { 'PORT|' + $matches[1] + '|' + $_.Name } }"') do (
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
    set /p "CHOICE=Enter device number (1-!MATCHCOUNT!) or (or P to re-scan ports): "
    echo(!CHOICE!| findstr /r "^[1-9][0-9]*$" >nul
    if /i "!CHOICE!"=="P" goto SCAN_PORTS
    if errorlevel 1 (
        echo %RED%Invalid selection.%RESET%
        goto SELECT_DEVICE
    )

    if !CHOICE! GTR !MATCHCOUNT! (
        echo %RED%Selection out of range.%RESET%
        goto SELECT_DEVICE
    )

    for %%I in (!CHOICE!) do (
        call set "AUTOCOM=%%COM_%%I%%"
        call set "AUTONAME=%%NAME_%%I%%"
    )
)

if not defined AUTOCOM (
    echo %RED%Port selection failed.%RESET%
    goto SELECT_DEVICE
)

echo.
echo %GREEN%Selected:%RESET% %BLUE%!AUTOCOM!%RESET% (!AUTONAME!)


:SETTINGS_MENU
echo.
echo %BLUE%Current Settings:%RESET% !AUTOCOM! ^| %GREEN%!BAUD! baud, !DATABITS! data bits, !PARITY! parity, !STOPBITS! stop bit%RESET%
set "KEEP=Y"
set /p "KEEP=Keep current settings? [Y/n] (or P to re-scan ports): "

if /i "!KEEP!"=="P" goto SCAN_PORTS
if /i "!KEEP!"=="Y" goto CONNECT
if "!KEEP!"=="" goto CONNECT

echo.
echo %BLUE%--- Custom Serial Settings (Press Enter to keep current value) ---%RESET%

set "INPUT="
set /p "INPUT=Baud Rate [!BAUD!]: "
if defined INPUT set "BAUD=!INPUT!"
echo(!BAUD!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo %RED%Invalid baud rate.%RESET%
    goto SETTINGS_MENU
)
if !BAUD! LSS 50 goto SETTINGS_MENU
if !BAUD! GTR 4000000 goto SETTINGS_MENU

set "INPUT="
set /p "INPUT=Data Bits (5-8) [!DATABITS!]: "
if defined INPUT set "DATABITS=!INPUT!"
if not "!DATABITS!"=="5" if not "!DATABITS!"=="6" if not "!DATABITS!"=="7" if not "!DATABITS!"=="8" (
    echo %RED%Invalid data bits.%RESET%
    goto SETTINGS_MENU
)

set "INPUT="
set /p "INPUT=Parity (N/None, O/Odd, E/Even, M/Mark, S/Space) [!PARITY!]: "
if defined INPUT set "PARITY=!INPUT!"
if /i "!PARITY!"=="N" set "PARITY=None"
if /i "!PARITY!"=="O" set "PARITY=Odd"
if /i "!PARITY!"=="0" set "PARITY=None"
if /i "!PARITY!"=="E" set "PARITY=Even"
if /i "!PARITY!"=="M" set "PARITY=Mark"
if /i "!PARITY!"=="S" set "PARITY=Space"

if /i not "!PARITY!"=="None" if /i not "!PARITY!"=="Odd" if /i not "!PARITY!"=="Even" if /i not "!PARITY!"=="Mark" if /i not "!PARITY!"=="Space" (
    echo %RED%Invalid parity.%RESET%
    goto SETTINGS_MENU
)

set "INPUT="
set /p "INPUT=Stop Bits (1, 1.5, 2) [!STOPBITS!]: "
if defined INPUT set "STOPBITS=!INPUT!"
if "!STOPBITS!"=="1" set "STOPBITS=One"
if "!STOPBITS!"=="1.5" set "STOPBITS=OnePointFive"
if "!STOPBITS!"=="2" set "STOPBITS=Two"

if /i not "!STOPBITS!"=="One" if /i not "!STOPBITS!"=="OnePointFive" if /i not "!STOPBITS!"=="Two" (
    echo %RED%Invalid stop bits.%RESET%
    goto SETTINGS_MENU
)

:CONNECT
echo.
echo %YELLOW%Live Controls: [Ctrl+R] Reset Target   [Ctrl+E] Change Settings   [Ctrl+X] Quit%RESET%
echo ------------------------------------------------------------


powershell.exe -NoProfile -Command ^
 "$portName = '!AUTOCOM!'; " ^
 "$baud = [int]'!BAUD!'; " ^
 "$dataBits = [int]'!DATABITS!'; " ^
 "$parity = [System.IO.Ports.Parity]'!PARITY!'; " ^
 "$stopBits = [System.IO.Ports.StopBits]'!STOPBITS!'; " ^
 "$quit = $false; $exitCode = 0; " ^
 "function Get-Action { " ^
 "  try { " ^
 "    if ([Console]::KeyAvailable) { " ^
 "      $k = [Console]::ReadKey($true); " ^
 "      if (($k.Modifiers -band [ConsoleModifiers]::Control) -ne 0) { return [string]$k.Key } " ^
 "    } " ^
 "  } catch {} " ^
 "  return ''; " ^
 "} " ^
 "function Show-Line([string]$s) { " ^
 "  if ($s -match 'SUCCESS|OK|READY|DONE|0x[0-9A-Fa-f]+') { Write-Host $s -ForegroundColor Green } " ^
 "  elseif ($s -match 'ERROR|FAIL|FAULT|WARN|TIMEOUT') { Write-Host $s -ForegroundColor Red } " ^
 "  else { Write-Host $s } " ^
 "} " ^
 "while (-not $quit) { " ^
 "  $port = $null; $connected = $false; " ^
 "  try { " ^
 "    $port = [System.IO.Ports.SerialPort]::new($portName,$baud,$parity,$dataBits,$stopBits); " ^
 "    $port.DtrEnable = $true; $port.ReadTimeout = 100; " ^
 "    $port.Open(); $connected = $true; " ^
 "    Write-Host '[CONNECTED]' -ForegroundColor Green; " ^
 "    $buffer = ''; $timer = [Diagnostics.Stopwatch]::StartNew(); " ^
 "    while ($port.IsOpen -and -not $quit) { " ^
 "      $action = Get-Action; " ^
 "      if ($action -eq 'R') { " ^
 "        Write-Host '[RESETTING TARGET VIA DTR]' -ForegroundColor Cyan; " ^
 "        $port.DtrEnable = $false; Start-Sleep -Milliseconds 100; $port.DtrEnable = $true; " ^
 "      } elseif ($action -eq 'E') { $exitCode = 2; $quit = $true; break; " ^
 "      } elseif ($action -eq 'X') { $exitCode = 0; $quit = $true; break; } " ^
 "      $chunk = $port.ReadExisting(); " ^
 "      if ($chunk.Length -gt 0) { $buffer += $chunk; } " ^
 "      while (($newline = $buffer.IndexOf([char]10)) -ge 0) { " ^
 "        $line = $buffer.Substring(0,$newline).TrimEnd([char]13); " ^
 "        $buffer = $buffer.Substring($newline+1); " ^
 "        Show-Line $line; $timer.Restart(); " ^
 "      } " ^
 "      if ($buffer.Length -ge 256 -or ($buffer.Length -gt 0 -and $timer.ElapsedMilliseconds -ge 100)) { " ^
 "        Write-Host -NoNewline $buffer; $buffer = ''; $timer.Restart(); " ^
 "      } " ^
 "      Start-Sleep -Milliseconds 10; " ^
 "    } " ^
 "  } catch { " ^
 "    if (-not $quit) { Write-Host ('[DISCONNECTED] ' + $_.Exception.Message) -ForegroundColor Yellow; } " ^
 "  } finally { " ^
 "    if ($null -ne $port) { " ^
 "      try { if ($port.IsOpen) { $port.Close(); } } catch {} " ^
 "      try { $port.Dispose(); } catch {} " ^
 "    } " ^
 "  } " ^
 "  if ($buffer.Length -gt 0) { Write-Host -NoNewline $buffer; $buffer = ''; } " ^
 "  if ($quit) { break; } " ^
 "  if ($exitCode -eq 2) { $quit = $true; break; } " ^
 "  Write-Host '[WAITING FOR DEVICE] ' -ForegroundColor Yellow -NoNewline; Write-Host '[Ctrl+E SETTINGS | Ctrl+X QUIT]' -ForegroundColor Red; " ^
 "  $wait = [Diagnostics.Stopwatch]::StartNew(); " ^
 "  while ($wait.ElapsedMilliseconds -lt 1000 -and -not $quit) { " ^
 "    $action = Get-Action; " ^
 "    if ($action -eq 'E') { $exitCode = 2; $quit = $true; break; } " ^
 "    if ($action -eq 'X') { $exitCode = 0; $quit = $true; break; } " ^
 "    if ($action -eq 'R') { Write-Host '[DEVICE NOT CONNECTED - RESET UNAVAILABLE]' -ForegroundColor Yellow; } " ^
 "    Start-Sleep -Milliseconds 50; " ^
 "  } " ^
 "} " ^
 "exit $exitCode"

if errorlevel 2 goto SETTINGS_MENU

echo.
echo %BLUE%Serial monitor closed. Goodbye.%RESET%
exit /b 0
