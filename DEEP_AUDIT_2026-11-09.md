# Deeper audit — Windows maintenance and EXE repair scripts

**Snapshot:** commit `f154f595d19d34b74c37a78b2a240d19acb6d4a0`, branch `arena/64eda213-windows10`

**Date:** 2026-11-09

**Scope:** all eight tracked files, with emphasis on privileged operations, control flow, recovery, and the four EXE repair alternatives. This is a static review; findings below are code-derived, not claims of a successful exploit or Windows test.

## Executive assessment

**Do not enable Auto-Care or use the repair tools on a production machine as-is.** The scheduled task can execute a user-writable script as SYSTEM; several menus execute actions other than the one selected; the shared repair pipeline can execute repeatedly; and the advertised recovery mechanisms are incomplete. The EXE recovery tools can report success after failed writes and can remove legitimate security or debugging configuration.

If Auto-Care was already enabled, inspect `ASC_AutoCare` in Task Scheduler, check the task's action and the ACLs of its executable and parent directories, and disable/remove the task until the script is installed in a protected location. Back up relevant data before attempting repairs. A System Restore point is not a substitute for a data backup.

The existing `AUDIT.md` is a historical report about v2.9/v3.0. Its original scope, line numbers, verdict and "fixes applied" status do not establish that the current v3.2.4 code or the newer EXE repair files are safe. In particular, its broad claims about backup coverage and unattended behavior should not be relied on for the current snapshot.

## Findings

### Critical — SYSTEM task executes the script at its current, potentially writable location

**Evidence:** `cleanup_advanced.bat:1477-1495` registers `%~f0` as the task action with `/ru SYSTEM`; `README.md` recommends running the downloaded script directly and does not require a protected installation directory.

**Impact:** If a less-privileged user can modify the script or replace it through permissions on a parent directory, the next scheduled execution runs their modified commands as SYSTEM. The practical exploitability depends on the actual file and directory ACLs; a script in a standard user's own Downloads or Desktop is a typical risky deployment. Task Scheduler's own task ACL does not protect the action file.

**Recommendation:** Disable this feature until installation copies the script and any dependencies into an administrator-owned, non-user-writable location, verifies both file and parent ACLs, and registers that protected path. Refuse unsafe locations and avoid running with SYSTEM unless genuinely necessary. Test with a separate standard-user account.

### High — DNS menu falls through to public DNS, including after choosing reset or flush

**Evidence:** `cleanup_advanced.bat:1131-1136, 1144-1163`. Selection 3 calls `:dns_flush`, selection 2 may call `:dns_auto`, and execution then unconditionally calls `:dns_public`. The helper calls can also change `errorlevel`, so subsequent tests do not reliably refer to the original selection. There is no confirmation before `netsh` changes DNS.

**Impact:** Choosing “flush” or “automatic” can end by replacing the detected adapter's DNS servers with 8.8.8.8 and 1.1.1.1. This can break VPN/domain/split DNS, change name-resolution privacy, and contradict the user's explicit choice. Reset-to-DHCP is also not a restoration of previously configured static DNS.

**Recommendation:** Dispatch with mutually exclusive branches/labels using the captured selection; request confirmation before changing DNS; capture and offer to restore the actual previous configuration. Check every `netsh` result.

### High — Adapter menu enables disabled adapters even after declining restart

**Evidence:** `cleanup_advanced.bat:1197-1215`. Option 2 calls `:net_wireless`, then unconditionally calls `:net_enable`; a “No” returned from the wireless confirmation only leaves the helper, not the menu handler.

**Impact:** Selecting restart, including declining it, can enable every disabled adapter. This may activate intentionally disabled physical, virtual, or corporate adapters and alter connectivity/security posture.

**Recommendation:** Make selection dispatch mutually exclusive; require explicit confirmation and ideally per-adapter selection for enablement. Verify the selected target and check cmdlet errors.

### High — Repair-all control flow repeats work and retains a subroutine frame

