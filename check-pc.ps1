<#
.SYNOPSIS
    check-pc: Comprehensive Windows Hardware, Thermals, Resource, Dual-Boot & Security Auditor.
.DESCRIPTION
    Scans hardware specs, GPU/CPU/NVMe thermals (including Lenovo Legion WMI sensors when elevated),
    disk & partition layouts (detecting Linux dual-boot & exposed recovery partitions),
    grouped memory/process hogs, startup items, third-party background services,
    and OS/network security posture. Outputs a colorized CLI summary and generates a modern,
    self-contained HTML dashboard.
.PARAMETER OutputHtml
    Path for the generated HTML report (default: .\reports\pc-health-report.html).
.PARAMETER OutputJson
    Optional path to export raw JSON telemetry.
.PARAMETER OpenReport
    Automatically open the generated HTML dashboard in the default browser.
#>
[CmdletBinding()]
param(
    [string]$OutputHtml = "",
    [string]$OutputJson = "",
    [switch]$OpenReport,
    [switch]$AsAdmin
)

$ErrorActionPreference = "SilentlyContinue"
$startTime = Get-Date
$baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

if ([string]::IsNullOrWhiteSpace($OutputHtml)) {
    $OutputHtml = Join-Path $baseDir "reports\pc-health-report.html"
}
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
    $OutputJson = Join-Path $baseDir "reports\telemetry.local.json"
}

