<#
================================================================================
 terminal-kit\profile.ps1  --  the entry point PowerShell 7 actually loads
================================================================================
 Audience: James. Written to be READ as much as run -- every block says WHY,
 so any piece of it can be pulled into a lesson later.

 What this file demonstrates:
   1. Splitting one long profile into small numbered files you can reason about
   2. A one-line "stub" in $PROFILE that points here, instead of a fragile link
   3. Deciding ONCE whether a human is at the keyboard, and sharing the answer
   4. Measuring startup cost per file, because every file costs time at launch

 How it gets loaded: $PROFILE (Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
   contains a single line that dot-sources this file. install.ps1 writes it.
 Reload without restarting:   . $PROFILE
 See what each file costs:    $env:TERMKIT_TIMING = 1; . $PROFILE
 Skip the automatic transcript for one window:  $env:TERMKIT_NO_TRANSCRIPT = 1; pwsh
================================================================================
#>

# Where this repo lives. $PSScriptRoot is "the folder of the script that is
# running right now", so the repo still works if you move or re-clone it.
$script:KitRoot = $PSScriptRoot

# ------------------------------------------------------------------------------
# Is a human actually at the keyboard?
# ------------------------------------------------------------------------------
# Several files need this answer: prediction needs a real screen to draw on, and
# the automatic transcript should record YOUR sessions, not every script, build
# step, or AI agent that happens to start PowerShell. Computing it once here
# means every file agrees, and the rule lives in one place.
#
# Three tests, all must pass:
#   - output is not redirected   (nobody piped us into a file or another program)
#   - no -Command / -File / -NonInteractive on the command line
#                                (those mean "run this and leave", not "a session")
#                                ...unless -NoExit is there too, which means
#                                "run this, then stay open for me to type"
#   - the process is interactive (a Windows service would fail this)
$script:KitInteractive = $false
try {
    $launchArgs = [Environment]::GetCommandLineArgs() | Select-Object -Skip 1
    $runAndLeave = ($launchArgs | Where-Object { $_ -match '^-(c|command|f|file|noninteractive|encodedcommand|ec)$' }) -and
                   -not ($launchArgs | Where-Object { $_ -match '^-(noe|noexit)$' })
    $script:KitInteractive = (-not [Console]::IsOutputRedirected) -and
                             (-not $runAndLeave) -and
                             [Environment]::UserInteractive
} catch { }

# ------------------------------------------------------------------------------
# Load every file in profile.d, in name order
# ------------------------------------------------------------------------------
# The numbers in the filenames (10-, 20-, 30- ...) ARE the load order. Gaps of
# ten leave room to slot a new file in between later without renaming anything,
# the same trick old BASIC programs used for line numbers.
#
# Dot-sourcing (the leading ". ") runs code in THIS scope rather than a private
# one, so the functions and variables it defines survive after it ends. Without
# the dot, every function would vanish the moment its file finished.
#
# WHY the files are glued together before running (measured on this PC):
#   8 files dot-sourced one by one ........ 2.2-2.4 s
#   the same 8 files joined into one block  1.5-1.7 s
# This PC's security software scans each script file it runs, and every scan
# has a fixed cost on top of the size-based one. Eight files = eight fixed costs.
# Joining them means one scan. You keep the tidy separate files for EDITING and
# pay for only one file when RUNNING -- which is also, roughly, what a build
# step does for a website.
$kitFiles = Get-ChildItem -Path (Join-Path $script:KitRoot 'profile.d') -Filter '*.ps1' | Sort-Object Name

function script:Import-KitFilesOneByOne([switch]$ShowTiming) {
    foreach ($file in $kitFiles) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            . $file.FullName
        }
        catch {
            # One broken file should cost you one feature, not the whole shell.
            Write-Warning "terminal-kit: $($file.Name) failed: $($_.Exception.Message)"
        }
        if ($ShowTiming) { Write-Host ("  {0,6:N0} ms  {1}" -f $sw.Elapsed.TotalMilliseconds, $file.Name) -ForegroundColor DarkGray }
    }
}

if ($env:TERMKIT_TIMING) {
    # Diagnosis mode: slower, but tells you which file is the expensive one.
    . Import-KitFilesOneByOne -ShowTiming
}
else {
    try {
        # Second measurement that shaped this: the scan costs ~19 ms per KB, and
        # it costs the SAME for comments as for code (tested: 50 KB of pure
        # comments took as long as 50 KB of code). These files are about half
        # comments -- on purpose, they are meant to be read. So comments stay
        # in the files, and are dropped here, in memory, just before running:
        #   ^\s*#      a line whose first visible character is #  -> dropped
        #   (?!>)      ...unless it's "#>", the END of a <# help #> block
        # <# help #> blocks are kept whole, because Get-Help reads them from the
        # running code -- drop them and "hh Find-File" goes blank.
        # 58 KB on disk becomes ~33 KB to scan: roughly half a second saved.
        #
        # Between files goes a marker line. It is a Write-Debug COMMAND rather
        # than a comment precisely so the filter keeps it; if an error message
        # quotes nearby code, the marker tells you which file it came from.
        # (It prints nothing unless you turn on $DebugPreference.)
        #
        # One rule this depends on: no multi-line string in profile.d may have
        # a line that starts with #, or the filter would cut it. None do today.
        $combined = foreach ($file in $kitFiles) {
            "Write-Debug 'profile.d\$($file.Name)'"
            (Get-Content -Path $file.FullName) -notmatch '^\s*#(?!>)'
        }
        . ([scriptblock]::Create($combined -join "`n"))
    }
    catch {
        # Joined together, ONE broken file stops everything after it. So if the
        # fast path fails, fall back to one-by-one, which contains the damage
        # to the broken file and names it in the warning.
        Write-Warning "terminal-kit: fast load failed ($($_.Exception.Message)); loading files one at a time."
        . Import-KitFilesOneByOne
    }
}
Remove-Variable kitFiles, combined, launchArgs, runAndLeave -ErrorAction SilentlyContinue
