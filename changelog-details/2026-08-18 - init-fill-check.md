# Init, fill, and check (2026-08-18)

* `prohelp init` writes a blank-but-shaped `help.sdl` before any questions (`--fill` continues into the questionnaire).
* `prohelp fill` edits that file in a TTY, or via repeated `--set field=value`.
* `prohelp check` reports empty summaries, missing discovery URLs, empty sections, and line-budget slips. `--strict` fails the process so CI can block a ship.
* Downstream repos opt in with `uses: openshellorg/prohelp/.github/workflows/check-schema.yml`.
* SDL `example` tags are parsed and shown in Text Mode (they were previously ignored).