function Write-Section($Title) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor DarkCyan
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($AsAdmin -and -not $isAdmin) {
    Write-Host "[*] Requesting UAC Administrator elevation for full CPU/Fan RPM, NVMe SMART, and BitLocker telemetry..." -ForegroundColor Yellow
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-OutputHtml", "`"$OutputHtml`"", "-OutputJson", "`"$OutputJson`"")
    if ($OpenReport) { $argList += "-OpenReport" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList ($argList -join " ") -Wait
    Write-Host "[+] Elevated check-pc scan complete! Telemetry saved to $OutputJson" -ForegroundColor Green
    return
}

Write-Host ""
Write-Host "  CHECK-PC // System, Thermal, Resource & Security Auditor" -ForegroundColor White
Write-Host "  Privilege Level: $(if ($isAdmin) { 'Administrator (Full Sensor & BitLocker Access)' } else { 'Standard User (Run as Admin for CPU/NVMe/BitLocker telemetry)' })" -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Yellow' })

# ------------------------------------------------------------------------------
# 1. HARDWARE & OS
# ------------------------------------------------------------------------------
Write-Section "1. Hardware & Operating System"

$cs   = Get-CimInstance Win32_ComputerSystem
$os   = Get-CimInstance Win32_OperatingSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpus = @(Get-CimInstance Win32_VideoController)
$bb   = Get-CimInstance Win32_BaseBoard
$bios = Get-CimInstance Win32_BIOS
$ram  = @(Get-CimInstance Win32_PhysicalMemory)

$totalRamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedRamGB  = [math]::Round($totalRamGB - $freeRamGB, 1)
$ramUsedPct = [math]::Round(($usedRamGB / $totalRamGB) * 100, 1)
$uptimeSpan = (Get-Date) - $os.LastBootUpTime
$uptimeStr  = "{0}d {1}h {2}m" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes

Write-Host ("  Model        : {0} {1} (Board: {2})" -f $cs.Manufacturer, $cs.Model, $bb.Product)
Write-Host ("  BIOS         : {0} ({1:yyyy-MM-dd})" -f $bios.SMBIOSBIOSVersion, $bios.ReleaseDate)
Write-Host ("  OS           : {0} (Build {1}, {2})" -f $os.Caption.Trim(), $os.BuildNumber, $os.OSArchitecture)
Write-Host ("  Uptime       : {0} (Last boot: {1:yyyy-MM-dd HH:mm})" -f $uptimeStr, $os.LastBootUpTime)
Write-Host ("  CPU          : {0} ({1} Cores / {2} Threads, Load: {3}%)" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors, $cpu.LoadPercentage)
Write-Host ("  Memory       : {0} GB / {1} GB used ({2}%) across {3} DIMM(s)" -f $usedRamGB, $totalRamGB, $ramUsedPct, $ram.Count)

$gpuList = foreach ($g in $gpus) {
    $drvAgeDays = if ($g.DriverDate) { [math]::Round(((Get-Date) - $g.DriverDate).TotalDays) } else { 0 }
    Write-Host ("  GPU          : {0} | Driver {1} ({2:yyyy-MM-dd}, {3}d old) | Mode: {4}" -f $g.Name, $g.DriverVersion, $g.DriverDate, $drvAgeDays, $g.VideoModeDescription)
    [PSCustomObject]@{
        Name       = $g.Name
        Driver     = $g.DriverVersion
        DriverDate = if ($g.DriverDate) { $g.DriverDate.ToString("yyyy-MM-dd") } else { "Unknown" }
        AgeDays    = $drvAgeDays
        Resolution = $g.VideoModeDescription
    }
}

# ------------------------------------------------------------------------------
# 2. STORAGE, PARTITIONS & DUAL-BOOT DETECTION
# ------------------------------------------------------------------------------
Write-Section "2. Storage & Partition Layout"

$disks = @(Get-Disk | Select-Object Number, FriendlyName, PartitionStyle, OperationalStatus, HealthStatus, @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}})
$parts = @(Get-Partition | Select-Object DiskNumber, PartitionNumber, DriveLetter, Type, @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}})
$vols  = @(Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus, OperationalStatus, @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}}, @{N='FreeGB';E={[math]::Round($_.SizeRemaining/1GB,2)}}, @{N='UsedPct';E={if($_.Size -gt 0){[math]::Round((($_.Size - $_.SizeRemaining)/$_.Size)*100,1)}else{0}}})

foreach ($d in $disks) {
    Write-Host ("  Disk {0}: {1} ({2} GB) - Status: {3} / {4}" -f $d.Number, $d.FriendlyName, $d.SizeGB, $d.HealthStatus, $d.OperationalStatus)
}
foreach ($v in $vols) {
    $color = if ($v.HealthStatus -ne 'Healthy') { 'Yellow' } else { 'Gray' }
    Write-Host ("  Volume {0}: [{1}] {2} GB ({3} GB free, {4}% used) - Health: {5} ({6})" -f $v.DriveLetter, $v.FileSystem, $v.SizeGB, $v.FreeGB, $v.UsedPct, $v.HealthStatus, $v.OperationalStatus) -ForegroundColor $color
}

# ------------------------------------------------------------------------------
# 3. THERMALS, POWER & BATTERY
# ------------------------------------------------------------------------------
Write-Section "3. Thermals, Power & Battery"

$gpuTempC = $null
$gpuPowerW = $null
$gpuUtilPct = $null
$gpuMemUsedMB = $null
$gpuMemTotalMB = $null

if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $nvCsv = nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>$null
    if ($nvCsv) {
        $nvParts = $nvCsv.Split(',') | ForEach-Object { $_.Trim() }
        if ($nvParts.Count -ge 6) {
            $gpuTempC      = [double]$nvParts[1]
            $gpuUtilPct    = [double]$nvParts[2]
            $gpuMemUsedMB  = [double]$nvParts[3]
            $gpuMemTotalMB = [double]$nvParts[4]
            $gpuPowerW     = [double]$nvParts[5]
            Write-Host ("  NVIDIA GPU   : {0}°C | Load: {1}% | VRAM: {2}/{3} MiB | Power: {4} W" -f $gpuTempC, $gpuUtilPct, $gpuMemUsedMB, $gpuMemTotalMB, $gpuPowerW)
        }
    }
}

$lenovoCpuTemp  = $null
$lenovoGpuTemp  = $null
$lenovoFan1     = $null
$lenovoFan2     = $null
$lenovoFanMode  = $null
$nvmeSmart      = @()
$acpiTemps      = @()
if ($isAdmin) {
    $gz = Get-CimInstance -Namespace root/wmi -ClassName LENOVO_GAMEZONE_DATA -ErrorAction SilentlyContinue
    if ($gz) {
        $lenovoCpuTemp = (Invoke-CimMethod -InputObject $gz -MethodName GetCPUtemp -ErrorAction SilentlyContinue).Data
        $lenovoGpuTemp = (Invoke-CimMethod -InputObject $gz -MethodName GetGPUtemp -ErrorAction SilentlyContinue).Data
        $lenovoFan1    = (Invoke-CimMethod -InputObject $gz -MethodName GetFan1Speed -ErrorAction SilentlyContinue).Data
        $lenovoFan2    = (Invoke-CimMethod -InputObject $gz -MethodName GetFan2Speed -ErrorAction SilentlyContinue).Data
        $lenovoFanMode = (Invoke-CimMethod -InputObject $gz -MethodName GetSmartFanMode -ErrorAction SilentlyContinue).Data
        Write-Host ("  Legion WMI   : CPU Temp: {0}°C | GPU Temp: {1}°C | Fan 1: {2} RPM | Fan 2: {3} RPM | Thermal Mode: {4}" -f $lenovoCpuTemp, $lenovoGpuTemp, $lenovoFan1, $lenovoFan2, $lenovoFanMode) -ForegroundColor Green
    }
    $acpiTemps = @(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{ Zone = $_.InstanceName; TempC = [math]::Round(($_.CurrentTemperature / 10) - 273.15, 1) }
    })
    $nvmeSmart = @(Get-PhysicalDisk | Where-Object BusType -eq 'NVMe' | ForEach-Object {
        $rel = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        if ($rel) {
            Write-Host ("  NVMe SMART   : {0} -> Temp: {1}°C | Wear: {2}% | PowerOnHours: {3}h" -f $_.FriendlyName, $rel.Temperature, $rel.Wear, $rel.PowerOnHours) -ForegroundColor Cyan
            [PSCustomObject]@{ Disk = $_.FriendlyName; TempC = $rel.Temperature; TempMaxC = $rel.TemperatureMax; WearPct = $rel.Wear; PowerOnHours = $rel.PowerOnHours }
        }
    })
}

$pwrLine = (powercfg /getactivescheme) -join " "
$powerScheme = if ($pwrLine -match '\((.+)\)') { $Matches[1] } else { $pwrLine }
Write-Host ("  Power Plan   : {0}" -f $powerScheme)

$bat = Get-CimInstance Win32_Battery | Select-Object -First 1
$batFullCap = (Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1).FullChargedCapacity
if ($bat) {
    $capWh = if ($batFullCap) { "{0:N2} Wh" -f ($batFullCap / 1000) } else { "N/A" }
    Write-Host ("  Battery      : {0}% Charged | Full Charge Capacity: {1}" -f $bat.EstimatedChargeRemaining, $capWh)
}

# ------------------------------------------------------------------------------
# 4. TOP RESOURCE CONSUMERS & STARTUP APPS
# ------------------------------------------------------------------------------
Write-Section "4. Top Memory Consumers (Grouped by App)"

$topApps = @(Get-Process | Group-Object Name | Select-Object Name, Count, @{N='TotalRAM_MB';E={[math]::Round(($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)}} | Sort-Object TotalRAM_MB -Descending | Select-Object -First 12)
foreach ($app in $topApps) {
    Write-Host ("  {0,-24} ({1,2} proc) : {2,7:N1} MB" -f $app.Name, $app.Count, $app.TotalRAM_MB)
}

$startupItems = @()
$appCU = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -ErrorAction SilentlyContinue
$runCU = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
if ($runCU) {
    foreach ($p in ($runCU.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' })) {
        $val = $appCU.($p.Name)
        $en  = if ($val) { $val[0] -eq 2 -or $val[0] -eq 6 } else { $true }
        $startupItems += [PSCustomObject]@{ Scope = 'HKCU'; Name = $p.Name; Enabled = $en; Command = [string]$p.Value }
    }
}
$appLM = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -ErrorAction SilentlyContinue
$runLM = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
if ($runLM) {
    foreach ($p in ($runLM.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' })) {
        $val = $appLM.($p.Name)
        $en  = if ($val) { $val[0] -eq 2 -or $val[0] -eq 6 } else { $true }
        $startupItems += [PSCustomObject]@{ Scope = 'HKLM'; Name = $p.Name; Enabled = $en; Command = [string]$p.Value }
    }
}

# ------------------------------------------------------------------------------
# 5. SECURITY & NETWORK EXPOSURE AUDIT
# ------------------------------------------------------------------------------
Write-Section "5. Security & Network Exposure"

$sb   = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State").UEFISecureBootEnabled -eq 1
$uac  = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$hvci = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity").Enabled -eq 1
$rdp  = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server").fDenyTSConnections -eq 1
$fw   = @(Get-NetFirewallProfile | Select-Object Name, Enabled)
$fwAllEnabled = ($fw | Where-Object { -not $_.Enabled }).Count -eq 0

$exposedPorts = @(Get-NetTCPConnection -State Listen | Where-Object { $_.LocalAddress -notmatch '^(127\.|::1$)' } | Select-Object LocalAddress, LocalPort, OwningProcess, @{N='ProcessName';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}} | Sort-Object LocalPort -Unique)
$niServices   = @(Get-Service | Where-Object { $_.DisplayName -match '^NI ' -or $_.Name -match '^(NI|lkads|lktsrv|mxssvr)' } | Where-Object Status -eq 'Running')

$bitlockerStatus = "Requires Admin"
if ($isAdmin) {
    $blVol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
    if ($blVol) {
        $bitlockerStatus = "$($blVol.VolumeStatus) (Protection: $($blVol.ProtectionStatus), $($blVol.EncryptionPercentage)%)"
    }
}

Write-Host ("  Secure Boot          : {0}" -f $(if ($sb) { 'Enabled' } else { 'Disabled' }))
Write-Host ("  Memory Integrity     : {0}" -f $(if ($hvci) { 'Enabled (HVCI Active)' } else { 'Disabled' }))
Write-Host ("  UAC Secure Desktop   : {0}" -f $(if ($uac.EnableLUA -eq 1) { 'Enabled' } else { 'Disabled' }))
Write-Host ("  Windows Firewall     : {0}" -f $(if ($fwAllEnabled) { 'All Profiles Enabled' } else { 'WARNING: Profile Disabled' }))
Write-Host ("  Remote Desktop (RDP) : {0}" -f $(if ($rdp) { 'Disabled (Safe)' } else { 'Enabled' }))
Write-Host ("  BitLocker (C:)       : {0}" -f $bitlockerStatus)
Write-Host ("  Non-Localhost Ports  : {0} listening TCP ports ({1} active National Instruments services)" -f $exposedPorts.Count, $niServices.Count)

# ------------------------------------------------------------------------------
# 6. BUILD RECOMMENDATIONS
# ------------------------------------------------------------------------------
$recommendations = @()

$oldGpu = $gpuList | Where-Object { $_.AgeDays -gt 365 }
foreach ($og in $oldGpu) {
    $recommendations += [PSCustomObject]@{
        Severity = "Low"
        Category = "Drivers & Graphics"
        Title    = "OEM-Locked iGPU Driver: $($og.Name) ($($og.Driver), $($og.DriverDate))"
        Detail   = "Lenovo froze the OEM-validated Legion 5 Pro (82RB) Intel Iris Xe driver at 31.0.101.4502 (preserving Lenovo Hybrid/Optimus panel customisations). Intel offers newer generic 11th-14th Gen WHQL drivers (32.0.101.xxxx) if needed."
        Action   = "Optional: winget install Intel.IntelDriverAndSupportAssistant (or keep Lenovo OEM 31.0.101.4502 for Hybrid Mode stability)."
    }
}

$warnVol = $vols | Where-Object { $_.HealthStatus -ne 'Healthy' }
foreach ($wv in $warnVol) {
    $isLinuxRecovery = Test-Path "$($wv.DriveLetter):\recovery.conf"
    $recommendations += [PSCustomObject]@{
        Severity = "High"
        Category = "Storage & Dual-Boot"
        Title    = "Volume $($wv.DriveLetter): Health Warning ($($wv.OperationalStatus))"
        Detail   = $(if ($isLinuxRecovery) { "Volume $($wv.DriveLetter): is your Pop!_OS /recovery FAT32 partition on the Samsung 970 EVO Plus. Windows auto-mounted it and wrote `$RECYCLE.BIN / System Volume Information, triggering a FAT32 repair warning." } else { "Volume $($wv.DriveLetter): reports $($wv.HealthStatus) / $($wv.OperationalStatus)." })
        Action   = "Run .\optimize-pc.ps1 -HideLinuxRecoveryDrive (as Admin) to safely remove the D: drive letter in Windows without touching Pop!_OS data."
    }
}

