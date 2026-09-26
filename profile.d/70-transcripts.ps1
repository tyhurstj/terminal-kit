# ==============================================================================
# 70-transcripts.ps1 -- record sessions so an agent can find what you did, later
# ==============================================================================
# Start-Transcript / Stop-Transcript are built into PowerShell and do the actual
# recording. What they DON'T do on their own is give you a consistent place to
# put the file, a name you can find again, or any way to search a hundred saved
# sessions without opening each one. This file adds that, in two tiers:
#
#   AUTOMATIC  every interactive window records itself from the moment it opens
#              -> Terminal_Transcripts\auto\2026-09\2026-09-25_081502_pwsh-12345.txt
#              Not indexed, deleted after $AutoTranscriptDays days. A safety net:
#              "what was that command I ran Tuesday?" is answerable with rg.
#
#   CURATED    Start-AgentLog / Stop-AgentLog (aliases: log / endlog), on demand
#              -> Terminal_Transcripts\2026-09-18_143205_jot.txt  + a line in INDEX.md
#              Kept forever. For the session where you fought a bug for 20
#              minutes and won -- the one a future Claude Code session should
#              be able to find without asking you to re-explain it.
#
# The two coexist because transcripts NEST, like a stack of plates: starting a
# second transcript doesn't stop the first, both record, and Stop-Transcript
# removes the most recent one first. So a curated log is just a second plate on
# top of the automatic one. (Verified on this PC before relying on it.)
#
# PRIVACY: a transcript records everything printed, including any token or
# password a command displays. Before doing something like that, run 'nolog'.

$script:TranscriptRoot     = Join-Path $HOME 'Documents\Programming\Terminal_Transcripts'
$script:AutoTranscriptDays = 30
# Deliberately NOT reset here: $script:SessionLogPath and $script:AgentLog*.
# You reload this profile with ". $PROFILE" all the time. If a reload set them
# back to $null, it would forget a recording that is still running -- then start
# a duplicate one, and leave Stop-AgentLog unable to find its own file.

