# WarpBypass

[Русский](README.md) | **English**

<img src=".github/assets/banner.png" alt="WarpBypass Banner" width="100%">
<p align="center">
  <a href="https://github.com/BushHub/WarpBypass/releases/latest"><img src="https://img.shields.io/github/v/release/BushHub/WarpBypass?style=for-the-badge&logo=github&color=blue" alt="Latest Release"></a>
  <a href="https://github.com/BushHub/WarpBypass/releases"><img src="https://img.shields.io/github/downloads/BushHub/WarpBypass/total?style=for-the-badge&logo=github&color=brightgreen" alt="Total Downloads"></a>
  <a href="https://github.com/BushHub/WarpBypass/stargazers"><img src="https://img.shields.io/github/stars/BushHub/WarpBypass?style=for-the-badge&logo=github&color=yellow" alt="Stars"></a>
  <a href="https://github.com/BushHub/WarpBypass/issues"><img src="https://img.shields.io/github/issues/BushHub/WarpBypass?style=for-the-badge&logo=github&color=orange" alt="Issues"></a>
  <a href="https://github.com/BushHub/WarpBypass/blob/main/LICENSE"><img src="https://img.shields.io/github/license/BushHub/WarpBypass?style=for-the-badge&color=blueviolet" alt="License"></a>
  <img src="https://img.shields.io/badge/OS-Windows%2010%20%7C%2011-0078D6?style=for-the-badge&logo=windows" alt="Windows Support">
  <a href="https://github.com/BushHub"><img src="https://img.shields.io/badge/Author-BUSH-9c27b0?style=for-the-badge&logo=github" alt="Author BUSH"></a>
  <a href="https://t.me/bushsquad"><img src="https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram Community"></a>
  <a href="https://discord.gg/ebush"><img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord Server"></a>
</p>

**WarpBypass** is a single Windows file that automatically sets up and runs Cloudflare WARP together with packet masking (Zapret). Pick a profile and press Enter: the program downloads the components, connects the tunnel and shows the connection state.

It is made for people who need Discord (voice channels and streams), video hosting, gaming services and other platforms to work reliably, while Russian sites should still open directly.

---

## How it works

1. **Zapret (`winws`)** masks packets so that your ISP does not interfere with the connection to Cloudflare WARP.
2. **Cloudflare WARP** brings the tunnel up. As soon as it is connected, Zapret stops automatically: the tunnel does not need it.
3. **"Russia direct"** (optional) sends Russian domains and IP addresses around WARP, so banks, government services and similar sites work as usual.

---

## Features

**Connection**
- Full automation: the program downloads Zapret, installs Cloudflare WARP (if it is missing), registers the client and connects the tunnel.
- First-run wizard: just press Enter, the recommended values are chosen by default.
- Autostart of the last profile (no delay by default), pause and resume, one-key reconnect.
- IP change (`I`): re-registers the WARP client and shows the old and the new address.
- WARP+ support: the license key is applied on every registration, and the IP line shows whether it is active (`[WARP+]`).

**Bypassing blocks**
- Profile test: the program checks the Zapret profiles one by one (TLS connection to YouTube and Discord) and suggests the best one for your ISP.
- Zapret runs only while WARP is connecting and always exits together with the program, even if the window is closed with the X button.

**"Russia direct" routing**
- Rules live in the repository and are cached locally, the list can be updated in one click.
- Parallel application (up to 30 `warp-cli` calls), retries when the service fails, entries already covered by wildcards such as `*.ru` are skipped.
- View the active rules and turn everything off with a single menu item.

**Diagnostics**
- Availability check of popular services on the session screen (once, periodic or off), the host list is editable.
- WARP statistics: MTU, speed, packet loss, latency.
- Progress indicators for long operations: downloads, WARP installation, waiting for the service.

**Interface and safety**
- Two interface languages, English and Russian: chosen in the wizard and in "Settings → System", the Windows language is the default.
- A downloaded update is verified before installation (version and SHA256 checksum).
- Mouse selection mode is disabled in the console so that an accidental click cannot pause the program.
- Full uninstall with an option to remove the Cloudflare WARP client as well.

