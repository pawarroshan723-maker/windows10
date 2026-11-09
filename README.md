# Advanced System Care — `cleanup_advanced.bat`

A single-file, menu-driven maintenance tool for **Windows 10 (1803+) / Windows 11**.
It bundles the usual "PC care" operations — cleanup, SFC/DISM repair, service
health checks, registry fixes, quick fixes, tweaks and drive optimization —
into one interactive console script with color output and a single log file.

No installation, no downloads, no telemetry. Every action is a standard
Windows built-in (`sfc`, `dism`, `powercfg`, `reg`, `sc`, `netsh`, …).

## Requirements

- Windows 10 1803 or later, or Windows 11
- Administrator rights (the script elevates itself via UAC; you can also
  right-click → *Run as administrator*)
- Internet connection is needed for: DISM repair / AUTO-HEAL, forced time
  sync, and the (optional) Store cache reset check

## How to run

1. Right-click `cleanup_advanced.bat` → **Run as administrator**.
2. Pick a menu option:

| Key | What it does |
|-----|--------------|
| `R` | **One-click REPAIR ALL** — services + cleanup + SFC/DISM + drive optimize (30–90 min) |
| `1` / `2` / `3` | **QUICK / FULL / DEEP cleanup** — temp files, recycle bin, WER logs, update cache, thumbnails, dumps, DISM component store, delivery optimization |
| `4` | **Repair system files** — `sfc /scannow` + DISM `ScanHealth`/`RestoreHealth` (15–45 min) |
| `5` | **Repair network stack** — Winsock + TCP/IP reset (needs reboot) |
| `6` | **Reset Windows Update** — stops update services, moves `SoftwareDistribution`/`catroot2` to `*.old` |
| `7` | **Service health check** — scans 23 critical services against their correct start type, repairs with per-service confirmation |
| `8` | **Registry fixes** — EXE association, Task Manager, CMD, Regedit, Run dialog, Folder Options, USB storage, Control Panel locks |
| `9` | **Quick fixes** — printer, audio, Bluetooth, Store (WSReset), time sync, search indexer, CHKDSK, System Restore, RAM test — plus the **Troubleshooting** section (see below) |
| `A` | **Windows tweaks** — each with Apply/Restore: Photo Viewer, extensions, hidden files, Take Ownership, shortcut arrows, Bing off, menu speed, GameDVR off, lock screen |
| `B` | **Optimization** — drive TRIM/defrag, power plans, startup delay, Explorer restart, hibernation on/off |
| `C` | **Disk space overview** |
| `D` | **Auto-Care scheduler** — inspect or remove an existing task; new scheduling is disabled for safety |

Cleanup runs ask for confirmation. A confirmation proceeds only on an explicit
`Y`; `N` or an input error cancels. Not every settings change has a separate
confirmation, so review each option carefully.

## Troubleshooting section (menu `9`, keys `A`–`J`)

| Key | Tool | What it does |
|-----|------|--------------|
| `A` | No / slow internet | DNS fix on your default adapter: set public DNS (8.8.8.8 + 1.1.1.1) with a live `nslookup` test, reset to automatic, or just flush the cache |
| `B` | Wi-Fi / adapter problem | Lists all adapters + status; enables disabled adapters; restarts the wireless adapter (brief drop) |
| `C` | Disk / SSD health | SMART status of every physical disk — `Predicted`/`Failed` = back up data and replace |
| `D` | Analyze last crash | Blue-screen bug-check events (30 days), unclean shutdowns, minidumps on disk + interpretation hints |
| `E` | Slow at startup | Last boot time, uptime, all Run-key entries, startup folder items |
| `F` | What's using CPU / RAM | Top 10 processes by CPU time, top 5 by memory |
| `G` | Battery drains fast | Full battery report (HTML, opened in browser), last wake event, wake-armed devices |
| `H` | Windows license | Activation status via `slmgr /xpr` |
| `I` | Keyboard acts weird | Resets Filter / Sticky / Toggle keys (the "types on its own" fix) |
| `J` | Microsoft Defender | Show status and enable or disable Defender real-time protection, with confirmation |

