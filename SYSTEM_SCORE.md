# Laptop Health, Maintenance & OPSEC Scorecard

**System:** Lenovo Legion 5 Pro 16IAH7H (`82RB` — 2022 Gen 7)  
**Specs:** Intel Core i7-12700H (14C/20T) • RTX 3070 Ti Laptop (8 GB) • 64 GB DDR5-4800 • 4 TB Dual NVMe (`WD_BLACK SN850X 2TB` + `Samsung 970 EVO Plus 2TB`)  
**Last Audited:** 2026-11-12

---

## 🏆 Overall Score

| Audit Stage | Score | Grade | Summary |
| :--- | :---: | :---: | :--- |
| **How You Maintained It (Before Today)** | **91 / 100** | **A-** | Exceptional hardware upgrades, battery care, disk encryption, and OPSEC; minor deductions only for background NI services, power plan, and Windows auto-mounting the Linux recovery partition. |
| **Current State (After Today's Tuning)** | **98 / 100** | **A+** | Near-flawless dual-boot workstation: balanced thermals, zero exposed bloat services, isolated Linux recovery partition, and pinned/vetted software versions. |

---

## 📊 Category-by-Category Breakdown

### 1. Hardware Upgrades & Physical Maintenance — **10 / 10**
* **RAM Upgrade:** Upgraded to **64 GB Dual-Channel DDR5-4800** (`2 × 32 GB` Crucial), giving massive headroom for heavy multitasking, browsers, IDEs, and AI apps without pagefile thrashing.
* **Storage Architecture:** Paired two top-tier PCIe Gen4/Gen3 NVMe drives (**WD_BLACK SN850X 2TB** for Windows 11 Pro + **Samsung 970 EVO Plus 2TB** for Pop!_OS 24.04) with **>35% free space** (~694 GB free on `C:`), which keeps NVMe SLC caching and wear-leveling at peak performance.
* **Physical Drive Isolation During OS Install:** Physically removing the Windows NVMe drive before installing Pop!_OS on the Samsung SSD prevented Linux/Windows EFI bootloader entanglement—each SSD has its own independent EFI partition.

### 2. Battery & Thermal Longevity — **9.5 / 10** *(was 8.5 / 10)*
* **Battery Conservation Mode (80% Cap):** Keeping Lenovo's 80% charge limit active has preserved the battery at **75.02 Wh out of ~80 Wh design capacity (~93.8% health)** after years of use—far above average for a high-wattage gaming/workstation laptop.
* **NVMe & GPU Thermals:** Both 2 TB NVMe SSDs show **0% wear** and run cool (**42 °C** on the SN850X, **48 °C** on the 970 EVO Plus).
* **Today's Improvement (+1.0):** Switched Windows from locked *High Performance* to *Balanced* (paired with Legion Thermal Mode `2`), allowing Intel Thread Director to park idle P/E cores and dropping idle GPU temperature from **59.5 °C $\rightarrow$ 56.1 °C** and idle CPU load to **4%**.

### 3. Privacy & Torrent OPSEC — **10 / 10**
* **Dual-Layer VPN Protection:**
  1. **OS Level:** ProtonVPN runs on startup with **Auto-Connect** and **Advanced (Permanent) Kill Switch** enabled.
  2. **Client Level:** `qBittorrent.ini` is strictly bound to `Session\InterfaceName=ProtonVPN` (`iftype53_32770`) with `DHT=false`, `PeX=false`, `LSD=false`, and `PortForwardingEnabled=false` (UPnP off).
* **Tracker Whitelist Discipline:** Actively checked MyAnonamouse (MAM) whitelist announcements before accepting the `qBittorrent 5.3.0` update prompt—avoiding a banned client version with a known +10 GB RAM leak and file-removal crashes (`5.1.0` is now pinned in `winget`).

### 4. OS Security & Disk Encryption — **10 / 10** *(was 9.0 / 10)*
* **Full-Disk Encryption on Both OSes:**
  * **Windows 11 Pro (`C:`):** **100% BitLocker Encrypted** (`Protection: On`).
  * **Pop!_OS 24.04 (Disk 1):** **100% LUKS Full-Disk Encrypted**.
* **Hardware & Kernel Hardening:** UEFI **Secure Boot**, **Core Isolation / Memory Integrity (HVCI)**, **UAC Secure Desktop**, **Bitdefender Total Security**, and all three **Windows Firewall** profiles are active; **Remote Desktop (RDP)** is disabled.
* **Today's Improvement (+1.0):** Stopped and set to `Manual` **15 National Instruments** background services that were listening on `0.0.0.0:8080` and `0.0.0.0:3582` across all network interfaces.

### 5. Dual-Boot Hygiene — **10 / 10** *(was 8.5 / 10)*
* **Clean OS Separation:** Separate physical 2 TB NVMe drives for Windows 11 and Pop!_OS 24.04.
* **Today's Improvement (+1.5):** Unmounted drive letter `D:` in Windows so Windows Explorer and Search Indexer no longer write `$RECYCLE.BIN` and `System Volume Information` onto Pop!_OS's 4 GB FAT32 `/recovery` partition.

### 6. Startup & Software Hygiene — **9.5 / 10** *(was 8.5 / 10)*
* **Good Baseline Discipline:** Heavy launchers (`Steam`, `Epic Games`, `GOG Galaxy`, `OneDrive`, `Adobe Acrobat Synchronizer`) were already disabled in Task Manager startup.
* **Today's Improvement (+1.0):** Removed the orphaned `GalaxyClient` registry key, removed `TickTick` and `Eraser` from autostart, set `SamsungMagicianSVC` to `Manual`, and upgraded core security/utility tools (`KeePass 2.61.1`, `7-Zip 26.06`, `Tailscale 1.104.6`, `Proton Pass 1.37.0`, `Proton Mail 1.16.1`, `Git 2.56.0.4`, `Everything 1.4.1.1032`).
