@echo off
setlocal EnableExtensions
title Advanced System Care - Windows 10 / 11

:: ================================================================
::  ADVANCED SYSTEM CARE  v3.2.2
::  (Cleanup + Repair + Services + Registry + QuickFix + Tweaks
::   + ONE-CLICK REPAIR ALL)
:: ---------------------------------------------------------------
::  v3.0 CHANGES (audit fixes, 2026-09-19):
::   * FIXED   Y/N confirmations always returned "Yes" (an echo
::             between choice and exit reset the errorlevel)
::   * FIXED   Command Prompt fix removed the wrong value
::             (EnableCMD) - now removes DisableCMD from all 4 paths
::   * NEW     restore point + registry backup at session start
::   * SAFETY  every mass delete guarded against empty env vars
::   * SAFETY  no more C:\$Recycle.bin folder deletion
::   * SAFETY  Take Ownership warns about Windows system files
::   * FIXED   swallowed error codes (power plans, hibernation,
::             startup delay, WSReset) now report real failures
::   * FIXED   Explorer restart no longer spawns an elevated shell
::   * FIXED   WU reset renames (keeps) folders and aborts if locked
::   * NEW     warning when elevated under a different admin account
::   * NEW     internet check falls back to HTTPS when ICMP is blocked
::   * FIXED   service fixes keep Delayed-Auto start types and skip
::             Windows Defender when third-party AV is active
::   * FIXED   log is appended (rotates at 1 MB), DISM repair checks
::             pending reboot, SFC result parsed from its real output
::   * DEEP    no longer wipes Prefetch by default
::   * NEW     undo options: enable hibernation (B-7), restore
::             startup delay (B-8)
::  v3.0.1 (2026-09-19, field-report fix):
::   * FIXED   REPAIR ALL service loop - the old numbered-variable
::             pattern (%%SVCBAD_%%i%%) plus the "auto" no-prompt
::             argument could shift the flag into the service NAME
::             slot on the first iteration (a phantom "SVC FIX -
::             auto" was logged and the real service went unfixed).
::             Bad services are now read from a list file, the flag
::             is an env var, and unknown service names are skipped.
::  v3.0.2 (2026-09-19, field-report fix):
::   * FIXED   AudioEndpointBuilder probe line - missing space between
::             the two quoted arguments (a v2.9 bug) made cmd merge
::             them, so the service was never actually checked and the
::             scan printed a bogus '[ --- ] AUTO - not installed'.
::  v3.1 (2026-09-19):
::   * NEW     AUTO-CARE (menu D): schedule a weekly unattended run of
::             the full REPAIR ALL pipeline. Runs as SYSTEM (works
::             logged-off, no password stored), default 02:00, task
::             name ASC_AutoCare. Status/remove from the same menu.
::   * NEW     -auto flag: unattended mode (used by the scheduled
::             task, or manually: cleanup_advanced.bat -auto)
::   * NEW     auto runs log to %SystemDrive%\ASC_Logs\Cleanup.log
::  v3.2.2 (2026-09-19):
::   * NOTE    no functional change - version number is now shown on
::             the Quick Fixes (menu 9) screen too, so you can always
::             see which copy of the file you are running
::  v3.2.1 (2026-09-19):
::   * FIX     menu 9 key mapping was scrambled in v3.2 (A-I and
::             0 routed to the wrong tools) - keys now map correctly
::  v3.2 (2026-09-19):
::   * NEW     TROUBLESHOOTING section in menu 9 (keys A-I):
::             DNS fix (public/automatic/flush + test), network
::             adapter enable/restart, disk SMART health, crash /
::             blue-screen analysis, startup items report, top CPU /
::             memory processes, battery report + wake sources,
::             Windows license check, Filter/Sticky/Toggle key reset
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
::  SERVICES     health scan of ~23 critical services vs their
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

:: ---------- 1a. Unattended AUTO-CARE mode (-auto) ----------
:: -auto = run the full REPAIR ALL pipeline with no prompts. Used by
:: the scheduled auto-care task (menu D) or manually:
::   cleanup_advanced.bat -auto
:: ASC_EXTRA carries the flag through the UAC / color relaunches.
set "AUTO_MODE="
set "ASC_EXTRA="
for %%a in (%*) do if /i "%%a"=="-auto" (
    set "AUTO_MODE=1"
    set "ASC_EXTRA= -auto"
)

:: ---------- 1. Elevate to Administrator if needed ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Requesting Administrator privileges - please accept the UAC prompt...
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '-vt -orig=%USERNAME%%ASC_EXTRA%' -Verb RunAs } catch { exit 1 }" >nul 2>&1
    if errorlevel 1 (
        echo.
        echo   Elevation was cancelled - Administrator rights are REQUIRED.
        echo   Right-click the file and choose "Run as administrator".
        pause
    )
    exit /b 1
)

:: ---------- 1b. Enable ANSI colors (virtual terminal mode) ----------
:: conhost on Win10 needs VirtualTerminalLevel=1, and it only applies
:: to consoles created AFTER the key exists - so we relaunch ourselves
:: once (no UAC prompt here, we are already elevated). The -vt argument
:: guards against relaunching twice.
reg query "HKCU\Console" /v VirtualTerminalLevel 2>nul | find "0x1" >nul 2>&1
if errorlevel 1 reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
if /i not "%~1"=="-vt" if not defined AUTO_MODE (
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '-vt -orig=%USERNAME%%ASC_EXTRA%' -Verb RunAs } catch { exit 1 }" >nul 2>&1
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
:: scheduled auto-care runs as SYSTEM - use a machine-wide log folder
if /i "%USERNAME%"=="SYSTEM" (
    set "LOG_DIR=%SystemDrive%\ASC_Logs"
) else (
    set "LOG_DIR=%USERPROFILE%\CleanupLogs"
)
set "LOG_FILE=%LOG_DIR%\Cleanup.log"
set "HEAL_FLAG=%LOG_DIR%\dism_heal_armed.flg"
set "SVC_BAD_FILE=%LOG_DIR%\svc_bad.txt"
if not exist "%LOG_DIR%" md "%LOG_DIR%" >nul 2>&1

:: ---------- 3b. AUTO-HEAL state from the previous session ----------
set "PREV_DISM_FAIL="
if exist "%HEAL_FLAG%" set "PREV_DISM_FAIL=1"

:: ---------- 3c. Detect pending reboot (DISM depends on it) ----------
set "REBOOT_PENDING="
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "REBOOT_PENDING=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1 && set "REBOOT_PENDING=1"

:: ---------- 3d. Start the log (append mode, rotate at 1 MB) ----------
if exist "%LOG_FILE%" for %%F in ("%LOG_FILE%") do if %%~zF GTR 1048576 del /q "%LOG_FILE%" >nul 2>&1
>>"%LOG_FILE%" echo ===============================================
>>"%LOG_FILE%" echo  System Care session started: %DATE% %TIME%  (session %TS%)
>>"%LOG_FILE%" echo  Running as: %USERNAME%  -  Administrator: YES
ver | find /v "" >>"%LOG_FILE%"
if defined AUTO_MODE >>"%LOG_FILE%" echo  Mode: UNATTENDED AUTO CARE (-auto)
>>"%LOG_FILE%" echo ===============================================
if defined REBOOT_PENDING >>"%LOG_FILE%" echo  NOTE: Windows reports a PENDING REBOOT - the DISM cleanup task will be skipped.
if defined PREV_DISM_FAIL >>"%LOG_FILE%" echo  NOTE: previous session had a DISM failure - AUTO-HEAL is armed.