---

## Quick start

1. [Download the latest `WarpBypass.bat`](https://github.com/BushHub/WarpBypass/releases/latest/download/WarpBypass.bat) and run it.
2. Windows may show an "Unable to verify the publisher" warning: the file has no digital signature. Confirm the launch, then the UAC prompt (administrator rights are needed for services, the driver and network settings).
3. Go through the first-run wizard: language, automatic updates, "Russia direct", profile. If you just press Enter, the recommended values are chosen (profile `general (ALT12)`).
4. The program downloads the components, installs WARP, connects and opens the session screen.
5. To finish and restore the network to its original state, press `Q`.

### Controls

| Key | Session screen |
|---|---|
| `P` / `R` | Pause / resume the tunnel |
| `C` | Reconnect the tunnel |
| `I` | Change the IP address |
| `M` | Change the bypass profile |
| `S` | Settings |
| `Q` | Disconnect and exit |
| `Enter` | Refresh the IP address and the availability check |

In the main menu enter a profile number, `S` opens the settings, `Q` closes the program.

---

## Settings (key `S`)

| Section | Contents |
|---|---|
| **Connection** | Autostart of the last profile, autostart delay (0 sec by default), DNS cache flush before connecting |
| **Routing** | "Russia direct": enable, update the list, show the rules, disable |
| **Diagnostics** | Availability check (mode, interval, host list), WARP statistics, profile test |
| **System** | Interface language, WARP+ key, automatic updates, settings reset, uninstall |

---

## What changes on your system

- Program files live in `%LOCALAPPDATA%\WarpBypass` (settings, Zapret, rule lists). "Settings → System → Uninstall" removes them.
- If Cloudflare WARP is not installed, the program downloads it from Cloudflare and installs it.
- Zapret is downloaded from the [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) repository; the WinDivert driver is used only while `winws` is running.
- The `CloudflareWARP` service is set to manual start and the autostart of the WARP client window is disabled: the tunnel is controlled by WarpBypass.
- On a full uninstall you can remove the WARP client as well (yes by default) or keep it and restore its settings.

---

## FAQ

**Windows says "Unable to verify the publisher".** This is the standard warning for any unsigned file from the Internet. The source code is open and updates are verified by checksum. After the first run the program removes the "downloaded from the Internet" mark from itself, and the warning no longer appears.

**The profile does not work on my ISP.** Open "Settings → Diagnostics → Profile test": the program checks all profiles and suggests the best one. You can also turn on the DNS cache flush in "Settings → Connection".

**How do I check that the WARP+ key works?** After connecting, the "External IP address" line should be marked `[WARP+]`. Keys from public sources often have no free devices left, then it stays `[WARP]`.

**Why does connecting take up to a minute after the rules are applied?** The WARP service reloads more than a thousand routing rules. This is expected, a progress indicator is shown.

**Antivirus blocks the download or the launch.** Zapret uses the WinDivert driver, which some antivirus programs consider suspicious. Add the `%LOCALAPPDATA%\WarpBypass` folder to the exclusions.

**How do I update?** The program offers an update at startup. Manually: download the [latest release](https://github.com/BushHub/WarpBypass/releases/latest) and replace the file.

Did not find an answer? Open an [issue](https://github.com/BushHub/WarpBypass/issues/new/choose) or ask in [Telegram](https://t.me/bushsquad) / [Discord](https://discord.gg/ebush).

---

## Requirements

Windows 10 or 11, administrator rights, an Internet connection. The built-in Windows PowerShell 5.1 is enough, nothing else has to be installed.

## Tech stack

* **[zapret](https://github.com/Flowseal/zapret-discord-youtube):** low-level packet masking.
* **Cloudflare WARP (`warp-cli`):** the official console client that provides the tunnel.

---

## ⭐ Support the project

If the project is useful to you, give the repository a **Star** (the button at the top right of this page).

---
*Created by BUSH*
