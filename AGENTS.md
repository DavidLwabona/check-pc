# Antigravity Rules & Workspace Memory: check-pc (Windows 11 Workstation)

## 🚨 1. CRITICAL PRIVACY, SECURITY & OPSEC GUARDRAILS (READ FIRST) 🚨

1. **No Optimization May Compromise Privacy, Security, or OPSEC:**
   - Never disable, stop, or remove security, privacy, VPN, encryption, or homelab-connectivity software (**Bitdefender**, **ProtonVPN**, **Tailscale**, **VeraCrypt**, **KeePass**, **qBittorrent** interface bindings) purely to save RAM or CPU without **first discussing, checking configuration files, and weighing the trade-offs with the user**.
   - Always evaluate resource usage relative to the machine's actual hardware (**64 GB DDR5-4800 RAM**, **14-core / 20-thread Intel Core i7-12700H**). Saving 500–900 MB of RAM on a 64 GB system (~1.3% of RAM) is never worth degrading security or risking an IP leak.

2. **Mandatory Risk & Usage Check Before Touching Critical Apps:**
   - If the user asks about disabling or changing a security/privacy tool, you **MUST**:
     1. **Weigh in objectively** on whether the change makes sense for this hardware and threat model.
     2. **Explain what can go wrong** (e.g., ISP letters / German *Abmahnung* risk, kill-switch internet lockouts, tracker bans, developer I/O slowdowns).
     3. **Inspect local configs first** and **ask how the user uses the tool** before making changes.

---

## 🛡️ 2. Established Decisions & Threat Model on This PC

### A. Bitdefender Total Security vs. Windows Defender
- **Status:** Keep **Bitdefender Total Security** (`VSSERV` / `bdservicehost`).
- **Reasoning:**
  - Uses ~800–950 MB RAM, which is only **~1.3% of the 64 GB DDR5 RAM** on this Legion 5 Pro.
  - Provides stronger web/phishing traffic filtering, ransomware behavioral protection (`BDRedLine`), and fewer false positives than Windows Defender.
  - Switching to Windows Defender (`MsMpEng.exe`) saves only ~500 MB RAM while introducing significantly higher CPU and NVMe I/O spikes during software development (`git`, builds, thousands of small files).

### B. ProtonVPN + qBittorrent Windows OPSEC (Dual-Layer Protection)
- **How the User Uses ProtonVPN on Windows:**
  - Always-on at boot (`Auto-Connect` enabled).
  - **Advanced Kill Switch** (Permanent Kill Switch) is enabled.
- **How qBittorrent (`%APPDATA%\qBittorrent\qBittorrent.ini`) is Configured:**
  - Bound strictly to the ProtonVPN network interface: `Session\InterfaceName=ProtonVPN` (`Session\Interface=iftype53_32770`).
  - `Session\DHTEnabled=false`, `Session\PeXEnabled=false`, `Session\LSDEnabled=false`, `PortForwardingEnabled=false`.
- **What Goes Wrong If ProtonVPN Is Disabled:**
  1. Because **Advanced Kill Switch** is active, disabling ProtonVPN on startup blocks all internet traffic at the Windows Filtering Platform (WFP) level until ProtonVPN is launched.
  2. If the Kill Switch were ever turned off and qBittorrent's interface binding were reset, torrent traffic would leak over the home ISP IP (FRITZ!Box), risking ISP copyright letters or private tracker (MAM / TorrentLeech) IP rules violations.
- **Rule:** Never flag `Proton VPN` or `Tailscale` as startup bloat. `check-pc.ps1` must explicitly verify that `qBittorrent.ini` remains bound to `ProtonVPN`.

### C. Software Version Verification & Private Tracker Whitelists (MAM / TorrentLeech)
- **Rule:** Never blindly upgrade software—especially **qBittorrent**—without checking private tracker whitelists (MyAnonamouse, TorrentLeech, etc.) and recent GitHub issue regressions.
- **Current Known Bad Version — `qBittorrent 5.3.0` (DECLINED on MAM):**
  - **Do NOT upgrade to `qBittorrent 5.3.0`!**
  - MAM Senior Developer (`Dev03`, threads `/f/t/93812` and `/f/t/93867`) officially **declined `5.3.0`** due to:
    - Severe crashes when removing files ([Issue #25125](https://github.com/qbittorrent/qBittorrent/issues/25125), [Issue #25118](https://github.com/qbittorrent/qBittorrent/issues/25118), [Issue #25123](https://github.com/qbittorrent/qBittorrent/issues/25123)).
    - Massive memory leak (+10 GB RAM / OOM kills) and tracker announce timeouts on `libtorrent 2.0.15` and `2.1.2`.
  - MAM is awaiting `5.3.1` (`/f/t/93867`) before evaluating the `5.3.x` branch again.
  - **Current Safe Pin on Windows:** Stay on **`qBittorrent 5.1.0`** (or `5.2.4` on Titan) and maintain the `winget` blocking pin (`winget pin add --id qBittorrent.qBittorrent --blocking`).
- **Note on ExpressVPN (MAM Announcement):**
  - MAM also announced: *"ExpressVPN no longer an acceptable VPN provider"*. (The user uses **ProtonVPN** on Windows and **AirVPN** on Titan, both of which are safe.)

---

## 💻 3. Hardware & Dual-Boot Context (Lenovo Legion 5 Pro 16IAH7H `82RB`)
- **CPU:** 12th Gen Intel Core i7-12700H (14C/20T) — Keep Windows Power Plan on **Balanced** + Lenovo Legion Thermal Mode `2` (Balanced/Auto) so Intel Thread Director parks cores at idle.
- **GPUs:** NVIDIA RTX 3070 Ti Laptop GPU + Intel Iris Xe (`SUBSYS_3AF017AA`, Lenovo OEM driver `31.0.101.4502` preserved for Hybrid Mode / Optimus stability).
- **Storage:**
  - **Disk 0 (`WD_BLACK SN850X 2000GB`):** Windows 11 Pro (`C:`), **100% BitLocker Encrypted**.
  - **Disk 1 (`Samsung SSD 970 EVO Plus 2TB`):** Pop!_OS 24.04 (**100% LUKS Encrypted**). Its 4 GB FAT32 `/recovery` partition must remain unmounted (no drive letter `D:`) in Windows so Windows Explorer never writes `$RECYCLE.BIN` or `System Volume Information` onto it.