:: ---------- 3e. Elevation profile check ----------
:: UAC may have run us under a DIFFERENT admin account than the one
:: that started the script. HKCU tweaks would then land in the admin
:: profile, not the user's. The original name was passed through the
:: relaunch as the -orig= argument (see sections 1 and 1b).
set "PROFILE_MISMATCH="
set "ORIG_USER=%~2"
if defined ORIG_USER set "ORIG_CHECK=%ORIG_USER:-orig=%"
if defined ORIG_CHECK if not "%ORIG_CHECK%"=="%ORIG_USER%" (
    set "ORIG_USER=%ORIG_CHECK%"
    if /i not "%ORIG_USER%"=="%USERNAME%" (
        set "PROFILE_MISMATCH=1"
        >>"%LOG_FILE%" echo  NOTE: started by "%ORIG_USER%" but running as admin "%USERNAME%" - user tweaks affect the ADMIN profile.
    )
)

:: ---------- 3f. Safety: restore point + registry backup ----------
:: Best effort - if System Restore is unavailable the script warns
:: and continues. The registry backup stores every key this script
:: can change; double-click a .reg file to restore that key.
powershell -NoProfile -Command "Checkpoint-Computer -Description 'Before Advanced System Care (%TS%)' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop" >nul 2>&1
if errorlevel 1 (
    echo.
    echo   %C_WARN%Could not create a restore point ^(System Restore may be turned off^).%C_RESET%
    echo   %C_DIM%You can still create one manually: Win+R, rstrui.exe, Create.%C_RESET%
    >>"%LOG_FILE%" echo  Safety: restore point FAILED - System Restore may be off
) else (
    >>"%LOG_FILE%" echo  Safety: restore point created - Before Advanced System Care ^(%TS%^)
)
set "REG_BAK_DIR=%LOG_DIR%\regbak"
if not exist "%REG_BAK_DIR%" md "%REG_BAK_DIR%" >nul 2>&1
set /a REG_N=0
call :regbak "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies"           "HKLM_CV_Policies"
call :regbak "HKLM\SOFTWARE\Policies\Microsoft\Windows"                          "HKLM_Policies_MSW"
call :regbak "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" "HKLM_ShellIcons"
call :regbak "HKLM\SOFTWARE\Classes\exefile"                                     "HKLM_Classes_exefile"
call :regbak "HKLM\SOFTWARE\Classes\*\shell\TakeOwnership"                       "HKLM_Classes_star_TakeOwnership"
call :regbak "HKLM\SOFTWARE\Classes\Directory\shell\TakeOwnership"               "HKLM_Classes_Dir_TakeOwnership"
call :regbak "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"           "HKCU_Explorer"
call :regbak "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"             "HKCU_Search"
call :regbak "HKCU\Software\Policies\Microsoft\Windows"                          "HKCU_Policies_MSW"
call :regbak "HKCU\System\GameConfigStore"                                         "HKCU_GameConfigStore"
call :regbak "HKCU\Control Panel\Desktop"                                          "HKCU_Desktop"
call :regbak "HKCU\Console"                                                         "HKCU_Console"
call :regbak "HKCU\Software\Classes"                                               "HKCU_Classes"
>>"%LOG_FILE%" echo  Safety: registry backup written - %REG_N% keys - %REG_BAK_DIR%

:: ---------- 3g. Detect third-party antivirus ----------
:: If a non-Microsoft AV is active, Windows Defender being off is
:: legitimate and the service scan must not flag or re-enable it.
set "TPAV="
for /f %%a in ('powershell -NoProfile -Command "(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -notmatch 'Defender' -and ([int]$_.ProductState -band 100) -ne 0 }).Count" 2^>nul') do if "%%a" neq "" if "%%a" neq "0" set "TPAV=1"

:: ---------- 4. Main menu ----------
if defined AUTO_MODE goto RUN_AUTO
:MENU
cls
echo.
echo  %C_H%==================================================================
echo  %C_H%            ADVANCED SYSTEM CARE  %C_DIM%-  v3.2.2%C_H%
echo  %C_H%==================================================================%C_RESET%
echo.
echo    %C_OK%[R]%C_RESET% %C_HEAL%ONE-CLICK REPAIR ALL%C_RESET%  %C_DIM%- full automatic maintenance (30-90 min)%C_RESET%
echo.
echo    %C_DIM%-- CLEANUP --------------------------------------------------%C_RESET%
echo    %C_HEAL%[1]%C_RESET% %C_INFO%QUICK cleanup%C_RESET%      %C_DIM%- temp files, recycle bin, error logs, DNS%C_RESET%
echo    %C_HEAL%[2]%C_RESET% %C_INFO%FULL cleanup%C_RESET%       %C_DIM%- quick + update cache, thumbnails, dumps, shaders%C_RESET%
echo    %C_HEAL%[3]%C_RESET% %C_INFO%DEEP cleanup%C_RESET%       %C_DIM%- full + DISM store, delivery opt.%C_RESET%
echo.
echo    %C_DIM%-- REPAIR ---------------------------------------------------%C_RESET%
echo    %C_HEAL%[4]%C_RESET% %C_ERR%Repair system files%C_RESET% %C_DIM%- SFC + DISM scanhealth/restorehealth suite%C_RESET%
echo    %C_HEAL%[5]%C_RESET% %C_ERR%Repair network stack%C_RESET%%C_DIM% - winsock, TCP/IP, IP renewal, DNS%C_RESET%
echo    %C_HEAL%[6]%C_RESET% %C_ERR%Reset Windows Update%C_RESET%%C_DIM%- rebuild update components from scratch%C_RESET%
echo    %C_HEAL%[7]%C_RESET% %C_ERR%Service health check%C_RESET%%C_DIM%- scan ~23 critical services, fix broken ones%C_RESET%
echo    %C_HEAL%[8]%C_RESET% %C_ERR%Registry fixes%C_RESET%     %C_DIM%- EXE, Task Manager, regedit, USB, policies%C_RESET%
echo.
echo    %C_DIM%-- QUICK FIXES / TWEAKS ------------------------------------------%C_RESET%
echo    %C_HEAL%[9]%C_RESET% %C_OK%Fix a common problem%C_RESET%%C_DIM% - printer, sound, bluetooth, store, time, RAM...%C_RESET%
echo    %C_HEAL%[A]%C_RESET% %C_OK%Windows tweaks%C_RESET%      %C_DIM%- Photo Viewer, extensions, GameDVR, lock screen...%C_RESET%
echo    %C_HEAL%[B]%C_RESET% %C_OK%Optimization tools%C_RESET%  %C_DIM%- drives, power plan, startup, explorer, hibernation%C_RESET%
echo.
echo    %C_DIM%-- TOOLS ------------------------------------------------------%C_RESET%
echo    %C_HEAL%[C]%C_RESET% %C_INFO%Disk space overview%C_RESET%
echo    %C_HEAL%[D]%C_RESET% %C_INFO%Auto-Care scheduler%C_RESET% %C_DIM%- weekly unattended maintenance%C_RESET%
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
if defined PROFILE_MISMATCH (
    echo    %C_WARN%*  Started by "%ORIG_USER%" - running as admin "%USERNAME%". *%C_RESET%
    echo    %C_WARN%*  Tweaks in menu A write to the ADMIN profile, not yours.  *%C_RESET%
    echo    %C_WARN%*  For personal tweaks, run the script as your own admin.   *%C_RESET%
    echo.
)
echo    %C_DIM%Log: %LOG_FILE%%C_RESET%
echo.
choice /c 123456789ABCDR0 /n /m "  Choose an option [R=Repair All, D=Auto-Care, 1-9, A-C, 0=Exit]: "
if errorlevel 15 goto END
if errorlevel 14 goto RUN_REPAIRALL
if errorlevel 13 goto AUTOMENU
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
call :task "Recent documents (privacy history)" :t_recent
call :task "DNS cache flush"                   :t_dns
goto SUMMARY

