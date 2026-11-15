# Windows Sandbox Tools (fork)

Scripts and configs for [Windows Sandbox](https://learn.microsoft.com/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview), adapted from [ThioJoe/Windows-Sandbox-Tools](https://github.com/ThioJoe/Windows-Sandbox-Tools).

## Repository structure

- `Sandbox Configurations/WSandbox.wsb` — portable sandbox configuration template.
- `SandboxStartup.ps1` — startup script run inside the sandbox (registry/context-menu tweaks and optional auto-actions).
- `Install/` — installer scripts (run inside sandbox).
- `Theme/` — theme scripts (run inside sandbox).
- `General Scripts/` — general-purpose scripts (e.g. agent tunnel).
- `External Tools/` — host-side helper tools.
- `.github/workflows/` — CI/workflow definitions.

## Portable sandbox setup

1. Copy or edit `Sandbox Configurations/WSandbox.wsb`.
2. Set `<HostFolder>` to the **absolute path of this repository on your host** (mapped in sandbox as `C:\Users\WDAGUtilityAccount\Desktop\HostShared`). Windows Sandbox requires this path to exist (error `0x80070003` if not found).
3. Optionally map a downloads/cache folder (recommended read-only) to `C:\Users\WDAGUtilityAccount\Desktop\Downloads`.
4. Launch by double-clicking the `.wsb` file.

Keep machine-specific absolute paths appropriate for your setup; update `<HostFolder>` when moving/cloning the repo to a different location.

## Startup script (`SandboxStartup.ps1`)

Runs inside the sandbox (expects user `WDAGUtilityAccount`). Applies common tweaks:

- Classic context menu, show hidden files/extensions.
- Long path support, taskbar End Task, clipboard history, larger console buffer.
- Disables Desktop Spotlight and sets default wallpaper.
- Context menu entries: PowerShell/CMD/Windows Terminal here, edit with Notepad/Notepad++ (if present), `.txt` association, `.ps1` ShellNew/open support.
- Refreshes Explorer; opens `HostShared` on first launch (`-launchingSandbox`).

### Configurable auto-actions (off by default)

Pass parameters from the `.wsb` `<LogonCommand>` or when running manually:

- `-InstallWinget` — start `Install/Winget.ps1`.
- `-ApplyDarkTheme` — start `Theme/Dark-Mode.ps1` (`-NoRestartExplorer`).
- `-DarkThemeAutoRange "18:00-06:00"` — time range for dark theme (used with `-ApplyDarkTheme`).
- `-SetDns -DnsServer 8.8.8.8` — set DNS on detected adapters.
- `-RunScript "Install/Microsoft-Store.ps1","path\to\other.ps1"` — run extra scripts (relative to repo root / script dir, or absolute).
- `-debugTrace` — enable PowerShell trace and pause at end.

Example (visible window + auto-actions):

```xml
<Command>powershell -executionpolicy Bypass -command "start powershell {-NoExit -File C:\Users\WDAGUtilityAccount\Desktop\HostShared\SandboxStartup.ps1 -launchingSandbox -InstallWinget -ApplyDarkTheme -SetDns -DnsServer 8.8.8.8}"</Command>
```

## Installer scripts (`Install/`)

Run inside the sandbox from `C:\Users\WDAGUtilityAccount\Desktop\HostShared\...` (or your mapped path).

| Script | Purpose |
|---|---|
| `Winget.ps1` | Installs WinGet and dependencies from Microsoft releases. |
| `Microsoft-Store.ps1` | Installs Microsoft Store via Windows Update APIs (no third-party APIs). |
| `Install-Store-Apps.ps1` | Search/download/install Store/Windows Update catalog apps without requiring Store installed (no third-party APIs). |
| `Install-VC-Redist.ps1` | Installs latest VC++ Redistributables (x86/x64/ARM64 as applicable). Canonical script. |
| `VCRedist.ps1` | Compatibility wrapper that forwards to `Install-VC-Redist.ps1`. |

### Installer cache (faster repeated runs)

Many installers can reuse a pre-downloaded cache folder mapped into the sandbox instead of downloading every launch. Map a host cache folder into the sandbox and pass its **in-sandbox path**:

- `Install/Winget.ps1 -ExistingInstallerFilesPath "C:\Users\WDAGUtilityAccount\Desktop\HostSharedCache\Winget Install"`
- `Install/Microsoft-Store.ps1 -ExistingInstallerFilesPath "C:\Users\WDAGUtilityAccount\Desktop\HostSharedCache\MSStore Install"`  
  - supports `-ForceCachedFilesOnly` and `-NoCheckLatestVersion` (requires `-ExistingInstallerFilesPath`).
- `Install/Install-VC-Redist.ps1 -ExistingInstallerFilesPath "C:\Users\WDAGUtilityAccount\Desktop\HostSharedCache\VCRedist Install"` (or via `VCRedist.ps1`)  
  - supports `-ForceCachedFilesOnly` and `-NoCheckLatestVersion`.

Tip: keep cache folders populated from previous successful runs/downloads (scripts write version/hash metadata where applicable) and map them read-only or read-write depending on whether you want updates persisted to host.

## Theme scripts (`Theme/`)

- `Dark-Mode.ps1` — enables dark mode/wallpaper. Supports `-NoRestartExplorer` and `-AutoRange "HH:mm-HH:mm"`.
- `Light-Mode.ps1` — restores light theme.

## General scripts (`General Scripts/`)

- `Start-Agent-Tunnel.ps1` — creates disposable SSH access via outbound tunnel from inside sandbox and generates client connection packages/instructions (see script header for parameters and requirements).

## External tools (`External Tools/`)

- `Create-WSB-Copy-Files.bat` (host-side) — drag files onto it to generate a `.wsb` that copies those files into the sandbox at launch (no mapped folder required). Supports configurable options including optional auto-launch of a `.ps1`.

## Quality / CI

- `.github/workflows/lint.yml` runs [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) (`Warning`/`Error`) on PowerShell scripts.
- `SandboxStartup.ps1` tolerates missing `CiTool.exe` on sandbox images/builds where it is unavailable.
- `.github/workflows/ai-sandbox-windows.yml` provides upstream's temporary GitHub-hosted Windows sandbox/tunnel workflow (requires repository secrets/inputs as defined in the workflow).

Run lint locally (PowerShell):

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Get-ChildItem -Recurse -Filter *.ps1 -File | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Warning,Error }
```

## Notes

- Test inside Windows Sandbox after changes (startup, installers, cache modes, tunnel).
- Upstream reference: [ThioJoe/Windows-Sandbox-Tools](https://github.com/ThioJoe/Windows-Sandbox-Tools).
