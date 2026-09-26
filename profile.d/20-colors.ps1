# ==============================================================================
# 20-colors.ps1 -- stop the terminal being white text on a black rectangle
# ==============================================================================
# PowerShell 7 has a full color system built in ($PSStyle, added in 7.2) that
# ships almost entirely switched off. The useful mental model is that there are
# FOUR separate layers, configured in four different places. Keeping them
# straight is most of the battle:
#
#   Layer 0  the window itself -> Windows Terminal color scheme   (terminal\terminal-kit.json)
#   Layer 1  what you TYPE     -> Set-PSReadLineOption -Colors   (syntax highlighting)
#   Layer 2  what comes BACK   -> $PSStyle                        (output formatting)
#   Layer 3  the prompt itself -> your own prompt function        (30-prompt.ps1)
#
# Layer 0 is the one that is easy to forget: it sets the background and the
# sixteen "named" colors (Red, DarkGray...) that Write-Host -ForegroundColor
# uses. Layers 1-3 use exact RGB values and ignore it. The Terminal Kit scheme
# is built from the SAME palette below, so all four layers agree.

# --- Make sure the console can draw the characters we are about to use -------
# Box-drawing characters and arrows are UTF-8. Windows consoles have
# historically defaulted to an older codepage that renders them as garbage.
if (-not [Console]::IsOutputRedirected) {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
}

# $PSStyle exists in PowerShell 7.2+. It does NOT exist in Windows PowerShell
# 5.1, so guard rather than assume -- this file should degrade, not explode.
if ($null -ne $PSStyle) {

    # --- The palette ---------------------------------------------------------
    # Defined ONCE, in one place. This is the whole reason the scheme stays
    # coherent: every color below is chosen here, so retuning the look means
    # editing this block, not hunting through the file. Same idea as naming a
    # constant instead of scattering magic numbers through a program.
    #
    # These are 24-bit RGB values. FromRgb() converts a number into the escape
    # sequence a terminal understands. Tuned for a dark background.
    # If you change one, change the matching hex in terminal\terminal-kit.json
    # and FZF_DEFAULT_OPTS in 50-navigation.ps1 so the layers stay in step.
    $script:Palette = [ordered]@{
        Command   = $PSStyle.Foreground.FromRgb(0x62D6E8)  # cyan    - cmdlet names
        Parameter = $PSStyle.Foreground.FromRgb(0xE8C46A)  # amber   - -Switches
        Text      = $PSStyle.Foreground.FromRgb(0x8FD97A)  # green   - 'quoted strings'
        Number    = $PSStyle.Foreground.FromRgb(0xE89A6A)  # orange  - numeric literals
        Variable  = $PSStyle.Foreground.FromRgb(0xC79BF0)  # violet  - $things
        Operator  = $PSStyle.Foreground.FromRgb(0xB8C0CC)  # light   - | = + -
        Comment   = $PSStyle.Foreground.FromRgb(0x6B7684)  # dim     - # notes
        Bad       = $PSStyle.Foreground.FromRgb(0xF2726F)  # red     - errors
        Muted     = $PSStyle.Foreground.FromRgb(0x7A8794)  # gray    - chrome
        Plain     = $PSStyle.Foreground.FromRgb(0xD8DEE9)  # near-white - normal text
        Folder    = $PSStyle.Foreground.FromRgb(0x6EA8FE)  # blue    - directories
        Runnable  = $PSStyle.Foreground.FromRgb(0x8FD97A)  # green   - things that execute
        Data      = $PSStyle.Foreground.FromRgb(0xE8C46A)  # amber   - things that hold data
        Doc       = $PSStyle.Foreground.FromRgb(0xB8C0CC)  # light   - things you read
        Archive   = $PSStyle.Foreground.FromRgb(0xC79BF0)  # violet  - things that are bundled
    }
    $script:Reset = $PSStyle.Reset

    # --- LAYER 1: syntax highlighting as you type ----------------------------
    # This is the one people notice immediately. As you type, PSReadLine parses
    # the line and colors each piece by what it IS. That makes typos visible
    # BEFORE you press Enter: if a cmdlet name does not turn cyan, it does not
    # exist, and you have caught the error a second early instead of a second late.
    try {
        Set-PSReadLineOption -Colors @{
            Command                = $script:Palette.Command
            Parameter              = $script:Palette.Parameter
            String                 = $script:Palette.Text
            Number                 = $script:Palette.Number
            Variable               = $script:Palette.Variable
            Operator               = $script:Palette.Operator
            Comment                = $script:Palette.Comment
            Error                  = $script:Palette.Bad
            Type                   = $script:Palette.Command
            Member                 = $script:Palette.Plain
            Default                = $script:Palette.Plain
            # The prediction text is deliberately DIM. It is a suggestion, not
            # something you typed, and it should never compete with your input.
            InlinePrediction       = $script:Palette.Comment
            ListPrediction         = $script:Palette.Muted
            ListPredictionSelected = $PSStyle.Background.FromRgb(0x2A3A4A)
        }
    } catch { }

    # --- LAYER 2a: how results are formatted ---------------------------------
    # Table headers, errors, warnings. Small change, large effect: once headers
    # are a different color from data, a table stops being a gray slab.
    try {
        $PSStyle.Formatting.TableHeader  = $PSStyle.Bold + $script:Palette.Command
        $PSStyle.Formatting.FormatAccent = $script:Palette.Muted
        $PSStyle.Formatting.Error        = $script:Palette.Bad
        $PSStyle.Formatting.ErrorAccent  = $script:Palette.Parameter
        $PSStyle.Formatting.Warning      = $script:Palette.Parameter
        $PSStyle.Formatting.Verbose      = $script:Palette.Command
        $PSStyle.Formatting.Debug        = $script:Palette.Variable
    } catch { }

    # --- LAYER 2b: color files by what they ARE ------------------------------
    # This is the single biggest visual upgrade to everyday use, because you run
    # a directory listing constantly. The grouping is by ROLE, not by extension:
    # things that execute are green, things that hold data are amber, things you
    # read are light, things that are bundled up are violet. A .ps1 and a .py
    # look alike because they behave alike.
    try {
        $PSStyle.FileInfo.Directory  = $PSStyle.Bold + $script:Palette.Folder
        $PSStyle.FileInfo.Executable = $script:Palette.Runnable

        $fileRoles = @{
            Runnable = '.ps1', '.psm1', '.psd1', '.py', '.ino', '.cpp', '.c', '.h',
                       '.exe', '.bat', '.cmd', '.sh', '.js'
            Data     = '.json', '.csv', '.tsv', '.xml', '.yml', '.yaml', '.toml', '.ini', '.db'
            Doc      = '.md', '.txt', '.pdf', '.docx', '.pptx', '.xlsx', '.rtf', '.log'
            Archive  = '.zip', '.7z', '.tar', '.gz', '.hex', '.uf2', '.bin'
        }
        foreach ($role in $fileRoles.Keys) {
            foreach ($ext in $fileRoles[$role]) {
                $PSStyle.FileInfo.Extension[$ext] = $script:Palette[$role]
            }
        }
    } catch { }
}