:RUN_FULL
set "TASK_TOTAL=10"
call :start_run "FULL"
call :task "User Temp files - all profiles"    :t_user_temp
call :task "System Temp files"                 :t_sys_temp
call :task "Recycle Bin"                       :t_recycle
call :task "Windows Error Reporting logs"      :t_wer
call :task "Recent documents (privacy history)" :t_recent
call :task "DNS cache flush"                   :t_dns
call :task "Windows Update cache"              :t_wucache
call :task "Thumbnail and icon cache"          :t_thumbs
call :task "Crash dumps"                       :t_dumps
call :task "DirectX shader cache"              :t_d3ds
goto SUMMARY

:: NOTE: DISM runs FIRST here - it needs Windows Update in its normal
:: state, so it must not run right after the WU service restart cycle.
:: NOTE: Prefetch is NOT wiped by default (see :t_prefetch) - clearing
:: it saves a few MB but slows first app launches for a while.
:RUN_DEEP
set "TASK_TOTAL=12"
call :start_run "DEEP"
call :task "Component store cleanup - DISM"    :t_dism
call :task "User Temp files - all profiles"    :t_user_temp
call :task "System Temp files"                 :t_sys_temp
call :task "Recycle Bin"                       :t_recycle
call :task "Windows Error Reporting logs"      :t_wer
call :task "Recent documents (privacy history)" :t_recent
call :task "DNS cache flush"                   :t_dns
call :task "Windows Update cache"              :t_wucache
call :task "Thumbnail and icon cache"          :t_thumbs
call :task "Crash dumps"                       :t_dumps
call :task "DirectX shader cache"              :t_d3ds
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
if not defined AUTO_MODE (
    echo.
    call :confirm "ONE-CLICK REPAIR ALL: services + cleanup + system file repair + drive optimize. Can take 30-90 min. Start now?"
    if errorlevel 2 goto MENU
)
set "RUN_LABEL_PRE=REPAIR ALL"
call :pipeline_all

:: -- unattended entry: scheduled auto-care task or 'cleanup_advanced.bat -auto' --
:RUN_AUTO
set "RUN_LABEL_PRE=AUTO CARE (unattended)"
call :pipeline_all

:pipeline_all
set "TASK_TOTAL=13"
call :start_run %RUN_LABEL_PRE%
echo.
echo    %C_HEAL%*** PHASE 1/4 - SERVICE HEALTH CHECK + AUTO-FIX ***%C_RESET%
call :svc_scanall
echo.
if "%SVC_BAD_N%"=="0" (
    echo    %C_OK%All critical services healthy - nothing to fix.%C_RESET%
) else (
    echo    %C_WARN%%SVC_BAD_N% services need repair - fixing now...%C_RESET%
)
set "SVC_AUTO=1"
if %SVC_BAD_N% gtr 0 for /f "delims=" %%s in ('type "%SVC_BAD_FILE%" 2^>nul') do call :svc_fixone "%%s"
set "SVC_AUTO="

echo.
echo    %C_HEAL%*** PHASE 2/4 - SYSTEM CLEANUP ***%C_RESET%
call :task "User Temp files - all profiles"    :t_user_temp
call :task "System Temp files"                 :t_sys_temp
call :task "Recycle Bin"                       :t_recycle
call :task "Windows Error Reporting logs"      :t_wer
call :task "Recent documents (privacy history)" :t_recent
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
call :confirm "Repair the marked services? Each service is confirmed one by one."
if errorlevel 2 goto MENU
echo.
for /f "delims=" %%s in ('type "%SVC_BAD_FILE%" 2^>nul') do call :svc_fixone "%%s"
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
type nul >"%SVC_BAD_FILE%"
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
call :svc_probe "AudioEndpointBuilder"  "Audio Endpoint Builder"          AUTO
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
if "%~1"=="WinDefend" if defined TPAV (
    echo    %C_DIM%[ skip ] %~2  - third-party antivirus active, left alone%C_RESET%
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
    >>"%SVC_BAD_FILE%" echo %~1,%~3
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC BROKEN - %~1 is DISABLED - expected %~3
    exit /b 0
)
if "%~3"=="AUTO" if not "%SP_START%"=="AUTO" (
    echo    %C_ERR%[ BAD ]  %~2  - wrong start type: %SP_START%  %C_DIM%^(%~1^)%C_RESET%
    set /a SVC_BAD_N+=1
    >>"%SVC_BAD_FILE%" echo %~1,%~3
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC BROKEN - %~1 start type %SP_START% - expected AUTO
    exit /b 0
)
if "%~3"=="AUTO" if not "%SP_STATE%"=="RUN" (
    echo    %C_WARN%[ DOWN ] %~2  - not running %C_DIM%- will be started%C_RESET%
    set /a SVC_BAD_N+=1
    >>"%SVC_BAD_FILE%" echo %~1,%~3
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
    >>"%SVC_BAD_FILE%" echo %~1,%~3
)
exit /b 0