**Evidence:** `cleanup_advanced.bat:419-434, 469, 1581-1586, 1600-1607`. `call :pipeline_all` enters a subroutine that jumps to `:SUMMARY`, rather than returning to its caller. In auto mode, `exit /b 0` at `:END_AUTO` returns to the line after `call :pipeline_all` at line 432, which falls straight into `:pipeline_all` and runs the entire pipeline a second time. In manual repair-all, `:SUMMARY` enters the menu without returning; a later `:END` exits that call frame and falls through to `:RUN_AUTO`, potentially running further maintenance unexpectedly.

**Impact:** Repeated, unrequested service reconfiguration, deletion of caches/dumps and expensive repair/optimization work. Scheduler success also cannot reliably represent one pipeline execution.

**Recommendation:** Separate pipeline execution from UI: have `:pipeline_all` return normally, then explicitly branch to a summary or auto exit, with no fall-through into entry points. Propagate aggregate failures to the scheduled task exit code. Test manual and unattended control flow with mocked commands and count each phase.

### High — Scheduled runs can silently change intentionally disabled services

**Evidence:** `cleanup_advanced.bat:434-448, 514-536, 565-584, 620-632`. Repair-all and `-auto` set `SVC_AUTO` and reconfigure marked services without per-service consent. The fixed expectations include optional or environment-dependent services such as Spooler, Windows Search, Netman and Defender-related services. `sc config` failures are suppressed.

**Impact:** Weekly SYSTEM runs can undo deliberate hardening, security or performance decisions and alter service start types on otherwise healthy machines. A single initial scheduling confirmation does not explain individual service changes.

**Recommendation:** Make scheduled maintenance non-invasive by default; report service differences instead of changing them. Require explicit opt-in per service with saved original configuration and check each operation's result. Do not treat one hard-coded baseline as authoritative for all Windows versions and roles.

### High — Registry backups are incomplete, overwritten and not full undo

**Evidence:** `cleanup_advanced.bat:224-253, 1686-1689`; writes include `:r_exe` at `2129-2174`, policy fixes and `:t_filterkeys` at `1359-1362`. The export list omits, among others, `HKLM\SOFTWARE\Classes\.exe`, `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies`, `HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR` and accessibility keys. `reg export ... /y` replaces the same filenames on every launch, including before later sessions. Export failures are suppressed and only the successful count is logged. None of the standalone `fix_exe.*` files makes a backup.

**Impact:** A second launch can overwrite the pre-change snapshot with already-modified values. Re-importing an export merges registry content and does not generally remove values or keys created after export, nor recreate an originally absent key's absence. The README's “every key” and “double-click ... to restore that key” assurances are materially too broad. A restore-point attempt can fail, be throttled or be unavailable, and is not verified as a usable rollback.

**Recommendation:** Capture every affected value, type, key existence, ACL and intended view in a timestamped, access-controlled backup; report failures and offer to abort before mutations. Provide a tested rollback that also removes newly created entries. Document limitations and keep independent system/data backups.

### High — Windows Update reset deletes previous backups and can leave a partial reset

**Evidence:** `cleanup_advanced.bat:1852-1908`, especially `1871` and `1882`. Despite comments and README claiming `.old` folders are only removed manually, each reset first recursively deletes the previous `SoftwareDistribution.old` and `catroot2.old`. A failed second rename after a successful first rename goes to service restart without undoing the first rename; service stop/restart failures are ignored.

**Impact:** Repeating the operation destroys previous recovery copies. A failure can leave only one component renamed and services in unexpected states, even though the operation says it aborted cleanly.

**Recommendation:** Never overwrite/delete old copies implicitly; use unique names and validate free space and all service transitions. Track each completed step and explicitly report/offer rollback on partial failure. Update the documentation.

### High — EXE repair can break legitimate controls and falsely declare success

**Evidence:** `fix_exe.bat:44-78, 91-123, 135-150`; `fix_exe.ps1:27-58, 73-102`; `fix_exe.vbs:19-48`; `fix_exe.reg:7-11`; `cleanup_advanced.bat:2133-2174`.

