# Windows 10 / 11 - EXE Fix & Advanced System Care

> **Problem: Any .exe file not opening on Windows 10 / 11?**  
> This repo fixes that + full system cleanup/repair.

## 🚨 Quick Fix - EXE Files Not Opening

### Symptoms
- Double-click .exe and nothing happens
- Error: "This file does not have a program associated with it"
- All programs show same icon / open with wrong app
- Task Manager says "Choose app to open .exe"

### Cause
1. **Broken registry** - `HKCR\.exe` or `HKCR\exefile\shell\open\command` corrupted by malware / cleaner tools
2. **UserChoice hijack** - `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe\UserChoice` points to wrong app
3. **IFEO Debugger hijack** - Malware sets `HKLM\...\Image File Execution Options\<program>.exe Debugger` to block exe
4. **DisallowRun policy** - Group policy blocking exe execution

### Solution - 3 Methods (Pick One)

#### Method 1: One-Click BAT (Recommended)
1. Download `fix_exe.bat`
2. Right-click → **Run as administrator**
3. Follow prompts - it will auto-fix and restart Explorer
4. Try opening .exe now. If still fails, **restart PC**

#### Method 2: Registry File
1. Download `fix_exe.reg`
2. Double-click → Yes → Yes (UAC)
3. Press `Ctrl+Shift+Esc` → find Windows Explorer → Restart
4. Or reboot PC

#### Method 3: PowerShell
1. Right-click Start → Windows PowerShell (Admin)
2. `Set-ExecutionPolicy Bypass -Scope Process -Force`
3. `.\fix_exe.ps1`

#### Method 4: Use Advanced System Care Suite
1. Run `cleanup_advanced.bat` as Administrator
2. Choose `[8] Registry fixes` → `[1] Programs will not start - repair broken EXE association`
3. Done

---

## 📦 Files in this repo

| File | What it does |
|------|--------------|
| `fix_exe.bat` | **Standalone comprehensive fix** - removes user overrides, restores HKCR\.exe, checks IFEO hijacks, removes DisallowRun, optional SFC, restarts Explorer. Log on Desktop. |
| `fix_exe.reg` | Pure registry restore - double-click import. Fixes `\.exe`, `exefile`, `PersistentHandler`, `open\command` |
| `fix_exe.ps1` | PowerShell version with same logic, more verbose |
| `cleanup_advanced.bat` | Full suite v2.9 → v3.0 enhanced: Cleanup (Quick/Full/Deep) + Repair (SFC/DISM/Network/WU/Services/Registry) + Quick Fixes + Tweaks + Optimization. Now includes improved EXE fix. |

---

## 🔧 What `fix_exe.bat` does step-by-step

```
[1/7] Removing user-level overrides
  - HKCU\...\FileExts\.exe (entire key)
  - HKCU\Software\Classes\.exe
  - HKCU\Software\Classes\exefile

[2/7] Restoring core association
  - assoc .exe=exefile
  - ftype exefile="%1" %*
  - HKCR\.exe @=exefile, Content Type=application/x-msdownload
  - HKCR\.exe\PersistentHandler ={098f2470-bae0-11cd-b579-08002b30bfeb}
  - HKCR\exefile @=Application, DefaultIcon=%1
  - HKCR\exefile\shell\open\command @="%1" %*  (IsolatedCommand too)
  - HKLM\SOFTWARE\Classes copy for 64-bit

[3/7] Checking IFEO hijacks
  - Scans HKLM\...\Image File Execution Options for Debugger values
  - If found, offers to remove all Debugger values (malware cleanup)

[4/7] Checking DisallowRun policies
  - Removes DisallowRun if present

[5/7] SFC quick check (optional)
  - Asks to run sfc /scannow

[6/7] Restarting Explorer
  - taskkill + start explorer.exe

[7/7] Verification
  - assoc, ftype, reg query
```

---

## 🛡️ If still not opening after fix

1. **Restart PC** - Most fixes need reboot
2. **Safe Mode** - Boot Safe Mode (Shift+Restart → Troubleshoot → Safe Mode) and run fix again
3. **Malware scan**:
   - Windows Security → Virus & threat → Full scan
   - Malwarebytes free scan
4. **System files**:
   ```cmd
   sfc /scannow
   DISM /Online /Cleanup-Image /RestoreHealth
   ```
5. **New user profile** - Settings → Accounts → Add user → test exe there. If works, old profile corrupted.
6. **System Restore** - `rstrui.exe` → pick point before problem started
7. **Last resort**: Settings → Update & Security → Recovery → Reset this PC (keep files)

---

## 💡 Prevention

- Don't use aggressive "registry cleaners"
- Keep Windows Defender enabled
- Don't download exe from untrusted sites
- Create restore point before tweaking registry

---

## 🚀 Advanced System Care Suite (`cleanup_advanced.bat`)

Full toolkit for Windows 10/11:

- **R - Repair All** - One-click: services health + cleanup + SFC/DISM + TRIM (30-90 min)
- **1 Quick / 2 Full / 3 Deep** - Temp, cache, recycle, WER, DNS, WU cache, thumbs, dumps, shader, prefetch, Delivery Opt + DISM
- **4 Repair system files** - SFC + DISM scanhealth/restorehealth
- **5 Network reset** - winsock, TCP/IP, IP renewal
- **6 WU reset** - rebuild SoftwareDistribution
- **7 Service health** - scans ~22 critical services (EventLog, Schedule, Winmgmt, ProfSvc, Dhcp, Dnscache, CryptSvc, MpsSvc, WinDefend, Audiosrv, etc.)
- **8 Registry fixes** - **EXE association (now v3.0 full)**, Task Manager block, CMD block, Regedit block, Run dialog, Folder options, USBSTOR, Control Panel
- **9 Quick fixes** - Printer queue, Audio, Bluetooth, Store WSReset, Time sync, Search indexer, CHKDSK, System Restore, RAM test
- **A Tweaks** - Photo Viewer, show extensions, hidden files, Take Ownership, shortcut arrows, Bing search, menu speed, GameDVR, lock screen (Apply/Restore)
- **B Optimization** - TRIM/defrag, High perf / Balanced power, startup delay removal, Explorer restart, hibernation off
- **C Disk overview** - free space

Log: `%USERPROFILE%\CleanupLogs\Cleanup.log`

Run as **Administrator** required.

---

## 📋 Manual Registry Fix (if you can't run bat)

Open Command Prompt as Admin and run:

```cmd
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe" /f
reg delete "HKCU\Software\Classes\.exe" /f
reg delete "HKCU\Software\Classes\exefile" /f
assoc .exe=exefile
ftype exefile="%1" %*
reg add "HKCR\.exe" /ve /d "exefile" /f
reg add "HKCR\exefile\shell\open\command" /ve /d "\"%1\" %*" /f
taskkill /f /im explorer.exe & start explorer.exe
```

---

## License

MIT - Free for personal and commercial use. No warranty. Always backup registry before changes.

---

## Author

Made for Windows 10/11 users facing "exe not opening" issue. Enhanced from original `cleanup_advanced.bat` v2.9 to v3.0 with full EXE repair.
