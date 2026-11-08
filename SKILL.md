---
name: windows-debloat
description: Safely clean up and debloat a Windows 10/11 PC by surveying it, archiving personal files, uninstalling bloatware, trimming startup apps, clearing junk and preparing the machine to run as an always-on server or agent box. Use this skill whenever the user wants to clean, speed up, debloat, declutter, "remove everything not needed", free disk space or RAM, remove preinstalled HP/Dell/Lenovo/OEM or Xbox apps, stop apps from starting with Windows, or turn a Windows laptop or desktop into a server, agent host, build machine or home lab, even if they never say "debloat".
---

# Windows debloat

This skill turns a messy personal Windows PC into a lean machine without losing anything the user cares about. Most such requests are vague and emotional ("remove all bad things, delete everything we don't need"). Your job is to turn them into a concrete list the user has approved, carry it out reliably and prove the result.

There are two hard rules. Personal files are never destroyed on this machine before a copy exists somewhere else. Nothing is uninstalled or deleted until the user has seen the list.

## Workflow

### 1. Survey (read-only)

Run the bundled survey; it changes nothing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <skill-dir>/scripts/survey.ps1
```

It reports the disk, RAM and CPU, whether you are admin, the sizes of the user folders (with the biggest Desktop/Documents/Downloads items), temp and update-cache sizes, startup entries, installed Win32 apps with their sizes, Store apps, and the processes using the most memory. Read it and sort what you see into the groups in `references/bloat-catalog.md`.

### 2. Ask once, in groups

Ask with a multiple-choice question tool if you have one, in plain language, with sizes and RAM numbers so the user sees why each item matters. Cover these, and recommend a default for each:

- **Personal files.** Move them to one archive folder, `C:\Archive\<YYYY-MM-DD>\` (the default: instant on the same drive, nothing lost), zip them, or archive and delete later once they have copied the archive off the machine.
- **App groups.** Heavy third-party bloat; Windows/OEM bloat; personal apps (chat, games, emulators, VMs); dev tools. Keep dev tools by default for a server or agent machine, because an agent host needs Git, Node, Python, an editor and a JDK. Remove them only if the user explicitly says so.
- **Startup.** Disable everything non-essential, or keep cloud sync such as OneDrive.

If the user writes "use max agents / swarm", explain briefly that Windows installers lock each other (MSI error 1618), so uninstalls must run one at a time. Only the read-only survey can be split up.

### 3. Archive personal files

Use `Move-Item` within the same volume. It is a rename: instant, and the files stay intact. Leave `.lnk` shortcuts and `desktop.ini` in place. Count the moved and failed items and report them. Keep the archive on the machine unless the user has confirmed that a copy exists elsewhere (USB, cloud). Only then offer to delete it, and confirm first, because the deletion cannot be undone.

### 4. Clean junk, without hurting yourself

- In `%TEMP%`, delete only items older than 1 day, and skip anything under a `claude` folder or your own scratchpad. Wiping all of `%TEMP%` can delete the agent's own working files, including scripts you are about to run.
- `C:\Windows\Temp` and `C:\Windows\SoftwareDistribution\Download` need admin, so put them in the elevated batch (step 6).
- Empty the Recycle Bin only if the user agrees.

### 5. Trim startup, with a backup

Before removing any `Run` key value, write `name = command` lines to `<archive>\startup-backup.txt`, so the user can restore an entry they miss. The `HKCU` Run entries work without admin; `HKLM` Run entries go in the elevated batch. Never touch `SecurityHealth` (Windows Security) or audio and display driver entries.

### 6. Uninstall

Do it in this order:

1. **Store apps (no admin):** `Remove-AppxPackage` for each one. Error `0x80073CFA` means the app is system-protected: report it and move on.
2. **Per-user Win32 apps (no admin):** apps registered under `HKCU` (Discord, per-user Electron apps). Stop their processes first, then run their `QuietUninstallString`.
3. **Machine-wide apps (admin):** use `scripts/elevated-uninstall.ps1`. It takes app-name patterns, resolves each uninstall command from the registry, writes **one** elevated script and launches it, so the user approves **one** UAC prompt instead of ten. It logs every step and waits for the result:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File <skill-dir>/scripts/elevated-uninstall.ps1 `
     -Patterns 'BlueStacks,WebAdvisor,Duet Display' -RemoveHklmRun 'Opera Browser Assistant' `
     -WorkDir 'C:\Archive\2026-11-08' -CleanSystemTemp
   ```

   Patterns are comma-separated regexes matched against the app's display name. Make them specific: `Microsoft 365` would match Office itself.

   Run it with `-DryRun` first to show the resolved commands without executing anything. The script already handles:
   - MSI apps: `msiexec /x {GUID} /qn /norestart`, using the registry key name when `UninstallString` is empty (VMware Player had no uninstall string).
   - Exit code 1618 (another installer is running): it retries after a short wait.
   - Office Click-to-Run (Project, Visio): the ARP command plus `DisplayLevel=False`.
   - Inno Setup (`unins000.exe`): `/VERYSILENT /NORESTART`.
   - Uninstallers with no silent mode (McAfee, Zotero, BlueStacks): it runs them interactively. Before you launch, tell the user to approve the UAC prompt and click through these windows.

4. Re-query the registry afterwards. Anything left gets one targeted retry. Report the rest honestly.

### 7. Server settings (the user runs these)

Power, sleep, lid and service settings are system settings. Give them to the user as commands to run in an admin PowerShell, one per code block, and explain what each one does:

```
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setactive SCHEME_CURRENT
```

Optional, also for the user to decide: create a restore point before a big cleanup, set Windows Update active hours, set up auto-login or "restart apps after sign-in" for headless use, and choose the Balanced or High performance power plan while plugged in.

### 8. Verify and report

Measure the free space before and after, and re-check the app and startup lists. Then report:

- **Done:** archive location and item count, apps removed, startup entries disabled, space freed (before → after).
- **Kept on purpose:** dev tools, browsers, Office, security software, drivers, runtimes.
- **Left for the user:** restart the PC, the server settings, and copying the archive off the machine.

## Never remove

Defender / `Microsoft.SecHealthUI`; drivers and the OEM driver services for audio, display and touchpad; `Microsoft.WindowsStore`; `Microsoft.DesktopAppInstaller` (winget); Windows Terminal; VC++ redistributables, .NET and other frameworks (`IsFramework`); `Microsoft.XboxIdentityProvider` (other apps depend on it); the user's security tool (for example Malwarebytes); the browser the user is currently using; anything the agent itself is running in.
