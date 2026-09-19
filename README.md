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
| `9` | **Quick fixes** — printer queue, audio, Bluetooth, Store (WSReset), time sync, search indexer, CHKDSK schedule, System Restore wizard, RAM test (reboots) |
| `A` | **Windows tweaks** — each with Apply/Restore: Photo Viewer, extensions, hidden files, Take Ownership, shortcut arrows, Bing off, menu speed, GameDVR off, lock screen |
| `B` | **Optimization** — drive TRIM/defrag, power plans, startup delay, Explorer restart, hibernation on/off |
| `C` | **Disk space overview** |

Every destructive question is a real Y/N confirmation. `N` actually cancels
(fixed in v3.0 — in v2.9 every "No" silently fell through as "Yes").

## Safety model (v3.0)

- **Restore point** — a System Restore point (`Before Advanced System Care
  <timestamp>`) is created at session start when System Restore is available.
- **Registry backup** — every key the script can modify is exported to
  `%USERPROFILE%\CleanupLogs\regbak\*.reg` at session start. Double-click a
  `.reg` file to restore that key.
- **Guarded deletes** — every mass `del`/`rd` verifies its environment
  variable (`%TEMP%`, `%SystemRoot%`, …) before expanding the path.
- **Non-destructive WU reset** — `SoftwareDistribution`/`catroot2` are
  *renamed* to `*.old` (kept for comparison), never deleted outright; if a
  folder is locked the reset aborts and restarts the services.
- **Elevation-profile warning** — if UAC runs the script as a *different*
  admin account, the script warns that user-level tweaks (menu `A`) apply to
  that admin's profile.
- **Service fixes are conservative** — Delayed-Auto services stay
  Delayed-Auto, and Windows Defender is left alone when a third-party
  antivirus is active.

## Log & backups

| What | Where |
|------|-------|
| Session log (appended, rotated at 1 MB) | `%USERPROFILE%\CleanupLogs\Cleanup.log` |
| Registry backups | `%USERPROFILE%\CleanupLogs\regbak\*.reg` |
| SFC output capture | `%USERPROFILE%\CleanupLogs\sfc_out.txt` |
| Restore points | `rstrui.exe` → "Before Advanced System Care …" |
| WU reset leftovers | `%SystemRoot%\SoftwareDistribution.old`, `%SystemRoot%\System32\catroot2.old` (delete by hand once updates work) |

## Undos

- **Menu A tweaks** — choose the tweak again → `R` (Restore default).
- **Hibernation** — menu `B` → `7` (Enable hibernation).
- **Startup delay** — menu `B` → `8` (Restore default startup delay).
- **Registry changes** — double-click the matching `.reg` file in `regbak`.
- **Everything** — System Restore → pick the `Before Advanced System Care`
  point.

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