`C`–`H` are read-only diagnostics; `A`, `B`, `I` and `J` can change settings.

**Defender:** option `J` controls only Microsoft Defender Antivirus real-time
protection, not the entire Defender product or another antivirus. Turning it
off reduces protection. This script does **not** schedule re-enabling it; turn
it back on after use. Windows may re-enable it automatically. Tamper protection,
organization policy or passive mode can prevent changes; the tool reports an
error if the requested state cannot be confirmed. Verify status in Windows
Security.

## Auto-Care (menu `D`)

**Creating new Auto-Care tasks is disabled.** The old scheduler registered the
current script path to run as SYSTEM, even when that path could be writable by
an unprivileged user. Existing tasks are **not** removed automatically. Use
menu `D` → `2` to inspect an existing task and `3` to remove it, or manage
`ASC_AutoCare` in Task Scheduler. Review the task action and its file and
parent-directory permissions.

The `-auto` command-line mode still runs the maintenance pipeline unattended
and can modify services and delete crash dumps. It is not recommended for
unattended use until the remaining safety issues in
[DEEP_AUDIT_2026-11-09.md](DEEP_AUDIT_2026-11-09.md) are addressed. Auto runs
under SYSTEM use `%SystemDrive%\ASC_Logs\Cleanup.log`.

## Safety model (v3.0)

- **Restore point** — the script attempts to create a System Restore point at
  session start. Creation may fail or be throttled; verify it independently.
- **Registry backup** — selected keys are exported to
  `%USERPROFILE%\CleanupLogs\regbak\*.reg`, but coverage is incomplete and
  later sessions overwrite the files. Importing them is not a complete undo.
- **Delete guards** — several cleanup tasks check that environment variables
  are nonempty; they do not validate that the resulting paths are safe.
- **WU reset** — the current `SoftwareDistribution`/`catroot2` folders are
  renamed to `*.old`, but an existing `*.old` is deleted first. Failures can
  leave a partial reset; back up independently before running it.
- **Elevation-profile warning** — if UAC runs the script as a *different*
  admin account, the script warns that user-level tweaks (menu `A`) apply to
  that admin's profile.
- **Service fixes are conservative** — Delayed-Auto services stay
  Delayed-Auto, and Windows Defender is left alone when a third-party
  antivirus is active.

## Log & backups

| What | Where |
|------|-------|
| Session log (appended; deleted when over 1 MB) | `%USERPROFILE%\CleanupLogs\Cleanup.log` |
| Registry backups | `%USERPROFILE%\CleanupLogs\regbak\*.reg` |
| SFC output capture | `%USERPROFILE%\CleanupLogs\sfc_out.txt` |
| Restore points | System Restore, if a point was successfully created |
| WU reset leftovers | `%SystemRoot%\SoftwareDistribution.old`, `%SystemRoot%\System32\catroot2.old` (delete by hand once updates work) |

## Undos

- **Menu A tweaks** — choose the tweak again → `R` (Restore default); this
  does not necessarily restore your prior custom settings.
- **Hibernation** — menu `B` → `7` (Enable hibernation).
- **Startup delay** — menu `B` → `8` (Restore default startup delay).
- **Registry changes** — exported `.reg` files cover only selected keys and
  merge values on import; they are not a complete rollback.
- **System changes** — a verified System Restore point may undo some changes;
  it does not replace backups of personal data or deleted crash dumps.

## Known limitations

- If you elevate with a *different* admin account, menu `A` tweaks, the
  "recent documents" cleanup, thumbnail/dump cleanup and the Store reset
  apply to **that admin's profile**, not your everyday account. The script
  warns on the main menu when this happens.
- `WSReset` (Store fix) runs as the current elevated account.
- Service auto-repair re-enables *core* services that were disabled;
  intentionally-disabled optional services (Print Spooler, Windows Search,
  Themes) will also be started — confirm each one in menu `7`, and skip the
  ones you want left off. In one-click `R` the service pass runs without
  prompts.
- Disabling hibernation also disables Fast Startup (re-enable via `B` → `7`).
- Prefetch is **not** wiped by default (clearing it saves a few MB but slows
  first app launches); the `:t_prefetch` subroutine remains available.
