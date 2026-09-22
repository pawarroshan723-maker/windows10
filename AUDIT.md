# Deep Audit — `cleanup_advanced.bat` (Advanced System Care v2.9)

- **Repo:** `pawarroshan723-maker/windows10` (branch `arena/01a0b999-windows10`)
- **Scope:** entire repo = `cleanup_advanced.bat` (1,632 lines, ~68 KB) + `README.md` (11 bytes)
- **Date:** 2026-09-19 · **Method:** full line-by-line read + targeted verification (`grep`, tail inspection, control-flow tracing, batch errorlevel semantics)
- **Bottom line:** the script is **benign (no malware indicators)** and Structurally decent, but it has **2 critical functional bugs**, several **high-risk safety gaps**, and a tail-corruption artifact that proves the file was never linted/tested end-to-end. **Do not distribute as-is; fix P0s before any real use.**

> **Status (2026-09-19): fixes APPLIED.** All P0 and P1 items plus most P2/P3
> items were fixed in **v3.0** (`cleanup_advanced.bat`, 1,907 lines).
> Applied: P0-1, P0-2, P0-3, P0-4, P1-1, P1-2, P1-3, P1-4, P1-5, P1-6,
> P2-1, P2-2, P2-3, P2-4, P2-5, P2-6 (message only), P2-7 (per-service
> confirm in menu 7 + delayed-auto preserved + Defender skipped when
> third-party AV active; REPAIR ALL still one-click), P2-8, P2-9, P2-10,
> P2-11, P2-12, P2-13 (TS now used; 2 PowerShell launches removed),
> P3-1, P3-2, P3-3, P3-4, P3-5, P3-7 (quoting). Left as-is: P3-6 (ScanHealth
> kept — it is informative). `README.md` rewritten with usage/safety/undo docs.
> Verification: all 50 patch anchors matched exactly once, CRLF preserved,
> cmd block-balance simulation clean (0/0, never negative), every `goto`
> target exists, no `EnableCMD`/`FIclick`/tail corruption remnants.
> **Not possible in this sandbox: a real Windows test run** — review the
> diff (`git diff`) before first use on a real machine.

---

## 1. What this script is

An interactive, menu-driven Windows 10/11 maintenance batch file (requires Administrator):

| Area | Options |
|---|---|
| Cleanup | QUICK (6 tasks) / FULL (10) / DEEP (13: + DISM, Prefetch, Delivery Optimization) |
| Repair | SFC+DISM suite · Network stack reset · Windows Update reset · Service health (23 services) · 8 Registry fixes |
| Quick fixes | Printer · Audio · Bluetooth · Store (WSReset) · Time sync · Search indexer · CHKDSK schedule · System Restore wizard · RAM test |
| Tweaks (Apply/Restore) | Photo Viewer · Extensions · Hidden files · Take Ownership · Shortcut arrows · Bing off · Menu speed · GameDVR off · Lock screen |
| Optimize | Defrag/TRIM · Power plans · Startup delay · Explorer restart · Hibernation off |
| Meta | One-click REPAIR ALL · Disk overview · Single log file · DISM AUTO-HEAL (internet check → repair → retry) |

---

## 2. Verdict

