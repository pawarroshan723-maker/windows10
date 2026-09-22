@echo off
setlocal EnableExtensions
title Fix EXE Files Not Opening - Windows 10 / 11
color 0A

:: ============================================================
::  FIX EXE NOT OPENING - Comprehensive Repair
::  For Windows 10 / 11 when .exe files won't launch
::  Run as Administrator
:: ============================================================

:: ---------- Elevate to Administrator ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Requesting Administrator privileges - please accept UAC...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
        echo   Elevation cancelled. Right-click ^> Run as administrator.
        pause
    )
    exit /b
)

echo.
echo  ==================================================================
echo    FIX EXE ASSOCIATION - When no .exe file opens on Windows 10/11
echo  ==================================================================
echo.
echo  This will repair:
echo   - Broken .exe file association (exefile)
echo   - UserChoice override in HKCU
echo   - HKCR\.exe and exefile shell\open\command
echo   - Will check IFEO Debugger hijacks (malware)
echo   - Will restart Explorer to apply
echo.
pause

set "LOG=%USERPROFILE%\Desktop\exe_fix_log.txt"
echo EXE Fix Log - %DATE% %TIME% > "%LOG%"
echo ====================================== >> "%LOG%"

echo.
echo [1/7] Removing user-level overrides...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe" /f >nul 2>&1
echo   - Deleted HKCU\...\FileExts\.exe >> "%LOG%" 2>&1
reg delete "HKCU\Software\Classes\.exe" /f >nul 2>&1
echo   - Deleted HKCU\Software\Classes\.exe >> "%LOG%" 2>&1
reg delete "HKCU\Software\Classes\exefile" /f >nul 2>&1
echo   - Deleted HKCU\Software\Classes\exefile >> "%LOG%" 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe\UserChoice" /f >nul 2>&1
echo   OK - user overrides cleared
echo   OK - user overrides cleared >> "%LOG%"

echo.
echo [2/7] Restoring core .exe association...
assoc .exe=exefile >nul 2>&1
echo   assoc .exe=exefile >> "%LOG%" 2>&1
ftype exefile="%%1" %%* >nul 2>&1
echo   ftype exefile="%%1" %%* >> "%LOG%" 2>&1

reg add "HKCR\.exe" /ve /d "exefile" /f >> "%LOG%" 2>&1
reg add "HKCR\.exe" /v "Content Type" /d "application/x-msdownload" /f >> "%LOG%" 2>&1
reg add "HKCR\.exe\PersistentHandler" /ve /d "{098f2470-bae0-11cd-b579-08002b30bfeb}" /f >> "%LOG%" 2>&1

reg add "HKCR\exefile" /ve /d "Application" /f >> "%LOG%" 2>&1
reg add "HKCR\exefile" /v "EditFlags" /t REG_BINARY /d 38070000 /f >> "%LOG%" 2>&1
reg add "HKCR\exefile\DefaultIcon" /ve /d "%%1" /f >> "%LOG%" 2>&1
reg add "HKCR\exefile\shell\open" /v "EditFlags" /t REG_BINARY /d 00000000 /f >> "%LOG%" 2>&1
reg add "HKCR\exefile\shell\open\command" /ve /d "\"%%1\" %%*" /f >> "%LOG%" 2>&1
reg add "HKCR\exefile\shell\open\command" /v "IsolatedCommand" /d "\"%%1\" %%*" /f >> "%LOG%" 2>&1

:: Also fix for 64-bit reg view - ensure HKLM\SOFTWARE\Classes
reg add "HKLM\SOFTWARE\Classes\.exe" /ve /d "exefile" /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Classes\.exe" /v "Content Type" /d "application/x-msdownload" /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Classes\exefile\shell\open\command" /ve /d "\"%%1\" %%*" /f >> "%LOG%" 2>&1

echo   OK - core association restored

echo.
echo [3/7] Checking Image File Execution Options (IFEO) hijacks...
echo   IFEO hijacks are common malware technique that blocks exe via Debugger value
echo.
set "IFEO_FOUND=0"
for /f "tokens=*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s /f "Debugger" 2^>nul ^| findstr /i "Debugger"') do (
    set "IFEO_FOUND=1"
    echo   FOUND: %%a
    echo   FOUND: %%a >> "%LOG%"
)

if "%IFEO_FOUND%"=="1" (
    echo.
    echo   WARNING: Debugger hijacks found! This often causes exe not to open.
    echo   Do you want to REMOVE all Debugger values under IFEO? (Removes hijacks)
    echo   This will NOT delete legitimate entries, only the Debugger value.
    choice /c YN /n /m "   Remove all IFEO Debugger hijacks? [Y/N]: "
    if errorlevel 2 goto skip_ifeo
    echo   Removing Debugger values...
    for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s /f "Debugger" 2^>nul ^| findstr /i "HKEY_"') do (
        echo     Cleaning %%k
        reg delete "%%k" /v Debugger /f >> "%LOG%" 2>&1
    )
    echo   OK - IFEO cleaned
) else (
    echo   OK - No IFEO Debugger hijacks found
    echo   No IFEO hijacks >> "%LOG%"
)
:skip_ifeo

echo.
echo [4/7] Checking DisallowRun policies...
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisallowRun >nul 2>&1
if not errorlevel 1 (
    echo   WARNING: DisallowRun policy exists - may block exe
    reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisallowRun
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisallowRun /f >> "%LOG%" 2>&1
    echo   Removed DisallowRun
)
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisallowRun >nul 2>&1
if not errorlevel 1 (
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisallowRun /f >> "%LOG%" 2>&1
    echo   Removed HKLM DisallowRun
)
echo   OK - DisallowRun check done

echo.
echo [5/7] Running SFC quick check (optional)...
echo   If exe still fails, system files may be corrupt.
choice /c YN /n /m "   Run sfc /scannow now? Takes 5-15 min [Y/N]: "
if errorlevel 2 goto skip_sfc
sfc /scannow
echo   SFC finished >> "%LOG%" 2>&1
:skip_sfc

echo.
echo [6/7] Restarting Windows Explorer to apply...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul 2>&1
start explorer.exe
echo   OK - Explorer restarted

echo.
echo [7/7] Final verification...
assoc .exe
ftype exefile
reg query "HKCR\.exe" /ve 2>nul
reg query "HKCR\exefile\shell\open\command" /ve 2>nul

echo.
echo  ==================================================================
echo    FIX COMPLETE!
echo  ==================================================================
echo.
echo  Try opening any .exe file now.
echo.
echo  If still not opening:
echo   1. Restart your PC
echo   2. Boot into Safe Mode and run this again
echo   3. Scan for malware: Windows Defender Full Scan
echo   4. Run: DISM /Online /Cleanup-Image /RestoreHealth
echo   5. Create new Windows user profile - test exe there
echo.
echo  Log saved to: %LOG%
echo.
pause
exit /b 0
