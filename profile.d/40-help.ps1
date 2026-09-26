# ==============================================================================
# 40-help.ps1 -- help wrappers: ask a narrow question, get a narrow answer
# ==============================================================================
# The complaint about Get-Help is not that it lacks information. It is that it
# answers a question you did not ask: you wanted "what order do the arguments
# go in" and got four screens of prose. Each function below is one narrow
# question. Note they all carry comment-based help, so "Get-Help hh" works.

function Show-Syntax {
<#
.SYNOPSIS
    Show only the syntax lines for a command. No prose.
.DESCRIPTION
    Answers exactly one question: what goes where, and what is optional?
    Square brackets mean optional. Angle brackets are the expected type.
.EXAMPLE
    syn Get-ChildItem
.EXAMPLE
    syn Copy-Item
#>
    [CmdletBinding()]
    param(
        # Name of the command to inspect.
        [Parameter(Mandatory)][string]$Name
    )
    Get-Command $Name -Syntax
}


function Get-HelpExample {
<#
.SYNOPSIS
    Show only the EXAMPLES section of a command's help.
.DESCRIPTION
    Examples are the part of help that actually teaches. This skips the prose
    and prints them in color: commands in green, sample output dimmed, the
    explanation in gray. If a command shows no examples at all, your help files
    were never downloaded -- run Update-Help -Scope CurrentUser (PowerShell 7;
    Windows PowerShell 5.1 has no -Scope and needs admin).
.EXAMPLE
    ex Get-ChildItem
.EXAMPLE
    ex Get-Process -First 3
#>
    [CmdletBinding()]
    param(
        # Name of the command whose examples you want.
        [Parameter(Mandatory)][string]$Name,
        # Show only the first N examples. 0 (the default) means show them all.
        [int]$First = 0
    )

    $help = Get-Help $Name -ErrorAction SilentlyContinue
    $examples = @($help.Examples.Example)

    if (-not $examples) {
        Write-Host "No examples found for '$Name'." -ForegroundColor Yellow
        Write-Host "If that is surprising, the help files are missing. Run:" -ForegroundColor DarkGray
        Write-Host "    Update-Help -Scope CurrentUser -ErrorAction SilentlyContinue" -ForegroundColor DarkGray
        return
    }

    $total = $examples.Count
    if ($First -gt 0 -and $First -lt $total) { $examples = $examples[0..($First - 1)] }

    foreach ($e in $examples) {
        Write-Host ""
        Write-Host (($e.title -replace '-{2,}', '').Trim()) -ForegroundColor Cyan

        # Two different help formats exist in the wild and you will hit both.
        # Older MAML help fills .code and .remarks. Help generated from Markdown
        # -- which is what Update-Help downloads today -- leaves those EMPTY and
        # puts the whole example, prose and fenced code together, in
        # .introduction. Reading only .code is why an earlier version of this
        # function printed titles and nothing else.
        $body = (($e.introduction | ForEach-Object { $_.Text }) -join "`n").Trim()
        if (-not $body) {
            $body = ("$($e.code)`n" + (($e.remarks | ForEach-Object { $_.Text }) -join "`n")).Trim()
        }
        if (-not $body) { continue }

        # Walk the Markdown line by line, tracking whether we are inside a
        # ```fenced``` block, so commands and sample output get told apart.
        $inFence   = $false
        $fenceKind = ''
        foreach ($line in ($body -split "`r?`n")) {

            if ($line -match '^\s*```(\w*)') {
                if (-not $inFence) { $fenceKind = $Matches[1] }
                $inFence = -not $inFence
                continue
            }

            if ($inFence) {
                # 'Output' fences are what the command PRINTED; dim them so the
                # command you would actually type stays the thing that pops.
                $color = if ($fenceKind -match '(?i)output') { 'DarkGray' } else { 'Green' }
                Write-Host "    $line" -ForegroundColor $color
                continue
            }

            if ($line.Trim()) {
                # Strip Markdown that means nothing in a console: **bold**,
                # `code spans`, and [text](links) all become their plain text.
                $clean = $line -replace '\*\*(.+?)\*\*', '$1' `
                               -replace '`([^`]+)`', '$1' `
                               -replace '\[([^\]]+)\]\([^)]+\)', '$1'
                Write-Host "  $clean" -ForegroundColor Gray
            }
        }
    }

    if ($First -gt 0 -and $First -lt $total) {
        Write-Host ""
        Write-Host "  ... $($total - $First) more. Run:  ex $Name" -ForegroundColor DarkGray
    }
}


function Get-HelpParam {
<#
.SYNOPSIS
    Explain ONE parameter of a command instead of all of them.
.DESCRIPTION
    Wildcards are added for you, so a partial name is fine. This is the fastest
    way to settle "what does -Recurse actually do here" style questions.
.EXAMPLE
    par Get-ChildItem Recurse
.EXAMPLE
    par Copy-Item dest
#>
    [CmdletBinding()]
    param(
        # Command to inspect.
        [Parameter(Mandatory)][string]$Name,
        # Parameter name, or any fragment of it. A leading dash is fine.
        [Parameter(Mandatory)][string]$Parameter
    )
    $pattern = "*{0}*" -f $Parameter.TrimStart('-')
    Get-Help $Name -Parameter $pattern -ErrorAction SilentlyContinue
}


function Resolve-Cmd {
<#
.SYNOPSIS
    Answer "what IS this thing?" -- alias, function, cmdlet, or an .exe on PATH.
.DESCRIPTION
    A surprising amount of terminal confusion is not knowing what you just
    typed. 'ls' is an alias for Get-ChildItem, not the Unix tool. 'python' on
    this machine may be a Microsoft Store stub rather than a real interpreter.
    This unwraps the name and shows every match, in the order PowerShell would
    resolve them.
.EXAMPLE
    what ls
.EXAMPLE
    what python
#>
    [CmdletBinding()]
    param(
        # Name to resolve.
        [Parameter(Mandatory)][string]$Name
    )

    $found = Get-Command $Name -All -ErrorAction SilentlyContinue
    if (-not $found) {
        Write-Host "'$Name' is not a command on this machine." -ForegroundColor Yellow
        Write-Host "Try a wildcard search:  Get-Command *$Name*" -ForegroundColor DarkGray
        return
    }

    foreach ($c in $found) {
        [pscustomobject]@{
            Name       = $c.Name
            Kind       = $c.CommandType
            ResolvesTo = if ($c.CommandType -eq 'Alias') { $c.Definition } else { $c.Source }
            Module     = $c.ModuleName
        }
    }
}


function Show-Members {
<#
.SYNOPSIS
    "What can I do with this object?" -- the other half of discovery.
.DESCRIPTION
    PowerShell pipes objects, not text. That is the whole design. When a command
    returns something you do not recognize, pipe it here to see its properties
    and methods. Get-Help tells you about COMMANDS; this tells you about RESULTS.
.EXAMPLE
    Get-Process | mem
.EXAMPLE
    Get-Item $PROFILE | mem
#>
    [CmdletBinding()]
    param(
        # Piped input. Collected first so you get one table, not one per item.
        [Parameter(ValueFromPipeline)]$InputObject
    )
    begin   { $all = [System.Collections.Generic.List[object]]::new() }
    process { if ($null -ne $InputObject) { $all.Add($InputObject) } }
    end     { $all | Get-Member }
}


function Get-HelpFast {
<#
.SYNOPSIS
    One command for "explain this", whether it is PowerShell or a native tool.
.DESCRIPTION
    If the name is a PowerShell command, prints a compact card: what it does,
    how to call it, and its examples -- in that order, which is the order you
    actually want them.

    If the name is an external program (git.exe, python.exe), Get-Help knows
    nothing about it, so this runs that program's own --help instead. Note:
    a program that ignores --help could sit waiting for input; Ctrl+C is safe.
.EXAMPLE
    hh Get-ChildItem
.EXAMPLE
    hh git
#>
    [CmdletBinding()]
    param(
        # Command or program name.
        [Parameter(Mandatory)][string]$Name
    )

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host "No command named '$Name'." -ForegroundColor Yellow
        Write-Host "Try a wildcard search:  Get-Command *$Name*" -ForegroundColor DarkGray
        return
    }

    # --- External programs: hand off to the tool's own help ---
    if ($cmd.CommandType -eq 'Application') {
        Write-Host "$($cmd.Name) is an external program, not a PowerShell command." -ForegroundColor DarkGray
        Write-Host "Showing its own help instead.`n" -ForegroundColor DarkGray
        foreach ($flag in '--help', '-h', 'help') {
            $out = & $cmd.Source $flag 2>&1
            if ($out) { $out; return }
        }
        Write-Host "Could not get help from $($cmd.Name). Try: $($cmd.Name) --help" -ForegroundColor Yellow
        return
    }

    # --- PowerShell commands: synopsis, then syntax, then examples ---
    $help = Get-Help $cmd.Name -ErrorAction SilentlyContinue

    Write-Host "`n$($cmd.Name)" -ForegroundColor Cyan
    if ($help.Synopsis) { Write-Host $help.Synopsis.Trim() -ForegroundColor White }

    Write-Host "`nSYNTAX" -ForegroundColor Cyan
    (Get-Command $cmd.Name -Syntax).Trim() | Write-Host -ForegroundColor Gray

    # Only the first few examples here. A dozen examples is a reference manual,
    # not an answer -- 'ex <name>' gets the rest when you want them.
    Write-Host "`nEXAMPLES" -ForegroundColor Cyan
    Get-HelpExample $cmd.Name -First 3

    Write-Host "`nGo deeper:" -ForegroundColor DarkGray
    Write-Host "  Get-Help $($cmd.Name) -Full        full text, all parameters" -ForegroundColor DarkGray
    Write-Host "  Get-Help $($cmd.Name) -ShowWindow  searchable pop-out window"  -ForegroundColor DarkGray
    Write-Host "  Get-Help $($cmd.Name) -Online      the Microsoft docs page"    -ForegroundColor DarkGray
}
