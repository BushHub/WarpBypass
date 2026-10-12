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

**WarpBypass** is a convenient tool that automates network connections and traffic routing. It provides stable, fast and uninterrupted access to global resources through the Cloudflare WARP protocol, using advanced packet masking to prevent connection drops.

It is built for people who need Discord (voice channels and streams), video hosting, gaming services and professional platforms to work without interruptions.

---

## 🚀 Features

- **All in one (automation):** the script audits the system, downloads missing components, configures routes and starts services. You do not have to set anything up by hand.
- **Built-in split tunneling ("Russia direct"):**
  Sends Russian domains and IP ranges directly, bypassing the protected connection.
  - The rule base is downloaded from the repository and cached locally.
  - Version checks and quick list updates.
  - Very fast route application (up to 30 parallel `warp-cli` workers); entries already covered by wildcards such as `*.ru` are skipped.
  - If some commands fail, the program shows which ones.
- **Automatic bypass profile test (DPI benchmark):**
  Tests the Zapret presets one by one: for each profile a TLS connection to popular services (YouTube, Discord) is checked. The tool finds and offers to save the most effective profile for your ISP and restores the active session afterwards.
- **Zapret only while connecting:**
  The masking module starts before WARP connects and stops automatically as soon as the connection is established. It also exits together with the program, even if the window is closed with the X button.
- **External IP and address change:**
  The session screen shows your external IPv4 address marked `[WARP]` or `[direct]`. The `I` key re-registers the WARP client and shows whether the address changed.
- **WARP+:**
  A license key can be set in the settings and is applied on every client registration.
- **Two interface languages (English and Russian):**
  The language is chosen in the first-run wizard and can be changed at any time in "Settings → System". By default the Windows language is used.
- **Download progress indicator:**
  Large downloads (Cloudflare WARP, Zapret modules) show a detailed progress bar in the console.
- **Hidden background services:**
  The masking module and the WARP client work quietly in the background. You control everything from the launcher window, which can be minimized.
- **Better console UX:**
  - The console no longer has the intrusive "Administrator:" title and Quick-Edit blocking (accidental clicks no longer pause the script).
  - No screen flicker thanks to partial redraws.

---

## ⚙️ Getting started

1. **Run:** [download the latest WarpBypass.bat](https://github.com/BushHub/WarpBypass/releases/latest/download/WarpBypass.bat) and run it.
2. **Administrator rights:** confirm the UAC prompt. The tool needs them to configure network interfaces, the registry and system services.
3. **First run:** the wizard asks for the language, configures automatic updates, offers the "Russia direct" routing and applies the recommended profile. Just press Enter to accept the recommended values. After you pick a profile, the program starts it immediately without a delay.
4. **Choose a profile:** in the main menu enter the number of the profile (the recommended universal option is `general (ALT12)`).
5. **Session controls:** on the active connection screen you can:
   - Pause the connection (`P`)
   - Reconnect the tunnel (`C`)
   - Change the IP address (`I`)
   - Open the settings (`S`)
6. **Exit:** to restore the network to its original state and close the program, press `Q` (Disconnect and exit) on the active session screen.

---

## 🛠 Settings (key `S`)

* **Connection:** autostart of the last profile, autostart delay (0 sec by default, i.e. instant start), DNS cache flush before connecting.
* **Routing ("Russia direct"):** turn the rules for Russian sites and IP addresses on or off, update the list, view the active rules.
* **Diagnostics:**
  * *Availability check* — response time of popular services on the session screen (once, periodic or off) and the host list.
  * *WARP statistics* — MTU, speed, packet loss, latency.
  * *Profile test* — automatic search for the best bypass profile for your ISP.
* **System:** interface language, WARP+ license key (paste with Ctrl+V or the right mouse button; the IP line shows `[WARP+]` when the key is active), automatic updates, settings reset and full uninstall (optionally together with the Cloudflare WARP client).

---

## 🛠 Tech stack

* **zapret:** low-level packet masking solution.
* **Cloudflare WARP (CLI):** the official console client for network connectivity.

---

## ⭐ Support the project

You can support the project by giving this repository a **Star** (the button at the top right of this page).

---
*Created by BUSH*
