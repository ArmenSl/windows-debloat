# windows-debloat

A [Claude](https://claude.com/claude-code) skill that safely cleans up and debloats a Windows 10/11 PC and gets it ready to run as an always-on server or agent machine.

Just tell Claude something like *"clean my PC, remove everything we don't need, I want to use it as a server"*. The skill turns that into a safe, step-by-step plan that you approve before anything happens.

## What it does

1. **Survey (read-only).** Disk, RAM, user folders, temp and update caches, startup entries, installed apps and the processes using the most memory.
2. **Asks you once.** Grouped choices with sizes: personal files, app groups (heavy bloat, Windows/OEM bloat, personal apps, dev tools) and startup apps.
3. **Archives your files.** Desktop and Downloads go to `C:\Archive\<date>\`. Nothing is deleted.
4. **Cleans junk safely.** Only temp files older than a day, plus the Windows Update cache.
5. **Trims startup.** Every removed entry is backed up to a text file first.
6. **Uninstalls.** Store apps, per-user apps, then every machine-wide app from **one** elevated script (one admin prompt). It logs each step, retries when another install is busy and handles MSI, Office Click-to-Run and Inno Setup. It has a dry-run mode.
7. **Server settings.** Gives you the `powercfg` commands so the PC never sleeps and keeps running with the lid closed.
8. **Verifies and reports.** Free space before and after, what was removed, what was kept on purpose, and what is left for you to do.

It never removes Windows Security, drivers, the Store, winget, Terminal, runtimes, your antivirus or your current browser. Dev tools (Git, Node, Python, JDK, editors) are kept by default.

## Install

**Claude desktop / claude.ai:** download `windows-debloat.skill` from [Releases](../../releases) and click **Save skill**, or upload this folder as a zip under *Settings → Capabilities → Skills*.

**Claude Code:**

```bash
git clone https://github.com/ArmenSL/windows-debloat ~/.claude/skills/windows-debloat
```

## Use the scripts on their own

```powershell
# Read-only report
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\survey.ps1

# Show what would be uninstalled, without running anything
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\elevated-uninstall.ps1 `
  -Patterns 'BlueStacks,WebAdvisor' -WorkDir C:\Archive\test -DryRun
```

Remove `-DryRun` to actually uninstall. You get one admin (UAC) prompt, and the log is written to `<WorkDir>\uninstall-log.txt`.

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | The workflow Claude follows |
| `scripts/survey.ps1` | Read-only system survey |
| `scripts/elevated-uninstall.ps1` | Resolves and runs uninstalls under one admin prompt |
| `references/bloat-catalog.md` | What counts as bloat, what to keep, exit codes |

## Disclaimer

Uninstalling software and changing startup entries affects your system. Review the plan Claude shows you, run with `-DryRun` first, and keep a backup of anything important. Use at your own risk.

## License

MIT
