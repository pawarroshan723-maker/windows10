#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fix EXE files not opening on Windows 10/11
.DESCRIPTION
    Repairs broken .exe association, removes UserChoice hijack,
    restores HKCR\exefile\shell\open\command, checks IFEO Debugger hijacks
#>

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  FIX EXE NOT OPENING - PowerShell Version" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

function Test-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Please run as Administrator! Right-click > Run as Administrator" -ForegroundColor Red
    pause
    exit 1
}

# Registry changes can fail independently. Stop on the first unexpected failure
# and do not announce success for a partially applied repair.
try {
    Write-Host "[1/5] Removing user overrides..." -ForegroundColor Yellow
    $overrides = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe",
        "HKCU:\Software\Classes\.exe",
        "HKCU:\Software\Classes\exefile"
    )
    foreach ($path in $overrides) {
        if (Test-Path -LiteralPath $path -ErrorAction Stop) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
        }
    }
    Write-Host "  OK - user overrides cleared" -ForegroundColor Green

    Write-Host "[2/5] Restoring core association..." -ForegroundColor Yellow
    cmd /c "assoc .exe=exefile" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "assoc failed with exit code $LASTEXITCODE" }
    cmd /c 'ftype exefile="%1" %*' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "ftype failed with exit code $LASTEXITCODE" }

    # Use a provider-qualified path: HKCR: is not a default PowerShell drive.
    $classesRoot = "Registry::HKEY_CLASSES_ROOT"
    New-Item -Path "$classesRoot\.exe" -Force -ErrorAction Stop | Out-Null
    Set-ItemProperty -Path "$classesRoot\.exe" -Name "(default)" -Value "exefile" -Force -ErrorAction Stop
    Set-ItemProperty -Path "$classesRoot\.exe" -Name "Content Type" -Value "application/x-msdownload" -Force -ErrorAction Stop

    New-Item -Path "$classesRoot\.exe\PersistentHandler" -Force -ErrorAction Stop | Out-Null
    Set-ItemProperty -Path "$classesRoot\.exe\PersistentHandler" -Name "(default)" -Value "{098f2470-bae0-11cd-b579-08002b30bfeb}" -Force -ErrorAction Stop

    New-Item -Path "$classesRoot\exefile\DefaultIcon" -Force -ErrorAction Stop | Out-Null
    New-Item -Path "$classesRoot\exefile\shell\open\command" -Force -ErrorAction Stop | Out-Null
    Set-ItemProperty -Path "$classesRoot\exefile" -Name "(default)" -Value "Application" -Force -ErrorAction Stop
    Set-ItemProperty -Path "$classesRoot\exefile\DefaultIcon" -Name "(default)" -Value "%1" -Force -ErrorAction Stop
    Set-ItemProperty -Path "$classesRoot\exefile\shell\open\command" -Name "(default)" -Value '"%1" %*' -Force -ErrorAction Stop
    Set-ItemProperty -Path "$classesRoot\exefile\shell\open\command" -Name "IsolatedCommand" -Value '"%1" %*' -Force -ErrorAction Stop

    # HKLM copy
    New-Item -Path "HKLM:\SOFTWARE\Classes\.exe\PersistentHandler" -Force -ErrorAction Stop | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\.exe" -Name "(default)" -Value "exefile" -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\.exe" -Name "Content Type" -Value "application/x-msdownload" -Force -ErrorAction Stop
    New-Item -Path "HKLM:\SOFTWARE\Classes\exefile\shell\open\command" -Force -ErrorAction Stop | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\exefile\shell\open\command" -Name "(default)" -Value '"%1" %*' -Force -ErrorAction Stop
} catch {
    Write-Host "  EXE association repair failed; changes may be partial: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host "  Core association commands completed. Verify EXE launch in the affected user profile." -ForegroundColor Green

Write-Host "[3/5] Checking IFEO Debugger hijacks..." -ForegroundColor Yellow
$ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
$found = Get-ChildItem $ifeoPath -ErrorAction SilentlyContinue | ForEach-Object {
    $debugger = Get-ItemProperty -Path $_.PSPath -Name Debugger -ErrorAction SilentlyContinue
    if ($debugger) {
        [PSCustomObject]@{
            Key = $_.PSChildName
            Debugger = $debugger.Debugger
            Path = $_.PSPath
        }
    }
}

if ($found) {
    Write-Host "  WARNING: Found IFEO Debugger hijacks:" -ForegroundColor Red
    $found | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Red
    $ans = Read-Host "Remove all Debugger values? (Y/N)"
    if ($ans -eq "Y" -or $ans -eq "y") {
        foreach ($item in $found) {
            Write-Host "  Removing Debugger from $($item.Key)" -ForegroundColor Yellow
            Remove-ItemProperty -Path $item.Path -Name Debugger -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  OK - IFEO cleaned" -ForegroundColor Green
    }
} else {
    Write-Host "  OK - No IFEO hijacks" -ForegroundColor Green
}

Write-Host "[4/5] Checking DisallowRun policies..." -ForegroundColor Yellow
$policies = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
)
foreach ($p in $policies) {
    if (Test-Path $p) {
        $val = Get-ItemProperty -Path $p -Name DisallowRun -ErrorAction SilentlyContinue
        if ($val) {
            Write-Host "  Found DisallowRun at $p - removing" -ForegroundColor Red
            Remove-ItemProperty -Path $p -Name DisallowRun -Force -ErrorAction SilentlyContinue
        }
    }
}
Write-Host "  OK - policies checked" -ForegroundColor Green

Write-Host "[5/5] Restarting Explorer..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Start-Process explorer
Write-Host "  OK - Explorer restarted" -ForegroundColor Green

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  FIX COMPLETE - Try opening .exe now" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "If still broken:"
Write-Host " 1. Restart PC"
Write-Host " 2. Run: sfc /scannow"
Write-Host " 3. Run: DISM /Online /Cleanup-Image /RestoreHealth"
Write-Host " 4. Full malware scan"
Write-Host ""
pause