:: -- fix one recorded service; %1 = "name,expected" (SVC_AUTO = no prompt) --
:svc_fixone
for /f "tokens=1,2 delims=," %%a in ("%~1") do (
    set "FX_NAME=%%a"
    set "FX_EXP=%%b"
)
:: safety: never "fix" a name that is not a real service
sc query "%FX_NAME%" >nul 2>&1
if errorlevel 1 (
    echo        %C_WARN%service %FX_NAME% not found - skipped.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC FIX - %FX_NAME% not found, skipped
    exit /b 0
)
if not defined SVC_AUTO (
    call :confirm "Fix service %FX_NAME%? Restores its start type and starts it."
    if errorlevel 2 (
        echo        %C_DIM%skipped - left as found.%C_RESET%
        >>"%LOG_FILE%" echo [%TIME:~0,8%] SVC FIX - %FX_NAME% skipped by user
        exit /b 0
    )
)
echo    %C_HEAL%FIX%C_RESET% %FX_NAME% ...
:: keep Delayed-Auto services on Delayed-Auto (that is fine on purpose)
set "FX_DELAYED="
sc qc %FX_NAME% 2>nul | find /i "DELAYED" >nul 2>&1 && set "FX_DELAYED=1"
if "%FX_EXP%"=="MAN" (
    sc config %FX_NAME% start= demand >nul 2>&1
) else if defined FX_DELAYED (
    sc config %FX_NAME% start= delayed >nul 2>&1
) else (
    sc config %FX_NAME% start= auto >nul 2>&1
)
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
    echo         %C_WARN%WARNING: use only on your own files and folders.%C_RESET%
    echo         %C_WARN%Never "Take Ownership" of C:\Windows, C:\System32 or driver files -%C_RESET%
    echo         %C_WARN%it can break Windows Update and SFC repairs.%C_RESET%
    call :confirm "Add the Take Ownership right-click menu?"
    if errorlevel 2 (
        echo         %C_DIM%Skipped - nothing changed.%C_RESET%
        goto :eof
    )
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
echo  %C_H%        QUICK FIXES for common problems  %C_DIM%v3.2.2%C_H%
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
echo.
echo    %C_DIM%-- TROUBLESHOOTING --------------------------------------------------%C_RESET%
echo    %C_OK%[A]%C_RESET% %C_INFO%No / slow internet%C_RESET%       %C_DIM%- DNS fix: public DNS, automatic, flush%C_RESET%
echo    %C_OK%[B]%C_RESET% %C_INFO%Wi-Fi / adapter problem%C_RESET%  %C_DIM%- enable disabled, restart wireless%C_RESET%
echo    %C_OK%[C]%C_RESET% %C_INFO%Check disk / SSD health%C_RESET%  %C_DIM%- SMART status of all drives%C_RESET%
echo    %C_OK%[D]%C_RESET% %C_INFO%Analyze last crash%C_RESET%       %C_DIM%- blue screen codes, dumps%C_RESET%
echo    %C_OK%[E]%C_RESET% %C_INFO%Slow at startup%C_RESET%          %C_DIM%- boot time + startup items%C_RESET%
echo    %C_OK%[F]%C_RESET% %C_INFO%What is using CPU / RAM%C_RESET%  %C_DIM%- top processes%C_RESET%
echo    %C_OK%[G]%C_RESET% %C_INFO%Battery drains fast%C_RESET%      %C_DIM%- battery report + wake sources%C_RESET%
echo    %C_OK%[H]%C_RESET% %C_INFO%Check Windows license%C_RESET%    %C_DIM%- activation status%C_RESET%
echo    %C_OK%[I]%C_RESET% %C_INFO%Keyboard acts weird%C_RESET%      %C_DIM%- reset Filter / Sticky keys%C_RESET%
echo    %C_OK%[0]%C_RESET% %C_INFO%Back to main menu%C_RESET%
echo.
choice /c 123456789ABCDEFGHI0 /n /m "  Choose a fix [1-9, A-I, 0=Back]: "
if errorlevel 19 goto MENU
if errorlevel 18 goto FIX_FILTERKEYS
if errorlevel 17 goto FIX_LICENSE
if errorlevel 16 goto FIX_BATT
if errorlevel 15 goto FIX_PROCS
if errorlevel 14 goto FIX_STARTUP
if errorlevel 13 goto FIX_CRASH
if errorlevel 12 goto FIX_DSKH
if errorlevel 11 goto FIX_NETADAPT
if errorlevel 10 goto FIX_DNS
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
call :confirm "Schedule CHKDSK /f /r on %SystemDrive%? Runs at NEXT RESTART. Minutes on SSD, 1-10 h on a large HDD."
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


:: ============ TROUBLESHOOTING subroutines (menu 9, A-I) ============

:: -- A: DNS fix on the default (internet) adapter --
:FIX_DNS
cls
echo.
echo   %C_INFO%Current IP / DNS configuration of the adapters:%C_RESET%
echo.
netsh interface ip show config
echo.
choice /c 1230 /n /m "  [1]=Set public DNS 8.8.8.8+1.1.1.1   [2]=Reset DNS to automatic   [3]=Flush DNS cache   [0]=Cancel: "
if errorlevel 4 goto FIXMENU
if errorlevel 3 call :dns_flush
if errorlevel 2 call :dns_auto
call :dns_public
goto FIXMENU

:: -- find the default route's adapter name --
:dns_detect
set "DNS_IFACE="
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1).InterfaceAlias" 2^>nul') do set "DNS_IFACE=%%a"
goto :eof

:dns_public
call :dns_detect
if not defined DNS_IFACE (
    echo   %C_ERR%Could not detect the default network adapter - are you online via a router?%C_RESET%
    pause >nul
    goto :eof
)
echo   %C_DIM%Setting public DNS on "%DNS_IFACE%"...%C_RESET%
netsh interface ip set dns "%DNS_IFACE%" static 8.8.8.8
netsh interface ip add dns "%DNS_IFACE%" 1.1.1.1 index=2
ipconfig /flushdns >nul 2>&1
echo.
echo   %C_DIM%Testing name resolution...%C_RESET%
nslookup www.microsoft.com
echo.
echo   %C_DIM%Revert later with option [2] ^(automatic DNS^).%C_RESET%
echo   %C_DIM%Still no internet? Try [B] adapter or menu 5 full network reset.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] DNS - set public 8.8.8.8/1.1.1.1 on %DNS_IFACE%
echo.
pause >nul
goto :eof

:dns_auto
call :dns_detect
if not defined DNS_IFACE (
    echo   %C_ERR%Could not detect the default network adapter.%C_RESET%
    pause >nul
    goto :eof
)
netsh interface ip set dns "%DNS_IFACE%" dhcp
ipconfig /flushdns >nul 2>&1
echo   %C_OK%DNS back to automatic ^(router / ISP values^).%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] DNS - reset to automatic on %DNS_IFACE%
echo.
pause >nul
goto :eof

:dns_flush
ipconfig /flushdns
echo   %C_DIM%DNS cache cleared. If problems persist, try [1] or [2].%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] DNS - cache flushed
echo.
pause >nul
goto :eof

:: -- B: network adapters: list, enable disabled, restart wireless --
:FIX_NETADAPT
cls
echo.
echo   %C_INFO%Network adapters on this PC:%C_RESET%
echo.
powershell -NoProfile -Command "Get-NetAdapter | Format-Table Name, Status, LinkSpeed, InterfaceDescription -AutoSize"
echo.
choice /c 120 /n /m "  [1]=Enable all DISABLED adapters   [2]=Restart wireless adapter   [0]=Cancel: "
if errorlevel 3 goto FIXMENU
if errorlevel 2 call :net_wireless
call :net_enable
goto FIXMENU

:net_enable
powershell -NoProfile -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Disabled' } | ForEach-Object { Write-Output ('   Enabling ' + $_.Name); Enable-NetAdapter -Name $_.Name -Confirm:$false }"
echo.
echo   %C_DIM%Reconnect/replug the device if it is external.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] NETADAPT - enabled disabled adapters
echo.
pause >nul
goto :eof