# ------------------------------------------------------------------------------
# AUTOMATIC: start recording this window
# ------------------------------------------------------------------------------
# Only when a human opened this window (see profile.ps1). Without that check,
# every script, VS Code task, and AI agent that launches PowerShell would leave
# a transcript behind, and the folder would fill with noise nobody reads.
# $env:TERMKIT_NO_TRANSCRIPT = 1 before launching opts one window out.
if ($script:KitInteractive -and -not $env:TERMKIT_NO_TRANSCRIPT -and -not $script:SessionLogPath) {
    try {
        $month = Join-Path $script:TranscriptRoot ("auto\" + (Get-Date -Format 'yyyy-MM'))
        New-Item -ItemType Directory -Path $month -Force | Out-Null
        # $PID (this process's ID) makes the name unique even if you open two
        # windows in the same second.
        $script:SessionLogPath = Join-Path $month ("{0}_pwsh-{1}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'), $PID)
        # -UseMinimalHeader skips ~15 lines of machine details per file.
        Start-Transcript -Path $script:SessionLogPath -NoClobber -UseMinimalHeader | Out-Null
    }
    catch {
        $script:SessionLogPath = $null
        Write-Warning "Automatic transcript not started: $($_.Exception.Message)"
    }
    Remove-Variable month -ErrorAction SilentlyContinue

    # Housekeeping: delete automatic transcripts older than the limit. Done on
    # OnIdle -- after the prompt is up -- so it never slows the window opening.
    # An event's Action runs in its own scope and can't see our variables, so
    # the two values it needs travel in -MessageData.
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -MessageData @{
        Dir  = Join-Path $script:TranscriptRoot 'auto'
        Days = $script:AutoTranscriptDays
    } -Action {
        $cutoff = (Get-Date).AddDays(-$Event.MessageData.Days)
        Get-ChildItem -Path $Event.MessageData.Dir -Recurse -File -Filter '*.txt' -ErrorAction SilentlyContinue |
            Where-Object LastWriteTime -lt $cutoff |
            Remove-Item -ErrorAction SilentlyContinue
        # Then remove month folders left empty.
        Get-ChildItem -Path $Event.MessageData.Dir -Directory -ErrorAction SilentlyContinue |
            Where-Object { -not (Get-ChildItem $_.FullName -Force) } |
            Remove-Item -ErrorAction SilentlyContinue
    }
}


function Stop-SessionLog {
<#
.SYNOPSIS
    Stop this window's AUTOMATIC transcript -- e.g. before showing a secret.
.DESCRIPTION
    Everything a command prints goes into the transcript, including tokens and
    passwords (think "gh auth token"). Run this first. Only this window stops
    recording; new windows still record. Refuses while a curated Start-AgentLog
    is running, because Stop-Transcript would stop THAT one instead (the most
    recent transcript always stops first).
.EXAMPLE
    nolog
#>
    [CmdletBinding()]
    param()
    if ($script:AgentLogPath) {
        Write-Warning "A curated log is running (Start-AgentLog). Run Stop-AgentLog first."
        return
    }
    if (-not $script:SessionLogPath) {
        Write-Host "This window is not being recorded." -ForegroundColor DarkGray
        return
    }
    Stop-Transcript | Out-Null
    Write-Host "Stopped recording this window. The part already recorded is kept at:" -ForegroundColor DarkGray
    Write-Host "  $script:SessionLogPath" -ForegroundColor DarkGray
    $script:SessionLogPath = $null
}


# ------------------------------------------------------------------------------
# CURATED: on demand, indexed, kept
# ------------------------------------------------------------------------------
function Start-AgentLog {
<#
.SYNOPSIS
    Begin recording this shell session to Terminal_Transcripts\, under a name
    you'll be able to find later.
.DESCRIPTION
    Wraps Start-Transcript so you never have to think about path or naming.
    The filename bakes in the timestamp AND the folder you were standing in
    when you started -- that folder name is usually the project name, which is
    the first thing an agent searches for ("find anything about jot").

    Everything you type and everything the shell prints from this point on is
    written to that file, in order, until you call Stop-AgentLog. The automatic
    window transcript keeps running underneath; this is a second, curated copy.
.EXAMPLE
    Start-AgentLog
    Just start recording. Fine when you don't yet know what this session is.
.EXAMPLE
    Start-AgentLog -Description "debugging the jot startup crash"
    The description is stored for you and reused as the default summary if you
    call Stop-AgentLog without one -- handy since you often know the "why"
    at the START of a debugging session, not the end.
#>
    [CmdletBinding()]
    param(
        # Optional. What you're about to do. Reused as the index summary if
        # Stop-AgentLog isn't given its own -Summary.
        [string]$Description
    )

    if ($script:AgentLogPath) {
        Write-Warning "Already logging to $script:AgentLogPath -- run Stop-AgentLog first."
        return
    }

    if (-not (Test-Path -LiteralPath $script:TranscriptRoot)) {
        New-Item -ItemType Directory -Path $script:TranscriptRoot -Force | Out-Null
    }

    # The leaf folder name doubles as a project tag. Falls back to "misc" for
    # anywhere outside Documents\Programming (e.g. C:\ itself).
    $tag = Split-Path -Leaf $PWD.Path
    if ([string]::IsNullOrWhiteSpace($tag)) { $tag = 'misc' }

    $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $path  = Join-Path $script:TranscriptRoot "${stamp}_${tag}.txt"

    Start-Transcript -Path $path -NoClobber | Out-Null

    $script:AgentLogPath = $path
    $script:AgentLogTag  = $tag
    $script:AgentLogDesc = $Description

    Write-Host "Recording to $path" -ForegroundColor DarkGray
    Write-Host "Run Stop-AgentLog when done." -ForegroundColor DarkGray
}


function Stop-AgentLog {
<#
.SYNOPSIS
    Stop recording and file a one-line summary into Terminal_Transcripts\INDEX.md.
.DESCRIPTION
    This is the step that makes the transcript actually findable. A raw log
    with no summary is something an agent has to open and read in full to
    judge relevance; one indexed line lets it skip the 99% that don't match.

    If you don't pass -Summary, it reuses whatever -Description you gave
    Start-AgentLog. If neither exists, it asks rather than writing a useless
    "no summary" line to the index.

    Only the curated log stops. The automatic window transcript underneath it
    keeps recording.
.EXAMPLE
    Stop-AgentLog -Summary "Fixed the jot startup crash: stale venv path in launch.json"
.EXAMPLE
    Stop-AgentLog
    Uses the -Description from Start-AgentLog, if you gave one.
#>
    [CmdletBinding()]
    param(
        # One sentence: what happened in this session. Written to INDEX.md.
        [string]$Summary
    )

    if (-not $script:AgentLogPath) {
        Write-Warning "Not currently logging -- run Start-AgentLog first."
        return
    }

    # Most recent transcript stops first -- that is this curated one.
    Stop-Transcript | Out-Null

    $text = if ($Summary) { $Summary } else { $script:AgentLogDesc }
    if (-not $text) {
        $text = Read-Host "One-sentence summary for the index (what happened this session)"
    }

    $indexPath = Join-Path $script:TranscriptRoot 'INDEX.md'
    $fileName  = Split-Path -Leaf $script:AgentLogPath
    $line      = "- $(Get-Date -Format 'yyyy-MM-dd HH:mm')  [$script:AgentLogTag]  $fileName — $text"
    Add-Content -LiteralPath $indexPath -Value $line

    Write-Host "Logged: $fileName" -ForegroundColor DarkGray
    Write-Host "Indexed: $text" -ForegroundColor DarkGray

    $script:AgentLogPath = $null
    $script:AgentLogTag  = $null
    $script:AgentLogDesc = $null
}
