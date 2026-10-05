# terminal-kit

[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A readable, user-scope PowerShell 7 + Windows Terminal + Python REPL setup. It is
designed to be copied, studied, adapted, and reused on another Windows machine—no
administrator rights required.

This is an opinionated reference configuration, not a framework. Each `.ps1` file is
written to be read as much as run: comments explain the engineering trade-offs and are
intended to be useful in a classroom or for someone learning PowerShell.

> **Privacy note:** The optional transcript feature records terminal output. Review the
> [Transcripts](#transcripts) section before enabling it, and never commit transcripts,
> credentials, or other private material.

Every `.ps1` file is written to be *read* as much as run: each block says why it exists,
and the comments are meant to be lifted into class material.

## What you get

| Area | What it does | Where |
|---|---|---|
| **Prediction** | Suggestions from your history *and* from PowerShell's own completion engine (CompletionPredictor), in a dropdown list | `profile.d/10-psreadline.ps1` |
| **Colors** | One palette drives syntax highlighting, output formatting, file colors by role, the prompt, the fzf picker, and the Windows Terminal scheme | `profile.d/20-colors.ps1`, `terminal/terminal-kit.json` |
| **Prompt** | Two-line prompt, git branch without running git, visible `[failed]` marker | `profile.d/30-prompt.ps1` |
| **Help** | `hh`, `ex`, `par`, `syn`, `what`, `mem` — narrow questions, narrow answers | `profile.d/40-help.ps1` |
| **Navigation** | `z` (folder jumper that learns), Ctrl+r / Ctrl+t / Alt+c fuzzy pickers, `ff` (find files), `fif` (find in files) | `profile.d/50-navigation.ps1` |
| **Completion** | Tab completion for `gh`, `rg`, `fd`, `bat`, `winget` | `profile.d/60-completers.ps1` |
| **Transcripts** | Every interactive window records itself automatically; `log`/`endlog` for curated, indexed ones | `profile.d/70-transcripts.ps1` |
| **Cheat sheet** | `kit` prints every key and command on one screen | `profile.d/90-aliases.ps1` |
| **Python REPL** | Pretty results, readable tracebacks, `mem(obj)` — via `PYTHONSTARTUP` | `python/startup.py` |

## Install

From PowerShell 7 (`pwsh`), in this folder:

```powershell
.\install.ps1                 # wire everything up; reports missing tools
.\install.ps1 -InstallTools   # also install missing tools (winget/PSGallery/pip, all user-scope)
.\install.ps1 -SkipFont       # leave fonts alone
```

It is safe to rerun: each step checks first and only changes what differs. It backs up
`$PROFILE` and Windows Terminal's `settings.json` before touching them.

Tools are opt-in because installing software on the school PC can raise an IT alert.
The tools are: `fzf`, `fd`, `bat`, `rg` (ripgrep), `zoxide` via winget; `PSFzf` and
`CompletionPredictor` from the PowerShell Gallery; `rich` via pip.

After installing, open a **new** Terminal window and type `kit`.

### What install.ps1 changes on the machine

- `$PROFILE` becomes a one-line stub that dot-sources `profile.ps1` from this repo.
  Edit the repo, never the stub. (Why not a link: symlinks need admin here, and hard
  links silently break when an editor saves by replacing the file.)
- Windows Terminal: a *fragment* with the "Terminal Kit" color scheme in
  `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\terminal-kit\`, and in
  `settings.json`: default profile → PowerShell 7, scheme + font for all profiles.
- Font: CaskaydiaCove Nerd Font (Cascadia Code + icons), installed for your account only.
- `PYTHONSTARTUP` user environment variable → `python\startup.py`.

### Undo

- `$PROFILE`: restore `Microsoft.PowerShell_profile.ps1.before-terminal-kit_<date>` next to it
  (a copy is also in `Documents\Programming\_backups\`).
- Windows Terminal: restore `settings.before-terminal-kit_<date>.json` in its LocalState
  folder, and delete the `Fragments\terminal-kit` folder.
- Python: `[Environment]::SetEnvironmentVariable('PYTHONSTARTUP', $null, 'User')`

## Startup speed — the constraint that shaped this design

This PC's security software scans every PowerShell script as it runs. Measured here:

| Measurement | Result |
|---|---|
| Scan cost | ~19 ms per KB — **comments cost the same as code** |
| Fixed cost per script *file* | ~150–250 ms |
| `uv`'s completion script (parse / run) | 0.1 s / **12 s** |
| 8 profile files loaded one by one | 2.2–2.4 s |
| Same 8 files joined into one block | 1.5–1.7 s |
| …and with `#` comment lines dropped in memory | **~1.0–1.2 s** (old single-file profile: 0.7–0.8 s) |

So:

1. `profile.ps1` **joins** `profile.d\*.ps1` into one block (one file-scan instead of eight)
   and **drops full-line `#` comments in memory** before running it. The files on disk keep
   every comment. `<# help #>` blocks are kept so `Get-Help` still works.
2. Anything expensive loads **lazily** — on first use, not at launch: PSFzf (first Ctrl+r /
   Ctrl+t / Alt+c / `fif`), zoxide (first `z`), each tool's completer (first Tab after it),
   CompletionPredictor (after the first prompt appears, via `PowerShell.OnIdle`).
3. `uv` completion is **off** — 12 s even lazily. Uncomment it in `60-completers.ps1` if you
   would rather wait once.

To see the per-file cost yourself: `$env:TERMKIT_TIMING = 1; . $PROFILE`

Rule this creates: **no multi-line string in `profile.d` may contain a line starting with
`#`** — the comment filter would cut it.

## Transcripts

- **Automatic**: every interactive window → `Terminal_Transcripts\auto\YYYY-MM\*.txt`.
  Not indexed. Deleted after 30 days (`$script:AutoTranscriptDays`). Not started for
  scripts, `-Command` runs, or AI agents launching PowerShell — only for a human at the
  keyboard (see the check at the top of `profile.ps1`).
- **Curated**: `log` / `endlog` (Start-AgentLog / Stop-AgentLog) → dated file + a line in
  `INDEX.md`. Kept. Nests on top of the automatic one; both record.
- **Privacy**: a transcript records everything printed, including tokens a command shows.
  Run `nolog` first. Or start a window with `$env:TERMKIT_NO_TRANSCRIPT = 1; pwsh`.

## The PowerShell terminal ecosystem

`terminal-kit` intentionally keeps its own dependency footprint small. The projects below
are public, open-source options worth considering alongside it; they are maintained by their
respective communities and are **not** bundled or automatically installed by this repository.
Check each project's documentation and license before adding it to your setup.

| Need | Projects to explore | Why they fit a PowerShell-focused terminal |
|---|---|---|
| PowerShell foundation | [PowerShell](https://github.com/PowerShell/PowerShell), [PSReadLine](https://github.com/PowerShell/PSReadLine) | The shell and its interactive editing, history, prediction, and completion experience. |
| Prompts and themes | [Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh), [Starship](https://github.com/starship/starship), [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) | Ready-made prompts and color schemes; Starship is useful when one prompt must work across several shells. |
| Fuzzy finding and navigation | [fzf](https://github.com/junegunn/fzf), [PSFzf](https://github.com/kelleyma49/PSFzf), [zoxide](https://github.com/ajeetdsouza/zoxide), [carapace-bin](https://github.com/carapace-sh/carapace-bin) | Fast interactive pickers, learned directory jumping, and broad command completion. |
| Files and search | [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd), [bat](https://github.com/sharkdp/bat), [eza](https://github.com/eza-community/eza), [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) | Better defaults for finding, reading, and listing files; icons require a Nerd Font. |
| Git at the prompt | [posh-git](https://github.com/dahlbyk/posh-git), [delta](https://github.com/dandavison/delta) | Git-aware prompt/completion support and more readable diffs. |
| PowerShell presentation | [PwshSpectreConsole](https://github.com/ShaunLawrie/PwshSpectreConsole), [PSScriptTools](https://github.com/jdhitsolutions/PSScriptTools) | More expressive terminal output and a broad set of scripting helpers. |
| Windows terminal host | [Windows Terminal](https://github.com/microsoft/terminal), [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) | The terminal host and font glyphs used by many modern prompts and file-listing tools. |

### Choosing additions deliberately

- Start with **PowerShell + PSReadLine**; this repository configures both.
- Add **one** prompt system—either the hand-written prompt here, Oh My Posh, or Starship—so
  startup cost and configuration ownership stay clear.
- Test an optional module's import time before adding it to your profile. This repository
  deliberately lazy-loads costly components to keep a new terminal responsive.
- Prefer user-scope installs on managed Windows devices. Review each project's installation
  instructions instead of copying commands from untrusted gists.

## Contributing

Issues and pull requests are welcome. Before proposing a change, please keep these goals in
mind:

- Preserve the user-scope, no-admin installation path.
- Keep startup work small; defer expensive integrations until they are actually used.
- Write comments for a reader learning PowerShell, not only for someone maintaining the code.
- Never commit transcripts, backups, credentials, or machine-specific configuration.

## License

Released under the [MIT License](LICENSE). The linked projects above have their own licenses
and policies; this license does not apply to them.

## Layout

```
terminal-kit/
  profile.ps1          entry point: decides "is a human here?", loads profile.d
  profile.d/           one concern per file; the number is the load order
  terminal/            Windows Terminal fragment (color scheme)
  python/startup.py    PYTHONSTARTUP file
  install.ps1          wires the repo into this PC; idempotent
```
