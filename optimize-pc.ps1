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
    [switch]$HideLinuxRecoveryDrive
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not ($SetBalancedPowerPlan -or $CleanOrphanStartup -or $DisableNIServices -or $RestoreNIServices -or $HideLinuxRecoveryDrive)) {
    Write-Host ""
    Write-Host "  OPTIMIZE-PC // Available Remediation Flags" -ForegroundColor Cyan
    Write-Host "  ------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  .\optimize-pc.ps1 -SetBalancedPowerPlan    # Switch from High Performance to Balanced (Intel 12th Gen P+E optimal)"
    Write-Host "  .\optimize-pc.ps1 -CleanOrphanStartup      # Remove empty/orphaned HKCU Run registry entries (e.g. GalaxyClient)"
    Write-Host "  .\optimize-pc.ps1 -DisableNIServices       # [Admin] Stop NI background web servers (port 8080/3582) & set Manual"
    Write-Host "  .\optimize-pc.ps1 -RestoreNIServices       # [Admin] Start NI background services for LabVIEW/Multisim sessions"
    Write-Host "  .\optimize-pc.ps1 -HideLinuxRecoveryDrive  # [Admin] Safely unmount D: letter from Pop!_OS /recovery partition"
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

if ($DisableNIServices) {
    if (-not $isAdmin) {
        Write-Warning "Stopping and reconfiguring National Instruments system services requires an Administrator PowerShell prompt."
    } else {
        $niSvcs = Get-Service | Where-Object { $_.DisplayName -match '^NI ' -or $_.Name -match '^(NI|lkads|lktsrv|mxssvr)' }
        foreach ($s in $niSvcs) {
            Write-Host "    Setting $($s.Name) ($($s.DisplayName)) -> Manual & Stopped" -ForegroundColor Yellow
            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s.Name -StartupType Manual -ErrorAction SilentlyContinue
        }
        Write-Host "    National Instruments services set to Manual and stopped." -ForegroundColor Green
    }
}

if ($RestoreNIServices) {
    if (-not $isAdmin) {
        Write-Warning "Starting National Instruments system services requires an Administrator PowerShell prompt."
    } else {
        $niSvcs = Get-Service | Where-Object { $_.DisplayName -match '^NI ' -or $_.Name -match '^(NI|lkads|lktsrv|mxssvr)' }
        foreach ($s in $niSvcs) {
            Write-Host "    Starting $($s.Name) ($($s.DisplayName))..." -ForegroundColor Cyan
            Start-Service -Name $s.Name -ErrorAction SilentlyContinue
        }
        Write-Host "    National Instruments services started." -ForegroundColor Green
    }
}

if ($HideLinuxRecoveryDrive) {
    if (-not $isAdmin) {
        Write-Warning "Removing a drive letter mount requires an Administrator PowerShell prompt."
    } else {
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
}