function Show-Palette {
<#
.SYNOPSIS
    Print the current color scheme, with a live sample of all three layers.
.DESCRIPTION
    Two uses. First, tuning: change an RGB value in the palette block of
    profile.d\20-colors.ps1, run '. $PROFILE', then run this to see the result
    immediately. Second, explaining: it shows that the colors are a SYSTEM with
    meanings, not decoration.
.EXAMPLE
    palette
#>
    [CmdletBinding()]
    param()

    if ($null -eq $PSStyle) { Write-Warning 'Needs PowerShell 7.2 or newer.'; return }
    $r = $script:Reset

    Write-Host ""
    Write-Host "$($script:Palette.Command)$($PSStyle.Bold)PALETTE$r  $($script:Palette.Muted)(edit the RGB values in profile.d\20-colors.ps1, then run . `$PROFILE)$r"
    Write-Host "$($script:Palette.Muted)$('─' * 60)$r"
    foreach ($name in $script:Palette.Keys) {
        $swatch = "$($script:Palette[$name])████████$r"
        Write-Host ("  {0} {1,-10}{2}sample text{3}" -f $swatch, $name, $script:Palette[$name], $r)
    }

    Write-Host ""
    Write-Host "$($script:Palette.Command)$($PSStyle.Bold)LAYER 2: file roles$r"
    Write-Host "$($script:Palette.Muted)$('─' * 60)$r"
    Write-Host "  $($PSStyle.Bold)$($script:Palette.Folder)folder/$r          directories"
    Write-Host "  $($script:Palette.Runnable)script.ps1$r         things that execute"
    Write-Host "  $($script:Palette.Data)data.json$r          things that hold data"
    Write-Host "  $($script:Palette.Doc)notes.md$r           things you read"
    Write-Host "  $($script:Palette.Archive)build.hex$r          things that are bundled"
    Write-Host ""
}
