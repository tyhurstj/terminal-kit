"""
================================================================================
 terminal-kit/python/startup.py  --  Python's version of $PROFILE
================================================================================
 Audience: James. Same idea as the PowerShell profile, for the Python REPL
 (the >>> prompt you get from typing plain `python`).

 What this file demonstrates:
   1. PYTHONSTARTUP: an environment variable naming a file Python runs every
      time the interactive prompt starts -- exactly what $PROFILE is to pwsh
   2. Pretty-printing results, so a dict or list is readable instead of one line
   3. Readable error messages (tracebacks) with the failing code highlighted
   4. A `mem()` helper that mirrors `mem` in PowerShell: "what can I do with this?"
   5. Failing SOFTLY: if `rich` is missing, the REPL still starts normally

 What it does NOT touch: your scripts. PYTHONSTARTUP only runs for the
 interactive prompt, never for `python myscript.py`, so nothing here can change
 how a student's program behaves when it runs.

 How to run: it runs itself. install.ps1 sets the user environment variable
   PYTHONSTARTUP = <this file>
 Then open a NEW terminal (environment variables are read when a program
 starts) and type:  python
 Needs:  python -m pip install --user rich
================================================================================
"""

try:
    # `rich` is a library for good-looking terminal output. Three parts of it:
    from rich import pretty, traceback, inspect as _rich_inspect

    # 1. pretty.install() replaces how the REPL shows a RESULT. Type a dict at
    #    the >>> prompt and it comes back indented and colored, not crammed on
    #    one line. Only affects what the REPL echoes, not print().
    pretty.install()

    # 2. traceback.install() replaces how errors look: a box around the failing
    #    line, the code around it, syntax-highlighted. The information is the
    #    same as a normal traceback -- it is just laid out so you READ it.
    #    show_locals=False keeps it short; set True to also see every variable's
    #    value at the moment it crashed (great for debugging, noisy otherwise).
    traceback.install(show_locals=False)

    # 3. mem(x): same name, same job as `mem` in the PowerShell profile. PowerShell
    #    pipes OBJECTS and so does Python -- when something comes back and you
    #    don't know what it is, ask what it can do.
    def mem(obj, methods=True):
        """Show what an object IS and what you can do with it (like `mem` in pwsh)."""
        _rich_inspect(obj, methods=methods)

    print("startup.py: rich loaded -- pretty results, readable errors, mem(obj)")

except ImportError:
    # No rich installed? Say how to fix it once, and carry on with the plain REPL.
    # A startup file that crashes would break `python` for every session.
    print("startup.py: `rich` not installed -- run: python -m pip install --user rich")
