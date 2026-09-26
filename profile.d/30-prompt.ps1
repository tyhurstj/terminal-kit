# ==============================================================================
# 30-prompt.ps1 -- LAYER 3: the prompt
# ==============================================================================
# The prompt is just a function named 'prompt' that returns a string. That is
# the entire mechanism -- PowerShell calls it before every line. Anything you
# can compute, you can display.
#
# This one is two lines on purpose: the path gets a whole line to itself so long
# paths never squeeze the space you type in, and your command always starts at
# the same column.
#
# It also does one quiet job for zoxide (the "z" command, 50-navigation.ps1):
# every time you land in a new folder, it tells zoxide so "z" can learn where
# you go. zoxide's own setup would normally do that by WRAPPING this function
# in one of its own -- but its wrapper runs a statement before calling ours,
# which resets $? to True and would silently break the [failed] marker below.
# Doing it ourselves, after $? has been read, keeps both working.
function prompt {
    try {
        # Capture the outcome of the PREVIOUS command before doing anything
        # else -- almost any statement here overwrites $?. Order matters.
        $lastOk = $?
        $exit   = $LASTEXITCODE

        # --- Feed zoxide, only when the folder actually changed -------------
        # Running zoxide.exe is a new process; doing that on every prompt would
        # be wasteful, so remember the last folder and skip if it's the same.
        if ($script:ZoxideExe -and $PWD.Provider.Name -eq 'FileSystem' -and
            $PWD.ProviderPath -ne $script:LastPromptDir) {
            $script:LastPromptDir = $PWD.ProviderPath
            & $script:ZoxideExe add -- $PWD.ProviderPath 2>$null
        }

        if ($null -eq $PSStyle) { return "PS $($PWD.Path)> " }
        $p = $script:Palette
        $r = $script:Reset

        # Shorten the home folder to ~ the way every other shell does.
        $path = $PWD.Path.Replace($HOME, '~')

        # --- Git branch, WITHOUT running git.exe ---------------------------
        # Walk up the folder tree looking for .git, then read .git/HEAD, which
        # is a one-line text file naming the current branch. Spawning a real
        # process on every single prompt is what makes fancy prompts feel
        # sluggish; reading one small file does not.
        $branch = $null
        $dir = Get-Item -LiteralPath $PWD.Path -ErrorAction SilentlyContinue
        while ($dir) {
            $head = Join-Path $dir.FullName '.git/HEAD'
            if (Test-Path -LiteralPath $head -PathType Leaf) {
                $line = Get-Content -LiteralPath $head -TotalCount 1 -ErrorAction SilentlyContinue
                $branch = if ($line -match 'ref: refs/heads/(.+)') { $Matches[1] } else { 'detached' }
                break
            }
            $dir = $dir.Parent
        }

        $out  = "`n$($p.Muted)┌ $r"
        $out += "$($PSStyle.Bold)$($p.Folder)$path$r"
        if ($branch) { $out += "  $($p.Variable)($branch)$r" }

        # Did the last thing fail? Say so, visibly. A silent failure you scroll
        # past is worse than a loud one you notice.
        if (-not $lastOk -or ($null -ne $exit -and $exit -ne 0)) {
            $out += "  $($p.Bad)[failed]$r"
        }

        $out += "`n$($p.Muted)└ $r$($p.Command)>$r "
        return $out
    }
    catch {
        # A prompt that throws makes the shell unusable, so always leave a way out.
        return "PS $($PWD.Path)> "
    }
    finally {
        # zoxide.exe just set $LASTEXITCODE to ITS exit code. Put yours back, so
        # "$LASTEXITCODE" at the prompt still means "how did MY last program end".
        $global:LASTEXITCODE = $exit
    }
}
