# CLAUDE.md — terminal-kit

James's PowerShell 7 profile, Windows Terminal scheme, and Python REPL startup file.
`README.md` has the what and why; this file is the rules for changing it.

## Rules

- **The repo is the source of truth.** `$PROFILE` is a one-line stub that dot-sources
  `profile.ps1`. Never edit the stub; never copy profile code into it.
- **Measure startup before and after any change to `profile.d`.** This PC's security
  software scans scripts at ~19 ms/KB plus ~150–250 ms per file. Anything that costs
  more than a few tens of ms at launch must load lazily (see how PSFzf, zoxide, and the
  completers do it). Measure with `$env:TERMKIT_TIMING = 1; . $PROFILE`, or cold, in an
  isolated process (next rule).
- **Test in an isolated process with a timeout.** Launching `pwsh` inline from the
  Claude Code PowerShell tool can hang the tool. Use
  `Start-Process pwsh -ArgumentList '-NoProfile','-NonInteractive','-File',<test.ps1> -PassThru`
  then `.WaitForExit(60000)`, and have the test write its results to a file.
  The tool's own shell also has a stale PATH after installs — refresh it from the registry.
- **No multi-line string in `profile.d` may contain a line starting with `#`.** The loader
  drops full-line comments in memory before running, and would cut it.
- **Keep the comments.** They are stripped at load time, so they cost nothing at startup,
  and they are lesson material. House style: header block, comments that say why.
- **`$?` must be the first thing the prompt reads**, and `$LASTEXITCODE` is restored in the
  prompt's `finally`. Anything added to the prompt goes after the capture.
- **`install.ps1` stays idempotent**: check, then change only what differs, back up first.
  Installing tools stays opt-in (`-InstallTools`) — installs can trigger school IT alerts.
- No admin, ever. User-scope installs only.
- Transcripts live outside the repo (`Documents\Programming\Terminal_Transcripts\`) and
  must never be committed.
