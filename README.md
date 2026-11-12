# check-pc

A zero-dependency Windows hardware, thermal, resource, dual-boot, and security auditing toolkit with an interactive dark-mode HTML dashboard and safe remediation scripts.

Built for high-performance Windows 11 laptops and workstations (with native support for **Lenovo Legion WMI sensors**, **NVIDIA GPUs**, and **Windows + Linux (Pop!_OS) dual-boot** setups).

---

## Features

- **Hardware & OS Inventory**: Queries CPU core/thread topology, hybrid GPUs (NVIDIA + Intel Iris Xe) and driver age, DDR5 DIMM configuration, BIOS revision, and system uptime.
- **Storage & Dual-Boot Protection**: Inspects NVMe physical disks, partition tables, and volume health—automatically detecting exposed Linux (`Pop!_OS` `/recovery`) partitions mounted in Windows.
- **Thermals, Power & Battery Health**:
  - Reads GPU temperature, VRAM usage, and wattage via `nvidia-smi`.
  - Queries battery charge level, Conservation Mode status, and full-charge capacity (Wh).
  - Supports elevated **Lenovo Legion (`LENOVO_GAMEZONE_DATA`)** WMI telemetry for CPU/GPU temperatures and dual-fan RPM speeds.
- **Resource & Startup Bloat Analysis**: Groups running processes by application to reveal true multi-process memory consumption (Chrome, VS Code, Electron apps) and audits `HKCU`/`HKLM` startup items (including Task Manager enabled/disabled state and orphaned keys).
- **Security & Network Exposure Audit**: Verifies Secure Boot, Memory Integrity (HVCI), UAC, Windows Firewall, Remote Desktop (RDP), Antivirus status, and maps all non-localhost (`0.0.0.0` / `::`) listening TCP ports to their owning processes and background services.
- **Self-Contained HTML Dashboard**: Generates a clean, responsive dark-mode report (`reports/pc-health-report.html`) alongside optional JSON telemetry.

---

## Quick Start

### 1. Run a Full Audit & Generate the HTML Dashboard

```powershell
# Run directly via the wrapper (automatically bypasses PowerShell ExecutionPolicy)
.\check-pc.cmd -OpenReport

# Or via PowerShell directly
powershell -NoProfile -ExecutionPolicy Bypass -File .\check-pc.ps1 -OpenReport
```

To export raw JSON telemetry alongside the HTML report:

```powershell
.\check-pc.cmd -OutputJson .\reports\telemetry.local.json
```

### 2. Apply Safe Optimizations (`optimize-pc.cmd`)

```powershell
# Switch Windows Power Plan from locked 'High Performance' to 'Balanced'
# (Recommended for Intel 12th+ Gen P+E core Thread Director efficiency)
.\optimize-pc.cmd -SetBalancedPowerPlan

# Remove orphaned/empty startup registry entries in HKCU\...\Run
.\optimize-pc.cmd -CleanOrphanStartup
```

#### Administrator Optimizations (Run in Elevated PowerShell / CMD)

```powershell
# Stop National Instruments background web servers (port 8080/3582) & set to Manual
.\optimize-pc.cmd -DisableNIServices

# Re-enable National Instruments services when needed for LabVIEW/Multisim
.\optimize-pc.cmd -RestoreNIServices

# Safely remove the Windows D: drive letter from the Pop!_OS /recovery FAT32 partition
# (Prevents Windows from writing $RECYCLE.BIN / System Volume Information to Linux recovery)
.\optimize-pc.cmd -HideLinuxRecoveryDrive
```

---

## Project Structure

```text
check-pc/
├── check-pc.ps1       # Diagnostic CLI + HTML Dashboard & JSON generator
├── check-pc.cmd       # Zero-config launcher (bypasses ExecutionPolicy)
├── optimize-pc.ps1    # Safe, reversible system & security remediation toolkit
├── optimize-pc.cmd    # Zero-config remediation launcher
├── .gitignore         # Excludes machine-specific local HTML/JSON reports
└── README.md          # Documentation
```