:net_wireless
call :confirm "Restart the wireless adapter? Internet drops for a few seconds."
if errorlevel 2 goto :eof
powershell -NoProfile -Command "Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq '802.11' } | ForEach-Object { Disable-NetAdapter -Name $_.Name -Confirm:$false; Start-Sleep 2; Enable-NetAdapter -Name $_.Name -Confirm:$false }"
echo   %C_OK%Wireless adapter restarted - test the connection.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] NETADAPT - wireless adapter restarted
echo.
pause >nul
goto :eof

:: -- C: disk / SSD SMART health (read-only) --
:FIX_DSKH
cls
echo.
echo   %C_INFO%Physical disk health ^(SMART^):%C_RESET%
echo.
powershell -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, @{n='Size_GB';e={[int]($_.Size/1GB)}}, HealthStatus | Format-Table -AutoSize"
echo.
echo   %C_DIM%Healthy = fine. Predicted/Failed = BACK UP DATA and replace%C_RESET%
echo   %C_DIM%the drive soon. A 'Predicted' SSD is wearing out.%C_RESET%
echo.
echo   %C_DIM%Press any key to return...%C_RESET%
pause >nul
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - disk SMART health report shown
goto FIXMENU

:: -- D: crash / blue screen analysis (read-only) --
:FIX_CRASH
cls
echo.
echo   %C_INFO%Bug check events, last 30 days:^C_RESET%
echo.
powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='System';Id=1001;StartTime=(Get-Date).AddDays(-30)} -MaxEvents 5 -ErrorAction SilentlyContinue | ForEach-Object { $_.TimeCreated.ToString('yyyy-MM-dd HH:mm') + '  ' + $_.Message.Trim().Substring(0,[Math]::Min(140,$_.Message.Trim().Length)) }"
echo.
echo   %C_INFO%Unclean shutdowns in the last 30 days ^C_RESET%
powershell -NoProfile -Command "(Get-WinEvent -FilterHashtable @{LogName='System';Id=41;StartTime=(Get-Date).AddDays(-30)} -ErrorAction SilentlyContinue | Measure-Object).Count"
echo.
echo   %C_INFO%Memory dumps on disk:^C_RESET%
if exist "%SystemRoot%\Minidump\*.dmp" (
    dir /o-d "%SystemRoot%\Minidump\*.dmp"
) else (
    echo   %C_DIM%No minidumps found.%C_RESET%
)
if exist "%SystemRoot%\MEMORY.DMP" echo   %C_DIM%MEMORY.DMP present ^(full dump^).%C_RESET%
echo.
echo   %C_DIM%A repeating bug check code usually points to a driver or bad RAM.%C_RESET%
echo   %C_DIM%Try the RAM test ^(option 9^) and update GPU / chipset drivers.%C_RESET%
echo.
echo   %C_DIM%Press any key to return...%C_RESET%
pause >nul
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - crash analysis report shown
goto FIXMENU

:: -- E: startup report (read-only) --
:FIX_STARTUP
cls
echo.
powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; $up = (Get-Date) - $os.LastBootUpTime; Write-Output ('   Last boot: ' + $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm')); Write-Output ('   Uptime:    ' + [int]$up.TotalHours + ' h ' + $up.Minutes + ' min')"
echo.
echo   %C_INFO%Startup entries - Run keys:%C_RESET%
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" 2>nul
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" 2>nul
echo.
echo   %C_INFO%Startup folder items:%C_RESET%
dir /b "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 2>nul
echo.
echo   %C_DIM%Disable unwanted ones: Task Manager - Startup tab, or%C_RESET%
echo   %C_DIM%Settings - Apps - Startup. Many entries are normal.%C_RESET%
echo.
echo   %C_DIM%Press any key to return...%C_RESET%
pause >nul
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - startup report shown
goto FIXMENU

:: -- F: top CPU / memory processes (read-only) --
:FIX_PROCS
cls
echo.
echo   %C_INFO%Top 10 processes by CPU time:^C_RESET%
echo.
powershell -NoProfile -Command "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 ProcessName, @{n='CPU_s';e={[int]$_.CPU}}, @{n='Mem_MB';e={[int]($_.WorkingSet64/1MB)}} | Format-Table -AutoSize"
echo.
echo   %C_INFO%Top 5 by memory:^C_RESET%
powershell -NoProfile -Command "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 ProcessName, @{n='Mem_MB';e={[int]($_.WorkingSet64/1MB)}} | Format-Table -AutoSize"
echo.
echo   %C_DIM%CPU_s = seconds of CPU used since the process started.%C_RESET%
echo   %C_DIM%Task Manager ^(Ctrl+Shift+Esc^) shows live percentages.%C_RESET%
echo.
echo   %C_DIM%Press any key to return...%C_RESET%
pause >nul
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - top processes report shown
goto FIXMENU

:: -- G: battery report + wake sources --
:FIX_BATT
cls
echo.
echo   %C_INFO%Generating battery report...%C_RESET%
powercfg /batteryreport /output "%LOG_DIR%\battery_report.html"
if exist "%LOG_DIR%\battery_report.html" (
    echo   %C_OK%Report saved: %LOG_DIR%\battery_report.html%C_RESET%
    echo.
    start "" "%LOG_DIR%\battery_report.html"
) else (
    echo   %C_DIM%No battery detected ^(desktop PC^) - nothing to report.%C_RESET%
)
echo.
echo   %C_INFO%Last wake event:%C_RESET%
powercfg /lastwake
echo.
echo   %C_INFO%Devices allowed to wake the PC:%C_RESET%
powercfg /devicequery wake_armed
echo.
echo   %C_DIM%Wake events + background apps explain most 'battery died overnight'.%C_RESET%
echo.
echo   %C_DIM%Press any key to return...%C_RESET%
pause >nul
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - battery report generated
goto FIXMENU

:: -- H: Windows license status (read-only) --
:FIX_LICENSE
cls
echo.
echo   %C_INFO%Windows license status:%C_RESET%
echo.
slmgr /xpr
echo.
echo   %C_DIM%If not activated: Settings - Activation. With a license key,%C_RESET%
echo   %C_DIM%run slmgr /ipk ^<key^> in an elevated prompt.%C_RESET%
echo.
echo   %C_DIM%Press any key to return...%C_RESET%
pause >nul
>>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - license status shown
goto FIXMENU

:: -- I: keyboard Filter/Sticky/Toggle keys reset --
:FIX_FILTERKEYS
cls
echo.
call :confirm "Reset Filter / Sticky / Toggle keys to off? Fixes 'keyboard types on its own' or keys that feel dead."
if errorlevel 2 goto FIXMENU
set "TASK_TOTAL=1"
call :start_run "KEYBOARD FILTER KEYS"
call :task "Reset Filter/Sticky/Toggle keys" :t_filterkeys
goto SUMMARY

:t_filterkeys
reg add "HKCU\Control Panel\Accessibility\FilterKeys" /v FilterKeysActive /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v StickyKeysActive /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v ToggleKeysActive /t REG_DWORD /d 0 /f >nul 2>&1
echo         %C_OK%Filter, Sticky and Toggle keys disabled.%C_RESET%
echo         %C_DIM%Note: applies to the current ^possibly elevated^ user profile.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] keyboard - filter/sticky/toggle keys reset
exit /b 0


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
echo    %C_OK%[7]%C_RESET% %C_INFO%Enable hibernation %C_DIM%(undo 6)%C_RESET%
echo    %C_OK%[8]%C_RESET% %C_INFO%Restore startup delay %C_DIM%(undo 4)%C_RESET%
echo    %C_OK%[9]%C_RESET% %C_INFO%Back to main menu%C_RESET%
echo.
choice /c 123456789 /n /m "  Choose an option [1-9]: "
if errorlevel 9 goto MENU
if errorlevel 8 goto OPT_STARTREST
if errorlevel 7 goto OPT_HIBON
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

