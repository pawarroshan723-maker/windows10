@echo off
setlocal EnableExtensions
title Advanced System Care - Windows 10 / 11

:: ================================================================
::  ADVANCED SYSTEM CARE  v2.9
::  (Cleanup + Repair + Services + Registry + QuickFix + Tweaks
::   + ONE-CLICK REPAIR ALL)
:: ---------------------------------------------------------------
::  COLOR CODING SCHEME (ANSI 256-color safe):
::    CYAN    = headers and structure        GREEN  = success
::    YELLOW  = warnings / pending reboot    RED    = failures
::    MAGENTA = auto-heal / repair status    GRAY   = hints, notes
::    WHITE   = body text
::  Colors use ANSI escape codes. The script enables Windows
::  virtual-terminal mode and relaunches its own console once, so
::  colors work on Windows 10 conhost, Windows Terminal, etc.
:: ---------------------------------------------------------------
::  CLEANUP      QUICK / FULL / DEEP (temp, caches, update cache...)
::  REPAIR       SFC + DISM suite, network stack reset, WU reset
::  SERVICES     health scan of ~20 critical services vs their
::               correct start types + one-click repair
::  REGISTRY     fixes for classic regedit damage: EXE association,
::               Task Manager / CMD / Regedit blocked by policies,
::               missing Run dialog, hidden folder options,
::               blocked USB storage, locked Control Panel
::  QUICK FIXES  printer, audio, bluetooth, Store, time sync,
::               search indexer, CHKDSK, System Restore, RAM test
::  TWEAKS       popular Windows tweaks (MajorGeeks-style), each
::               with Apply / Restore toggle: Photo Viewer, file
::               extensions, hidden files, Take Ownership menu,
::               shortcut arrows, Bing suggestions, menu speed,
::               GameDVR, lock screen
::  OPTIMIZE     drive TRIM/defrag, power plans, startup delay,
::               Explorer restart, hibernation control
::  AUTO-HEAL    if DISM cleanup fails: internet check, then
::               scanhealth + restorehealth, then automatic retry
::  LOG          ONE file: %USERPROFILE%\CleanupLogs\Cleanup.log
:: ================================================================

:: ---------- 1. Elevate to Administrator if needed ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Requesting Administrator privileges - please accept the UAC prompt...
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '-vt' -Verb RunAs } catch { exit 1 }" >nul 2>&1
    if errorlevel 1 (
        echo.
        echo   Elevation was cancelled - Administrator rights are REQUIRED.
        echo   Right-click the file and choose "Run as administrator".
        pause
    )
    exit /b
)

:: ---------- 1b. Enable ANSI colors (virtual terminal mode) ----------
:: conhost on Win10 needs VirtualTerminalLevel=1, and it only applies
:: to consoles created AFTER the key exists - so we relaunch ourselves
:: once (no UAC prompt here, we are already elevated). The -vt argument
:: guards against relaunching twice.
reg query "HKCU\Console" /v VirtualTerminalLevel 2>nul | find "0x1" >nul 2>&1
if errorlevel 1 reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
if /i not "%~1"=="-vt" (
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '-vt' -Verb RunAs } catch { exit 1 }" >nul 2>&1
    if not errorlevel 1 exit /b
    echo.
    echo   Could not relaunch for color support - continuing without it.
    pause
)

:: ---------- 2. Build the color palette ----------
set "ESC="
for /f %%a in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%a"
if not defined ESC for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
if not defined ESC (
    set "C_H="
    set "C_OK="
    set "C_WARN="
    set "C_ERR="
    set "C_HEAL="
    set "C_INFO="
    set "C_DIM="
    set "C_RESET="
)
if defined ESC (
    set "C_H=%ESC%[1;96m"
    set "C_OK=%ESC%[92m"
    set "C_WARN=%ESC%[93m"
    set "C_ERR=%ESC%[91m"
    set "C_HEAL=%ESC%[95m"
    set "C_INFO=%ESC%[97m"
    set "C_DIM=%ESC%[90m"
    set "C_RESET=%ESC%[0m"
)

:: ---------- 3. Initialise log file ----------
set "SYS_DRIVE=%SystemDrive:~0,1%"
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "TS=%%a"
set "LOG_DIR=%USERPROFILE%\CleanupLogs"
set "LOG_FILE=%LOG_DIR%\Cleanup.log"
set "HEAL_FLAG=%LOG_DIR%\dism_heal_armed.flg"
if not exist "%LOG_DIR%" md "%LOG_DIR%" >nul 2>&1

:: ---------- 3b. AUTO-HEAL state from the previous session ----------
set "PREV_DISM_FAIL="
if exist "%HEAL_FLAG%" set "PREV_DISM_FAIL=1"

:: ---------- 3c. Detect pending reboot (DISM depends on it) ----------
set "REBOOT_PENDING="
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "REBOOT_PENDING=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1 && set "REBOOT_PENDING=1"

:: ---------- 3d. Start the log (OVERWRITE mode) ----------
> "%LOG_FILE%" echo ===============================================
>>"%LOG_FILE%" echo  System Care session started: %DATE% %TIME%
>>"%LOG_FILE%" echo  Running as: %USERNAME%  -  Administrator: YES
ver | find /v "" >>"%LOG_FILE%"
>>"%LOG_FILE%" echo ===============================================
if defined REBOOT_PENDING >>"%LOG_FILE%" echo  NOTE: Windows reports a PENDING REBOOT - the DISM cleanup task will be skipped.
if defined PREV_DISM_FAIL >>"%LOG_FILE%" echo  NOTE: previous session had a DISM failure - AUTO-HEAL is armed.

:: ---------- 4. Main menu ----------
:MENU
cls
echo.
echo  %C_H%==================================================================
echo  %C_H%            ADVANCED SYSTEM CARE  %C_DIM%-  v2.9%C_H%
echo  %C_H%==================================================================%C_RESET%
echo.
echo    %C_OK%[R]%C_RESET% %C_HEAL%ONE-CLICK REPAIR ALL%C_RESET%  %C_DIM%- full automatic maintenance (30-90 min)%C_RESET%
echo.
echo    %C_DIM%-- CLEANUP --------------------------------------------------%C_RESET%
echo    %C_HEAL%[1]%C_RESET% %C_INFO%QUICK cleanup%C_RESET%      %C_DIM%- temp files, recycle bin, error logs, DNS%C_RESET%
echo    %C_HEAL%[2]%C_RESET% %C_INFO%FULL cleanup%C_RESET%       %C_DIM%- quick + update cache, thumbnails, dumps, shaders%C_RESET%
echo    %C_HEAL%[3]%C_RESET% %C_INFO%DEEP cleanup%C_RESET%       %C_DIM%- full + DISM store, prefetch, delivery opt.%C_RESET%
echo.
echo    %C_DIM%-- REPAIR ---------------------------------------------------%C_RESET%
echo    %C_HEAL%[4]%C_RESET% %C_ERR%Repair system files%C_RESET% %C_DIM%- SFC + DISM scanhealth/restorehealth suite%C_RESET%
echo    %C_HEAL%[5]%C_RESET% %C_ERR%Repair network stack%C_RESET%%C_DIM% - winsock, TCP/IP, IP renewal, DNS%C_RESET%
echo    %C_HEAL%[6]%C_RESET% %C_ERR%Reset Windows Update%C_RESET%%C_DIM%- rebuild update components from scratch%C_RESET%
echo    %C_HEAL%[7]%C_RESET% %C_ERR%Service health check%C_RESET%%C_DIM%- scan ~20 critical services, fix broken ones%C_RESET%
echo    %C_HEAL%[8]%C_RESET% %C_ERR%Registry fixes%C_RESET%     %C_DIM%- EXE, Task Manager, regedit, USB, policies%C_RESET%
echo.
echo    %C_DIM%-- QUICK FIXES / TWEAKS ------------------------------------------%C_RESET%
echo    %C_HEAL%[9]%C_RESET% %C_OK%Fix a common problem%C_RESET%%C_DIM% - printer, sound, bluetooth, store, time, RAM...%C_RESET%
echo    %C_HEAL%[A]%C_RESET% %C_OK%Windows tweaks%C_RESET%      %C_DIM%- Photo Viewer, extensions, GameDVR, lock screen...%C_RESET%
echo    %C_HEAL%[B]%C_RESET% %C_OK%Optimization tools%C_RESET%  %C_DIM%- drives, power plan, startup, explorer, hibernation%C_RESET%
echo.
echo    %C_DIM%-- TOOLS ------------------------------------------------------%C_RESET%
echo    %C_HEAL%[C]%C_RESET% %C_INFO%Disk space overview%C_RESET%
echo    %C_HEAL%[0]%C_RESET% %C_INFO%Exit%C_RESET%
echo.
if defined REBOOT_PENDING (
    echo    %C_WARN%************************************************************%C_RESET%
    echo    %C_WARN%*  PENDING REBOOT detected - the DISM task in DEEP will    *%C_RESET%
    echo    %C_WARN%*  be SKIPPED. Restart the PC, then run DEEP again.        *%C_RESET%
    echo    %C_WARN%************************************************************%C_RESET%
    echo.
)
if defined PREV_DISM_FAIL (
    echo    %C_HEAL%*  Last session had a DISM failure - AUTO-HEAL is armed.   *%C_RESET%
    echo    %C_HEAL%*  If it fails again: internet check, repair, auto-retry.  *%C_RESET%
    echo.
)
echo    %C_DIM%Log: %LOG_FILE%%C_RESET%
echo.
choice /c 123456789ABCR0 /n /m "  Choose an option [R=Repair All, 1-9, A-C, 0=Exit]: "
if errorlevel 14 goto END
if errorlevel 13 goto RUN_REPAIRALL
if errorlevel 12 goto DISKINFO
if errorlevel 11 goto OPTMENU
if errorlevel 10 goto TWKMENU
if errorlevel 9 goto FIXMENU
if errorlevel 8 goto REGMENU
if errorlevel 7 goto SVCMENU
if errorlevel 6 goto RUN_WURESET
if errorlevel 5 goto RUN_NETRESET
if errorlevel 4 goto RUN_SFCSUITE
if errorlevel 3 goto RUN_DEEP
if errorlevel 2 goto RUN_FULL
if errorlevel 1 goto RUN_QUICK


