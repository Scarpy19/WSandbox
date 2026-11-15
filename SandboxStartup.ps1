param(
    # Included by .wsb launch to indicate first sandbox launch
    [switch]$launchingSandbox,

    # Optional auto-actions (off by default for portability)
    [switch]$InstallWinget,
    [switch]$ApplyDarkTheme,
    [string]$DarkThemeAutoRange,
    [switch]$SetDns,
    [string]$DnsServer = '8.8.8.8',

    # Extra scripts to run at startup (paths relative to this script or absolute, inside sandbox)
    [string[]]$RunScript,

    # Set to $true to enable debug tracing and pause at end
    [switch]$debugTrace
)

if ($debugTrace) { Set-PSDebug -Trace 1 }

# ------ Check that we're running in the Windows Sandbox ------
if ($env:USERNAME -ne 'WDAGUtilityAccount') {
    Write-Host "`n`nERROR: This script is intended to be run from WITHIN the Windows Sandbox.`nIt appears you are running this from outside the sandbox.`n" -ForegroundColor Red
    Write-Host "`nPress Enter to exit." -ForegroundColor Yellow
    Read-Host
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Optional DNS override
if ($SetDns) {
    try {
        $adapters = Get-DnsClient -ErrorAction Stop | Where-Object { $_.InterfaceAlias -and $_.InterfaceAlias -notmatch 'Loopback' }
        if ($adapters) {
            foreach ($a in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses $DnsServer -ErrorAction Stop
            }
            Write-Host "DNS set to $DnsServer on $($adapters.Count) adapter(s)."
        } else {
            netsh interface ipv4 set dnsservers "Ethernet" static $DnsServer primary | Out-Null
            Write-Host "DNS set to $DnsServer (fallback adapter name)."
        }
    } catch {
        Write-Host "Warning: failed to set DNS ($DnsServer): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Change context menu to old style
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null

# Show file extensions
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f | Out-Null

# Show hidden files
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d 1 /f | Out-Null

# Enable Windows Long Path support
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" /v "LongPathsEnabled" /t REG_DWORD /d 1 /f | Out-Null

# Add End Task option to Taskbar right click menu
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v "TaskbarEndTask" /t REG_DWORD /d 1 /f | Out-Null

# Fix for slow MSI package install.
# See: https://github.com/microsoft/Windows-Sandbox/issues/68#issuecomment-2754867968
reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" /v "VerifiedAndReputablePolicyState" /t REG_DWORD /d 0 /f | Out-Null
CiTool.exe --refresh --json | Out-Null

# Allow running scripts
try { Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -ErrorAction Stop | Out-Null } catch {}

# Enable Clipboard History
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 1 -Type DWord -Force

# Increase console history
if (!(Test-Path "HKCU:\Console")) { New-Item -Path "HKCU:\Console" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Console" -Name "ScreenBufferSize" -Value 4294967295 -Type DWord

# Disable spotlight wallpaper and set default wallpaper
if (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings")) { New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings" -Name "EnabledState" -Value 0 -Type DWord
Copy-Item -Path "C:\Windows\Web\Wallpaper\Windows\img0.jpg" -Destination "$env:APPDATA\Microsoft\Windows\Themes\TranscodedWallpaper" -Force -ErrorAction SilentlyContinue
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d 1 /f | Out-Null

# ---- Optional auto-actions ----
if ($InstallWinget) {
    $wingetScript = Join-Path $scriptDir 'Install\Winget.ps1'
    if (Test-Path $wingetScript) {
        Start-Process powershell -ArgumentList @('-ExecutionPolicy','Bypass','-File',$wingetScript)
    } else {
        Write-Host "Winget script not found: $wingetScript" -ForegroundColor Yellow
    }
}

if ($ApplyDarkTheme) {
    $darkModeScript = Join-Path $scriptDir 'Theme\Dark-Mode.ps1'
    if (Test-Path $darkModeScript) {
        $args = @('-ExecutionPolicy','Bypass','-File',$darkModeScript,'-NoRestartExplorer')
        if ($DarkThemeAutoRange) { $args += @('-AutoRange', $DarkThemeAutoRange) }
        Start-Process powershell -ArgumentList $args
    } else {
        Write-Host "Dark mode script not found: $darkModeScript" -ForegroundColor Yellow
    }
}

if ($RunScript) {
    foreach ($s in $RunScript) {
        $path = if ([System.IO.Path]::IsPathRooted($s)) { $s } else { Join-Path $scriptDir $s }
        if (Test-Path $path) {
            Start-Process powershell -ArgumentList @('-ExecutionPolicy','Bypass','-File',$path)
        } else {
            Write-Host "Requested script not found: $path" -ForegroundColor Yellow
        }
    }
}

# ---- Add 'Open PowerShell Here' and 'Open CMD Here' to context menu -------
$powershellPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$cmdPath = 'C:\Windows\System32\cmd.exe'
Write-Host "`nAdding 'Open PowerShell/CMD Here' context menu options"
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\MyPowerShell" /ve /d "Open PowerShell Here" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\MyPowerShell" /v "Icon" /t REG_SZ /d "$powershellPath,0" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\MyPowerShell\command" /ve /d "powershell.exe -noexit -command Set-Location -literalPath '%V'" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\Mycmd" /ve /d "Open CMD Here" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\Mycmd" /v "Icon" /t REG_SZ /d "$cmdPath,0" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\Mycmd\command" /ve /d "cmd.exe /s /k cd /d `"\`"%V`"\`"" /f | Out-Null

# ---- Add Windows Terminal (wt) to context menu -------
$wtPath = (Get-Command wt.exe -ErrorAction SilentlyContinue).Source
if ($wtPath -and (Test-Path $wtPath)) {
    Write-Host "`nAdding 'Open in Windows Terminal' context menu option"
    reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\OpenWTHere" /ve /d "Open in Windows Terminal" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\OpenWTHere" /v "Icon" /t REG_SZ /d "$wtPath,0" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\OpenWTHere\command" /ve /d "wt.exe -d .""" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\shell\OpenWTHere" /ve /d "Open in Windows Terminal" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\shell\OpenWTHere" /v "Icon" /t REG_SZ /d "$wtPath,0" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\shell\OpenWTHere\command" /ve /d "wt.exe -d """%V"""" /f | Out-Null
}

# ---- Add Notepad / Notepad++ context menu options -------
$notepadPath = 'C:\Windows\System32\notepad.exe'
$notepadPlusPlusPath = 'C:\Program Files\Notepad++\notepad++.exe'
if (!(Test-Path $notepadPath)) { $notepadPath = $null; Write-Host 'Notepad not found, context menu options will not be added.' }
if (!(Test-Path $notepadPlusPlusPath)) { $notepadPlusPlusPath = $null }

if ($null -ne $notepadPath) {
    Write-Host "`nAdding notepad edit option in context menu"
    reg add "HKEY_CLASSES_ROOT\*\shell\Edit with Notepad" /v "Icon" /t REG_SZ /d "$notepadPath,0" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\*\shell\Edit with Notepad\command" /ve /d "notepad.exe `"%1`"" /f | Out-Null
}

if ($null -ne $notepadPlusPlusPath) {
    Write-Host "`nAdding Notepad++ edit option in context menu"
    reg add "HKEY_CLASSES_ROOT\*\shell\Edit with Notepad++" /v "Icon" /t REG_SZ /d "$notepadPlusPlusPath,0" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\*\shell\Edit with Notepad++\command" /ve /t REG_EXPAND_SZ /d "`"$notepadPlusPlusPath`" -settingsDir=`"%appdata%`" `"`"%1`"`"" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\Notepad++" /ve /d "Open Notepad++" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\Notepad++" /v "Icon" /t REG_SZ /d "$notepadPlusPlusPath,0" /f | Out-Null
    reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\Notepad++\command" /ve /t REG_EXPAND_SZ /d "`"$notepadPlusPlusPath`" -settingsDir=`"%appdata%`"" /f | Out-Null
}

# Set .txt files to open with Notepad, or Notepad++ if available
cmd /c assoc .txt=txtfile | Out-Null
if (($null -ne $notepadPath) -or ($null -ne $notepadPlusPlusPath)) {
    if (!(Test-Path 'HKLM:\SOFTWARE\Classes\txtfile\shell\open\command')) { New-Item -Path 'HKLM:\SOFTWARE\Classes\txtfile\shell\open\command' -Force | Out-Null }
    if ($null -ne $notepadPlusPlusPath) {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Classes\txtfile\shell\open\command' -Name '(Default)' -Value ('"{0}" -settingsDir=%appdata% "%1"' -f $notepadPlusPlusPath) -Type ExpandString -Force
    } else {
        cmd /c ftype txtfile=`"$notepadPath`" "%1" | Out-Null
    }
}

# ShellNew PowerShell Script - .ps1
Write-Host "`nAdding PowerShell new file option"
reg add "HKEY_CLASSES_ROOT\.ps1" /ve /d "ps1file" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\ps1file" /ve /d "PowerShell Script" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\ps1file\DefaultIcon" /ve /d "%SystemRoot%\System32\imageres.dll,-5372" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\.ps1\ShellNew" /ve /d "ps1file" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\.ps1\ShellNew" /f | Out-Null
reg --% add "HKEY_CLASSES_ROOT\.ps1\ShellNew" /v "NullFile" /t REG_SZ /d "" /f | Out-Null
reg add "HKEY_CLASSES_ROOT\.ps1\ShellNew" /v "ItemName" /t REG_SZ /d "script" /f | Out-Null

# ================================ FINALIZATION ================================

# Restart Explorer so changes take effect
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

# Open an explorer window to the host-shared folder on first launch
if ($launchingSandbox) {
    $hostShared = 'C:\Users\WDAGUtilityAccount\Desktop\HostShared'
    if (Test-Path $hostShared) { Start-Process explorer.exe $hostShared }
}

if ($debugTrace) { Read-Host 'Debug trace complete, press Enter to exit.' }