**Impact:** The tools delete entire per-user class subtrees and remove `DisallowRun`, potentially undoing intentional application restrictions. The batch and PowerShell tools offer bulk removal of IFEO Debugger values, which may include legitimate debuggers, accessibility, diagnostics or security products; the batch text's “will NOT delete legitimate entries” is false. Most failed writes/deletes are suppressed or ignored before printing success. The VBS `RegDelete` calls are not recursive, so keys with subkeys may remain while errors are ignored. The fixes run HKCU operations under the elevated identity, which may not be the affected user.

**Recommendation:** Export exact affected keys first; show a per-key preview and distinguish policy/legitimate IFEO from suspicious entries. Never bulk-delete without explicit informed selection; do not remove managed policy automatically. Check every change and read back the effective association under the affected user's SID; make failure visible and return a nonzero status.

### High — PowerShell EXE fix relies on a registry drive not created by default

**Evidence:** `fix_exe.ps1:37-49`. It uses `HKCR:` repeatedly without creating a PowerShell drive for `HKEY_CLASSES_ROOT`. Normal Windows PowerShell sessions provide `HKLM:` and `HKCU:` by default, not necessarily `HKCR:`.

**Impact:** HKCR operations can fail while the script continues and displays “core association restored.” Some separate HKLM writes may still succeed, leaving a partial repair. The default icon key is also not explicitly created before writing it.

**Recommendation:** Use explicit provider paths or create/check the registry drive, create all required keys, treat errors as terminating, and verify written values. Exercise both clean and corrupted associations in a Windows VM.

### Medium — Scheduler always chooses Sunday; failure status is masked

**Evidence:** `cleanup_advanced.bat:1485-1493, 1581-1586`. After the descending `if errorlevel` assignments, `set "ASC_DAY=SUN"` is unconditional, so every selection schedules Sunday. Auto mode always exits 0 at summary, regardless of `FAIL_NUM`.

**Impact:** Maintenance runs on the wrong day and monitoring can mark a failed run successful.

**Recommendation:** Capture `choice` once and map it to exactly one day; return a meaningful nonzero exit status on failure and distinguish skips from failures.

### Medium — “Guarded” temp deletion does not validate the target

**Evidence:** `cleanup_advanced.bat:1680-1703` tests only whether `TEMP` and `SystemDrive` are nonempty, then recursively deletes the supplied `%TEMP%` contents and all matching profile temp directories. Quick cleanup, including unattended repair-all, invokes it at `333-341` and `450-453` without a separate cleanup confirmation.

**Impact:** A nonempty but incorrect or attacker-controlled `TEMP` can point at unrelated data; the guard is not a path safety check. The code also deletes files from other users' temp directories and may disrupt active installations or destroy unsaved/transient work. Reparse-point and permissions behavior needs Windows-specific validation rather than an assumption that paths cannot escape the intended tree.

**Recommendation:** Resolve canonical targets; reject roots, unexpected locations and unsafe reparse points; restrict cleanup to explicitly selected users and avoid active workloads. Provide a preview and separate consent, especially for unattended all-profile cleanup.

### Medium — Cleanup and repair success reporting is unreliable

**Evidence:** `cleanup_advanced.bat:1711-1716, 1734-1751, 1785-1788, 1835-1849, 1893-1909, 2178-2184`; `fix_exe.bat:45-53, 143-150`; `fix_exe.vbs:19-48`. Several commands discard errors and unconditionally return success. Windows Update cache cleaning stops services using `net stop /y` and restarts only selected services, not necessarily dependents stopped by `/y`. The summary counts skipped tasks as completed and may say “all clean.”

**Impact:** Logs and UI can indicate a healthy system when deletion, repairs, service restoration, or registry writes failed; dependent services may remain stopped. This matters particularly for unattended runs.

**Recommendation:** Capture exit codes immediately, record per-step stderr and postconditions, count skipped/partial/failed separately, and surface service restoration failures. Test service dependencies and deliberate access-denied cases.

