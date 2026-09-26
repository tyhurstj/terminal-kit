# ==============================================================================
# 50-navigation.ps1 -- get around the file system, find files, search inside them
# ==============================================================================
# Four small programs do the heavy lifting here. Each is one .exe, installed to
# your user folder (no admin), and each does exactly one job well:
#
#   fzf     a FUZZY FINDER. Give it any list; type a few letters from anywhere
#           in the thing you want ("prgjot" finds Programming\jot) and it narrows
#           the list live. On its own it does nothing -- it makes OTHER lists
#           searchable: your history, your files, your folders.
#   fd      a faster, friendlier "find files by name". Skips .git and anything
#           your .gitignore lists, so results are the files you actually wrote.
#   rg      ripgrep: "find text INSIDE files" -- the grep of this toolkit. Same
#           .gitignore-aware skipping, and much faster than Select-String.
#   zoxide  a folder jumper that LEARNS. After you visit a folder a few times,
#           "z jot" takes you there from anywhere. No full paths.
#
# Keys and commands this file adds (run 'kit' any time to see this list):
#   Ctrl+r        fuzzy-search everything you have ever typed
#   Ctrl+t        fuzzy-pick a file below this folder; pastes its path
#   Alt+c         fuzzy-pick a folder below this folder; cd's into it
#   z <words>     jump to a folder you have visited before
#   zi            same, but pick from a fuzzy list
#   ff <name>     find files by name                         (fd)
#   fif <text>    find in files, live, then open the hit in VS Code (rg + fzf)
#   .. / ...      up one / two folders

# ------------------------------------------------------------------------------
# Locate the tools once
# ------------------------------------------------------------------------------
# Get-Command -CommandType Application finds real .exe files on PATH and ignores
# functions or aliases with the same name. $null means "not installed", and
# every feature below checks for that, so a missing tool costs you that one
# feature and nothing else.
function script:Find-Exe([string]$Name) {
    (Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1).Source
}
$script:FzfExe    = Find-Exe fzf
$script:FdExe     = Find-Exe fd
$script:BatExe    = Find-Exe bat
$script:RgExe     = Find-Exe rg
$script:ZoxideExe = Find-Exe zoxide

# ------------------------------------------------------------------------------
# fzf settings, shared by every fuzzy list
# ------------------------------------------------------------------------------
# fzf reads its settings from environment variables, which is why these are
# $env: and not ordinary variables: fzf is a separate program, and environment
# variables are how a parent process hands settings to a child.
if ($script:FzfExe) {
    # Colors copied from the palette in 20-colors.ps1 so the picker matches the shell.
    $env:FZF_DEFAULT_OPTS = @(
        '--height=45%', '--layout=reverse', '--border=rounded', '--info=inline'
        '--color=fg:#D8DEE9,fg+:#F2F4F8,bg+:#2A3A4A,hl:#62D6E8,hl+:#62D6E8'
        '--color=info:#E8C46A,prompt:#62D6E8,pointer:#C79BF0,marker:#8FD97A'
        '--color=spinner:#C79BF0,header:#6B7684,border:#3A4654'
    ) -join ' '

    if ($script:FdExe) {
        # What to list when fzf is asked for "files" or "folders". --hidden
        # includes dotfiles, --exclude .git skips git's internal clutter.
        $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
        $env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --exclude .git'
    }
    if ($script:BatExe) {
        # Ctrl+t shows the file's contents, syntax-highlighted, as you move
        # through the list -- you see WHICH notes.md before you pick it.
        $env:FZF_CTRL_T_OPTS = "--preview ""bat --color=always --style=numbers --line-range=:200 {}"""
    }
}