| Question | Answer |
|---|---|
| Malicious? | **No.** No exfiltration, no downloads, no `IEX`/`DownloadString`/Base64, no persistence, no credential access. All 13 PowerShell calls are trivial one-liners. Network use = `ping`, `w32tm`, DISM only. |
| Safe to run today? | **Mostly, with caveats** — on Win10/11, run as a same-user admin, answer prompts carefully (see P0-1: "N" doesn't stop anything). |
| Safe to share/recommend? | **No — fix P0s + P1s first.** The broken confirmations alone make every destructive path one keypress away from running regardless of user choice. |
| Code health | 6/10. Good structure/comments/UX; unreliable error propagation; zero tests; corrupted tail; empty README. |

---

## 3. P0 — Critical (fix before anything else)

### P0-1. `:confirm` always returns 0 — EVERY Yes/No prompt is broken (L1044–1051)

```bat
:confirm
echo   %C_WARN%?%C_RESET% %~1
choice /c yn /n /m "   Continue [Y/N]: "
if errorlevel 2 (
    echo   %C_DIM%Cancelled.%C_RESET%        ← resets %errorlevel% to 0
    >>"%LOG_FILE%" echo ... user cancelled  ← stays 0
)
exit /b %errorlevel%                           ← always 0, never 2
```

`echo` clobbers `%errorlevel%`, so the subroutine returns 0 whether the user pressed Y or N.
Every caller does `if errorlevel 2 goto MENU` — which **never triggers**. "Cancelled." prints, then the operation **runs anyway**.

**Blast radius:** SFC suite, network reset, WU reset, REPAIR ALL, all service repairs, all 8 registry fixes, printer fix, CHKDSK schedule (!), RAM-test reboot (!!), drive optimize, hibernation off. ~15 call sites.

**Fix:**
```bat
choice /c yn /n /m "   Continue [Y/N]: "
set "CONFIRM_RC=%errorlevel%"
if %CONFIRM_RC%==2 (
    echo   %C_DIM%Cancelled.%C_RESET%
    >>"%LOG_FILE%" echo [%TIME:~0,8%] INFO - user cancelled: %~1
)
exit /b %CONFIRM_RC%
```

### P0-2. "Command Prompt disabled" fix targets a non-existent value (L1463, 1465, 1472)

Uses value name **`EnableCMD`** — the real policy value is **`DisableCMD`**
(`HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System\DisableCMD`, plus the
`HKCU\Software\Policies\Microsoft\Windows\System\DisableCMD` path, which isn't covered at all).
Result: the fix **always reports "was not blocked" even on a blocked machine**. All 7 sibling registry fixes use correct names — only CMD is wrong.

**Fix:** rename to `DisableCMD` in both `r_del_policy` calls + log line, and add the `Software\Policies\Microsoft\Windows\System` path.

### P0-3. No safety net: zero restore points, zero registry backups

The script mutates services, `SoftwareDistribution`, `catroot2`, ~30 registry values, power/hibernation state — and the only "backup" reference in the file is a help string telling the *user* to pick a restore point (L882). There is no `Checkpoint-Computer` / `reg export` anywhere (verified by search).

**Fix:** at session start (after elevation), attempt a restore point and `reg export` of touched hives; on failure, warn loudly but allow continue:
```bat
powershell -NoProfile -Command "Checkpoint-Computer -Description 'Before Advanced System Care' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop"
```

### P0-4. Unguarded mass `del / rd` on environment variables

26 deletion commands interpolate `%TEMP%`, `%SystemRoot%`, `%SystemDrive%`, `%ProgramData%`, `%APPDATA%`, `%LOCALAPPDATA%` with **no `if defined` / `if exist` guard** (L1102–1315). If any variable is empty (corrupt env, SYSTEM context, WinPE), e.g. `del /q /f /s "%TEMP%\*"` becomes `del /q /f /s "\*"` — **mass delete from the drive root, silently** (`>nul 2>&1` hides it).

Probability low, impact catastrophic — classic must-guard. **Fix:** guard helper, e.g.
```bat
if not defined TEMP exit /b 1
if not exist "%TEMP%\*" exit /b 0
```
for every destructive path. At minimum guard `%TEMP%`, `%SystemRoot%`, `%SystemDrive%` (used in `rd`).

---

## 4. P1 — High

### P1-1. HKCU writes land in the wrong profile when elevated as a different admin (26 `HKCU` refs)
All HKCU tweaks/fixes (Photo Viewer, extensions, hidden files, Bing, menu delay, GameDVR, startup delay, TaskMgr/CMD/regedit/NoRun…​) write to **the admin account's hive**, not the standard user's, when UAC elevation uses different credentials. Symptom: "tweak applied successfully" but nothing changes for the user. Same for `%APPDATA%`/`%LOCALAPPDATA%` cleanups (Recent, thumbs, dumps, D3D) — while `t_user_temp` correctly iterates all profiles, the others clean only the admin profile. **Inconsistent + silent.**
**Fix:** detect `HKCU ≠ launching user` (compare `%USERNAME%` vs original via `query session` / `powershell Get-Process explorer`), warn, and ideally write through `HKEY_USERS\<SID>`.

### P1-2. `rd /s /q "%SystemDrive%\$Recycle.bin"` (L1119) — dangerous overkill
`Clear-RecycleBin -Force` (same subroutine) already empties **all drives'** bins properly. The `rd` then deletes the system folder itself **for every user on the box** without per-user consent, and only on the system drive. **Fix:** delete the `rd` line.

### P1-3. Explorer restart spawns an **elevated** Explorer (L1293–1298)
`taskkill explorer.exe` + `start explorer.exe` from an elevated console relaunches the shell with admin rights → UAC virtualization weirdness, broken drag-drop/Store, permission-loop dialogs. Windows also auto-restarts Explorer anyway, risking a duplicate instance.
**Fix:** warn, or relaunch as the logged-on user (scheduled-task / `runas /trustlevel` trick); at minimum document.

### P1-4. "Take Ownership" context menu ships with no warning
One right-click lets users seize `C:\Windows\System32` files from TrustedInstaller and `icacls /grant Administrators:F` them — a classic way to break SFC/Windows Update. The script prints only a success line.
**Fix:** confirm prompt + warning that system files must never be "taken".

### P1-5. WU reset is destructive (L1244–1249)
Deletes the **entire** `SoftwareDistribution` (history + DataStore, not just `Download`) and `catroot2`, with only a rename-fallback leaving `*.old` GBs behind. No backup (see P0-3).
**Fix:** restore-point first; prefer rename-over-delete; report `.old` leftovers.

### P1-6. Internet check = ICMP ping only (L1180–1190)
`ping microsoft.com` → fallback `ping 8.8.8.8`, matching `TTL=`. Corporate/strict firewalls that block ICMP but allow HTTP cause **false "NO INTERNET"** → DISM repair, time sync, and AUTO-HEAL wrongly skipped.
**Fix:** add an HTTP fallback: `powershell Test-NetConnection -ComputerName www.microsoft.com -Port 443` (fast, no ICMP).

---

## 5. P2 — Medium

| # | Finding | Lines | Impact / Fix |
|---|---|---|---|
| P2-1 | `exit /b %errorlevel%` **after `echo`** always returns 0: `t_startdelay`, `t_hiboff`, `t_storereset` | 1290, 1305, 1370 | Real failures reported as OK → save code before echoing |
| P2-2 | `t_powerhigh`/`t_powerbal` return `getactivescheme`'s code, not `setactive`'s | 1277, 1283 | Failed plan-switch reports OK → save `setactive` code first |
| P2-3 | Log **overwritten** every session (`> "%LOG_FILE%"`) | 114 | No history/audit trail → append + per-run headers, rotate |
| P2-4 | `REBOOT_ADVISED` cleared in `:start_run` | 1059 | Run A advises reboot, user runs B, advice vanishes → clear once per session, not per run |
| P2-5 | `start /wait wsreset.exe` run **elevated** | 1365–1370 | Resets the admin's Store cache (see P1-1); WSReset is flaky elevated; `exit` code is `start`'s, then clobbered by echo (P2-1) |
| P2-6 | CHKDSK `/f /r` time "1–2+ h" understated; no SSD/HDD split | ~1414 | 4 TB HDD `/r` can take 8+ h; SSDs don't need `/r` (wear) → detect media type via PowerShell, adjust flags/message |
| P2-7 | Service auto-fix re-enables **intentionally-disabled** services (Spooler, WSearch, Themes…), converts Delayed-Auto → Auto, and "fixes" WinDefend even when 3rd-party AV owns protection | 356–470 | Per-service confirm or skip-list; preserve `delayed-auto`; skip WinDefend/MpsSvc when 3rd-party protection registered |
| P2-8 | `t_repair` ignores `REBOOT_PENDING` while `t_dism` honors it | 1550+, 1575+ | Inconsistent; RestoreHealth also fails with pending reboot → check in both |
| P2-9 | Power-plan GUIDs may not exist (Modern Standby hides High Performance) | 1273–1283 | Unhandled `powercfg` failure → check code (needs P2-2 fix), print fallback hint |
| P2-10 | `t_recent` wipes jump-list/recent-docs history without framing it as privacy deletion; per-user inconsistency (see P1-1) | 1131 | Users expect space-saving, lose history → reword + confirm, or move out of default runs |
| P2-11 | Prefetch `*.pf` wipe in DEEP default | 1174 | Microsoft: Prefetch is self-maintaining (128-file cap); wiping slows launches for ~MB freed. Disclosure exists (good) but shouldn't be default → drop or opt-in |
| P2-12 | SFC exit-code check unreliable | 1196–1210 | `sfc` exit codes are poorly documented; "unable to fix" can still return 0 → parse output (`findstr "found corrupt"`) in addition to code |
| P2-13 | Dead `TS` variable + 13× `powershell.exe` launches (~1–2 s each) | 98 | ~15–25 s of pure interpreter spin-up per session (5 launches in start+summary alone) → use `%DATE%_%TIME%` or batch the queries |

---

## 6. P3 — Low / hygiene

| # | Finding | Lines |
|---|---|---|
| P3-1 | **Tail corruption:** duplicate `exit /b %DISM_RC%` + stray `] AUTO-HEAL retry FAILED …` line (missing `>>log echo [` prefix). Dead code (after `exit`), but proves no end-to-end test | 1629–1632 |
| P3-2 | Typo `QUICK FIclick fixes for common problems` | 803 |
| P3-3 | One-way doors: StartupDelay and Hibernation have Apply but no Restore toggle (every Tweak has one) | 1287, 1300 |
| P3-4 | Claims "~20 critical services", actually probes **23** | header vs 23× `svc_probe` |
| P3-5 | `README.md` = `# windows10`; no usage, warnings, requirements, license; single squashed commit "Add files via upload" | repo root |
| P3-6 | `ScanHealth` before every `RestoreHealth` wastes 5–15 min (RestoreHealth scans anyway) | `t_repair` |
| P3-7 | Minor: elevation-cancel does bare `exit /b` (code 0); `SYS_DRIVE`/`FREE_*` unquoted in PowerShell; `sc config`/`net start` unquoted; `assoc`/`ftype` EXE repair is partial (misses `HKLM\…\exefile\shell\open\command`, `HKCU\Software\Classes\.exe` hijacks, no backup) | 40–56, SUMMARY, svc_fixone, `r_exe` |

---

## 7. What's done well (credit where due)

- **Honest in-file docs** — Prefetch slowdown, hibernation/Fast-Startup tradeoff, Recent-docs privacy note, "locked files skipped", "freed space is approximate" are all disclosed. Rare for this genre.
- **Correct `choice` → `errorlevel` reverse mapping** (14 options incl. `R`) and the `call :svc_fixone %%SVCBAD_%%i%%` double-expansion trick both check out.
- **WU cache task preserves service state** (only restarts what was running) — genuinely careful.
- **DISM design is sound**: `StartComponentCleanup` *without* `/ResetBase` (keeps update uninstall), pending-reboot skip, failure flag file, AUTO-HEAL pipeline.
- **Defrag uses `/O`** (TRIM on SSD / defrag on HDD) — the correct modern switch.
- **No `EnableDelayedExpansion`** (avoids `!` path bugs), all destructive paths quoted, `-NoProfile` on every PowerShell call.
- **Compatibility choices** (Clear-RecycleBin, delivery-opt cache, `defrag /O`) target Win10 1803+ correctly.

---

## 8. Suggested fix order (smallest diffs, biggest risk reduction)

1. `:confirm` save-code fix (P0-1) — 3 lines, fixes 15 prompts.
2. `EnableCMD` → `DisableCMD` (P0-2) — 3 lines.
3. Env-var guards on all `del`/`rd` (P0-4) + remove `$Recycle.bin` `rd` (P1-2).
4. Restore-point + `reg export` at session start (P0-3).
5. Save-before-echo in P2-1/P2-2 subs (5 small edits).
6. HKCU/elevation warning (P1-1) + log-append mode (P2-3).
7. Tail cleanup + typo (P3-1/P3-2) — 4 lines.
8. README + usage/warnings + license (P3-5).

## 9. If you run it before fixes

1. Run as an **admin account you normally log in with** (not "Run as" a different admin) — avoids P1-1.
2. Treat **every Y/N as Y** (P0-1) — close the window (`X`) instead of pressing N to abort.
3. Skip menu `8→3` (CMD fix — does nothing) and avoid `B→6`/`B→4` unless you accept one-way changes.
4. Create a **manual restore point** first (`rstrui.exe` → Create) — covers P0-3.
5. Close installers/editors first — Temp wipe can break in-progress installs.

---

*Audit artifacts: `cleanup_advanced.bat` L1044–1051 (confirm), L1463–1472 (CMD), L98 (TS), L803 (typo), L1629–1632 (tail), L1051/1277/1283/1290/1305/1370 (errorlevel), L114 (log overwrite), L1180–1190 (ping check), 23× `svc_probe`, 26× `HKCU`, 13× `powershell`.*
