<#
================================================================================
 terminal-kit\install.ps1  --  wire this repo into this PC (no admin needed)
================================================================================
 Audience: James. Safe to run again at any time: every step checks what is
 already there and only changes what is missing or different ("idempotent").

 What this file demonstrates:
   1. A "stub" profile: $PROFILE holds one line that loads the repo, so the
      repo is the single source of truth and a git pull updates your shell
   2. Backing up any file before replacing it
   3. Editing a JSON settings file as DATA (ConvertFrom-Json), not as text
   4. Installing a font for one user only, which needs no admin
   5. Setting a USER environment variable that survives reboots

 What it changes:
   - $PROFILE                  -> one-line stub (old one backed up next to it)
   - Windows Terminal          -> fragment with the "Terminal Kit" color scheme;
                                  settings.json: default = PowerShell 7, scheme + font
   - Fonts (your account only) -> CaskaydiaCove Nerd Font, unless -SkipFont
   - PYTHONSTARTUP (user env)  -> python\startup.py
   - Programs/modules          -> ONLY with -InstallTools (see below)

 How to run (from the repo folder, in PowerShell 7):
   .\install.ps1                  check tools, wire everything up
   .\install.ps1 -InstallTools    also install missing fzf/fd/bat/rg/zoxide,
                                  PSFzf, CompletionPredictor, and rich
   .\install.ps1 -SkipFont        leave fonts alone

 Why tools are opt-in: installing software on a school PC can raise an IT
 alert. Every install here is user-scope (no admin), but it is still your call.
================================================================================
#>
[CmdletBinding()]
param(
    [switch]$InstallTools,
    [switch]$SkipFont
)

$ErrorActionPreference = 'Stop'
$repo  = $PSScriptRoot
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'

function Say([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }
function Step([string]$Text) { Write-Host "`n== $Text" -ForegroundColor Cyan }

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "Run this from PowerShell 7 (pwsh), not Windows PowerShell $($PSVersionTable.PSVersion)."
}

# ------------------------------------------------------------------------------
Step '1. Programs and modules'
# ------------------------------------------------------------------------------
# winget IDs for single-file programs. winget puts these under
# %LOCALAPPDATA%\Microsoft\WinGet\Packages and adds them to PATH -- user scope.
#
# But PATH is copied into each program when it STARTS. A winget install updates
# the saved PATH in the registry, not the copy this shell already has -- so a
# freshly installed tool looks "missing" until you open a new window. Re-read
# the saved PATH (system part first, then yours, the order Windows uses) so
# this script sees what a new window would.
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
Update-SessionPath
$programs = [ordered]@{
    fzf    = 'junegunn.fzf'
    fd     = 'sharkdp.fd'
    bat    = 'sharkdp.bat'
    rg     = 'BurntSushi.ripgrep.MSVC'
    zoxide = 'ajeetdsouza.zoxide'
}
foreach ($name in $programs.Keys) {
    if (Get-Command $name -CommandType Application -ErrorAction SilentlyContinue) {
        Say "  ok       $name"
    }
    elseif ($InstallTools) {
        Say "  install  $name ($($programs[$name]))" Yellow
        winget install --id $programs[$name] --exact --scope user --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Null
        Update-SessionPath
    }
    else {
        Say "  missing  $name   (rerun with -InstallTools, or: winget install --id $($programs[$name]) --scope user)" Yellow
    }
}

foreach ($module in 'PSFzf', 'CompletionPredictor') {
    if (Get-Module $module -ListAvailable) {
        Say "  ok       $module (module)"
    }
    elseif ($InstallTools) {
        Say "  install  $module (module)" Yellow
        Install-PSResource $module -Scope CurrentUser -TrustRepository -Quiet
    }
    else {
        Say "  missing  $module   (Install-PSResource $module -Scope CurrentUser)" Yellow
    }
}

if (Get-Command python -CommandType Application -ErrorAction SilentlyContinue) {
    python -c "import rich" 2>$null
    if ($LASTEXITCODE -eq 0) { Say "  ok       rich (Python)" }
    elseif ($InstallTools)   { Say "  install  rich (Python)" Yellow; python -m pip install --user --quiet rich }
    else                     { Say "  missing  rich   (python -m pip install --user rich)" Yellow }
}