:: ---------- 5. Cleanup run definitions ----------
:RUN_QUICK
set "TASK_TOTAL=6"
call :start_run "QUICK"
call :task "User Temp files - all profiles"    :t_user_temp
call :task "System Temp files"                 :t_sys_temp
call :task "Recycle Bin"                       :t_recycle
call :task "Windows Error Reporting logs"      :t_wer
call :task "Recent Document shortcuts"         :t_recent
call :task "DNS cache flush"                   :t_dns
goto SUMMARY

:RUN_FULL
set "TASK_TOTAL=10"
call :start_run "FULL"
call :task "User Temp files - all profiles"    :t_user_temp
call :task "System Temp files"                 :t_sys_temp
call :task "Recycle Bin"                       :t_recycle
call :task "Windows Error Reporting logs"      :t_wer
call :task "Recent Document shortcuts"         :t_recent
call :task "DNS cache flush"                   :t_dns
call :task "Windows Update cache"              :t_wucache
call :task "Thumbnail and icon cache"          :t_thumbs
call :task "Crash dumps"                       :t_dumps
call :task "DirectX shader cache"              :t_d3ds
goto SUMMARY

:: NOTE: DISM runs FIRST here - it needs Windows Update in its normal
:: state, so it must not run right after the WU service restart cycle.
:RUN_DEEP
set "TASK_TOTAL=13"
call :start_run "DEEP"
call :task "Component store cleanup - DISM"    :t_dism
call :task "User Temp files - all profiles"    :t_user_temp
call :task "System Temp files"                 :t_sys_temp
call :task "Recycle Bin"                       :t_recycle
call :task "Windows Error Reporting logs"      :t_wer
call :task "Recent Document shortcuts"         :t_recent
call :task "DNS cache flush"                   :t_dns
call :task "Windows Update cache"              :t_wucache
call :task "Thumbnail and icon cache"          :t_thumbs
call :task "Crash dumps"                       :t_dumps
call :task "DirectX shader cache"              :t_d3ds
call :task "Prefetch files"                    :t_prefetch
call :task "Delivery Optimization cache"       :t_dopty
goto SUMMARY


:: ---------- 5b. Repair run definitions ----------
:RUN_SFCSUITE
cls
echo.
call :confirm "Run the full system file repair suite? SFC + DISM can take 15-45 min."
if errorlevel 2 goto MENU
set "TASK_TOTAL=2"
call :start_run "SYSTEM FILE REPAIR"
call :task "System File Checker - sfc /scannow"     :t_sfc
call :task "DISM scanhealth + restorehealth"        :t_repair
goto SUMMARY

:RUN_NETRESET
cls
echo.
call :confirm "Reset the network stack? Winsock + TCP/IP need a REBOOT; brief disconnect now."
if errorlevel 2 goto MENU
set "TASK_TOTAL=1"
call :start_run "NETWORK STACK REPAIR"
call :task "Winsock + TCP/IP + IP renewal + DNS"    :t_netreset
goto SUMMARY

:RUN_WURESET
cls
echo.
call :confirm "Reset Windows Update components? Pending downloads will be re-checked later."
if errorlevel 2 goto MENU
set "TASK_TOTAL=1"
call :start_run "WINDOWS UPDATE RESET"
call :task "WU components rebuild"                  :t_wureset
goto SUMMARY

:: ---------- 5b-plus. ONE-CLICK REPAIR ALL ----------
:: One confirmation, then the full maintenance pipeline runs by
:: itself, in the correct order: services -> cleanup -> DISM/SFC
:: -> drive optimize. Deliberately EXCLUDES disruptive operations
:: (network reset, WU full reset, CHKDSK, hibernation) - those
:: stay individual menu options because they need reboots.
:RUN_REPAIRALL
cls
echo.
call :confirm "ONE-CLICK REPAIR ALL: services + cleanup + system file repair + drive optimize. Can take 30-90 min. Start now?"
if errorlevel 2 goto MENU
set "TASK_TOTAL=13"
call :start_run "REPAIR ALL"
echo.
echo    %C_HEAL%*** PHASE 1/4 - SERVICE HEALTH CHECK + AUTO-FIX ***%C_RESET%
call :svc_scanall
echo.
if "%SVC_BAD_N%"=="0" (
    echo    %C_OK%All critical services healthy - nothing to fix.%C_RESET%
) else (
    echo    %C_WARN%%SVC_BAD_N% services need repair - fixing now...%C_RESET%
)
if %SVC_BAD_N% gtr 0 for /l %%i in (1,1,%SVC_BAD_N%) do call :svc_fixone %%SVCBAD_%%i%%
echo.
echo    %C_HEAL%*** PHASE 2/4 - SYSTEM CLEANUP ***%C_RESET%
call :task "User Temp files - all profiles"    :t_user_temp
call :task "System Temp files"                 :t_sys_temp
call :task "Recycle Bin"                       :t_recycle
call :task "Windows Error Reporting logs"      :t_wer
call :task "Recent Document shortcuts"         :t_recent
call :task "DNS cache flush"                   :t_dns
call :task "Windows Update cache"              :t_wucache
call :task "Thumbnail and icon cache"          :t_thumbs
call :task "Crash dumps"                       :t_dumps
call :task "DirectX shader cache"              :t_d3ds
echo.
echo    %C_HEAL%*** PHASE 3/4 - SYSTEM FILE REPAIR ***%C_RESET%
call :task "Component store cleanup - DISM + auto-heal" :t_dism
call :task "System File Checker - sfc /scannow"         :t_sfc
echo.
echo    %C_HEAL%*** PHASE 4/4 - DRIVE OPTIMIZATION ***%C_RESET%
call :task "Drive optimization - TRIM / defrag"         :t_defrag
goto SUMMARY


:: ---------- 5c. SERVICE HEALTH CHECK ----------
:: Scans critical services against their CORRECT start type. Disabled
:: core services are classic malware / "booster" tool damage.
:SVCMENU
cls
echo.
echo  %C_H%------------------------------------------------------------------
echo  %C_H%        SERVICE HEALTH CHECK  %C_DIM%-  critical services scan%C_H%
echo  %C_H%------------------------------------------------------------------%C_RESET%
echo.
echo   %C_DIM%Legend: AUTO expected to always run, MAN runs when needed%C_RESET%
echo.
set /a SVC_BAD_N=0
set /a SVC_CHK=0
call :svc_scanall
>>"%LOG_FILE%" echo ---- service scan done: %SVC_CHK% checked, %SVC_BAD_N% problem(s) ----
echo.
if %SVC_BAD_N%==0 (
    echo   %C_OK%All critical services are healthy.%C_RESET%
    echo.
    pause
    goto MENU
)
echo   %C_ERR%%SVC_BAD_N% service(s) need attention - see lines marked above.%C_RESET%
echo.
call :confirm "Repair ALL marked services now? Restores start type + starts them."
if errorlevel 2 goto MENU
echo.
for /l %%i in (1,1,%SVC_BAD_N%) do call :svc_fixone %%SVCBAD_%%i%%
echo.
echo   %C_OK%Service repair pass finished.%C_RESET%
echo   %C_DIM%A restart is recommended so everything settles.%C_RESET%
set "REBOOT_ADVISED=1"
pause
goto MENU

:: -- the full scan list, shared by the menu and REPAIR ALL --
:svc_scanall
set /a SVC_BAD_N=0
set /a SVC_CHK=0
>>"%LOG_FILE%" echo ---- service health scan started %TIME% ----
call :svc_probe "EventLog"            "Windows Event Log"                 AUTO
call :svc_probe "Schedule"            "Task Scheduler"                    AUTO
call :svc_probe "Winmgmt"             "Windows Management Instrument."    AUTO
call :svc_probe "ProfSvc"             "User Profile Service"              AUTO
call :svc_probe "gpsvc"               "Group Policy Client"               AUTO
call :svc_probe "Dhcp"                "DHCP Client"                       AUTO
call :svc_probe "Dnscache"            "DNS Client"                        AUTO
call :svc_probe "nsi"                 "Network Store Interface"           AUTO
call :svc_probe "NlaSvc"              "Network Location Awareness"        AUTO
call :svc_probe "Netman"              "Network Connections"               AUTO
call :svc_probe "CryptSvc"            "Cryptographic Services"            AUTO
call :svc_probe "MpsSvc"              "Windows Defender Firewall"         AUTO
call :svc_probe "WinDefend"           "Windows Defender Antivirus"        AUTO
call :svc_probe "Audiosrv"            "Windows Audio"                     AUTO
call :svc_probe "AudioEndpointBuilder""Audio Endpoint Builder"            AUTO
call :svc_probe "Themes"              "Themes"                            AUTO
call :svc_probe "Spooler"             "Print Spooler"                     AUTO
call :svc_probe "WSearch"             "Windows Search"                    AUTO
call :svc_probe "ShellHWDetection"    "Shell Hardware Detection"          AUTO
call :svc_probe "wuauserv"            "Windows Update"                    MAN
call :svc_probe "bits"                "Background Intelligent Transfer"   MAN
call :svc_probe "msiserver"           "Windows Installer"                 MAN
call :svc_probe "TrustedInstaller"    "Windows Modules Installer"         MAN
exit /b 0

