# 2026-08-06 - Nushell Windows config and detection

## Summary

`prohelp wrapper install --shell=nu` wrote Unix-style `~/.config/nushell/config.nu` on Windows and often mis-detected the shell when `$SHELL` still pointed at bash/zsh.

## Changes

* Config dir: `%APPDATA%\nushell` on Windows; honor `XDG_CONFIG_HOME` everywhere.
* Detection: prefer `NU_VERSION` / `NU_LIB_DIRS` / `NU_PLUGIN_DIRS` before `$SHELL`.
* Source block: only `source` when the snippet path exists.
* PowerShell: prefer Documents profiles on Windows.
