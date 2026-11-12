# Workstation Software Stack Audit & Alternatives (`SOFTWARE_REVIEW.md`)

**System:** Lenovo Legion 5 Pro 16IAH7H (`82RB`) • Windows 11 Pro + Pop!_OS 24.04 Dual-Boot  
**Companion Homelab:** Titan (`192.168.178.46`)  
**Last Reviewed:** 2026-11-12

---

## 1. System, Disk & Hardware Utilities — **10 / 10 (S-Tier Stack)**

| Installed Application | Rating | Status | Notes & Alternatives |
| :--- | :---: | :---: | :--- |
| **Everything (`voidtools`)** | **10 / 10** | **Keep** | Reads the NTFS USN journal directly; instant file search with ~11 MB RAM footprint. Best in class. |
| **WizTree** | **10 / 10** | **Keep** | Reads the NTFS Master File Table (MFT) directly—10× faster than WinDirStat or TreeSize. |
| **7-Zip (`26.06`)** | **10 / 10** | **Keep** | Open-source, fast, zero nagware. *(Optional modern Windows 11 context-menu fork: **NanaZip**.)* |
| **HWiNFO64 + GPU-Z + MSI Afterburner / RTSS** | **10 / 10** | **Keep** | Gold-standard hardware sensor telemetry, GPU voltage/frequency curve tuning, and OSD frame-time overlay. |
| **AllDup** | **9 / 10** | **Keep** | Fast duplicate file finder. *(Cross-platform Windows + Linux alternative for similar images/videos: **Czkawka**.)* |

---

## 2. Lenovo Hardware & Thermal Control — **Upgraded to S-Tier**

| Application | Rating | Status | Notes |
| :--- | :---: | :---: | :--- |
| **Lenovo Legion Toolkit (`LLT`)** | **10 / 10** | **Installed** | Open-source, ad-free, telemetry-free utility (`BartoszCichecki.LenovoLegionToolkit`) that controls 80% Battery Conservation Mode, Thermal Modes (`Fn+Q`), Hybrid Mode / dGPU sleep, and RGB with ~12 MB RAM and 0% idle CPU. Can also disable Lenovo Vantage background services in one click. |
| **Lenovo Vantage** | **6 / 10** | **Optional** | Heavy OEM app with marketing widgets; can be left dormant/disabled via Lenovo Legion Toolkit. |
| **Lenovo Now & Legion Arena** | **2 / 10** | **Removed** | Promotional OEM upsell bloatware (`Lenovo Now`) and redundant game launcher (`Legion Arena`). Uninstalled. |

---

## 3. Password Management & Encryption — **10 / 10**

| Application | Rating | Status | Notes |
| :--- | :---: | :---: | :--- |
| **KeePassXC** | **10 / 10** | **Installed** | Modern C++/Qt cross-platform upgrade over classic KeePass 2 (`KeePassXCTeam.KeePassXC`). Uses the exact same `.kdbx` format, works identically on Windows 11 and Pop!_OS 24.04, and adds native dark mode, TOTP, Passkeys, and browser auto-fill. |
| **Proton Pass & Proton Authenticator** | **9.5 / 10** | **Keep** | Clean encrypted cloud password & 2FA ecosystem (paired with **Vaultwarden** on Titan). |
| **VeraCrypt** | **10 / 10** | **Keep** | Gold-standard encrypted containers/volumes across Windows and Linux. |

---

## 4. PDF & Document Workflow

| Application | Rating | Status | Notes & Alternatives |
| :--- | :---: | :---: | :--- |
| **SumatraPDF** | **10 / 10** | **Keep (Default)** | Launches in milliseconds, minimal RAM, reads PDF/EPUB/CBZ without locking files. |
| **LibreOffice (`26.2`)** | **9 / 10** | **Keep** | Best open-source local office suite (pairs with Nextcloud + OnlyOffice on Titan). |
| **Adobe Acrobat (64-bit)** | **4 / 10** | **Optional / Heavy** | Spawns background updater services and uses 300–600 MB RAM. Use **SumatraPDF** for reading and **Stirling-PDF** on Titan (`192.168.178.46`) for merging, splitting, OCR, and signing unless proprietary Adobe XFA forms are needed. |

---

## 5. Web Browsers

| Application | Rating | Status | Notes |
| :--- | :---: | :---: | :--- |
| **Mozilla Firefox / Zen Browser** | **9.5 / 10** | **Keep** | Best privacy and ad-blocking browsers (support full **uBlock Origin** without Chrome Manifest V3 restrictions). **Zen Browser** brings Arc-style vertical tabs and workspaces to the Gecko engine. |
| **Brave** | **9 / 10** | **Keep** | Best Chromium alternative when Chrome compatibility is required—includes native C++ ad/tracker shields and uses less background memory than Google Chrome. |
| **Google Chrome** | **6.5 / 10** | **Watch RAM** | Currently the #1 RAM consumer on the system (~6.5–10 GB across ~50 processes) and restricts full uBlock Origin under Manifest V3. |

---

## 6. Media, Usenet & Torrents

| Application | Rating | Status | Notes & Alternatives |
| :--- | :---: | :---: | :--- |
| **qBittorrent (`5.1.0` Pinned) + ProtonVPN** | **10 / 10** | **Keep (Protected)** | Bound strictly to `Session\InterfaceName=ProtonVPN` with `DHT/PeX/LSD/UPnP=false` and pinned in `winget` against the declined `5.3.0` release. |
| **Jellyfin Media Player** | **10 / 10** | **Keep** | Uses `mpv` internally to direct-play 4K HEVC/HDR media from Titan with zero transcoding overhead. |
| **VLC Media Player** | **8.5 / 10** | **Keep** | Reliable classic player. *(Optional upgrade for local HDR/Dolby Vision playback on the 165Hz 1440p panel: **mpv.net**.)* |
| **Newshosting Desktop Client** | **5 / 10** | **Redundant with Titan** | Heavy desktop Usenet bundle. Prefer sending NZBs directly to **SABnzbd on Titan** (which downloads over 1 Gbit/s Ethernet directly to `/mnt/ExpansionMedia` without wearing the laptop's NVMe SSD). |

---

## 7. AI, Coding & 3D Creation — **10 / 10**

| Application | Rating | Status | Notes |
| :--- | :---: | :---: | :--- |
| **Antigravity (`agy`) / VS Code / Cursor** | **10 / 10** | **Keep** | Core agentic & IDE development stack. |
| **LM Studio / Claude / ChatGPT** | **9.5 / 10** | **Keep** | Local LLM inference (`LM Studio` on RTX 3070 Ti + 64 GB DDR5) + frontier model desktop apps. |
| **Blender (`5.2`)** | **10 / 10** | **Keep** | Industry-standard open-source 3D creation suite with RTX OptiX acceleration. |

---

## 8. Notes & Task Management

| Application | Rating | Status | Notes & Alternatives |
| :--- | :---: | :---: | :--- |
| **Notion** | **8 / 10** | **Keep** | Strong structured databases/wikis, though cloud-only and unencrypted at rest. *(Recommended local-first Markdown alternative that works identically on Windows 11 and Pop!_OS: **Obsidian**.)* |