:: -- probe one service: %1=key  %2=friendly  %3=expected AUTO|MAN --
:svc_probe
set /a SVC_CHK+=1
set "SP_STATE="
set "SP_START="
sc query "%~1" >nul 2>&1
if errorlevel 1 (
    echo    %C_DIM%[ --- ]  %~2  - not installed on this system%C_RESET%
    exit /b 0
)
sc query "%~1" | find /i "RUNNING" >nul 2>&1 && set "SP_STATE=RUN"
sc qc "%~1" 2>nul | find /i "DISABLED" >nul 2>&1 && set "SP_START=DISABLED"
if not defined SP_START if "%~3"=="AUTO" (
    sc qc "%~1" 2>nul | findstr /i /c:"AUTO_START" >nul 2>&1 && set "SP_START=AUTO"
)
if not defined SP_START if "%~3"=="AUTO" (
    sc qc "%~1" 2>nul | findstr /i /c:"DELAYED" >nul 2>&1 && set "SP_START=AUTO"
)
if not defined SP_START if "%~3"=="MAN" (
    sc qc "%~1" 2>nul | findstr /i /c:"DEMAND_START" >nul 2>&1 && set "SP_START=MAN"
)
if not defined SP_START set "SP_START=OTHER"
if "%SP_START%"=="DISABLED" (
    echo    %C_ERR%[ BAD ]  %~2  - DISABLED  %C_DIM%^(%~1^)%C_RESET%
    set /a SVC_BAD_N+=1
    set "SVCBAD_%SVC_BAD_N%=%~1,%~3"
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC BROKEN - %~1 is DISABLED - expected %~3
    exit /b 0
)
if "%~3"=="AUTO" if not "%SP_START%"=="AUTO" (
    echo    %C_ERR%[ BAD ]  %~2  - wrong start type: %SP_START%  %C_DIM%^(%~1^)%C_RESET%
    set /a SVC_BAD_N+=1
    set "SVCBAD_%SVC_BAD_N%=%~1,%~3"
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC BROKEN - %~1 start type %SP_START% - expected AUTO
    exit /b 0
)
if "%~3"=="AUTO" if not "%SP_STATE%"=="RUN" (
    echo    %C_WARN%[ DOWN ] %~2  - not running %C_DIM%- will be started%C_RESET%
    set /a SVC_BAD_N+=1
    set "SVCBAD_%SVC_BAD_N%=%~1,%~3"
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC DOWN - %~1 is not running
    exit /b 0
)
if "%~3"=="MAN" if not "%SP_STATE%"=="RUN" (
    echo    %C_OK%[ OK ]   %~2  %C_DIM%- stopped - normal for this service%C_RESET%
    exit /b 0
)
if "%SP_STATE%"=="RUN" (
    echo    %C_OK%[ OK ]   %~2%C_RESET%
) else (
    echo    %C_WARN%[ DOWN ] %~2 %C_DIM%- will be started%C_RESET%
    set /a SVC_BAD_N+=1
    set "SVCBAD_%SVC_BAD_N%=%~1,%~3"
)
exit /b 0

:: -- fix one recorded service; %1 = "name,expected" --
:svc_fixone
for /f "tokens=1,2 delims=," %%a in ("%~1") do (
    set "FX_NAME=%%a"
    set "FX_EXP=%%b"
)
echo    %C_HEAL%FIX%C_RESET% %FX_NAME% ...
sc config %FX_NAME% start= auto >nul 2>&1
if "%FX_EXP%"=="MAN" sc config %FX_NAME% start= demand >nul 2>&1
net start %FX_NAME% >nul 2>&1
sc query %FX_NAME% | find /i "RUNNING" >nul 2>&1
if errorlevel 1 (
    echo        %C_WARN%could not start now %C_DIM%- often fine; it may be trigger-started. Check after reboot.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC FIX - %FX_NAME% configured but not started
    exit /b 0
)
echo        %C_OK%repaired and running.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] SVC FIX - %FX_NAME% repaired and running
exit /b 0


:: ---------- 5d. REGISTRY FIXES (classic regedit damage) ----------
:REGMENU
cls
echo.
echo  %C_H%------------------------------------------------------------------
echo  %C_H%        REGISTRY FIXES  %C_DIM%-  common policy / association damage%C_H%
echo  %C_H%------------------------------------------------------------------%C_RESET%
echo.
echo    %C_OK%[1]%C_RESET% %C_INFO%Programs will not start%C_RESET%     %C_DIM%- repair broken EXE file association%C_RESET%
echo    %C_OK%[2]%C_RESET% %C_INFO%Task Manager disabled%C_RESET%       %C_DIM%- remove the block %C_DIM%(often malware)%C_RESET%
echo    %C_OK%[3]%C_RESET% %C_INFO%Command Prompt disabled%C_RESET%     %C_DIM%- remove the block%C_RESET%
echo    %C_OK%[4]%C_RESET% %C_INFO%Registry Editor disabled%C_RESET%    %C_DIM%- remove DisableRegistryTools block%C_RESET%
echo    %C_OK%[5]%C_RESET% %C_INFO%Run dialog missing%C_RESET%          %C_DIM%- restore Win+R%C_RESET%
echo    %C_OK%[6]%C_RESET% %C_INFO%Folder options missing%C_RESET%      %C_DIM%- restore hidden-files options%C_RESET%
echo    %C_OK%[7]%C_RESET% %C_INFO%USB storage blocked%C_RESET%         %C_DIM%- re-enable USBSTOR drives%C_RESET%
echo    %C_OK%[8]%C_RESET% %C_INFO%Control Panel blocked%C_RESET%       %C_DIM%- remove NoControlPanel lock%C_RESET%
echo    %C_OK%[0]%C_RESET% %C_INFO%Back to main menu%C_RESET%
echo.
echo   %C_DIM%Fixes remove policy values only - they never delete your data.%C_RESET%
echo   %C_DIM%If a policy comes back after a reboot, scan for malware.%C_RESET%
echo.
choice /c 123456780 /n /m "  Choose a fix [1-8, 0=Back]: "
if errorlevel 9 goto MENU
if errorlevel 8 goto REG_CPANEL
if errorlevel 7 goto REG_USB
if errorlevel 6 goto REG_FOLDEROPT
if errorlevel 5 goto REG_RUN
if errorlevel 4 goto REG_REGEDIT
if errorlevel 3 goto REG_CMD
if errorlevel 2 goto REG_TASKMGR
if errorlevel 1 goto REG_EXE

:REG_EXE
cls
echo.
call :confirm "Repair the EXE file association now? Fixes 'program won't open' errors."
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - EXE ASSOCIATION"
call :task "Repair EXE association"                :r_exe
goto SUMMARY

:REG_TASKMGR
cls
echo.
call :confirm "Remove the Task Manager block?"
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - TASK MANAGER"
call :task "Unblock Task Manager"                  :r_taskmgr
goto SUMMARY

:REG_CMD
cls
echo.
call :confirm "Remove the Command Prompt block?"
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - COMMAND PROMPT"
call :task "Unblock Command Prompt"                :r_cmd
goto SUMMARY

:REG_REGEDIT
cls
echo.
call :confirm "Remove the Registry Editor block?"
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - REGISTRY EDITOR"
call :task "Unblock Registry Editor"               :r_regedit
goto SUMMARY

:REG_RUN
cls
echo.
call :confirm "Restore the Win+R Run dialog?"
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - RUN DIALOG"
call :task "Unblock Run dialog"                    :r_run
goto SUMMARY

:REG_FOLDEROPT
cls
echo.
call :confirm "Restore missing Folder Options / hidden files setting?"
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - FOLDER OPTIONS"
call :task "Unblock Folder Options"                :r_folderopt
goto SUMMARY

:REG_USB
cls
echo.
call :confirm "Re-enable USB storage drives?"
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - USB STORAGE"
call :task "Re-enable USBSTOR"                     :r_usb
goto SUMMARY

:REG_CPANEL
cls
echo.
call :confirm "Remove the Control Panel / Settings block?"
if errorlevel 2 goto REGMENU
set "TASK_TOTAL=1"
call :start_run "REGISTRY - CONTROL PANEL"
call :task "Unblock Control Panel"                 :r_cpanel
goto SUMMARY


:: ---------- 5e. TWEAKS (popular, reversible, MajorGeeks-style) ----------
:TWKMENU
cls
echo.
echo  %C_H%------------------------------------------------------------------
echo  %C_H%        WINDOWS TWEAKS  %C_DIM%-  every tweak has Apply / Restore%C_H%
echo  %C_H%------------------------------------------------------------------%C_RESET%
echo.
echo    %C_OK%[1]%C_RESET% %C_INFO%Restore Windows Photo Viewer%C_RESET%  %C_DIM%- classic viewer back as default%C_RESET%
echo    %C_OK%[2]%C_RESET% %C_INFO%Show file extensions%C_RESET%         %C_DIM%- .txt .jpg visible in Explorer%C_RESET%
echo    %C_OK%[3]%C_RESET% %C_INFO%Show hidden files%C_RESET%            %C_DIM%- reveal hidden items in Explorer%C_RESET%
echo    %C_OK%[4]%C_RESET% %C_INFO%Add "Take Ownership" menu%C_RESET%    %C_DIM%- right-click file to own it%C_RESET%
echo    %C_OK%[5]%C_RESET% %C_INFO%Remove shortcut arrows%C_RESET%       %C_DIM%- cleaner desktop icons%C_RESET%
echo    %C_OK%[6]%C_RESET% %C_INFO%Disable Bing in Search%C_RESET%       %C_DIM%- no web suggestions in Start search%C_RESET%
echo    %C_OK%[7]%C_RESET% %C_INFO%Speed up menus%C_RESET%               %C_DIM%- menu show delay 400ms to 0ms%C_RESET%
echo    %C_OK%[8]%C_RESET% %C_INFO%Disable GameDVR recording%C_RESET%    %C_DIM%- free gaming performance%C_RESET%
echo    %C_OK%[9]%C_RESET% %C_INFO%Hide the lock screen%C_RESET%         %C_DIM%- boot straight to sign-in%C_RESET%
echo    %C_OK%[0]%C_RESET% %C_INFO%Back to main menu%C_RESET%
echo.
choice /c 1234567890 /n /m "  Choose a tweak [1-9, 0=Back]: "
if errorlevel 10 goto MENU
if errorlevel 9 goto TWK_9
if errorlevel 8 goto TWK_8
if errorlevel 7 goto TWK_7
if errorlevel 6 goto TWK_6
if errorlevel 5 goto TWK_5
if errorlevel 4 goto TWK_4
if errorlevel 3 goto TWK_3
if errorlevel 2 goto TWK_2
if errorlevel 1 goto TWK_1

