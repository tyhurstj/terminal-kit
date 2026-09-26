# terminal-kit

James's PowerShell 7 + Windows Terminal + Python REPL setup, as a repo — so it can be
read, versioned, reused on another machine, and pulled into lessons. Everything is
**user-scope**: nothing here needs admin.

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

## Where to look next — the wider landscape

Scouted 2026-09-25 (GitHub stars / last activity at that date). None of these are installed.

**Prompts and looks**
- [Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh) (23k★, active) and
  [Starship](https://github.com/starship/starship) (60k★, active) — themed prompts, compiled
  so they're fast. Starship's one config works in bash/zsh too. Worth comparing against the
  hand-written prompt, which is the one to keep for teaching.
- [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) — 450+ schemes
  with ready Windows Terminal JSON; preview at windowsterminalthemes.dev.
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) — file icons in `ls`
  (needs the Nerd Font, now installed). No commits since 2024.
- [eza](https://github.com/eza-community/eza) — modern `ls` with icons, tree view, git status.

**Completion**
- [carapace-bin](https://github.com/carapace-sh/carapace-bin) — completions for ~1,000 CLIs in
  one binary. Would replace `60-completers.ps1`; check its load cost here first.
- [inshellisense](https://github.com/microsoft/inshellisense) (Microsoft) — IDE-style popup
  completion for 600+ commands. Needs Node.js.
- [posh-git](https://github.com/dahlbyk/posh-git) — git subcommand/branch Tab completion.
  No commits since 2024; import cost unmeasured.

**Everyday tools**
- [delta](https://github.com/dandavison/delta) — side-by-side, highlighted `git diff`.
- [PwshSpectreConsole](https://github.com/ShaunLawrie/PwshSpectreConsole) — tables, progress
  bars, charts from PowerShell scripts; good for demos.
- [PSScriptTools](https://github.com/jdhitsolutions/PSScriptTools) — large admin toolbox.

**Python**
- Python **3.13/3.14** rebuilt the REPL (multi-line editing, color; 3.14 adds syntax
  highlighting). This PC has 3.12. `uv python install 3.14` adds it without admin.
- [IPython](https://github.com/ipython/ipython) — `%timeit`, `obj?` help, autoreload.
- [ptpython](https://github.com/prompt-toolkit/ptpython) — completion popups as you type.
- [icecream](https://github.com/gruns/icecream) — `ic(x)` prints the expression *and* value;
  great first debugging tool for students.
- `uv tool install <name>` — isolated command-line tools (replaces pipx).

**Avoid**: ConsoleGuiTools (`Out-ConsoleGridView`) — archived June 2026.
awesome-powershell — archived (still fine to browse). bpython — weak on Windows.

## Layout

```
terminal-kit/
  profile.ps1          entry point: decides "is a human here?", loads profile.d
  profile.d/           one concern per file; the number is the load order
  terminal/            Windows Terminal fragment (color scheme)
  python/startup.py    PYTHONSTARTUP file
  install.ps1          wires the repo into this PC; idempotent
```
