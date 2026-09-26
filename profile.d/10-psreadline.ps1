# ==============================================================================
# 10-psreadline.ps1 -- make the shell predict, not just echo
# ==============================================================================
# PSReadLine is the module that actually draws your command line. PowerShell 7
# ships with PredictionSource = None, meaning it does nothing but let you type.
# Turning prediction on is most of why a "fast" terminal looks fast: the shell
# finishes your sentence using commands you have already run.
try {
    Import-Module PSReadLine -ErrorAction Stop

    # Prediction needs a real terminal it can draw into. When PowerShell runs
    # with its output piped somewhere -- a script, a build step, an editor task
    # -- there is no such terminal, and asking for prediction throws a warning
    # every single time.
    #
    # $script:KitInteractive is worked out once in profile.ps1. Worth knowing
    # why the obvious check is wrong: $Host.UI.SupportsVirtualTerminal stays
    # True even when output is redirected, because it describes the host, not
    # the destination. [Console]::IsOutputRedirected asks the question that
    # actually matters: is anything a human can see on the other end of this?
    if ($script:KitInteractive) {

        # History = your own past commands. Plugin = any predictor module that
        # has registered itself -- CompletionPredictor, loaded further down.
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin

        # ListView shows a dropdown of candidates. InlineView shows one ghost
        # suggestion. Press F2 any time to flip between them.
        Set-PSReadLineOption -PredictionViewStyle ListView
    }

    # After searching history, put the cursor at the end of the line instead of
    # leaving it wherever you happened to be typing.
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    # Keep more history, and don't keep the same line twice. Fuzzy history
    # search (Ctrl+r, see 50-navigation.ps1) makes a long history MORE useful,
    # not less: you never scroll it, you search it. The default is 4096 lines.
    Set-PSReadLineOption -MaximumHistoryCount 20000
    Set-PSReadLineOption -HistoryNoDuplicates

    # Up/Down now search history FILTERED BY WHAT YOU ALREADY TYPED.
    # Type "git" then press Up -> only your git commands. This is the keybinding
    # most people wish someone had shown them years earlier.
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Tab opens a selectable menu instead of blindly cycling through matches.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # These are already bound by default in PSReadLine 2.4 -- listed here so you
    # KNOW they exist, which is the actual discoverability problem:
    #   F1      ShowCommandHelp       help for the command your cursor sits on
    #   Alt+h   ShowParameterHelp     help for the PARAMETER your cursor sits on
    #   F2      SwitchPredictionView  toggle Inline <-> List
    # (Ctrl+r used to be ReverseSearchHistory; 50-navigation.ps1 upgrades it to
    #  a fuzzy search across everything you have ever typed.)
}
catch {
    Write-Warning "PSReadLine setup skipped: $($_.Exception.Message)"
}

# ------------------------------------------------------------------------------
# CompletionPredictor -- suggestions for commands you have NEVER typed
# ------------------------------------------------------------------------------
# History prediction only knows what you have already run. CompletionPredictor
# feeds PowerShell's own Tab-completion engine into the suggestion list, so
# typing "Get-Ch" offers Get-ChildItem and its parameters even on day one.
#
# The trick here is WHEN it loads. Importing it takes about a second on this
# PC, and a second at every launch adds up. PowerShell raises an "OnIdle" event
# once the shell is sitting at the prompt waiting for you -- so we import it
# THEN, while you are reading the prompt, instead of making you wait for it.
# -MaxTriggerCount 1 means "do this once, then unsubscribe yourself".
#
# The same idea shows up everywhere in software: do the expensive thing after
# the screen is usable, not before. Web pages call it lazy loading.
# (No "is it installed?" check first -- that scans every module folder, ~50 ms.
#  If it's missing, the import below fails silently and nothing else changes.)
if ($script:KitInteractive) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        Import-Module CompletionPredictor -Global -ErrorAction SilentlyContinue
    }
}
