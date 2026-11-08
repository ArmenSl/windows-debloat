# Bloat catalog

Use this to sort what the survey found into groups to offer the user. It is a starting point: always check what is actually installed, and when unsure, ask instead of guessing.

## Heavy third-party bloat (recommend removing)
Big or always running, and rarely needed on a server.
- Android emulators: BlueStacks (App Player, Services, X), NoxPlayer, LDPlayer. 2+ GB, background services.
- Trial or bundled "security": McAfee WebAdvisor / LiveSafe, Norton trials, Avast/AVG browser extensions. They duplicate Defender.
- Browser helpers: Opera Browser Assistant, Edge/Chrome auto-launch entries (startup only, keep the browser).
- Vendor updaters and helpers: Epson Software Updater and Event Manager, HP Smart, Dell SupportAssist, Lenovo Vantage extras.
- Gaming suites: OMEN Command Center, Armoury Crate, iCUE. These are often among the top RAM users.
- Second-screen and remote-display tools the user no longer uses: Duet Display, spacedesk.

## Windows / OEM Store bloat (recommend removing)
`Remove-AppxPackage` as the user, no admin needed.
- Xbox: `Microsoft.GamingApp`, `XboxGamingOverlay`, `XboxGameOverlay`, `XboxSpeechToTextOverlay`, `Xbox.TCUI` (keep `XboxIdentityProvider`).
- `MicrosoftSolitaireCollection`, `Clipchamp.Clipchamp`, `BingNews`, `BingWeather`, `MixedReality.Portal`, `MicrosoftFamily`, `People`, `WindowsMaps`, `WindowsFeedbackHub`, `GetHelp`, `ZuneMusic`/`ZuneVideo` (media players: ask first).
- Third-party Store apps: Spotify, TikTok, Instagram, Disney+, Candy Crush.
- HP (`AD2F1837.*`): myHP, HPQuickDrop, HPEnhance, HPSupportAssistant, OMENCommandCenter. Keep HPPrivacySettings, HPSystemEventUtility and BangOlufsenAudioControl unless the user wants them gone: they control the hotkeys and audio.

## Personal apps (ask; default is keep)
Chat (Discord, WhatsApp, Telegram), reference managers (Zotero, Mendeley), Apple support/Bonjour/iTunes, VM software (VMware, VirtualBox: an agent host may need these!), school VPN/Wi-Fi tools (geteduroam), niche hobby or car tools (E-Sys), extra Office products (Project, Visio).

## Dev tools (default is KEEP on a server or agent box)
Git, GitHub Desktop, Node.js, Python, JDK, VS Code, Cursor, IntelliJ, PuTTY, Xming, WinRAR or 7-Zip, Docker, WSL.

## Never remove
See the "Never remove" list in SKILL.md. In short: security, drivers, Store, winget, Terminal, runtimes and frameworks, the user's antivirus, the user's current browser.

## Exit codes and gotchas
| Code | Meaning | What to do |
|---|---|---|
| 0 / 3010 | success / success, restart needed | Tell the user to restart |
| 1605 | product not installed | Already gone, fine |
| 1618 | another install is running | Wait and retry; never run installers in parallel |
| 0x80073CFA | Store app is system-protected | Skip it and report it |
| no log after a UAC prompt | the user declined | Ask; don't relaunch in a loop |