if ($niServices.Count -gt 0) {
    $recommendations += [PSCustomObject]@{
        Severity = "Medium"
        Category = "Security & Network"
        Title    = "$($niServices.Count) National Instruments Services Exposing Network Ports (incl. 0.0.0.0:8080)"
        Detail   = "NI ApplicationWebServer (port 8080), NISystemWebServer (port 3582), and $($niServices.Count - 2) other NI services run 24/7 on all network interfaces."
        Action   = "Run .\optimize-pc.ps1 -DisableNIServices (as Admin) to stop them and set StartMode to Manual."
    }
}

if ($powerScheme -match 'High performance') {
    $recommendations += [PSCustomObject]@{
        Severity = "Medium"
        Category = "Thermals & Power"
        Title    = "Windows Power Plan Locked to 'High Performance'"
        Detail   = "On 12th Gen Intel Core i7-12700H (6P+8E hybrid architecture), Windows 11 'Balanced' mode allows Intel Thread Director to park idle cores and lower idle temperatures by 5-10°C without sacrificing boost performance."
        Action   = "Run .\optimize-pc.ps1 -SetBalancedPowerPlan to switch to Balanced."
    }
}

$orphanStartup = $startupItems | Where-Object { [string]::IsNullOrWhiteSpace($_.Command) }
if ($orphanStartup.Count -gt 0) {
    $recommendations += [PSCustomObject]@{
        Severity = "Low"
        Category = "Startup Hygiene"
        Title    = "$($orphanStartup.Count) Orphaned Startup Registry Entry ($($orphanStartup.Name -join ', '))"
        Detail   = "Found startup registry value(s) with an empty command string in HKCU\...\Run."
        Action   = "Run .\optimize-pc.ps1 -CleanOrphanStartup to remove broken registry entries."
    }
}

