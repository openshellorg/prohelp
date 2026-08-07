# Windows UTF-8 console + ASCII box fallback (2026-08-06)

## Problem

Static help frames use Unicode box-drawing (`┌─│`) and notices use punctuation like `—`. On Windows, PowerShell/conhost often start on OEM code page **437**. UTF-8 bytes were written as-is, so glyphs mojibaked (`┌` → `Γöî`, `—` → `ΓÇö`). This was **not** a UTF-16 help.sdl bug and **not** the nushell wrapper path — default static mode always rendered those boxes for every shell.

## Fix

* `prohelp.console.prepareConsoleOutput()` sets `SetConsoleOutputCP/CP(65001)` and enables VT processing on Windows before help output.
* If the console stays on a non-UTF-8 code page, render ASCII `+|-` boxes instead.
* Pipes/redirects keep UTF-8 Unicode (agent/log friendly).
* Overrides: `PROHELP_ASCII=1`, `PROHELP_UNICODE=1`.

## Also

* `stringImportPaths: ["."]` trips dub 1.41 (`Invalid variable: null`). Executables now use named dirs (`embed/`, `docs/`).
* ASCII fallback transliterates Unicode frames after render (`PROHELP_ASCII=1` or failed UTF-8 console CP).

## Upstream reports

* dub filename `$null` / `stringImportPaths "."`: https://github.com/dlang/dub/issues/3142
* DMD intermittent Windows AV: https://github.com/dlang/dmd/issues/23545