### Medium — Accessibility reset implementation and backup need Windows validation

**Evidence:** `cleanup_advanced.bat:1349-1366` writes `FilterKeysActive`, `StickyKeysActive`, and `ToggleKeysActive` DWORDs and always announces success; accessibility paths are absent from the export list. No API call or readback verifies the effective accessibility settings.

**Impact:** Users may believe accessibility features were disabled when the active Windows settings did not change; conversely, modifying accessibility settings without a restorable prior state can inconvenience users who depend on them. The prior release note alone does not demonstrate correct behavior.

**Recommendation:** Use documented Windows accessibility APIs or verify the actual version-specific settings and notification mechanism; test on supported Windows releases, preserve prior settings, and check effective state.

### Medium — One-click cleanup removes diagnostics before crash analysis

**Evidence:** `cleanup_advanced.bat:344-355, 450-460, 1760-1767` deletes user crash dumps, system minidumps and `MEMORY.DMP`, whereas menu 9 offers crash diagnostics (`1239` onward).

**Impact:** FULL/DEEP/repair-all and weekly Auto-Care can erase evidence needed to investigate an unresolved crash; System Restore does not restore these files.

**Recommendation:** Exclude dumps by default, or make deletion an explicit separate opt-in with size/age information and a clear warning.

### Low — Some documented safeguards and diagnostics are overstated

**Evidence:** `README.md` safety/undo and troubleshooting sections; `cleanup_advanced.bat:1223-1228, 1287-1295, 1306-1316, 198, 228-235`. Disk health uses `Get-PhysicalDisk` health status, not a comprehensive SMART interpretation; CPU output is accumulated process CPU time rather than current utilization; an old battery report can be mistaken for a newly generated one; log “rotation” deletes the prior log; and the manual restore-point instruction points to `rstrui.exe`, which opens restoration rather than the usual create-restore-point UI.

**Recommendation:** Describe actual measurements and limitations, verify tool success and output freshness, preserve or explicitly describe log retention, and correct the restore-point instructions.

## Verification performed and limitations

- Read the maintenance control flow, cleanup and recovery routines, scheduler, troubleshooting, EXE repair variants and documentation; traced the menu dispatch and `call`/`goto` return paths statically.
- A small Python scan found 2,379 lines, 134 labels, no duplicate labels and no missing colon-prefixed `call`/`goto` targets. This is not a batch parser and does **not** prove correctness. Targeted searches confirmed the fall-through dispatch and unconditional Sunday assignment.
- This environment has neither Windows `cmd.exe`, PowerShell nor Wine. No scripts were executed against a Windows registry, services, filesystem, Task Scheduler or actual Windows versions. In particular, exact task-action quoting, registry view/association behavior, reparse-point handling, restore-point throttling and accessibility effects require isolated Windows VM tests.
- No functional code was changed in this audit. The absence of an identified malicious payload is not proof of safety or of the absence of vulnerabilities.

## Suggested remediation and regression tests

1. Disable SYSTEM scheduling until the action and all its parent directories are protected from unprivileged modification. Test ACLs with a standard user and inspect the registered action.
2. Fix pipeline returns and all menu dispatch with mutually exclusive branches. In a disposable Windows VM, stub destructive commands and assert exactly one chosen action and one pipeline pass; test cancellation and every day choice.
3. Remove automatic service mutation and dump deletion from unattended defaults; add explicit, reversible opt-ins and verify service state restoration.
4. Implement timestamped, complete backups and tested rollback; exercise missing keys, access denied, repeated sessions and partial WU reset failures.
5. Harden EXE repair: per-entry IFEO/policy decisions, explicit target user and registry view, checked writes/readback, and real nonzero exit codes. Test each variant on snapshots with legitimate IFEO entries and deliberately broken associations.
6. Add Windows CI or VM-based tests for command failures, non-English output, paths containing spaces/apostrophes, UAC with a different admin account, locked files, and Task Scheduler status. Never run destructive integration tests on the host.