Write-Section "6. Actionable Recommendations ($($recommendations.Count) Found)"
foreach ($rec in $recommendations) {
    $c = switch ($rec.Severity) { "High" { "Red" } "Medium" { "Yellow" } Default { "Cyan" } }
    Write-Host ("  [{0}] {1}" -f $rec.Severity.ToUpper(), $rec.Title) -ForegroundColor $c
    Write-Host ("         -> {0}" -f $rec.Action) -ForegroundColor Gray
}

# ------------------------------------------------------------------------------
# 7. GENERATE HTML REPORT & OPTIONAL JSON
# ------------------------------------------------------------------------------
$reportDir = Split-Path -Parent $OutputHtml
if ($reportDir -and -not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$telemetry = [PSCustomObject]@{
    GeneratedAt     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    IsAdmin         = $isAdmin
    System          = @{
        Manufacturer = $cs.Manufacturer
        Model        = $cs.Model
        Board        = $bb.Product
        BIOS         = $bios.SMBIOSBIOSVersion
        OS           = $os.Caption.Trim()
        Build        = $os.BuildNumber
        Uptime       = $uptimeStr
        CPU          = $cpu.Name.Trim()
        Cores        = $cpu.NumberOfCores
        Threads      = $cpu.NumberOfLogicalProcessors
        CPULoadPct   = $cpu.LoadPercentage
        TotalRamGB   = $totalRamGB
        UsedRamGB    = $usedRamGB
        RamUsedPct   = $ramUsedPct
    }
    GPUs            = $gpuList
    Thermals        = @{
        NvidiaTempC   = $gpuTempC
        NvidiaPowerW  = $gpuPowerW
        NvidiaUtil    = $gpuUtilPct
        LegionCpuC    = $lenovoCpuTemp
        LegionGpuC    = $lenovoGpuTemp
        LegionFan1    = $lenovoFan1
        LegionFan2    = $lenovoFan2
        LegionFanMode = $lenovoFanMode
        AcpiZones     = $acpiTemps
        NvmeSmart     = $nvmeSmart
        PowerPlan     = $powerScheme
        BatteryPct    = $bat.EstimatedChargeRemaining
        BatteryWh     = if ($batFullCap) { [math]::Round($batFullCap / 1000, 2) } else { $null }
    }
    Disks           = $disks
    Volumes         = $vols
    TopApps         = $topApps
    StartupItems    = $startupItems
    Security        = @{
        SecureBoot   = $sb
        HVCI         = $hvci
        UAC          = ($uac.EnableLUA -eq 1)
        FirewallOk   = $fwAllEnabled
        RDPDisabled  = $rdp
        BitLockerC   = $bitlockerStatus
        ExposedPorts = $exposedPorts
    }
    Recommendations = $recommendations
}

if ($OutputJson) {
    $telemetry | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputJson -Encoding UTF8
    Write-Host "`n  JSON telemetry saved to: $OutputJson" -ForegroundColor Green
}

$recHtml = foreach ($r in $recommendations) {
    $badgeClass = switch ($r.Severity) { "High" { "badge-high" } "Medium" { "badge-med" } Default { "badge-low" } }
    @"
    <div class="rec-card">
        <div class="rec-header">
            <span class="badge $badgeClass">$($r.Severity)</span>
            <span class="rec-cat">$($r.Category)</span>
            <strong>$($r.Title)</strong>
        </div>
        <p class="rec-detail">$($r.Detail)</p>
        <div class="rec-action"><code>$($r.Action)</code></div>
    </div>
"@
}

$appRows = foreach ($a in $topApps) {
    $pct = [math]::Min(100, [math]::Round(($a.TotalRAM_MB / ($totalRamGB * 1024)) * 100 * 4, 1))
    @"
    <tr>
        <td><strong>$($a.Name)</strong></td>
        <td>$($a.Count)</td>
        <td>$($a.TotalRAM_MB) MB</td>
        <td><div class="bar-bg"><div class="bar-fill" style="width:$($pct)%"></div></div></td>
    </tr>
"@
}

$portRows = foreach ($p in $exposedPorts) {
    @"
    <tr>
        <td><code>$($p.LocalAddress):$($p.LocalPort)</code></td>
        <td>$($p.ProcessName)</td>
        <td>$($p.OwningProcess)</td>
    </tr>
"@
}

$volRows = foreach ($v in $vols) {
    $statusBadge = if ($v.HealthStatus -eq 'Healthy') { '<span class="badge badge-ok">Healthy</span>' } else { "<span class='badge badge-high'>$($v.HealthStatus) ($($v.OperationalStatus))</span>" }
    @"
    <tr>
        <td><strong>$($v.DriveLetter):</strong></td>
        <td>$($v.FileSystem)</td>
        <td>$($v.SizeGB) GB</td>
        <td>$($v.FreeGB) GB ($($v.UsedPct)% used)</td>
        <td>$statusBadge</td>
    </tr>
"@
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>check-pc // System Health & Security Report</title>
<style>
    :root {
        --bg: #0b0f19;
        --card: #131b2e;
        --border: #1e293b;
        --text: #e2e8f0;
        --muted: #94a3b8;
        --accent: #38bdf8;
        --green: #22c55e;
        --amber: #f59e0b;
        --red: #ef4444;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        background: var(--bg);
        color: var(--text);
        line-height: 1.5;
        padding: 2rem;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    header {
        display: flex; justify-content: space-between; align-items: center;
        border-bottom: 1px solid var(--border); padding-bottom: 1rem; margin-bottom: 2rem;
    }
    h1 { font-size: 1.6rem; color: #fff; }
    h2 { font-size: 1.15rem; margin-bottom: 1rem; color: var(--accent); }
    .meta { color: var(--muted); font-size: 0.9rem; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
    .grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(480px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem; }
    .card {
        background: var(--card); border: 1px solid var(--border);
        border-radius: 10px; padding: 1.25rem;
    }
    .stat-label { color: var(--muted); font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; }
    .stat-value { font-size: 1.4rem; font-weight: 700; margin: 0.25rem 0; color: #fff; }
    .stat-sub { font-size: 0.85rem; color: var(--muted); }
    table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
    th, td { text-align: left; padding: 0.6rem 0.5rem; border-bottom: 1px solid var(--border); }
    th { color: var(--muted); font-weight: 600; font-size: 0.8rem; text-transform: uppercase; }
    .badge { padding: 0.15rem 0.55rem; border-radius: 999px; font-size: 0.75rem; font-weight: 600; }
    .badge-high { background: rgba(239,68,68,0.18); color: #fca5a5; border: 1px solid rgba(239,68,68,0.4); }
    .badge-med { background: rgba(245,158,11,0.18); color: #fcd34d; border: 1px solid rgba(245,158,11,0.4); }
    .badge-low { background: rgba(56,189,248,0.18); color: #7dd3fc; border: 1px solid rgba(56,189,248,0.4); }
    .badge-ok { background: rgba(34,197,94,0.18); color: #86efac; border: 1px solid rgba(34,197,94,0.4); }
    .rec-card {
        background: rgba(15,23,42,0.65); border: 1px solid var(--border);
        border-radius: 8px; padding: 1rem; margin-bottom: 0.85rem;
    }
    .rec-header { display: flex; align-items: center; gap: 0.6rem; margin-bottom: 0.4rem; }
    .rec-cat { color: var(--muted); font-size: 0.8rem; }
    .rec-detail { color: var(--muted); font-size: 0.9rem; margin-bottom: 0.5rem; }
    .rec-action code {
        display: inline-block; background: #090d16; color: var(--accent);
        padding: 0.3rem 0.6rem; border-radius: 5px; font-size: 0.82rem;
    }
    .bar-bg { background: #090d16; height: 8px; border-radius: 4px; overflow: hidden; width: 120px; }
    .bar-fill { background: var(--accent); height: 100%; }
</style>
</head>
<body>
<div class="container">
    <header>
        <div>
            <h1>check-pc // System Diagnostic & Security Dashboard</h1>
            <div class="meta">$($cs.Manufacturer) $($cs.Model) &bull; $($os.Caption.Trim()) (Build $($os.BuildNumber)) &bull; Generated $($telemetry.GeneratedAt)</div>
        </div>
        <div>
            <span class="badge $(if($isAdmin){'badge-ok'}else{'badge-med'})">$(if($isAdmin){'Admin Telemetry'}else{'Standard User Mode'})</span>
        </div>
    </header>

    <div class="grid">
        <div class="card">
            <div class="stat-label">Processor</div>
            <div class="stat-value">$($cpu.LoadPercentage)% Load</div>
            <div class="stat-sub">$($cpu.Name.Trim()) ($($cpu.NumberOfCores)C / $($cpu.NumberOfLogicalProcessors)T)</div>
        </div>
        <div class="card">
            <div class="stat-label">Memory (DDR5-4800)</div>
            <div class="stat-value">$usedRamGB / $totalRamGB GB ($ramUsedPct%)</div>
            <div class="stat-sub">$freeRamGB GB Free across $($ram.Count) Dual-Channel DIMMs</div>
        </div>
        <div class="card">
            <div class="stat-label">Dedicated GPU</div>
            <div class="stat-value">$(if($gpuTempC){"$gpuTempC &deg;C"}else{"Active"})</div>
            <div class="stat-sub">RTX 3070 Ti Laptop &bull; Power: $(if($gpuPowerW){"$gpuPowerW W"}else{"N/A"}) &bull; VRAM: $(if($gpuMemUsedMB){"$gpuMemUsedMB MiB"}else{"N/A"})</div>
        </div>
        <div class="card">
            <div class="stat-label">Power & Battery</div>
            <div class="stat-value">$($bat.EstimatedChargeRemaining)% ($(if($batFullCap){"{0:N1} Wh" -f ($batFullCap/1000)}else{"AC"}))</div>
            <div class="stat-sub">Plan: $powerScheme</div>
        </div>
    </div>

    <div class="card" style="margin-bottom: 1.5rem;">
        <h2>Actionable Recommendations ($($recommendations.Count))</h2>
        $($recHtml -join "`n")
    </div>

    <div class="grid-2">
        <div class="card">
            <h2>Top Memory Consumers (Grouped)</h2>
            <table>
                <thead><tr><th>Application</th><th>Procs</th><th>RAM Used</th><th>Relative</th></tr></thead>
                <tbody>
                    $($appRows -join "`n")
                </tbody>
            </table>
        </div>

        <div class="card">
            <h2>Storage Volumes & Security Posture</h2>
            <table style="margin-bottom: 1.25rem;">
                <thead><tr><th>Vol</th><th>FS</th><th>Size</th><th>Free</th><th>Status</th></tr></thead>
                <tbody>
                    $($volRows -join "`n")
                </tbody>
            </table>

            <h2>Non-Localhost Listening TCP Ports ($($exposedPorts.Count))</h2>
            <table>
                <thead><tr><th>Endpoint</th><th>Process</th><th>PID</th></tr></thead>
                <tbody>
                    $($portRows -join "`n")
                </tbody>
            </table>
        </div>
    </div>
</div>
</body>
</html>
"@

$html | Set-Content -Path $OutputHtml -Encoding UTF8
Write-Host "`n  HTML Dashboard generated: $OutputHtml" -ForegroundColor Green

if ($OpenReport) {
    Start-Process $OutputHtml
}