# ------------------------------------------------------------------------------
Step '2. $PROFILE stub'
# ------------------------------------------------------------------------------
# The stub is ONE line that dot-sources the repo's profile.ps1. Why not a link?
# Symbolic links need admin on this PC. Hard links work, but many editors save
# by writing a brand-new file and renaming it over the old one, which silently
# breaks a hard link -- you'd be editing a copy without knowing it.
# A one-line stub can't break that way.
$profilePath = $PROFILE.CurrentUserCurrentHost
$stub = @"
# terminal-kit stub, written by install.ps1 on $(Get-Date -Format 'yyyy-MM-dd').
# The real profile lives in the repo -- edit it there, not here:
#   $repo
. "$(Join-Path $repo 'profile.ps1')"
"@

$current = if (Test-Path $profilePath) { Get-Content -Raw $profilePath } else { '' }
if ($current -and $current.Trim() -eq $stub.Trim()) {
    Say "  ok       $profilePath already points at the repo"
}
else {
    if ($current) {
        $backup = "$profilePath.before-terminal-kit_$stamp"
        Copy-Item $profilePath $backup
        Say "  backup   $backup"
    }
    New-Item -ItemType Directory -Path (Split-Path $profilePath) -Force | Out-Null
    Set-Content -Path $profilePath -Value $stub -Encoding utf8
    Say "  wrote    $profilePath" Green
}

# ------------------------------------------------------------------------------
Step '3. Nerd Font (your account only)'
# ------------------------------------------------------------------------------
# A "Nerd Font" is an ordinary programming font with thousands of icons added.
# CaskaydiaCove is Cascadia Code (Windows Terminal's default) plus those icons,
# so it looks familiar. Since Windows 10 (1809), a font can be installed for
# ONE user by copying it into %LOCALAPPDATA%\Microsoft\Windows\Fonts and
# registering it under HKEY_CURRENT_USER -- no admin, no system folder.
#
# The NAME to give Windows Terminal is less obvious than it looks. A font file
# carries more than one family name, and different parts of Windows read
# different ones. Checked on this PC:
#   DirectWrite (Windows Terminal, modern apps) sees: CaskaydiaCove NF, CaskaydiaCove Nerd Font
#   GDI         (older Win32 programs)          sees: CaskaydiaCove NF
# "CaskaydiaCove NF" is the one name every reader agrees on, so that's the one used.
$fontFace  = 'CaskaydiaCove NF'
$fontLabel = 'CaskaydiaCove Nerd Font'   # just the label shown in Settings > Fonts
$userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontRegKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$haveFont = Test-Path (Join-Path $userFonts 'CaskaydiaCoveNerdFont-Regular.ttf')

if ($haveFont) {
    Say "  ok       $fontLabel"
}
elseif ($SkipFont) {
    Say "  skipped  $fontLabel (-SkipFont)"
}
else {
    # Pinned to a known release rather than "latest", so this script does the
    # same thing every time it runs.
    $url = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaCode.zip'
    $tmp = Join-Path $env:TEMP "terminal-kit-font-$stamp"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Say "  download $url (~54 MB)" Yellow
    # Drawing the progress bar for every chunk can make a big download many
    # times slower in PowerShell. Switch it off just for this call.
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile (Join-Path $tmp 'font.zip')
    $ProgressPreference = 'Continue'
    Expand-Archive -Path (Join-Path $tmp 'font.zip') -DestinationPath $tmp -Force

    # The zip holds dozens of variants; a terminal needs just these four.
    New-Item -ItemType Directory -Path $userFonts -Force | Out-Null
    foreach ($style in 'Regular', 'Bold', 'Italic', 'BoldItalic') {
        $file = "CaskaydiaCoveNerdFont-$style.ttf"
        $src  = Join-Path $tmp $file
        if (-not (Test-Path $src)) { Say "  missing  $file in zip" Yellow; continue }
        $dest = Join-Path $userFonts $file
        Copy-Item $src $dest -Force
        $label = if ($style -eq 'Regular') { $fontLabel } else { "$fontLabel $style" }
        New-ItemProperty -Path $fontRegKey -Name "$label (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        Say "  font     $file" Green
    }
    Remove-Item $tmp -Recurse -Force
    $haveFont = Test-Path (Join-Path $userFonts 'CaskaydiaCoveNerdFont-Regular.ttf')
}