# ------------------------------------------------------------------------------
# PSFzf, loaded the first time you actually use it
# ------------------------------------------------------------------------------
# PSFzf is the module that connects fzf to PSReadLine's keys. Importing it costs
# about 1.5 seconds on this PC -- this machine's security software scans every
# script it loads, and PSFzf is ~200 KB of script. Paying that on EVERY launch,
# for keys you might not press, is a bad trade.
#
# So the keys below are bound to tiny stand-ins. The first press imports PSFzf
# (you wait once), then hands off to the real handler. Every press after that
# is instant because the module is already loaded. This is "lazy loading".
function Import-KitFzf {
    if (Get-Module PSFzf) { return $true }
    if (-not $script:FzfExe) { Write-Warning 'fzf is not installed.'; return $false }
    try {
        Import-Module PSFzf -Global -ErrorAction Stop
        if ($script:FdExe) { Set-PsFzfOption -EnableFd:$true }
        return $true
    }
    catch {
        Write-Warning "PSFzf could not load: $($_.Exception.Message)"
        return $false
    }
}

# (No "is PSFzf installed?" check here: that check scans every module folder and
#  costs ~50 ms per launch. Import-KitFzf reports a missing module when you
#  actually press the key, which is the only time it matters.)
if ($script:KitInteractive -and $script:FzfExe) {
    Set-PSReadLineKeyHandler -Chord Ctrl+r -BriefDescription FuzzyHistory `
        -Description 'Fuzzy-search your whole command history (PSFzf)' `
        -ScriptBlock { if (Import-KitFzf) { Invoke-FzfPsReadlineHandlerHistory } }

    Set-PSReadLineKeyHandler -Chord Ctrl+t -BriefDescription FuzzyFile `
        -Description 'Fuzzy-pick a file and paste its path (PSFzf)' `
        -ScriptBlock { if (Import-KitFzf) { Invoke-FzfPsReadlineHandlerProvider } }

    Set-PSReadLineKeyHandler -Chord Alt+c -BriefDescription FuzzyCd `
        -Description 'Fuzzy-pick a folder and cd into it (PSFzf)' `
        -ScriptBlock { if (Import-KitFzf) { Invoke-FzfPsReadlineHandlerSetLocation } }
}

# ------------------------------------------------------------------------------
# zoxide -- "z jot" instead of "cd ~\Documents\Programming\jot"
# ------------------------------------------------------------------------------
# Two separate jobs, handled two separate ways:
#
#   LEARNING where you go: our prompt (30-prompt.ps1) runs "zoxide add" each
#   time you land in a new folder. That needs only zoxide.exe, nothing loaded.
#
#   JUMPING (z / zi): needs zoxide's PowerShell functions. zoxide.exe PRINTS
#   those for you ("zoxide init powershell"). Most guides pipe that into
#   Invoke-Expression at every launch -- which runs zoxide.exe AND pays this
#   PC's script-scan cost at every launch, for a command you may not use.
#
# So: z and zi below are stand-ins. The first time you use either one, they
# load zoxide's real functions from a cache file (generated once, rebuilt only
# when zoxide is updated) and pass your words along. zoxide's setup defines
# z and zi as ALIASES, and PowerShell looks up aliases BEFORE functions -- so
# from then on your typing goes straight to zoxide and these stand-ins are
# never called again. They step aside by themselves.
#
# --hook none: stop zoxide wrapping our prompt function (see 30-prompt.ps1).
function Import-KitZoxide {
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) { return $true }
    if (-not $script:ZoxideExe) { Write-Warning 'zoxide is not installed.'; return $false }
    $cacheFile = Join-Path $env:LOCALAPPDATA 'terminal-kit\zoxide-init.ps1'
    $stale = -not (Test-Path $cacheFile) -or
             (Get-Item $cacheFile).LastWriteTime -lt (Get-Item $script:ZoxideExe).LastWriteTime
    if ($stale) {
        New-Item -ItemType Directory -Path (Split-Path $cacheFile) -Force | Out-Null
        & $script:ZoxideExe init powershell --hook none | Set-Content -Path $cacheFile -Encoding utf8
    }
    # zoxide's script declares everything "global:", so it survives even
    # though we are loading it from inside this function.
    . $cacheFile
    return $true
}
function z  { if (Import-KitZoxide) { __zoxide_z @args } }
function zi { if (Import-KitZoxide) { __zoxide_zi @args } }