:OPT_HIBON
set "TASK_TOTAL=1"
call :start_run "HIBERNATION"
call :task "Enable hibernation"                     :t_hibon
goto SUMMARY

:OPT_STARTREST
set "TASK_TOTAL=1"
call :start_run "STARTUP TUNE"
call :task "Restore default startup delay"          :t_startdelayrest
goto SUMMARY

:: ---------- 5h. AUTO-CARE: scheduled unattended maintenance ----------
:AUTOMENU
cls
echo.
echo  %C_H%------------------------------------------------------------------
echo  %C_H%                  AUTO-CARE  %C_DIM%-  scheduled maintenance%C_H%
echo  %C_H%------------------------------------------------------------------%C_RESET%
echo.
echo    %C_OK%[1]%C_RESET% %C_INFO%Enable weekly auto-care%C_RESET%  %C_DIM%- runs as SYSTEM, no prompts%C_RESET%
echo    %C_OK%[2]%C_RESET% %C_INFO%Show auto-care status%C_RESET%
echo    %C_OK%[3]%C_RESET% %C_INFO%Remove auto-care task%C_RESET%
echo    %C_OK%[0]%C_RESET% %C_INFO%Back to main menu%C_RESET%
echo.
echo   %C_DIM%Auto-care = full REPAIR ALL pipeline, unattended (30-90 min):%C_RESET%
echo   %C_DIM%services + cleanup + DISM/SFC + drive optimize, restore point first.%C_RESET%
echo   %C_DIM%Log of auto runs: %SystemDrive%\ASC_Logs\Cleanup.log%C_RESET%
echo.
choice /c 1230 /n /m "  Choose an option [1-3, 0=Back]: "
if errorlevel 4 goto MENU
if errorlevel 3 goto AUTO_REMOVE
if errorlevel 2 goto AUTO_STATUS
if errorlevel 1 goto AUTO_ENABLE

:AUTO_ENABLE
cls
echo.
echo  %C_H%Enable weekly auto-care%C_H%
echo.
echo   The script runs the full REPAIR ALL pipeline unattended - no
echo   prompts, no waiting. A restore point is created first, as always.
echo.
choice /c 1234567 /n /m "  Which day? [1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat]: "
if errorlevel 7 set "ASC_DAY=SAT"
if errorlevel 6 set "ASC_DAY=FRI"
if errorlevel 5 set "ASC_DAY=THU"
if errorlevel 4 set "ASC_DAY=WED"
if errorlevel 3 set "ASC_DAY=TUE"
if errorlevel 2 set "ASC_DAY=MON"
set "ASC_DAY=SUN"
call :confirm "Schedule auto-care every %ASC_DAY% at 02:00?"
if errorlevel 2 goto AUTOMENU
schtasks /create /tn "ASC_AutoCare" /tr "\"%~f0\" -auto" /sc weekly /d %ASC_DAY% /st 02:00 /ru SYSTEM /f
if errorlevel 1 (
    echo   %C_ERR%Could not create the scheduled task - see the error above.%C_RESET%
) else (
    echo   %C_OK%Auto-care scheduled: every %ASC_DAY% at 02:00.%C_RESET%
    echo   %C_DIM%Change the time in Task Scheduler -^> ASC_AutoCare.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-CARE task created - weekly %ASC_DAY% 02:00
)
echo.
pause
goto AUTOMENU

:AUTO_STATUS
cls
echo.
echo  %C_H%Auto-care task status%C_H%
echo.
schtasks /query /tn "ASC_AutoCare" /v /fo list 2>nul
if errorlevel 1 echo   %C_DIM%No auto-care task is configured (use option 1).%C_RESET%
echo.
pause
goto AUTOMENU

:AUTO_REMOVE
cls
echo.
call :confirm "Remove the weekly auto-care task?"
if errorlevel 2 goto AUTOMENU
schtasks /delete /tn "ASC_AutoCare" /f
if errorlevel 1 (
    echo   %C_DIM%No auto-care task was present.%C_RESET%
) else (
    echo   %C_OK%Auto-care task removed.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] AUTO-CARE task removed
)
echo.
pause
goto AUTOMENU


:: ---------- 6. Summary screen ----------
:SUMMARY
for /f "tokens=1,2" %%a in ('powershell -NoProfile -Command "$f=Get-PSDrive -Name %SYS_DRIVE%; '{0} {1}' -f ([math]::Round($f.Free/1MB)),([math]::Round($f.Free/1GB,2))"') do (
    set "FREE_AFTER=%%a"
    set "FREE_NOW_GB=%%b"
)
set /a FREED_MB=%FREE_AFTER%-%FREE_BEFORE%
if %FREED_MB% lss 0 set "FREED_MB=0"
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
if defined AUTO_MODE (
    >>"%LOG_FILE%" echo ---- AUTO CARE (unattended) finished %DATE% %TIME% ----
    exit /b 0
)
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

:: -- Confirmation prompt: %1 = question; returns 2 when answered No --
:: NOTE: capture %errorlevel% IMMEDIATELY after choice - any echo or
:: other command in between resets it (that bug used to make every
:: "No" answer fall through as "Yes").
:confirm
echo   %C_WARN%?%C_RESET% %~1
choice /c yn /n /m "   Continue [Y/N]: "
set "CONFIRM_RC=%errorlevel%"
if "%CONFIRM_RC%"=="2" (
    echo   %C_DIM%Cancelled.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - user cancelled: %~1
)
exit /b %CONFIRM_RC%

:: -- Start a run: baseline free space, header, log entry --
:start_run
set "RUN_LABEL=%~1"
set /a TASK_NUM=0
set /a FAIL_NUM=0
set "DISM_FAILED_RUN="
:: NOTE: REBOOT_ADVISED is NOT cleared here - a reboot advised by an
:: earlier run in this session stays advised until the next session.
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

:: -- Safety guard: %1 = env var name. Returns 1 when the variable is
:: -- undefined/empty. Destructive tasks call this BEFORE expanding the
:: -- variable into a delete path - otherwise an empty variable would
:: -- turn del "%%TEMP%%\*" into a silent mass delete of "\*".
:require_env
if not defined %~1 exit /b 1
exit /b 0

:: -- export one registry key to the backup dir (silent, best effort) --
:: %1 = key path, %2 = output file name (without .reg)
:regbak
reg export "%~1" "%REG_BAK_DIR%\%~2.reg" /y >nul 2>&1
if not errorlevel 1 set /a REG_N+=1
goto :eof

