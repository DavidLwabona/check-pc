<#
.SYNOPSIS
    optimize-pc: Safe remediation & optimization script for check-pc findings.
.DESCRIPTION
    Provides targeted, reversible optimizations for power management, startup hygiene,
    dual-boot Linux recovery partition protection, and background National Instruments services.
#>
[CmdletBinding()]
param(
    [switch]$SetBalancedPowerPlan,
    [switch]$CleanOrphanStartup,
    [switch]$DisableNIServices,
    [switch]$RestoreNIServices,
    [switch]$HideLinuxRecoveryDrive,
    [switch]$DisableUnusedBloat,
    [switch]$UpdateSafePackages,
    [switch]$UpgradeSoftwareStack
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not ($SetBalancedPowerPlan -or $CleanOrphanStartup -or $DisableNIServices -or $RestoreNIServices -or $HideLinuxRecoveryDrive -or $DisableUnusedBloat -or $UpdateSafePackages -or $UpgradeSoftwareStack)) {
    Write-Host ""
    Write-Host "  OPTIMIZE-PC // Available Remediation Flags" -ForegroundColor Cyan
    Write-Host "  ------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  .\optimize-pc.cmd -SetBalancedPowerPlan    # Switch from High Performance to Balanced (Intel 12th Gen P+E optimal)"
    Write-Host "  .\optimize-pc.cmd -CleanOrphanStartup      # Remove empty/orphaned HKCU Run registry entries (e.g. GalaxyClient)"
    Write-Host "  .\optimize-pc.cmd -DisableNIServices       # [Admin] Stop NI background web servers (port 8080/3582) & set Manual"
    Write-Host "  .\optimize-pc.cmd -RestoreNIServices       # [Admin] Start NI background services for LabVIEW/Multisim sessions"
    Write-Host "  .\optimize-pc.cmd -HideLinuxRecoveryDrive  # [Admin] Safely unmount D: letter from Pop!_OS /recovery partition"
    Write-Host "  .\optimize-pc.cmd -DisableUnusedBloat      # [Admin] Disable Eraser & TickTick autostart + stop SamsungMagicianSVC"
    Write-Host "  .\optimize-pc.cmd -UpdateSafePackages      # [Admin] Pin qBittorrent 5.1.0 & upgrade vetted security/utility apps"
    Write-Host "  .\optimize-pc.cmd -UpgradeSoftwareStack    # [Admin] Remove Lenovo Now/Legion Arena & install Legion Toolkit + KeePassXC"
    Write-Host ""
    return
}

if ($SetBalancedPowerPlan) {
    Write-Host "[*] Switching active Windows Power Plan to Balanced (381b4222-f694-41f0-9685-ff5bb260df2e)..." -ForegroundColor Cyan
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    $active = (powercfg /getactivescheme) -join " "
    Write-Host "    Active Scheme: $active" -ForegroundColor Green
}

if ($CleanOrphanStartup) {
    Write-Host "[*] Scanning HKCU:\Software\Microsoft\Windows\CurrentVersion\Run for empty/orphaned entries..." -ForegroundColor Cyan
    $runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $props = (Get-ItemProperty $runPath).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }
    $removed = 0
    foreach ($p in $props) {
        if ([string]::IsNullOrWhiteSpace([string]$p.Value)) {
            Write-Host "    Removing orphaned empty startup entry: '$($p.Name)'" -ForegroundColor Yellow
            Remove-ItemProperty -Path $runPath -Name $p.Name -ErrorAction SilentlyContinue
            $removed++
        }
    }
    if ($removed -eq 0) {
        Write-Host "    No empty/orphaned HKCU startup entries found." -ForegroundColor Green
    } else {
        Write-Host "    Cleaned $removed orphaned startup entry(s)." -ForegroundColor Green
    }
}

$needsAdmin = ($DisableNIServices -or $RestoreNIServices -or $HideLinuxRecoveryDrive -or $DisableUnusedBloat -or $UpdateSafePackages -or $UpgradeSoftwareStack)
if ($needsAdmin -and -not $isAdmin) {
    Write-Host "[*] Administrator privileges are required for the selected flags. Requesting UAC elevation..." -ForegroundColor Yellow
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($SetBalancedPowerPlan)   { $argList += "-SetBalancedPowerPlan" }
    if ($CleanOrphanStartup)     { $argList += "-CleanOrphanStartup" }
    if ($DisableNIServices)      { $argList += "-DisableNIServices" }
    if ($RestoreNIServices)      { $argList += "-RestoreNIServices" }
    if ($HideLinuxRecoveryDrive) { $argList += "-HideLinuxRecoveryDrive" }
    if ($DisableUnusedBloat)     { $argList += "-DisableUnusedBloat" }
    if ($UpdateSafePackages)     { $argList += "-UpdateSafePackages" }
    if ($UpgradeSoftwareStack)   { $argList += "-UpgradeSoftwareStack" }
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ($argList -join " ") -Wait
        return
    } catch {
        Write-Warning "Could not auto-elevate from this session ($($_.Exception.Message)). Please run this command in an Administrator PowerShell window or your interactive VS Code terminal."
        return
    }
}