:: -- shared: ask Apply or Restore, then run the tweak sub --
:tw_ask
echo.
choice /c ar0 /n /m "   [A]=Apply tweak   [R]=Restore default   [0]=Cancel: "
if errorlevel 3 goto :eof
if errorlevel 2 (
    call %~1 R
) else (
    call %~1 A
)
echo.
echo   %C_DIM%Press any key to return...%C_RESET%
pause >nul
goto :eof

:TWK_1
call :tw_ask :tw_photoviewer
goto TWKMENU
:TWK_2
call :tw_ask :tw_ext
goto TWKMENU
:TWK_3
call :tw_ask :tw_hidden
goto TWKMENU
:TWK_4
call :tw_ask :tw_own
goto TWKMENU
:TWK_5
call :tw_ask :tw_arrow
goto TWKMENU
:TWK_6
call :tw_ask :tw_bing
goto TWKMENU
:TWK_7
call :tw_ask :tw_menu
goto TWKMENU
:TWK_8
call :tw_ask :tw_gamedvr
goto TWKMENU
:TWK_9
call :tw_ask :tw_lock
goto TWKMENU

:: -- 1: Windows Photo Viewer (the most popular tweak worldwide) --
:tw_photoviewer
if /i "%~1"=="A" (
    echo.
    echo         %C_DIM%Associating images with classic Photo Viewer...%C_RESET%
    for %%e in (.jpg .jpeg .jpe .jfif .gif .png .bmp .dib .tif .tiff .ico) do reg add "HKCU\Software\Classes\%%e" /ve /d "PhotoViewer.FileAssoc.Tiff" /f >nul 2>&1
    echo         %C_OK%Photo Viewer restored - open an image, pick it once, done.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - Windows Photo Viewer restored
    exit /b 0
)
echo.
echo         %C_DIM%Returning image associations to the Photos app...%C_RESET%
for %%e in (.jpg .jpeg .jpe .jfif .gif .png .bmp .dib .tif .tiff .ico) do reg delete "HKCU\Software\Classes\%%e" /f >nul 2>&1
echo         %C_OK%Reverted - Photos app is default again.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - Photo Viewer override removed
exit /b 0

:: -- 2: Show file extensions --
:tw_ext
if /i "%~1"=="A" (
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f >nul 2>&1
    echo.
    echo         %C_OK%File extensions are now shown in Explorer.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - show file extensions
    exit /b 0
)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f >nul 2>&1
echo.
echo         %C_OK%File extensions hidden again.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - hide file extensions
exit /b 0

:: -- 3: Show hidden files --
:tw_hidden
if /i "%~1"=="A" (
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f >nul 2>&1
    echo.
    echo         %C_OK%Hidden files and folders are now visible.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - show hidden files
    exit /b 0
)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 2 /f >nul 2>&1
echo.
echo         %C_OK%Hidden files are hidden again.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - hide hidden files
exit /b 0

:: -- 4: Take Ownership right-click menu (files + folders) --
:tw_own
if /i "%~1"=="A" (
    echo.
    echo         %C_DIM%Adding Take Ownership to files and folders...%C_RESET%
    reg add "HKLM\SOFTWARE\Classes\*\shell\TakeOwnership" /ve /d "Take Ownership" /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Classes\*\shell\TakeOwnership" /v "HasLUAShield" /t REG_SZ /d "" /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Classes\*\shell\TakeOwnership\command" /ve /d "cmd.exe /c takeown /f \"%%1\" && icacls \"%%1\" /grant Administrators:F" /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Classes\Directory\shell\TakeOwnership" /ve /d "Take Ownership" /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Classes\Directory\shell\TakeOwnership\command" /ve /d "cmd.exe /c takeown /f \"%%1\" /r /d y && icacls \"%%1\" /grant Administrators:F /t" /f >nul 2>&1
    echo         %C_OK%Right-click any file or folder - Take Ownership is there.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - Take Ownership context menu
    exit /b 0
)
echo.
echo         %C_DIM%Removing Take Ownership menu entries...%C_RESET%
reg delete "HKLM\SOFTWARE\Classes\*\shell\TakeOwnership" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Classes\Directory\shell\TakeOwnership" /f >nul 2>&1
echo         %C_OK%Menu entries removed.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - Take Ownership menu removed
exit /b 0

:: -- 5: Remove desktop shortcut arrows (needs Explorer restart) --
:tw_arrow
if /i "%~1"=="A" (
    echo.
    echo         %C_DIM%Hiding shortcut arrows - restarting Explorer...%C_RESET%
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /t REG_SZ /d "%SystemRoot%\System32\shell32.dll,-50" /f >nul 2>&1
    call :t_explorer
    echo         %C_OK%Shortcut arrows hidden.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - shortcut arrows hidden
    exit /b 0
)
echo.
echo         %C_DIM%Restoring shortcut arrows - restarting Explorer...%C_RESET%
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v 29 /f >nul 2>&1
call :t_explorer
echo         %C_OK%Shortcut arrows restored.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - shortcut arrows restored
exit /b 0

:: -- 6: Disable Bing suggestions in Start-menu search --
:tw_bing
if /i "%~1"=="A" (
    echo.
    echo         %C_DIM%Disabling Bing suggestions - sign out/in or reboot after.%C_RESET%
    reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f >nul 2>&1
    echo         %C_OK%Bing disabled - search shows local results only.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - Bing suggestions disabled
    exit /b 0
)
echo.
echo         %C_DIM%Re-enabling Bing suggestions...%C_RESET%
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /f >nul 2>&1
echo         %C_OK%Bing suggestions re-enabled - reboot to apply fully.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - Bing suggestions re-enabled
exit /b 0

:: -- 7: Menu speed (default MenuShowDelay is 400 ms) --
:tw_menu
if /i "%~1"=="A" (
    reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f >nul 2>&1
    echo.
    echo         %C_OK%Menus open instantly now - applies after next sign-in.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - MenuShowDelay 0
    exit /b 0
)
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 400 /f >nul 2>&1
echo.
echo         %C_OK%Menu delay back to Windows default - 400 ms.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - MenuShowDelay 400
exit /b 0

:: -- 8: GameDVR background recording off (gaming performance) --
:tw_gamedvr
if /i "%~1"=="A" (
    echo.
    echo         %C_DIM%Disabling Game Bar background recording...%C_RESET%
    reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1
    echo         %C_OK%GameDVR disabled - games get those resources back.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - GameDVR disabled
    exit /b 0
)
echo.
echo         %C_DIM%Re-enabling GameDVR...%C_RESET%
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /f >nul 2>&1
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 1 /f >nul 2>&1
echo         %C_OK%GameDVR enabled again.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - GameDVR enabled
exit /b 0

:: -- 9: Hide the lock screen (boot straight to sign-in) --
:tw_lock
if /i "%~1"=="A" (
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f >nul 2>&1
    echo.
    echo         %C_OK%Lock screen disabled - applies from the next sign-out/boot.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK apply - lock screen hidden
    exit /b 0
)
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /f >nul 2>&1
echo.
echo         %C_OK%Lock screen enabled again.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] TWEAK revert - lock screen restored
exit /b 0


:: ---------- 5f. QUICK FIXES submenu (common Win10 problems) ----------
:FIXMENU
cls
echo.
echo  %C_H%------------------------------------------------------------------
echo  %C_H%        QUICK FIclick fixes for common problems%C_H%
echo  %C_H%------------------------------------------------------------------%C_RESET%
echo.
echo    %C_OK%[1]%C_RESET% %C_INFO%Printer not printing%C_RESET%    %C_DIM%- clear stuck queue + restart spooler%C_RESET%
echo    %C_OK%[2]%C_RESET% %C_INFO%No sound / audio dead%C_RESET%   %C_DIM%- restart Windows audio services%C_RESET%
echo    %C_OK%[3]%C_RESET% %C_INFO%Bluetooth broken%C_RESET%        %C_DIM%- restart Bluetooth stack %C_DIM%(skips if none)%C_RESET%
echo    %C_OK%[4]%C_RESET% %C_INFO%Store apps broken%C_RESET%       %C_DIM%- reset Microsoft Store cache%C_RESET%
echo    %C_OK%[5]%C_RESET% %C_INFO%Clock shows wrong time%C_RESET%  %C_DIM%- force time sync with Microsoft NTP%C_RESET%
echo    %C_OK%[6]%C_RESET% %C_INFO%Search finds nothing%C_RESET%    %C_DIM%- restart Windows Search indexer%C_RESET%
echo    %C_OK%[7]%C_RESET% %C_INFO%Disk errors / freezes%C_RESET%   %C_DIM%- schedule CHKDSK repair at next restart%C_RESET%
echo    %C_OK%[8]%C_RESET% %C_INFO%System Restore wizard%C_RESET%   %C_DIM%- roll back recent system changes%C_RESET%
echo    %C_OK%[9]%C_RESET% %C_INFO%RAM memory test%C_RESET%         %C_DIM%- Windows Memory Diagnostic %C_WARN%(reboots PC)%C_RESET%
echo    %C_OK%[0]%C_RESET% %C_INFO%Back to main menu%C_RESET%
echo.
choice /c 1234567890 /n /m "  Choose a fix [1-9, 0=Back]: "
if errorlevel 10 goto MENU
if errorlevel 9 goto FIX_MEM
if errorlevel 8 goto FIX_SRESTORE
if errorlevel 7 goto FIX_CHKDSK
if errorlevel 6 goto FIX_SEARCH
if errorlevel 5 goto FIX_TIME
if errorlevel 4 goto FIX_STORE
if errorlevel 3 goto FIX_BT
if errorlevel 2 goto FIX_AUDIO
if errorlevel 1 goto FIX_PRINTER