:: -- Clean Temp for EVERY user profile (elevated context aware) --
:t_user_temp
call :require_env TEMP || ( set "TASK_SKIPPED=1" & exit /b 0 )
call :require_env SystemDrive || ( set "TASK_SKIPPED=1" & exit /b 0 )
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
call :require_env SystemRoot || ( set "TASK_SKIPPED=1" & exit /b 0 )
del /q /f /s "%SystemRoot%\Temp\*" >nul 2>&1
for /d %%x in ("%SystemRoot%\Temp\*") do rd /s /q "%%x" >nul 2>&1
exit /b 0

:t_recycle
:: Clear-RecycleBin empties the bin on every drive properly. Do NOT
:: rd the $Recycle.bin folder itself - that deletes every user's bin
:: structure and can race with the API call above.
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
exit /b 0

:t_wer
call :require_env ProgramData || ( set "TASK_SKIPPED=1" & exit /b 0 )
del /q /f /s "%ProgramData%\Microsoft\Windows\WER\ReportArchive\*" >nul 2>&1
for /d %%x in ("%ProgramData%\Microsoft\Windows\WER\ReportArchive\*") do rd /s /q "%%x" >nul 2>&1
del /q /f /s "%ProgramData%\Microsoft\Windows\WER\ReportQueue\*" >nul 2>&1
for /d %%x in ("%ProgramData%\Microsoft\Windows\WER\ReportQueue\*") do rd /s /q "%%x" >nul 2>&1
exit /b 0

:t_recent
:: Privacy note: this clears the recent-documents list for the
:: CURRENT (possibly elevated) user profile. It is a privacy reset,
:: not a meaningful space saver.
call :require_env APPDATA || ( set "TASK_SKIPPED=1" & exit /b 0 )
del /q /f /s "%APPDATA%\Microsoft\Windows\Recent\*" >nul 2>&1
exit /b 0

:t_dns
ipconfig /flushdns >nul 2>&1
exit /b 0

:t_wucache
call :require_env SystemRoot || ( set "TASK_SKIPPED=1" & exit /b 0 )
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
call :require_env LOCALAPPDATA || ( set "TASK_SKIPPED=1" & exit /b 0 )
del /q /f /a "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /q /f /a "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
exit /b 0

:t_dumps
call :require_env LOCALAPPDATA || ( set "TASK_SKIPPED=1" & exit /b 0 )
call :require_env SystemRoot || ( set "TASK_SKIPPED=1" & exit /b 0 )
del /q /f /s "%LOCALAPPDATA%\CrashDumps\*" >nul 2>&1
for /d %%x in ("%LOCALAPPDATA%\CrashDumps\*") do rd /s /q "%%x" >nul 2>&1
del /q /f /s "%SystemRoot%\Minidump\*" >nul 2>&1
del /q /f "%SystemRoot%\MEMORY.DMP" >nul 2>&1
exit /b 0

:t_d3ds
:: Safe to delete - Windows rebuilds shader caches automatically
call :require_env LOCALAPPDATA || ( set "TASK_SKIPPED=1" & exit /b 0 )
del /q /f /s "%LOCALAPPDATA%\D3DSCache\*" >nul 2>&1
for /d %%x in ("%LOCALAPPDATA%\D3DSCache\*") do rd /s /q "%%x" >nul 2>&1
exit /b 0

:t_prefetch
:: NOTE: Prefetch helps apps start faster. Only .pf traces are removed;
:: Windows rebuilds them, but first launches may be slower for a while.
:: This task is intentionally NOT part of any default run (DEEP) -
:: it saves a few MB at the cost of launch speed.
call :require_env SystemRoot || ( set "TASK_SKIPPED=1" & exit /b 0 )
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
if not defined INET_OK (
    :: firewalls that block ICMP but allow HTTPS would cause a false
    :: "no internet" - verify with a real HTTPS request in that case
    powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 https://www.microsoft.com).StatusCode } catch { exit 1 }" >nul 2>&1 && set "INET_OK=1"
)
if defined INET_OK exit /b 0
exit /b 1

:: -- System File Checker --
:: sfc exit codes are poorly documented, so the RESULT is parsed from
:: the real output (kept in %LOG_DIR%\sfc_out.txt) as well.
:t_sfc
echo.
echo         %C_DIM%Scanning protected system files - can take 5-15 min:%C_RESET%
powershell -NoProfile -Command "sfc /scannow 2>&1 | Tee-Object -FilePath '%LOG_DIR%\sfc_out.txt'; exit $LASTEXITCODE"
set "SFC_RC=%errorlevel%"
set "SFC_UNFIXED="
find /i "unable to fix" "%LOG_DIR%\sfc_out.txt" >nul 2>&1 && set "SFC_UNFIXED=1"
find /i "could not fix" "%LOG_DIR%\sfc_out.txt" >nul 2>&1 && set "SFC_UNFIXED=1"
>>"%LOG_FILE%" echo [%TIME:~0,8%] sfc /scannow finished - exit code %SFC_RC%
if defined SFC_UNFIXED (
    echo         %C_ERR%SFC found corrupt files it COULD NOT FIX - re-run after a reboot.%C_RESET%
    echo         %C_ERR%If it persists, run DISM repair ^(menu 4, step 2^).%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] sfc reported UNFIXABLE corruption
    exit /b 1
)
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
call :require_env SystemRoot || ( set "TASK_SKIPPED=1" & exit /b 0 )
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
:: rename (keep) instead of delete - the .old folders stay for
:: comparison and are only removed by hand. Abort cleanly if locked.
rd /s /q "%SystemRoot%\SoftwareDistribution.old" >nul 2>&1
if exist "%SystemRoot%\SoftwareDistribution" (
    ren "%SystemRoot%\SoftwareDistribution" "SoftwareDistribution.old" >nul 2>&1
    if exist "%SystemRoot%\SoftwareDistribution" (
        echo         %C_ERR%SoftwareDistribution is locked - WU reset aborted.%C_RESET%
        echo         %C_DIM%Close update-related apps, then try again.%C_RESET%
        set "WU_ABORTED=1"
        goto :wu_restore
    )
)
echo         %C_DIM%Rebuilding catroot2 security database...%C_RESET%
rd /s /q "%SystemRoot%\System32\catroot2.old" >nul 2>&1
if exist "%SystemRoot%\System32\catroot2" (
    ren "%SystemRoot%\System32\catroot2" "catroot2.old" >nul 2>&1
    if exist "%SystemRoot%\System32\catroot2" (
        echo         %C_ERR%catroot2 is locked - WU reset aborted.%C_RESET%
        echo         %C_DIM%Close update-related apps, then try again.%C_RESET%
        set "WU_ABORTED=1"
        goto :wu_restore
    )
)
:wu_restore
:: always restart the services we stopped, then report the outcome
echo         %C_DIM%Restarting services that were running...%C_RESET%
if defined WU_MSI net start msiserver >nul 2>&1
if defined WU_CRYPT net start cryptsvc >nul 2>&1
if defined WU_BITS net start bits >nul 2>&1
if defined WU_WUA net start wuauserv >nul 2>&1
if defined WU_ABORTED (
    set "WU_ABORTED="
    >>"%LOG_FILE%" echo [%TIME:~0,8%] WU reset ABORTED - a folder was locked
    exit /b 1
)
set "REBOOT_ADVISED=1"
echo.
echo         %C_OK%Windows Update components rebuilt.%C_RESET%
echo         %C_DIM%Old components kept as *.old - delete them by hand once updates work again.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] WU components reset done - reboot advised
exit /b 0