# ------------------------------------------------------------------------------
# Small commands
# ------------------------------------------------------------------------------
# A function CAN be named '..' -- PowerShell only needs the name to not clash
# with anything, and nothing else is called that.
function .. { Set-Location .. }
function ... { Set-Location ..\.. }


function Find-File {
<#
.SYNOPSIS
    Find files by name, fast, skipping .git and anything .gitignore'd.
.DESCRIPTION
    A thin wrapper around fd. The pattern is a regular expression matched
    against the file NAME, anywhere in it, case-insensitive unless you type a
    capital letter ("smart case"). If fd is missing, falls back to
    Get-ChildItem -Recurse, which is slower and does not know about .gitignore.

    The built-in equivalent, for comparison:
        Get-ChildItem -Recurse -Filter *profile*
.EXAMPLE
    ff profile
    Every file with "profile" in its name, below the current folder.
.EXAMPLE
    ff '\.ino$' ~\Documents\Programming\Arduino
    Every Arduino sketch under a specific folder ('$' means "ends with").
.EXAMPLE
    ff jot -Extension py
    Only .py files with "jot" in the name.
#>
    [CmdletBinding()]
    param(
        # Part of the file name to look for (a regular expression).
        [Parameter(Mandatory, Position = 0)][string]$Pattern,
        # Where to start looking. Defaults to the current folder.
        [Parameter(Position = 1)][string]$Path = '.',
        # Only files with this extension, without the dot: py, ps1, ino...
        [string]$Extension
    )

    if ($script:FdExe) {
        $fdArgs = @('--type', 'f', '--hidden', '--exclude', '.git')
        if ($Extension) { $fdArgs += @('--extension', $Extension) }
        $fdArgs += $Pattern
        # Only pass a folder if you gave one. fd searches the current folder by
        # default and then prints tidy relative paths; handing it '.' makes it
        # print './' in front of every result.
        if ($PSBoundParameters.ContainsKey('Path')) { $fdArgs += $Path }
        & $script:FdExe @fdArgs
    }
    else {
        $filter = if ($Extension) { "*.$Extension" } else { '*' }
        Get-ChildItem -Path $Path -Recurse -File -Filter $filter -ErrorAction SilentlyContinue |
            Where-Object Name -match $Pattern |
            ForEach-Object FullName
    }
}


function Search-Text {
<#
.SYNOPSIS
    Find text inside files, live: type to narrow, Enter opens the hit in VS Code.
.DESCRIPTION
    ripgrep (rg) does the searching; fzf shows the results and re-runs the search
    as you edit the query. A preview pane shows the matching line in context.
    Inside the picker: Ctrl+r = search mode (re-run rg), Ctrl+f = filter mode
    (fuzzy-filter the current results without searching again).

    For a plain, non-interactive search, use rg directly -- it IS the grep here:
        rg "Start-Transcript"               search below the current folder
        rg -i "todo" -g "*.py"              case-insensitive, only .py files
        rg -l "Palette"                     list matching FILES, not lines

    PowerShell's own grep is Select-String (alias sls). It is slower, but it
    works on OBJECTS in a pipeline too:  Get-Process | sls chrome
.EXAMPLE
    fif Palette
.EXAMPLE
    fif 'def main' -NoEditor
    Print the chosen file's path instead of opening it.
#>
    [CmdletBinding()]
    param(
        # Starting query. You can keep editing it inside the picker.
        [Parameter(Mandatory, Position = 0)][string]$Query,
        # Return the path instead of opening an editor.
        [switch]$NoEditor
    )
    if (-not $script:RgExe) { Write-Warning 'ripgrep (rg) is not installed.'; return }
    if (-not (Import-KitFzf)) { return }
    Invoke-PsFzfRipgrep -SearchString $Query -NoEditor:$NoEditor
}