:FIX_PRINTER
cls
echo.
call :confirm "Clear ALL stuck print jobs and restart the Print Spooler?"
if errorlevel 2 goto FIXMENU
set "TASK_TOTAL=1"
call :start_run "PRINTER FIX"
call :task "Print queue clear + spooler restart"   :t_spooler
goto SUMMARY

:FIX_AUDIO
set "TASK_TOTAL=1"
call :start_run "AUDIO FIX"
call :task "Restart Windows audio services"        :t_audio
goto SUMMARY

:FIX_BT
set "TASK_TOTAL=1"
call :start_run "BLUETOOTH FIX"
call :task "Restart Bluetooth stack"               :t_bt
goto SUMMARY

:FIX_STORE
set "TASK_TOTAL=1"
call :start_run "STORE FIX"
call :task "Reset Microsoft Store cache - WSReset" :t_storereset
goto SUMMARY

:FIX_TIME
set "TASK_TOTAL=1"
call :start_run "TIME SYNC FIX"
call :task "Force time sync - internet time"       :t_time
goto SUMMARY

:FIX_SEARCH
set "TASK_TOTAL=1"
call :start_run "SEARCH FIX"
call :task "Restart Windows Search indexer"        :t_wsearch
goto SUMMARY

:FIX_CHKDSK
cls
echo.
call :confirm "Schedule CHKDSK /f /r on %SystemDrive%? Runs at NEXT RESTART - can take 1-2+ h on HDD."
if errorlevel 2 goto FIXMENU
set "TASK_TOTAL=1"
call :start_run "DISK CHECK"
call :task "Schedule CHKDSK repair at restart"     :t_chkdsk
goto SUMMARY

:FIX_SRESTORE
echo.
echo   %C_INFO%Opening the System Restore wizard...%C_RESET%
echo   %C_DIM%Pick a restore point - your files stay untouched, only system%C_RESET%
echo   %C_DIM%settings, drivers and recent programs roll back.%C_RESET%
start "" rstrui.exe
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - System Restore wizard launched
echo.
echo   %C_DIM%Press any key to return to the menu...%C_RESET%
pause >nul
goto FIXMENU

:FIX_MEM
cls
echo.
call :confirm "Windows Memory Diagnostic will RESTART THE PC NOW and test your RAM."
if errorlevel 2 goto FIXMENU
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - Memory Diagnostic launched - PC restarting
mdsched.exe
goto END


:: ---------- 5g. Optimization submenu ----------
:OPTMENU
cls
echo.
echo  %C_H%------------------------------------------------------------------
echo  %C_H%                  OPTIMIZATION TOOLS%C_RESET%
echo  %C_H%------------------------------------------------------------------%C_RESET%
echo.
echo    %C_OK%[1]%C_RESET% %C_INFO%Optimize system drive%C_RESET%   %C_DIM%- SSD: TRIM retrim / HDD: defrag%C_RESET%
echo    %C_OK%[2]%C_RESET% %C_INFO%Power plan - High performance%C_RESET%
echo    %C_OK%[3]%C_RESET% %C_INFO%Power plan - Balanced %C_DIM%(Windows default)%C_RESET%
echo    %C_OK%[4]%C_RESET% %C_INFO%Remove startup apps delay%C_RESET%  %C_DIM%- apps launch sooner after logon%C_RESET%
echo    %C_OK%[5]%C_RESET% %C_INFO%Restart Explorer shell%C_RESET%    %C_DIM%- frees shell memory leaks; screen flashes%C_RESET%
echo    %C_OK%[6]%C_RESET% %C_INFO%Disable hibernation%C_RESET%       %C_DIM%- frees several GB  %C_WARN%(also disables Fast Startup)%C_RESET%
echo    %C_OK%[7]%C_RESET% %C_INFO%Back to main menu%C_RESET%
echo.
choice /c 1234567 /n /m "  Choose an option [1-7]: "
if errorlevel 7 goto MENU
if errorlevel 6 goto OPT_HIBOFF
if errorlevel 5 goto OPT_EXPLORER
if errorlevel 4 goto OPT_STARTUP
if errorlevel 3 goto OPT_PWRBAL
if errorlevel 2 goto OPT_PWRHIGH
if errorlevel 1 goto OPT_DRIVES

:OPT_DRIVES
cls
echo.
call :confirm "Optimize %SystemDrive% now? SSD: a few minutes. HDD: can take 10-60 min."
if errorlevel 2 goto OPTMENU
set "TASK_TOTAL=1"
call :start_run "DRIVE OPTIMIZE"
call :task "Drive optimization - TRIM / defrag"     :t_defrag
goto SUMMARY

:OPT_PWRHIGH
set "TASK_TOTAL=1"
call :start_run "POWER PLAN"
call :task "Set power plan - High performance"      :t_powerhigh
goto SUMMARY

:OPT_PWRBAL
set "TASK_TOTAL=1"
call :start_run "POWER PLAN"
call :task "Set power plan - Balanced"              :t_powerbal
goto SUMMARY

:OPT_STARTUP
set "TASK_TOTAL=1"
call :start_run "STARTUP TUNE"
call :task "Remove startup apps delay"              :t_startdelay
goto SUMMARY

:OPT_EXPLORER
set "TASK_TOTAL=1"
call :start_run "EXPLORER RESTART"
call :task "Restart Explorer shell"                 :t_explorer
goto SUMMARY

:OPT_HIBOFF
cls
echo.
call :confirm "Disable hibernation? Frees GB on %SystemDrive% but also disables Fast Startup."
if errorlevel 2 goto OPTMENU
set "TASK_TOTAL=1"
call :start_run "HIBERNATION"
call :task "Disable hibernation"                    :t_hiboff
goto SUMMARY


:: ---------- 6. Summary screen ----------
:SUMMARY
for /f %%a in ('powershell -NoProfile -Command "[math]::Round((Get-PSDrive -Name %SYS_DRIVE%).Free/1MB)"') do set "FREE_AFTER=%%a"
for /f %%a in ('powershell -NoProfile -Command "[math]::Max(0, %FREE_AFTER% - %FREE_BEFORE%)"') do set "FREED_MB=%%a"
for /f %%a in ('powershell -NoProfile -Command "[math]::Round((Get-PSDrive -Name %SYS_DRIVE%).Free/1GB, 2)"') do set "FREE_NOW_GB=%%a"
>>"%LOG_FILE%" echo ---- %RUN_LABEL% run finished %DATE% %TIME% - approx %FREED_MB% MB freed - %FAIL_NUM% warnings ----
cls
echo.
echo  %C_H%==============================================================
echo  %C_H%              TASK COMPLETE  %C_DIM%-  %RUN_LABEL% RUN%C_H%
echo  %C_H%==============================================================%C_RESET%
echo.
echo    %C_INFO%Tasks completed  :%C_RESET%  %TASK_NUM% of %TASK_TOTAL%
if %FAIL_NUM% gtr 0 (
    echo    %C_INFO%Warnings         :%C_RESET%  %C_ERR%%FAIL_NUM% tasks reported errors - see log%C_RESET%
) else (
    echo    %C_INFO%Warnings         :%C_RESET%  %C_OK%none - all clean!%C_RESET%
)
echo    %C_INFO%Space freed      :%C_RESET%  %C_OK%approx. %FREED_MB% MB%C_RESET%
echo    %C_INFO%Free space now   :%C_RESET%  approx. %FREE_NOW_GB% GB on %SystemDrive%
echo    %C_INFO%Log file         :%C_RESET%  %C_DIM%%LOG_FILE%%C_RESET%
echo.
if defined REBOOT_PENDING (
    echo    %C_WARN%****************************************************************%C_RESET%
    echo    %C_WARN%*  PENDING REBOOT: restart Windows, then run DEEP again.       *%C_RESET%
    echo    %C_WARN%*  The DISM component store task needs a clean boot to work.   *%C_RESET%
    echo    %C_WARN%****************************************************************%C_RESET%
    echo.
)
if defined DISM_FAILED_RUN (
    echo    %C_HEAL%*  DISM failed this run - failure remembered. The next DEEP  *%C_RESET%
    echo    %C_HEAL%*  run will auto-heal: internet check, repair, retry.        *%C_RESET%
    echo.
)
if defined REBOOT_ADVISED (
    echo    %C_WARN%*  A RESTART is recommended so repair changes fully apply.   *%C_RESET%
    echo.
)
echo  %C_DIM%--------------------------------------------------------------
echo   some files locked by running apps are skipped - normal
echo   freed space is approximate; other apps also write to disk
echo  -------------------------------------------------------------%C_RESET%
echo.
pause
goto MENU

