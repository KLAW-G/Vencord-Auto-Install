<p align="center">
  <img src="assets/tokyo-ghoul-kaneki-header.png" alt="Dark Tokyo Ghoul artwork featuring Ken Kaneki" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-1678C2?style=for-the-badge&logo=windows11&logoColor=white" alt="Windows 10 and 11">
  <img src="https://img.shields.io/badge/Discord-Stable%20%7C%20Canary%20%7C%20PTB-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord channels">
  <img src="https://img.shields.io/badge/Mode-Fully%20Silent-111827?style=for-the-badge" alt="Fully silent">
  <img src="https://img.shields.io/badge/Integrity-SHA--256-059669?style=for-the-badge" alt="SHA-256 verified">
</p>

<h3 align="center">Automatic Vencord installation — silent, secure, and built for every Discord channel</h3>

<p align="center">
  A lightweight Windows tool that detects Discord Stable, Canary, and PTB, downloads the official Vencord Installer,<br>
  verifies its integrity, then runs two install and repair passes for every detected version — without a CMD window.
</p>

<p align="center">
  <img src="assets/features.svg" alt="Vencord Auto Installer features" width="100%">
</p>

---

## ✦ Why use this tool?

<table>
  <tr>
    <td width="50%"><strong>🌑 Fully hidden execution</strong><br>No CMD or PowerShell window appears during manual installation or automatic startup.</td>
    <td width="50%"><strong>🎯 Smart detection</strong><br>Automatically detects the installed Stable, Canary, and PTB versions.</td>
  </tr>
  <tr>
    <td><strong>🛡️ Integrity verification</strong><br>Checks the installer against the officially published SHA-256 checksum.</td>
    <td><strong>⚡ Two passes per version</strong><br>The second pass reinstalls or repairs Vencord to help ensure the process completes successfully.</td>
  </tr>
</table>

## 🚀 Quick manual installation

1. Double-click **`Install Vencord Hidden.vbs`**.
2. Let it run in the background. Discord may close automatically while its files are being patched.
3. A small notification appears when the process finishes.
4. Open Discord Settings and confirm that the **Vencord** section is available.

> [!IMPORTANT]
> Run the tool as a normal user. Do not use **Run as administrator**.

<p align="center">
  <img src="assets/tokyo-ghoul-duality.png" alt="Ken Kaneki human and ghoul duality" width="100%">
</p>

## 🖥️ Startup Manager

<p align="center">
  <img src="assets/startup-manager.png" alt="Vencord Startup Manager" width="430">
</p>

<table>
  <tr>
    <td width="50%" align="center">
      <h3>🟢 Add</h3>
      Copies the required files to a persistent location and enables silent startup execution.
    </td>
    <td width="50%" align="center">
      <h3>🔴 Remove</h3>
      Removes the Startup shortcut and cleans up helper files without uninstalling Vencord from Discord.
    </td>
  </tr>
</table>

### Add it to Startup

1. Open **`Startup.vbs`**. The interface appears immediately without waiting for PowerShell.
2. Under **Run at Startup**, only installed Discord versions are shown. These checkboxes select which Discord apps open after Vencord finishes; they do not select which versions receive Vencord.
3. Every checkbox is unchecked by default, and you may leave all of them unchecked. Click **Add** to save your selection.
4. The required files are copied automatically to:

   ```text
   %LOCALAPPDATA%\VencordAutoInstaller
   ```

5. After **Added to Startup** appears, you may safely delete the downloaded project folder.
6. At Windows sign-in, the tool silently installs Vencord on every detected Discord version, then opens only the Discord apps selected in the interface. If nothing is selected, Discord will not open automatically.

When Windows starts, the tool silently waits until GitHub is reachable, checking every five seconds before beginning installation. There is no timeout and no window appears while it waits.

When you click **Add**, the native Startup entries for Discord, Discord Canary, and Discord PTB are set to **Disabled** in Task Manager, whether all three versions are installed or not. After Vencord finishes, the helper opens only the Discord apps selected in the interface. It waits ten seconds after launching them and disables the three native entries again to prevent Discord from re-enabling them. **Remove** does not re-enable Discord's native Startup entries.

> [!TIP]
> **Remove** disables automatic execution and removes the helper files only. Vencord installed inside Discord remains unchanged. If a helper file is still in use, Startup is still removed and the file can be cleaned up after the active installer exits.

## ⚙️ What happens in the background?

```text
Detect Discord versions
          ↓
Download official Vencord Installer
          ↓
Verify published SHA-256 checksum
          ↓
Install pass 1 → Repair pass 2
          ↓
Save result to Vencord-Install.log
```

The two passes run sequentially rather than simultaneously for the same Discord version. This prevents conflicts while `app.asar` and `_app.asar` are being replaced.

## 🔐 Security and privacy

- Downloads come from the [official Vencord Installer repository](https://github.com/Vencord/Installer/releases/latest).
- The tool does not send personal data and never asks for your Discord password.
- It does not install drivers or modify Windows system files.
- It runs only with the current user's permissions.
- Temporary installer and checksum files are deleted when the process finishes.
- Success and error details are stored locally in **`Vencord-Install.log`**.

## 📦 Project files

| File | Purpose |
|---|---|
| `Install Vencord Hidden.vbs` | Hidden launcher for installation and repair |
| `utilis/Install-Vencord-All.ps1` | Detects Discord, downloads and verifies the installer, and runs both passes |
| `Startup.vbs` | Opens the fast Startup Manager interface |
| `utilis/Startup-Manager.hta` | Dark Add and Remove interface |
| `Vencord-Install.log` | Log from the latest run; created after the tool runs |

## 🧪 Safe test without modifying Discord

Open PowerShell in the project folder and run:

```powershell
.\utilis\Install-Vencord-All.ps1 -DryRun -Passes 2
```

This mode tests Discord detection, downloads the installer, and verifies its checksum without installing Vencord or modifying any Discord files.

## 🧩 Troubleshooting

1. Make sure your internet connection works and GitHub is not blocked.
2. Close Discord completely, then run **`Install Vencord Hidden.vbs`** again.
3. Check **`Vencord-Install.log`** to identify the version or pass that failed.
4. If you moved the downloaded files before clicking Add, open `Startup.vbs` from the new location and click Add again.

---

<p align="center">
  <strong>Vencord Auto Installer</strong><br>
  Dark, fast, and silent — built for a smoother installation.
</p>

> [!WARNING]
> Vencord is an unofficial Discord modification and may violate Discord's Terms of Service. Use it at your own risk.