# ------------------------------------------------------------------------------
Step '4. Windows Terminal'
# ------------------------------------------------------------------------------
# A "fragment" is a JSON file Windows Terminal reads IN ADDITION to its own
# settings.json. The color scheme lives in the fragment, so the repo owns it:
# change terminal\terminal-kit.json, rerun this script, done.
$fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\terminal-kit'
$fragmentSrc = Join-Path $repo 'terminal\terminal-kit.json'
$fragmentDst = Join-Path $fragmentDir 'terminal-kit.json'
# Compare by content hash: identical files have identical hashes, so this says
# "already up to date" without caring about timestamps.
if ((Test-Path $fragmentDst) -and (Get-FileHash $fragmentSrc).Hash -eq (Get-FileHash $fragmentDst).Hash) {
    Say "  ok       color scheme fragment"
}
else {
    New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
    Copy-Item $fragmentSrc $fragmentDst -Force
    Say "  fragment $fragmentDst" Green
}

$wtSettings = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue |
              Select-Object -First 1
if (-not $wtSettings) {
    Say "  skipped  Windows Terminal settings.json not found" Yellow
}
else {
    # Read the file as DATA. Editing JSON with find-and-replace on text is how
    # you end up with a missing comma and a terminal that won't open.
    $json = Get-Content -Raw $wtSettings.FullName | ConvertFrom-Json -AsHashtable
    $changed = $false

    # Default profile -> PowerShell 7. Found by its SOURCE rather than a
    # hard-coded ID, so this works on a PC where the ID is different.
    $pwsh = $json.profiles.list | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1
    if ($pwsh -and $json.defaultProfile -ne $pwsh.guid) {
        $json.defaultProfile = $pwsh.guid
        $changed = $true
        Say "  default  new tabs now open PowerShell 7 (was Windows PowerShell 5.1, which never loads this profile)" Green
    }

    # "defaults" applies to every profile in the terminal, so cmd and Git Bash
    # get the same colors and font. One look, everywhere.
    if (-not $json.profiles.defaults) { $json.profiles.defaults = @{} }
    $d = $json.profiles.defaults
    if ($d.colorScheme -ne 'Terminal Kit') { $d.colorScheme = 'Terminal Kit'; $changed = $true; Say "  scheme   Terminal Kit" Green }
    if ($haveFont) {
        if (-not $d.font) { $d.font = @{} }
        if ($d.font.face -ne $fontFace) { $d.font.face = $fontFace; $changed = $true; Say "  font     $fontFace" Green }
    }

    if ($changed) {
        $backup = Join-Path $wtSettings.DirectoryName "settings.before-terminal-kit_$stamp.json"
        Copy-Item $wtSettings.FullName $backup
        Say "  backup   $backup"
        $json | ConvertTo-Json -Depth 32 | Set-Content -Path $wtSettings.FullName -Encoding utf8
        Say "  wrote    settings.json (Windows Terminal reloads it by itself)" Green
    }
    else {
        Say "  ok       settings.json already set"
    }
}

# ------------------------------------------------------------------------------
Step '5. Python startup file'
# ------------------------------------------------------------------------------
# 'User' scope writes to HKEY_CURRENT_USER\Environment: permanent, just for you,
# no admin. Programs read environment variables when they START, so only
# terminals opened AFTER this will see it.
$startup = Join-Path $repo 'python\startup.py'
if ([Environment]::GetEnvironmentVariable('PYTHONSTARTUP', 'User') -eq $startup) {
    Say "  ok       PYTHONSTARTUP"
}
else {
    [Environment]::SetEnvironmentVariable('PYTHONSTARTUP', $startup, 'User')
    Say "  set      PYTHONSTARTUP = $startup" Green
}

Step 'Done'
Say "  Open a NEW Windows Terminal tab (close and reopen the window if the font looks wrong)."
Say "  Then type:  kit"