:DISKINFO
cls
echo.
echo  %C_H%--------------------------------------------------------------
echo  %C_H%                   DISK SPACE OVERVIEW%C_RESET%
echo  %C_H%--------------------------------------------------------------%C_RESET%
echo.
powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{n='Used_GB';e={[math]::Round($_.Used/1GB,1)}}, @{n='Free_GB';e={[math]::Round($_.Free/1GB,1)}} | Format-Table -AutoSize"
echo.
pause
goto MENU

:END
cls
echo.
echo    %C_OK%Session closed.%C_RESET% Log saved as:
echo    %C_DIM%%LOG_FILE%%C_RESET%
echo.
timeout /t 3 >nul 2>&1
exit /b 0


:: ================================================================
::  HELPER SUBROUTINES
:: ================================================================

:: -- Confirmation prompt: %1 = question; errorlevel 2 = answered No --
:confirm
echo   %C_WARN%?%C_RESET% %~1
choice /c yn /n /m "   Continue [Y/N]: "
if errorlevel 2 (
    echo   %C_DIM%Cancelled.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - user cancelled: %~1
)
exit /b %errorlevel%

:: -- Start a run: baseline free space, header, log entry --
:start_run
set "RUN_LABEL=%~1"
set /a TASK_NUM=0
set /a FAIL_NUM=0
set "DISM_FAILED_RUN="
set "REBOOT_ADVISED="
for /f %%a in ('powershell -NoProfile -Command "[math]::Round((Get-PSDrive -Name %SYS_DRIVE%).Free/1MB)"') do set "FREE_BEFORE=%%a"
cls
echo.
echo  %C_H%==============================================================
echo  %C_H%   %RUN_LABEL% RUN IN PROGRESS  %C_DIM%-  please wait...%C_H%
echo  %C_H%==============================================================%C_RESET%
if defined REBOOT_PENDING (
    echo    %C_WARN%*** PENDING REBOOT: the DISM task will be skipped.         ***%C_RESET%
    echo    %C_WARN%*** Restart the PC, then run DEEP again to include it.     ***%C_RESET%
)
>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo ---- %RUN_LABEL% run started %DATE% %TIME% ----
goto :eof

:: -- Task wrapper: prints progress, runs subroutine, logs result --
:: Subroutines return 0 for "done/skipped by design" (locked files
:: are expected and ignored). Non-zero exit = REAL problem - FAIL.
:: A subroutine may set TASK_SKIPPED=1 for a deliberate skip.
:task
set /a TASK_NUM+=1
set "TASK_SKIPPED="
echo.
echo   %C_H%[%TASK_NUM%/%TASK_TOTAL%]%C_RESET% %~1 ...
call %~2
set "TASK_RC=%errorlevel%"
if "%TASK_RC%"=="0" if defined TASK_SKIPPED (
    echo        %C_WARN%[ SKIP ]%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SKIP - %~1
    goto :eof
)
if "%TASK_RC%"=="0" (
    echo        %C_OK%[ OK ]%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] OK - %~1
    goto :eof
)
set /a FAIL_NUM+=1
echo        %C_ERR%[ FAIL ]%C_RESET%  %C_DIM%see log for details%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] WARN - %~1 - exit code %TASK_RC%
goto :eof

:: -- Clean Temp for EVERY user profile (elevated context aware) --
:t_user_temp
del /q /f /s "%TEMP%\*" >nul 2>&1
for /d %%x in ("%TEMP%\*") do rd /s /q "%%x" >nul 2>&1
for /d %%U in ("%SystemDrive%\Users\*") do (
    if /i not "%%~nxU"=="Public" if /i not "%%~nxU"=="Default" if /i not "%%~nxU"=="Default User" if /i not "%%~nxU"=="All Users" (
        del /q /f /s "%%U\AppData\Local\Temp\*" >nul 2>&1
        for /d %%x in ("%%U\AppData\Local\Temp\*") do rd /s /q "%%x" >nul 2>&1
    )
)
exit /b 0

:t_sys_temp
del /q /f /s "%SystemRoot%\Temp\*" >nul 2>&1
for /d %%x in ("%SystemRoot%\Temp\*") do rd /s /q "%%x" >nul 2>&1
exit /b 0

:t_recycle
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
rd /s /q "%SystemDrive%\$Recycle.bin" >nul 2>&1
exit /b 0

:t_wer
del /q /f /s "%ProgramData%\Microsoft\Windows\WER\ReportArchive\*" >nul 2>&1
for /d %%x in ("%ProgramData%\Microsoft\Windows\WER\ReportArchive\*") do rd /s /q "%%x" >nul 2>&1
del /q /f /s "%ProgramData%\Microsoft\Windows\WER\ReportQueue\*" >nul 2>&1
for /d %%x in ("%ProgramData%\Microsoft\Windows\WER\ReportQueue\*") do rd /s /q "%%x" >nul 2>&1
exit /b 0

:t_recent
:: Privacy note: this clears jump-list history for the current user.
del /q /f /s "%APPDATA%\Microsoft\Windows\Recent\*" >nul 2>&1
exit /b 0

:t_dns
ipconfig /flushdns >nul 2>&1
exit /b 0

:t_wucache
:: Only restart services if they were running BEFORE we stopped them
set "WU_RUNNING="
set "BITS_RUNNING="
sc query wuauserv | find /i "RUNNING" >nul 2>&1 && set "WU_RUNNING=1"
sc query bits    | find /i "RUNNING" >nul 2>&1 && set "BITS_RUNNING=1"
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
del /q /f /s "%SystemRoot%\SoftwareDistribution\Download\*" >nul 2>&1
for /d %%x in ("%SystemRoot%\SoftwareDistribution\Download\*") do rd /s /q "%%x" >nul 2>&1
if defined BITS_RUNNING net start bits >nul 2>&1
if defined WU_RUNNING net start wuauserv >nul 2>&1
exit /b 0

:t_thumbs
:: Locked while Explorer runs - we clear whatever is not in use
del /q /f /a "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /q /f /a "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
exit /b 0

:t_dumps
del /q /f /s "%LOCALAPPDATA%\CrashDumps\*" >nul 2>&1
for /d %%x in ("%LOCALAPPDATA%\CrashDumps\*") do rd /s /q "%%x" >nul 2>&1
del /q /f /s "%SystemRoot%\Minidump\*" >nul 2>&1
del /q /f "%SystemRoot%\MEMORY.DMP" >nul 2>&1
exit /b 0

:t_d3ds
:: Safe to delete - Windows rebuilds shader caches automatically
del /q /f /s "%LOCALAPPDATA%\D3DSCache\*" >nul 2>&1
for /d %%x in ("%LOCALAPPDATA%\D3DSCache\*") do rd /s /q "%%x" >nul 2>&1
exit /b 0

:t_prefetch
:: NOTE: Prefetch helps apps start faster. Only .pf traces are removed;
:: Windows rebuilds them, but first launches may be slightly slower.
del /q /f /s "%SystemRoot%\Prefetch\*.pf" >nul 2>&1
exit /b 0

:t_dopty
:: Requires Windows 10 1803+ - silently skipped on older builds
powershell -NoProfile -Command "Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue" >nul 2>&1
exit /b 0

:: -- Internet connectivity check (restorehealth downloads files) --
:: Two ping tests: first via microsoft.com (tests DNS + connectivity),
:: then via 8.8.8.8 (raw connectivity, in case only DNS is broken).
:: "TTL=" appears in output only when a real reply came back.
:check_internet
set "INET_OK="
ping -n 2 -w 3000 www.microsoft.com 2>nul | find "TTL=" >nul 2>&1 && set "INET_OK=1"
if not defined INET_OK (
    ping -n 2 -w 3000 8.8.8.8 2>nul | find "TTL=" >nul 2>&1 && set "INET_OK=1"
)
if defined INET_OK exit /b 0
exit /b 1

:: -- System File Checker --
:t_sfc
echo.
echo         %C_DIM%Scanning protected system files - can take 5-15 min:%C_RESET%
sfc /scannow
set "SFC_RC=%errorlevel%"
>>"%LOG_FILE%" echo [%TIME:~0,8%] sfc /scannow finished - exit code %SFC_RC%
if not "%SFC_RC%"=="0" (
    echo         %C_ERR%SFC reported a problem - details:%C_RESET%
    echo         %C_DIM%%SystemRoot%\Logs\CBS\CBS.log  %C_DIM%^(look for entries tagged [SR]^)%C_RESET%
) else (
    echo         %C_OK%SFC completed - no integrity violations, or repairs applied.%C_RESET%
)
exit /b %SFC_RC%

:: -- Network stack repair --
:t_netreset
echo.
echo         %C_DIM%Resetting Winsock catalog...%C_RESET%
netsh winsock reset >nul 2>&1
echo         %C_DIM%Resetting TCP/IP stack...%C_RESET%
netsh int ip reset >nul 2>&1
echo         %C_DIM%Renewing IP address...%C_RESET%
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
ipconfig /flushdns >nul 2>&1
set "REBOOT_ADVISED=1"
echo.
echo         %C_WARN%Network stack reset - a RESTART is required to fully apply.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] network stack reset done - reboot advised
exit /b 0