if ($DisableNIServices) {
    $niSvcs = Get-Service | Where-Object { $_.DisplayName -match '^NI ' -or $_.Name -match '^(NI|lkads|lktsrv|mxssvr)' }
    foreach ($s in $niSvcs) {
        Write-Host "    Setting $($s.Name) ($($s.DisplayName)) -> Manual & Stopped" -ForegroundColor Yellow
        Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $s.Name -StartupType Manual -ErrorAction SilentlyContinue
    }
    Write-Host "    National Instruments services set to Manual and stopped." -ForegroundColor Green
}

if ($RestoreNIServices) {
    $niSvcs = Get-Service | Where-Object { $_.DisplayName -match '^NI ' -or $_.Name -match '^(NI|lkads|lktsrv|mxssvr)' }
    foreach ($s in $niSvcs) {
        Write-Host "    Starting $($s.Name) ($($s.DisplayName))..." -ForegroundColor Cyan
        Start-Service -Name $s.Name -ErrorAction SilentlyContinue
    }
    Write-Host "    National Instruments services started." -ForegroundColor Green
}

if ($HideLinuxRecoveryDrive) {
    if (Test-Path "D:\recovery.conf") {
        Write-Host "[*] Verified D:\ is a Pop!_OS recovery partition (found D:\recovery.conf)." -ForegroundColor Cyan
        $part = Get-Partition -DriveLetter D -ErrorAction SilentlyContinue
        if ($part) {
            Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "D:\"
            Write-Host "    Successfully removed drive letter D: in Windows. Your Pop!_OS /recovery partition is now hidden from Windows Explorer." -ForegroundColor Green
        }
    } else {
        Write-Warning "D:\recovery.conf was not found. Aborting to avoid unmounting an unexpected drive."
    }
}

if ($DisableUnusedBloat) {
    Write-Host "[*] Disabling TickTick, Eraser autostart, and SamsungMagicianSVC background service..." -ForegroundColor Cyan
    $tt = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\TickTick.lnk"
    if (Test-Path $tt) {
        Remove-Item $tt -Force -ErrorAction SilentlyContinue
        Write-Host "    Removed TickTick.lnk from User Startup folder." -ForegroundColor Green
    }
    $eraserReg = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Eraser" -ErrorAction SilentlyContinue
    if ($eraserReg) {
        Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Eraser" -ErrorAction SilentlyContinue
        Write-Host "    Removed Eraser from HKLM\...\Run autostart." -ForegroundColor Green
    }
    $smSvc = Get-Service -Name "SamsungMagicianSVC" -ErrorAction SilentlyContinue
    if ($smSvc) {
        Stop-Service -Name "SamsungMagicianSVC" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "SamsungMagicianSVC" -StartupType Manual -ErrorAction SilentlyContinue
        Write-Host "    Stopped SamsungMagicianSVC and set StartupType to Manual." -ForegroundColor Green
    }
}

if ($UpdateSafePackages) {
    Write-Host "[*] Ensuring qBittorrent 5.1.0 is pinned against 5.3.0 (declined on MAM)..." -ForegroundColor Cyan
    winget pin add --id qBittorrent.qBittorrent --blocking --accept-source-agreements 2>$null
    $safeIds = @(
        "DominikReichl.KeePass",
        "IDRIX.VeraCrypt",
        "7zip.7zip",
        "Tailscale.Tailscale",
        "Proton.ProtonPass",
        "Proton.ProtonMail",
        "Git.Git",
        "voidtools.Everything"
    )
    foreach ($pkg in $safeIds) {
        Write-Host "[*] Upgrading $pkg..." -ForegroundColor Cyan
        winget upgrade --id $pkg --silent --accept-package-agreements --accept-source-agreements
    }
    Write-Host "[+] Safe package upgrades completed!" -ForegroundColor Green
}

if ($UpgradeSoftwareStack) {
    $arenaUninst = "C:\Program Files (x86)\Lenovo\Legion Arena\unins000.exe"
    if (Test-Path $arenaUninst) {
        Write-Host "[*] Uninstalling Legion Arena..." -ForegroundColor Yellow
        Start-Process -FilePath $arenaUninst -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
        Write-Host "    Legion Arena uninstalled." -ForegroundColor Green
    } else {
        Write-Host "    Legion Arena is already uninstalled." -ForegroundColor Gray
    }

    $nowUninst = "C:\Program Files (x86)\Lenovo\LenovoNow\unins000.exe"
    if (Test-Path $nowUninst) {
        Write-Host "[*] Uninstalling Lenovo Now..." -ForegroundColor Yellow
        Start-Process -FilePath $nowUninst -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
        Write-Host "    Lenovo Now uninstalled." -ForegroundColor Green
    } else {
        Write-Host "    Lenovo Now is already uninstalled." -ForegroundColor Gray
    }

    Write-Host "[*] Installing Lenovo Legion Toolkit (BartoszCichecki.LenovoLegionToolkit)..." -ForegroundColor Cyan
    winget install --id BartoszCichecki.LenovoLegionToolkit --silent --accept-package-agreements --accept-source-agreements

    Write-Host "[*] Installing KeePassXC (KeePassXCTeam.KeePassXC)..." -ForegroundColor Cyan
    winget install --id KeePassXCTeam.KeePassXC --silent --accept-package-agreements --accept-source-agreements

    Write-Host "[+] Software stack upgrade complete!" -ForegroundColor Green
}
