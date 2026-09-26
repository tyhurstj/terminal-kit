# ==============================================================================
# 90-aliases.ps1 -- short names, and a cheat sheet so you can find them again
# ==============================================================================
# Note what is NOT here: 'h'. That is already an alias for Get-History, and
# quietly stealing a built-in name is how you confuse yourself six months later.
# Hence 'hh'. Checking before you claim a name is the habit, not the exception:
#   Get-Command h        (or: what h)
# Every name below was checked against this PC before it was claimed.
Set-Alias hh      Get-HelpFast    -Force
Set-Alias ex      Get-HelpExample -Force
Set-Alias par     Get-HelpParam   -Force
Set-Alias syn     Show-Syntax     -Force
Set-Alias what    Resolve-Cmd     -Force
Set-Alias mem     Show-Members    -Force
Set-Alias palette Show-Palette    -Force
Set-Alias log     Start-AgentLog  -Force
Set-Alias endlog  Stop-AgentLog   -Force
Set-Alias nolog   Stop-SessionLog -Force
Set-Alias ff      Find-File       -Force
Set-Alias fif     Search-Text     -Force
Set-Alias kit     Show-TerminalKit -Force


function Show-TerminalKit {
<#
.SYNOPSIS
    One screen listing every key and short command this profile adds.
.DESCRIPTION
    The real discoverability problem with a customized shell is not that the
    features are hard to use, it is that you forget they exist. This is the
    answer to "what was that key again?" without opening any file.
.EXAMPLE
    kit
#>
    [CmdletBinding()]
    param()

    $c = $script:Palette
    $r = $script:Reset
    $section = { param($t) Write-Host "`n$($PSStyle.Bold)$($c.Command)$t$r" }
    $row     = { param($k, $d) Write-Host ("  $($c.Parameter){0,-16}$r {1}" -f $k, $d) }

    & $section 'KEYS'
    & $row 'Up / Down'   'history, filtered by what you already typed'
    & $row 'Tab'         'menu of completions (also for gh, rg, fd, bat, winget)'
    & $row 'Ctrl+r'      'fuzzy-search ALL history'
    & $row 'Ctrl+t'      'fuzzy-pick a file, paste its path'
    & $row 'Alt+c'       'fuzzy-pick a folder, cd into it'
    & $row 'F1 / Alt+h'  'help for the command / parameter under the cursor'
    & $row 'F2'          'switch suggestion list <-> inline'

    & $section 'GET AROUND'
    & $row 'z <words>'   'jump to a folder you have been to     (z jot)'
    & $row 'zi'          'same, pick from a list'
    & $row '.. / ...'    'up one / two folders'

    & $section 'FIND'
    & $row 'ff <name>'   'find files by name                    (ff profile)'
    & $row 'fif <text>'  'find text in files, live, open hit    (fif Palette)'
    & $row 'rg <text>'   'plain grep-style search               (rg -i todo -g *.py)'

    & $section 'HELP'
    & $row 'hh <cmd>'    'summary + syntax + examples (works on .exe too)'
    & $row 'ex / par / syn' 'examples only / one parameter / syntax only'
    & $row 'what <name>' 'is it an alias, function, cmdlet, or .exe?'
    & $row '<obj> | mem' 'what properties and methods does this have?'

    & $section 'TRANSCRIPTS'
    $state = if ($script:SessionLogPath) { "on  -> $script:SessionLogPath" } else { 'off' }
    & $row 'this window'  $state
    & $row 'nolog'       'stop recording this window (before showing secrets)'
    & $row 'log / endlog' 'curated, indexed log for a session worth keeping'

    Write-Host "`n  $($c.Muted)Full source: $script:KitRoot$r`n"
}