:: -- Full Windows Update component reset --
:t_wureset
set "WU_WUA="
set "WU_BITS="
set "WU_CRYPT="
set "WU_MSI="
sc query wuauserv | find /i "RUNNING" >nul 2>&1 && set "WU_WUA=1"
sc query bits     | find /i "RUNNING" >nul 2>&1 && set "WU_BITS=1"
sc query cryptsvc | find /i "RUNNING" >nul 2>&1 && set "WU_CRYPT=1"
sc query msiserver| find /i "RUNNING" >nul 2>&1 && set "WU_MSI=1"
echo         %C_DIM%Stopping update services...%C_RESET%
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop cryptsvc /y >nul 2>&1
net stop msiserver /y >nul 2>&1
timeout /t 2 /nobreak >nul 2>&1
echo         %C_DIM%Rebuilding SoftwareDistribution...%C_RESET%
rd /s /q "%SystemRoot%\SoftwareDistribution.old" >nul 2>&1
rd /s /q "%SystemRoot%\SoftwareDistribution" >nul 2>&1
if exist "%SystemRoot%\SoftwareDistribution" ren "%SystemRoot%\SoftwareDistribution" "SoftwareDistribution.old" >nul 2>&1
echo         %C_DIM%Rebuilding catroot2 security database...%C_RESET%
rd /s /q "%SystemRoot%\System32\catroot2.old" >nul 2>&1
rd /s /q "%SystemRoot%\System32\catroot2" >nul 2>&1
if exist "%SystemRoot%\System32\catroot2" ren "%SystemRoot%\System32\catroot2" "catroot2.old" >nul 2>&1
echo         %C_DIM%Restarting services that were running...%C_RESET%
if defined WU_MSI net start msiserver >nul 2>&1
if defined WU_CRYPT net start cryptsvc >nul 2>&1
if defined WU_BITS net start bits >nul 2>&1
if defined WU_WUA net start wuauserv >nul 2>&1
set "REBOOT_ADVISED=1"
echo.
echo         %C_OK%Windows Update components rebuilt.%C_RESET%
echo         %C_DIM%The next update check re-scans and re-downloads what is needed.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] WU components reset done - reboot advised
exit /b 0

:: -- Drive optimization: TRIM on SSD, defrag on HDD --
:t_defrag
echo.
echo         %C_DIM%%SystemDrive% - defrag /O picks TRIM or defrag automatically:%C_RESET%
defrag.exe %SystemDrive% /O /U
set "DEFRAG_RC=%errorlevel%"
>>"%LOG_FILE%" echo [%TIME:~0,8%] drive optimization finished - exit code %DEFRAG_RC%
exit /b %DEFRAG_RC%

:: -- Power plans (standard Windows GUIDs, present on all editions) --
:t_powerhigh
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
echo         %C_DIM%Active scheme:%C_RESET%
powercfg /getactivescheme
exit /b %errorlevel%

:t_powerbal
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
echo         %C_DIM%Active scheme:%C_RESET%
powercfg /getactivescheme
exit /b %errorlevel%

:: -- Startup apps delay removal (revert: delete the value) --
:t_startdelay
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /t REG_DWORD /d 0 /f >nul 2>&1
echo         %C_OK%Startup delay removed - applies after next sign-in.%C_RESET%
echo         %C_DIM%Revert: delete StartupDelayInMSec under ...\Explorer\Serialize%C_RESET%
exit /b %errorlevel%

:: -- Restart Explorer shell --
:t_explorer
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
start explorer.exe
echo         %C_OK%Explorer restarted.%C_RESET%
exit /b 0

:: -- Hibernation off (also disables Fast Startup) --
:t_hiboff
powercfg /h off
echo         %C_OK%Hibernation disabled - hiberfil.sys freed.%C_RESET%
echo         %C_WARN%Note: Fast Startup is also disabled. Revert with: powercfg /h on%C_RESET%
exit /b %errorlevel%

:: ============ QUICK FIX subroutines ============

:: -- Printer fix: stop spooler, clear stuck jobs, restart. --
:t_spooler
echo.
echo         %C_DIM%Stopping Print Spooler...%C_RESET%
net stop spooler >nul 2>&1
echo         %C_DIM%Clearing stuck jobs in spool\PRINTERS...%C_RESET%
del /q /f /s "%SystemRoot%\System32\spool\PRINTERS\*.*" >nul 2>&1
echo         %C_DIM%Starting Print Spooler...%C_RESET%
net start spooler >nul 2>&1
sc query spooler | find /i "RUNNING" >nul 2>&1
if errorlevel 1 (
    echo         %C_ERR%Spooler did NOT come back up - check printer drivers.%C_RESET%
    exit /b 1
)
echo         %C_OK%Print Spooler running, queue is clean.%C_RESET%
exit /b 0

:: -- Audio fix: restart audio service stack --
:t_audio
echo.
echo         %C_DIM%Restarting Windows Audio services...%C_RESET%
net stop Audiosrv /y >nul 2>&1
net stop AudioEndpointBuilder /y >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
net start AudioEndpointBuilder >nul 2>&1
net start Audiosrv >nul 2>&1
sc query Audiosrv | find /i "RUNNING" >nul 2>&1
if errorlevel 1 (
    echo         %C_ERR%Audio service did not restart - check audio device drivers.%C_RESET%
    exit /b 1
)
echo         %C_OK%Audio services running - test your sound now.%C_RESET%
exit /b 0

:: -- Bluetooth fix: restart the BT stack; SKIP if no BT hardware --
:t_bt
sc query bthserv >nul 2>&1
if errorlevel 1 (
    echo         %C_WARN%No Bluetooth service found - this PC has no Bluetooth.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo.
echo         %C_DIM%Restarting Bluetooth support service...%C_RESET%
net stop bthserv /y >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
net start bthserv >nul 2>&1
sc query bthserv | find /i "RUNNING" >nul 2>&1
if errorlevel 1 (
    echo         %C_ERR%Bluetooth service did not restart - re-pair devices after reboot.%C_RESET%
    exit /b 1
)
echo         %C_OK%Bluetooth stack restarted - re-test your devices.%C_RESET%
exit /b 0

:: -- Store fix: reset the Microsoft Store cache --
:t_storereset
echo.
echo         %C_DIM%Running WSReset - a Store window may open, keep it in front...%C_RESET%
start /wait wsreset.exe
echo         %C_OK%Store cache reset done - if it opened, test downloading an app.%C_RESET%
exit /b %errorlevel%

:: -- Time sync fix: needs internet (talks to Microsoft NTP) --
:t_time
call :check_internet
if errorlevel 1 (
    echo         %C_ERR%NO INTERNET - time sync needs the connection. Fix network first.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] time sync skipped - no internet
    exit /b 1
)
echo.
echo         %C_DIM%Restarting Windows Time service and forcing sync...%C_RESET%
net stop w32time >nul 2>&1
net start w32time >nul 2>&1
w32tm /resync /force
set "TIME_RC=%errorlevel%"
if not "%TIME_RC%"=="0" (
    echo         %C_WARN%Sync command returned %TIME_RC% - the clock may need a moment.%C_RESET%
)
echo         %C_DIM%Verify: clock in the taskbar; timezone in Settings.%C_RESET%
exit /b 0

:: -- Search fix: restart the Windows Search indexer --
:t_wsearch
echo.
echo         %C_DIM%Restarting Windows Search service...%C_RESET%
net stop WSearch /y >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
net start WSearch >nul 2>&1
sc query WSearch | find /i "RUNNING" >nul 2>&1
if errorlevel 1 (
    echo         %C_ERR%Search service did not restart.%C_RESET%
    exit /b 1
)
echo         %C_OK%Search indexer restarted - re-indexing runs in background.%C_RESET%
echo         %C_DIM%Still broken? Settings - Search - Windows Search - Rebuild index.%C_RESET%
exit /b 0

:: -- Disk check: schedule CHKDSK at next restart --
:t_chkdsk
echo.
echo         %C_DIM%Scheduling chkdsk /f /r on %SystemDrive% for the next restart...%C_RESET%
echo y| chkdsk %SystemDrive% /f /r
set "CHK_RC=%errorlevel%"
set "REBOOT_ADVISED=1"
if not "%CHK_RC%"=="0" (
    echo         %C_ERR%CHKDSK scheduling failed - run it manually as Administrator.%C_RESET%
    exit /b %CHK_RC%
)
echo         %C_OK%Scheduled. It runs automatically at the next restart - do not power off.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] chkdsk /f /r scheduled on %SystemDrive%
exit /b 0

:: ============ REGISTRY FIX subroutines ============
:: Each checks whether the policy value exists first. If it was never
:: set, the task reports SKIP ("already fine") instead of claiming OK.