:: -- Drive optimization: TRIM on SSD, defrag on HDD --
:t_defrag
echo.
echo         %C_DIM%%SystemDrive% - defrag /O picks TRIM or defrag automatically:%C_RESET%
defrag.exe "%SystemDrive%" /O /U
set "DEFRAG_RC=%errorlevel%"
>>"%LOG_FILE%" echo [%TIME:~0,8%] drive optimization finished - exit code %DEFRAG_RC%
exit /b %DEFRAG_RC%

:: -- Power plans (standard Windows GUIDs, present on all editions) --
:t_powerhigh
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
set "PWR_RC=%errorlevel%"
if not "%PWR_RC%"=="0" (
    echo         %C_ERR%Power plan could not be set - exit code %PWR_RC%.%C_RESET%
    echo         %C_DIM%High Performance is often absent on Modern Standby PCs.%C_RESET%
    exit /b %PWR_RC%
)
echo         %C_DIM%Active scheme:%C_RESET%
powercfg /getactivescheme
exit /b 0

:t_powerbal
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
set "PWR_RC=%errorlevel%"
if not "%PWR_RC%"=="0" (
    echo         %C_ERR%Power plan could not be set - exit code %PWR_RC%.%C_RESET%
    exit /b %PWR_RC%
)
echo         %C_DIM%Active scheme:%C_RESET%
powercfg /getactivescheme
exit /b 0

:: -- Startup apps delay removal (undo: Optimization menu option 8) --
:t_startdelay
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /t REG_DWORD /d 0 /f >nul 2>&1
set "SD_RC=%errorlevel%"
if not "%SD_RC%"=="0" (
    echo         %C_ERR%Could not set the startup delay value - exit code %SD_RC%.%C_RESET%
    exit /b %SD_RC%
)
echo         %C_OK%Startup delay removed - applies after next sign-in.%C_RESET%
echo         %C_DIM%Undo: Optimization menu - Restore startup delay.%C_RESET%
exit /b 0

:: -- Restart Explorer shell --
:: Windows (winlogon) auto-restarts Explorer as the logged-in user,
:: which is what we want. Only start it ourselves if that did not
:: happen (that fallback instance would be elevated - we say so).
:t_explorer
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul 2>&1
tasklist /fi "imagename eq explorer.exe" 2>nul | find /i "explorer.exe" >nul 2>&1
if not errorlevel 1 (
    echo         %C_OK%Explorer restarted %C_DIM%^(auto-restarted by Windows, normal user^).%C_RESET%
    exit /b 0
)
start explorer.exe
echo         %C_OK%Explorer restarted %C_WARN%(elevated fallback - sign out/in if the taskbar looks odd).%C_RESET%
exit /b 0

:: -- Hibernation off (also disables Fast Startup; undo: menu B option 7) --
:t_hiboff
powercfg /h off
set "HIB_RC=%errorlevel%"
if not "%HIB_RC%"=="0" (
    echo         %C_ERR%Hibernation could not be disabled - exit code %HIB_RC%.%C_RESET%
    exit /b %HIB_RC%
)
echo         %C_OK%Hibernation disabled - hiberfil.sys freed.%C_RESET%
echo         %C_WARN%Note: Fast Startup is also disabled. Undo: Optimization - Enable hibernation.%C_RESET%
exit /b 0

:: -- Hibernation on (undo of the task above; re-enables Fast Startup) --
:t_hibon
powercfg /h on
set "HIB_RC=%errorlevel%"
if not "%HIB_RC%"=="0" (
    echo         %C_ERR%Hibernation could not be enabled - exit code %HIB_RC%.%C_RESET%
    exit /b %HIB_RC%
)
echo         %C_OK%Hibernation enabled - Fast Startup is back.%C_RESET%
exit /b 0

:: -- Startup delay: restore Windows default (undo of t_startdelay) --
:t_startdelayrest
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /f >nul 2>&1
echo         %C_OK%Startup delay value removed - Windows default applies after next sign-in.%C_RESET%
exit /b 0

:: ============ QUICK FIX subroutines ============

:: -- Printer fix: stop spooler, clear stuck jobs, restart. --
:t_spooler
call :require_env SystemRoot || ( set "TASK_SKIPPED=1" & exit /b 0 )
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
:: NOTE: runs as the CURRENT (possibly elevated) account - if your
:: everyday account is different, run this fix from menu 9 while
:: signed in as that account.
:t_storereset
echo.
echo         %C_DIM%Running WSReset - a Store window may open, keep it in front...%C_RESET%
start /wait wsreset.exe
set "WS_RC=%errorlevel%"
echo         %C_OK%Store cache reset done - if it opened, test downloading an app.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] wsreset finished - exit code %WS_RC%
exit /b 0

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
call :require_env SystemDrive || ( set "TASK_SKIPPED=1" & exit /b 0 )
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

:: -- EXE association repair (classic "no program opens" damage) --
:r_exe
echo.
echo         %C_DIM%Restoring exefile class and .exe association...%C_RESET%
ftype exefile="%%1" %%* >nul 2>&1
assoc .exe=exefile >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe\UserChoice" /f >nul 2>&1
:: HKLM side + a classic hijack location (user-level class override)
reg add "HKLM\SOFTWARE\Classes\exefile" /ve /d "Application" /f >nul 2>&1
reg delete "HKCU\Software\Classes\.exe" /f >nul 2>&1
echo         %C_OK%EXE association restored - try opening a program now.%C_RESET%
echo         %C_DIM%Still broken? Sign out and back in, then scan for malware.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] EXE association repaired
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
:: the real policy value is DisableCMD (all four classic locations)
call :r_del_policy "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" "DisableCMD"
set "R_ANY=%R_FOUND%"
call :r_del_policy "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableCMD"
if not defined R_ANY if not defined R_FOUND set "R_ANY=1"
call :r_del_policy "HKCU\Software\Policies\Microsoft\Windows\System" "DisableCMD"
if not defined R_ANY if not defined R_FOUND set "R_ANY=1"
call :r_del_policy "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "DisableCMD"
if not defined R_ANY if not defined R_FOUND (
    echo         %C_OK%Command Prompt was not blocked - nothing to do.%C_RESET%
    set "TASK_SKIPPED=1"
    exit /b 0
)
echo         %C_OK%Command Prompt unblocked - opens normally now.%C_RESET%
>>"%LOG_FILE%" echo [%TIME:~0,8%] registry - DisableCMD block removed
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
if defined REBOOT_PENDING (
    echo.
    echo         %C_WARN%SKIPPED - Windows has a PENDING REBOOT.%C_RESET%
    echo         %C_DIM%RestoreHealth needs a clean boot. Restart the PC, then run again.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] SKIP - DISM repair - blocked by pending reboot
    set "TASK_SKIPPED=1"
    exit /b 0
)
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
