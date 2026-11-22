@echo off
:: Scan COM ports, auto-select Arduino, configure serial settings, and stream with live controls
setlocal EnableDelayedExpansion
title Arduino Serial Monitor

:: Generate ESC character for ANSI color codes
for /f %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "BLUE=%ESC%[96m"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RESET=%ESC%[0m"

:: --- Default Serial Settings ---
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

for /f "tokens=1,2,3 delims=|" %%A in ('powershell -NoProfile -Command ^
  "$ports = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\(COM\d+\)' }; " ^
  "foreach ($p in $ports) { " ^
  "  if ($p.Name -match '(COM\d+)') { $com = $matches[1] }; " ^
  "  if ($p.Name -match 'Arduino|CH340|CH9102|FTDI|USB Serial|CP210|Prolific') { " ^
  "    Write-Output ('MATCH|' + $com + '|' + $p.Name); " ^
  "  } else { " ^
  "    Write-Output ('OTHER|' + $com + '|' + $p.Name); " ^
  "  } " ^
  "}"') do (
  set /a TOTALCOUNT+=1
  if "%%A"=="MATCH" (
    set /a MATCHCOUNT+=1
    echo  %GREEN%[!MATCHCOUNT!] [Likely Arduino] %%B -^> %%C%RESET%
    set "AUTOCOM=%%B"
    set "AUTONAME=%%C"
    set "COM_!MATCHCOUNT!=%%B"
    set "NAME_!MATCHCOUNT!=%%C"
  ) else (
    echo  %YELLOW%[-] [Other Device]   %%B -^> %%C%RESET%
  )
)

echo.

if %TOTALCOUNT%==0 (
  echo %RED%[ERROR] No COM ports found. Check your USB cable.%RESET%
  pause
  goto SCAN_PORTS
)

if %MATCHCOUNT%==0 (
  echo %YELLOW%[WARN] No Arduino or USB-to-TTL adapter detected.%RESET%
  pause
  goto SCAN_PORTS
)

if %MATCHCOUNT%==1 (
  echo %GREEN%Auto-selected:%RESET% %BLUE%!AUTOCOM!%RESET% ^(!AUTONAME!^)
) else (
  echo %BLUE%Multiple matching devices found:%RESET%
  set /p "CHOICE=Enter device number (1-%MATCHCOUNT%): "
  for %%I in (!CHOICE!) do (
    set "AUTOCOM=!COM_%%I!"
    set "AUTONAME=!NAME_%%I!"
  )
  if "!AUTOCOM!"=="" (
    echo %RED%[ERROR] Invalid selection.%RESET%
    pause
    goto SCAN_PORTS
  )
  echo %GREEN%Selected:%RESET% %BLUE%!AUTOCOM!%RESET% ^(!AUTONAME!^)
)

:SETTINGS_MENU
echo.
echo %BLUE%Current Settings:%RESET% !AUTOCOM! ^| %GREEN%!BAUD! baud, !DATABITS! data bits, !PARITY! parity, !STOPBITS! stop bit%RESET%
set "KEEP=Y"
set /p "KEEP=Keep current settings? [Y/n] (or P to re-scan ports): "

if /i "!KEEP!"=="P" goto SCAN_PORTS

if /i not "!KEEP!"=="Y" (
  echo.
  echo %BLUE%--- Custom Serial Settings ^(Press Enter to keep current value^) ---%RESET%
  set /p "BAUD=Baud Rate [!BAUD!]: "
  set /p "DATABITS=Data Bits (5-8) [!DATABITS!]: "
  set /p "PARITY=Parity (None, Odd, Even, Mark, Space) [!PARITY!]: "
  set /p "STOPBITS=Stop Bits (One, Two, OnePointFive) [!STOPBITS!]: "
)

:CONNECT
echo.
echo %YELLOW%Live Controls: [Ctrl+R] Reset Target   [Ctrl+E] Change Settings   [Ctrl+X] Quit%RESET%
echo ------------------------------------------------------------

:: Built-in PowerShell Serial Monitor with Ctrl+Key detection
powershell -NoProfile -Command ^
  "$portName = '!AUTOCOM!'; " ^
  "$baud = [int]'!BAUD!'; " ^
  "$dataBits = [int]'!DATABITS!'; " ^
  "$parity = '!PARITY!'; " ^
  "$stopBits = '!STOPBITS!'; " ^
  "$exitCode = 0; " ^
  "$quit = $false; " ^
  "while (-not $quit) { " ^
  "  try { " ^
  "    $port = New-Object System.IO.Ports.SerialPort $portName, $baud, $parity, $dataBits, $stopBits; " ^
  "    $port.DtrEnable = $true; " ^
  "    $port.ReadTimeout = 100; " ^
  "    $port.Open(); " ^
  "    Write-Host '[CONNECTED]' -ForegroundColor Green; " ^
  "    while ($port.IsOpen) { " ^
  "      if ([Console]::KeyAvailable) { " ^
  "        $k = [Console]::ReadKey($true); " ^
  "        $ctrl = ($k.Modifiers -band [ConsoleModifiers]::Control) -ne 0; " ^
  "        if ($ctrl -and $k.Key -eq 'R') { " ^
  "          Write-Host '`n[RESETTING ARDUINO VIA DTR...]' -ForegroundColor Cyan; " ^
  "          $port.DtrEnable = $false; Start-Sleep -Milliseconds 100; $port.DtrEnable = $true; " ^
  "        } elseif ($ctrl -and $k.Key -eq 'E') { " ^
  "          Write-Host '`n[CLOSING PORT FOR SETTINGS...]' -ForegroundColor Yellow; " ^
  "          $exitCode = 2; $quit = $true; break; " ^
  "        } elseif ($ctrl -and $k.Key -eq 'X') { " ^
  "          $exitCode = 0; $quit = $true; break; " ^
  "        } " ^
  "      } " ^
  "      try { " ^
  "        $line = $port.ReadLine(); " ^
  "        if ($line -match 'SUCCESS|0x0BC11477') { Write-Host $line -ForegroundColor Green } " ^
  "        elseif ($line -match 'Failed|FAULT|ACK: 0|ACK: 7') { Write-Host $line -ForegroundColor Red } " ^
  "        else { Write-Host $line } " ^
  "      } catch [System.TimeoutException] { } " ^
  "    } " ^
  "  } catch { " ^
  "    if ([Console]::KeyAvailable) { " ^
  "      $k = [Console]::ReadKey($true); " ^
  "      $ctrl = ($k.Modifiers -band [ConsoleModifiers]::Control) -ne 0; " ^
  "      if ($ctrl -and $k.Key -eq 'E') { $exitCode = 2; $quit = $true; break; } " ^
  "      if ($ctrl -and $k.Key -eq 'X') { $exitCode = 0; $quit = $true; break; } " ^
  "    } " ^
  "    Write-Host '[DISCONNECTED - Waiting for device... (Ctrl+E for settings, Ctrl+X to quit)]' -ForegroundColor Yellow; " ^
  "    Start-Sleep -Seconds 1; " ^
  "  } finally { " ^
  "    if ($port -and $port.IsOpen) { $port.Close() } " ^
  "  } " ^
  "} " ^
  "exit $exitCode"
if %errorlevel%==2 goto SETTINGS_MENU

echo.
echo %BLUE%Serial monitor closed. Goodbye.%RESET%
exit /b 0