- SFC/DISM and drive defrag can take a long time; large HDD CHKDSK runs can
  take many hours at the next restart.

## Versioning

- **v3.2.7** (2026-11-09) — Added Defender real-time protection status and
  confirmed on/off controls in menu `9` → `J`.
- **v3.2.6** (2026-11-09) — Corrected the elevation-profile comparison,
  Store and time-sync error reporting, and diagnostic color-reset text. The
  PowerShell EXE repair now uses a provider-qualified classes path and stops
  on core repair errors. Windows runtime validation is still required.
- **v3.2.5** (2026-11-09) — Safer menu routing and cancellation, cleanup
  confirmations, return to the originating submenu, Optimization `0=Back`,
  and new Auto-Care scheduling disabled pending a secure installation design.
  Existing Auto-Care tasks must be removed separately.
- **v3.2.4** (2026-09-19) — Hardening: the summary
  screen's auto-mode exit moved to its own label, so a manual
  run can never be killed from that screen (protects against
  corrupted downloads of that block).
- **v3.2.3** (2026-09-19) — Bug fix: option I (keyboard)
  reset Filter Keys in the wrong registry key; it now writes to
  `Keyboard Response` (the key Windows actually reads).
- **v3.2.2** (2026-09-19) — No functional change: the
  version number is now shown on the Quick Fixes (menu 9) screen too,
  so it is easy to see which copy of the file you are running.
- **v3.2.1** (2026-09-19) — Bug fix: in v3.2 the menu 9
  keyboard mapping was scrambled (keys 1-9, A-I and 0 all routed to
  the wrong tools). Keys now map correctly.
- **v3.2** (2026-09-19) — Troubleshooting section in menu 9 (keys A–I):
  DNS fix, network adapter enable/restart, disk SMART health, crash
  analysis, startup report, top processes, battery report, license
  check, keyboard filter-key reset.
- **v3.1** (2026-09-19) — Auto-Care: scheduled unattended maintenance
  (menu `D`), `-auto` flag, auto runs log to `C:\ASC_Logs\`.
- **v3.0.2** (2026-09-19) — fixed the AudioEndpointBuilder probe line
  (pre-existing v2.9 bug: missing space made the service uncheckable).
- **v3.0.1** (2026-09-19) — fixed the phantom `auto` service in the
  REPAIR ALL service loop (now a deterministic list file + `SVC_AUTO`
  flag + unknown-service guard).
- **v3.0** (2026-09-19) — security/quality audit fixes: working Y/N
  confirmations, correct `DisableCMD` value, restore point + registry backup,
  guarded deletes, no `$Recycle.bin` folder deletion, real error codes,
  non-elevated Explorer restart, rename-based WU reset, elevation-profile
  warning, HTTPS internet fallback, conservative service fixes, appended log,
  SFC output parsing, prefetch out of DEEP, hibernation/startup-delay undo
  options, tail corruption removed.
- **v2.9** — previous release (see git history).

## Disclaimer

This tool modifies system state (services, registry, caches, power
configuration). Use at your own risk — the restore point and registry
backups are a safety net, not a guarantee. No license is included in this
repository; all rights reserved.

---

## 🚨 EXE Files Not Opening? FIX ADDED (v3.0)

This branch now includes comprehensive EXE fix (same as main fix):

- `fix_exe.bat` - One-click full repair (recommended, run as admin)
- `fix_exe.reg` - Registry file import
- `fix_exe.ps1` - PowerShell version
- `fix_exe.vbs` - VBScript fallback
- `EMERGENCY_INSTRUCTIONS.txt` - How to run when exe blocked

**Quick fix:**
1. Right-click `fix_exe.bat` → Run as administrator
2. Restart PC
3. If still broken: `sfc /scannow` + `DISM /Online /Cleanup-Image /RestoreHealth` + antivirus full scan

Also `cleanup_advanced.bat` → `[8] Registry fixes` → `[1] EXE association` now does FULL restore (v3.0): clears UserChoice, restores HKCR\.exe, PersistentHandler, exefile open command, checks IFEO hijacks.

See main README for full guide or check `fix_exe.bat` source.

