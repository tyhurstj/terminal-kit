# ==============================================================================
# 60-completers.ps1 -- Tab completion for programs that are not PowerShell
# ==============================================================================
# PowerShell knows every parameter of every CMDLET, because cmdlets describe
# themselves. It knows nothing about .exe programs: "gh pr <Tab>" or
# "rg --col<Tab>" would just offer file names. The fix is an "argument
# completer" -- a script block PowerShell calls when you press Tab after that
# program's name, which returns the list of sensible next words.
#
# You don't have to write those by hand. Most modern command-line tools will
# PRINT a ready-made completer for PowerShell if you ask:
#     gh completion -s powershell
#     rg --generate complete-powershell
# The usual advice is to run that at every launch. On this PC that is a bad idea,
# and it is worth knowing why, because the reason is not obvious:
#
#   Measured here: parsing uv's completer takes 0.1 s, but RUNNING it takes
#   12 s. rg's takes 0.5 s, gh's 0.3 s. The gap is not PowerShell -- it is the
#   school's security software scanning every script as it runs, and cost goes
#   up with script size. Four completers at launch would add ~13 s to EVERY
#   new window.
#
# So each program gets a tiny stand-in completer instead. The first Tab after
# that program's name: generate the real completer (saved to a cache file so
# it is generated only once), load it, then pass your Tab through to it. You
# wait once per program per window, and only for programs you actually use.

# Programs to set up, and the arguments that make each one print its completer.
# To add one: find the tool's "completion" command in its --help, add a line.
$script:LazyCompleters = [ordered]@{
    gh  = 'completion', '-s', 'powershell'
    rg  = '--generate', 'complete-powershell'
    fd  = '--gen-completions', 'powershell'
    bat = '--completion', 'ps1'
    # uv = 'generate-shell-completion', 'powershell'
    #   ^ left off on purpose: 12 s to load on this PC even lazily (see above).
    #     Uncomment if you'd rather wait once than go without.
}

function Register-LazyCompleter {
<#
.SYNOPSIS
    Give an external program Tab completion that loads on first use.
.DESCRIPTION
    Registers a small stand-in completer for -Name. On the first Tab it runs
    the program with -GenerateArgs to get the real completer script, caches it
    under %LOCALAPPDATA%\terminal-kit\completions, loads it, and forwards the
    request. The cache is rebuilt automatically when the program is updated
    (the .exe becomes newer than the cache file).
.EXAMPLE
    Register-LazyCompleter -Name gh -GenerateArgs completion, -s, powershell
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$GenerateArgs
    )

    $exe = (Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1).Source
    if (-not $exe) { return }   # not installed: nothing to complete

    $cacheFile = Join-Path $env:LOCALAPPDATA "terminal-kit\completions\$Name.ps1"

    # A hashtable used as a one-slot "have I loaded yet?" flag. It has to be an
    # object, not a plain $true/$false, because of the closure below: the
    # closure gets its own COPY of plain values, but a hashtable is shared by
    # reference, so a change made inside the closure sticks.
    $state = @{ Loaded = $false }

    Register-ArgumentCompleter -Native -CommandName $Name -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        # Loaded already but still called? Then the real completer did not
        # replace this stand-in. Return nothing rather than loop forever.
        if ($state.Loaded) { return }
        $state.Loaded = $true

        # Generate the real completer if we have none, or ours is older than
        # the program (the program was updated and may have new options).
        $stale = -not (Test-Path $cacheFile) -or
                 (Get-Item $cacheFile).LastWriteTime -lt (Get-Item $exe).LastWriteTime
        if ($stale) {
            New-Item -ItemType Directory -Path (Split-Path $cacheFile) -Force | Out-Null
            & $exe @GenerateArgs | Set-Content -Path $cacheFile -Encoding utf8
        }

        # Load it inside a throwaway module. Some completer scripts define
        # helper functions that the completer calls later; a module keeps those
        # alive for as long as the completer needs them. Loading it this way
        # also re-registers the completer for $Name, replacing this stand-in.
        $null = New-Module -Name "completer-$Name" -ScriptBlock ([scriptblock]::Create((Get-Content -Raw $cacheFile)))

        # Now ask PowerShell to complete the same text again. This time the
        # REAL completer answers. $cursorPosition counts from the start of the
        # whole line; the command may start partway in (after a pipe, say), so
        # convert it to a position within just this command's text.
        $text   = $commandAst.Extent.Text
        $column = $cursorPosition - $commandAst.Extent.StartOffset
        if ($column -gt $text.Length) { $text = $text.PadRight($column) }
        (TabExpansion2 -inputScript $text -cursorColumn $column).CompletionMatches
    }.GetNewClosure()
    # .GetNewClosure() freezes $exe, $cacheFile, $GenerateArgs and $state INTO
    # the script block. Without it, those names would be looked up when you
    # press Tab -- long after this function has returned and they are gone.
}

foreach ($entry in $script:LazyCompleters.GetEnumerator()) {
    Register-LazyCompleter -Name $entry.Key -GenerateArgs $entry.Value
}
Remove-Variable entry -ErrorAction SilentlyContinue

# ------------------------------------------------------------------------------
# winget -- small enough to register directly
# ------------------------------------------------------------------------------
# winget works differently: instead of printing a completer script, it has a
# "winget complete" command that answers ONE Tab at a time. So the completer is
# only a few lines, costs nothing to register, and needs no cache. This is the
# snippet from Microsoft's winget documentation.
if (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $word = $wordToComplete.Replace('"', '""')
        $ast  = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$word" --commandline "$ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