:: -- EXE association repair (classic "no program opens" damage) - FULL VERSION v3.0 --
:r_exe
echo.
echo         %C_DIM%Restoring exefile class and .exe association - FULL REPAIR...%C_RESET%
:: Step 1: Remove user overrides that hijack .exe
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe" /f >nul 2>&1
reg delete "HKCU\Software\Classes\.exe" /f >nul 2>&1
reg delete "HKCU\Software\Classes\exefile" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe\UserChoice" /f >nul 2>&1
echo         %C_DIM%  - user overrides cleared%C_RESET%
:: Step 2: Restore core assoc + ftype
ftype exefile="%%1" %%* >nul 2>&1
assoc .exe=exefile >nul 2>&1
:: Step 3: Restore HKCR\.exe keys
reg add "HKCR\.exe" /ve /d "exefile" /f >nul 2>&1
reg add "HKCR\.exe" /v "Content Type" /d "application/x-msdownload" /f >nul 2>&1
reg add "HKCR\.exe\PersistentHandler" /ve /d "{098f2470-bae0-11cd-b579-08002b30bfeb}" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Classes\.exe" /ve /d "exefile" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Classes\.exe" /v "Content Type" /d "application/x-msdownload" /f >nul 2>&1
:: Step 4: Restore exefile open command
reg add "HKCR\exefile" /ve /d "Application" /f >nul 2>&1
reg add "HKCR\exefile\DefaultIcon" /ve /d "%%1" /f >nul 2>&1
reg add "HKCR\exefile\shell\open\command" /ve /d "\"%%1\" %%*" /f >nul 2>&1
reg add "HKCR\exefile\shell\open\command" /v "IsolatedCommand" /d "\"%%1\" %%*" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Classes\exefile\shell\open\command" /ve /d "\"%%1\" %%*" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Classes\exefile\shell\open\command" /v "IsolatedCommand" /d "\"%%1\" %%*" /f >nul 2>&1
echo         %C_DIM%  - HKCR\.exe and exefile restored%C_RESET%
:: Step 5: Check IFEO hijacks
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s /f "Debugger" 2>nul | find /i "Debugger" >nul 2>&1
if not errorlevel 1 (
    echo         %C_WARN%  WARNING: IFEO Debugger hijacks FOUND - malware may be blocking exe%C_RESET%
    echo         %C_DIM%  Run fix_exe.bat for automatic removal, or check manually:%C_RESET%
    echo         %C_DIM%  reg query HKLM\...\Image File Execution Options /s /f Debugger%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] IFEO Debugger hijack detected
) else (
    echo         %C_DIM%  - No IFEO hijacks found%C_RESET%
)
:: Step 6: Check DisallowRun
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisallowRun >nul 2>&1
if not errorlevel 1 (
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisallowRun /f >nul 2>&1
    echo         %C_WARN%  Removed DisallowRun policy%C_RESET%
)
echo         %C_OK%EXE association fully restored - try opening a program now.%C_RESET%
echo         %C_DIM%If still broken: restart Explorer, sign out/in, scan malware, run sfc /scannow%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] EXE association repaired - full restore v3.0
exit /b 0

:: -- shared policy-value cleaner: %1=key %2=value name --
:: sets R_FOUND=1 when the value existed and was deleted
:r_del_policy
set "R_FOUND="
reg query "%~1" /v "%~2" >nul 2>&1
if errorlevel 1 exit /b 0
set "R_FOUND=1"
reg delete "%~1" /v "%~2" /f >nul 2>&1
exit /b 0

:r_taskmgr
call :r_del_policy "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" "DisableTaskMgr"
set "R_ANY=%R_FOUND%"
call :r_del_policy "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableTaskMgr"
if not defined R_ANY if not defined R_FOUND (
    echo         %C_OK%Task Manager was not blocked - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo         %C_OK%Task Manager unblocked - reopens right away.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - DisableTaskMgr removed
exit /b 0

:r_cmd
call :r_del_policy "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" "EnableCMD"
set "R_ANY=%R_FOUND%"
call :r_del_policy "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableCMD"
if not defined R_ANY if not defined R_FOUND (
    echo         %C_OK%Command Prompt was not blocked - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo         %C_OK%Command Prompt unblocked - opens normally now.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - EnableCMD block removed
exit /b 0

:r_regedit
call :r_del_policy "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" "DisableRegistryTools"
set "R_ANY=%R_FOUND%"
call :r_del_policy "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableRegistryTools"
if not defined R_ANY if not defined R_FOUND (
    echo         %C_OK%Registry Editor was not blocked - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo         %C_OK%Registry Editor unblocked - regedit opens now.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - DisableRegistryTools removed
exit /b 0

:r_run
call :r_del_policy "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRun"
set "R_ANY=%R_FOUND%"
call :r_del_policy "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoRun"
if not defined R_ANY if not defined R_FOUND (
    echo         %C_OK%Run dialog was not blocked - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo         %C_OK%Run dialog restored - sign out/in if it is still hidden.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - NoRun removed
exit /b 0

:r_folderopt
call :r_del_policy "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoFolderOptions"
set "R_ANY=%R_FOUND%"
call :r_del_policy "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoFolderOptions"
if not defined R_ANY if not defined R_FOUND (
    echo         %C_OK%Folder Options were not blocked - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo         %C_OK%Folder Options restored - re-tick "Show hidden files" if needed.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - NoFolderOptions removed
exit /b 0

:r_usb
reg query "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" /v Start 2>nul | find "0x3" >nul 2>&1
if not errorlevel 1 (
    echo         %C_OK%USB storage was already enabled - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" /v Start /t REG_DWORD /d 3 /f >nul 2>&1
if not "%errorlevel%"=="0" (
    echo         %C_ERR%Could not update the USBSTOR registry value.%C_RESET%
    exit /b 1
)
echo         %C_OK%USB storage enabled - plug the drive in again.%C_RESET%
echo         %C_WARN%Reboot may be needed if a drive is currently attached.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - USBSTOR Start set back to 3
exit /b 0

:r_cpanel
call :r_del_policy "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoControlPanel"
set "R_ANY=%R_FOUND%"
call :r_del_policy "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoControlPanel"
if not defined R_ANY if not defined R_FOUND (
    echo         %C_OK%Control Panel was not blocked - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo         %C_OK%Control Panel and Settings unblocked.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - NoControlPanel removed
exit /b 0

:: -- Repair sequence, also used by AUTO-HEAL --
:t_repair
echo.
echo         %C_HEAL%Checking internet connection first - restorehealth needs it...%C_RESET%
call :check_internet
if errorlevel 1 (
    echo         %C_ERR%NO INTERNET connection detected.%C_RESET%
    echo         %C_DIM%Skipping scanhealth + restorehealth - connect and try again.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] Repair skipped - no internet connection detected
    exit /b 1
)
echo         %C_OK%Internet OK.%C_RESET%
echo.
echo         %C_INFO%Step 1/2 - scanhealth %C_DIM%- can take 5-15 min - DISM shows progress:%C_RESET%
dism.exe /Online /Cleanup-Image /ScanHealth
set "SCAN_RC=%errorlevel%"
>>"%LOG_FILE%" echo [%TIME:~0,8%] scanhealth finished - exit code %SCAN_RC%
if not "%SCAN_RC%"=="0" exit /b %SCAN_RC%
echo.
echo         %C_INFO%Step 2/2 - restorehealth %C_DIM%- can take 10-30 min - needs internet:%C_RESET%
dism.exe /Online /Cleanup-Image /RestoreHealth
set "RESTORE_RC=%errorlevel%"
>>"%LOG_FILE%" echo [%TIME:~0,8%] restorehealth finished - exit code %RESTORE_RC%
exit /b %RESTORE_RC%

:: -- DISM component store cleanup with AUTO-HEAL --
:t_dism
if defined REBOOT_PENDING (
    echo.
    echo         %C_WARN%SKIPPED - Windows has a PENDING REBOOT.%C_RESET%
    echo         %C_DIM%Component store cleanup is blocked until that reboot.%C_RESET%
    echo         %C_DIM%Restart the PC, then run DEEP again to include this task.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SKIP - DISM - blocked by pending reboot
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo.
echo         %C_DIM%Component store cleanup - DISM shows its own progress:%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] DISM StartComponentCleanup started
dism.exe /Online /Cleanup-Image /StartComponentCleanup
set "DISM_RC=%errorlevel%"
if "%DISM_RC%"=="0" (
    del "%HEAL_FLAG%" >nul 2>&1
    echo         %C_OK%Component store cleaned successfully.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] DISM completed successfully
    exit /b 0
)
for /f "usebackq" %%h in (`powershell -NoProfile -Command "'0x{0:X8}' -f %DISM_RC%"`) do set "DISM_HEX=%%h"
set "DISM_FAILED_RUN=1"
echo failed>"%HEAL_FLAG%"
>>"%LOG_FILE%" echo [%TIME:~0,8%] DISM FAILED - decimal %DISM_RC% = hex %DISM_HEX%
echo.
echo         %C_ERR%DISM cleanup failed with error %DISM_HEX%.%C_RESET%
echo.
echo         %C_HEAL%AUTO-HEAL engaged - checking internet first...%C_RESET%
call :check_internet
if errorlevel 1 (
    echo         %C_ERR%NO INTERNET - restorehealth cannot run without it.%C_RESET%
    echo         %C_DIM%Connect to the internet, then re-run DEEP cleanup.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-HEAL skipped - no internet connection
    exit /b %DISM_RC%
)
echo         %C_OK%Internet OK%C_RESET% %C_HEAL%- repair then retry. Can take 10-30 minutes.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-HEAL engaged - scanhealth + restorehealth + retry
call :t_repair
set "HEAL_RC=%errorlevel%"
if not "%HEAL_RC%"=="0" (
    echo         %C_ERR%AUTO-HEAL repair failed - reboot, then try menu option 4 again.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-HEAL repair stage failed - exit code %HEAL_RC%
    exit /b %HEAL_RC%
)
echo.
echo         %C_HEAL%Repair finished - retrying component store cleanup...%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-HEAL retrying StartComponentCleanup
dism.exe /Online /Cleanup-Image /StartComponentCleanup
set "DISM_RC=%errorlevel%"
if "%DISM_RC%"=="0" (
    del "%HEAL_FLAG%" >nul 2>&1
    echo         %C_OK%AUTO-HEAL SUCCESS - component store cleaned after repair!%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-HEAL SUCCESS - cleanup completed after repair
    exit /b 0
)
for /f "usebackq" %%h in (`powershell -NoProfile -Command "'0x{0:X8}' -f %DISM_RC%"`) do set "DISM_HEX=%%h"
echo         %C_ERR%AUTO-HEAL retry failed with error %DISM_HEX% - reboot and run DEEP again.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-HEAL retry FAILED - decimal %DISM_RC% = hex %DISM_HEX%
exit /b %DISM_RC%
exit /b %DISM_RC%
] AUTO-HEAL retry FAILED - decimal %DISM_RC% = hex %DISM_HEX%
exit /b %DISM_RC%
