# Changelog

All notable changes to the Prohelp progressive command-line help project are documented here.

This project maintains a structured release history with links to detailed release notes in the `changelog-details/` directory.

---

## Release History

* **2026-08-01** — Whole-document schemas: author prohelp as `help.md` / `help.adoc` / `help.cmk` with frontmatter; headings → sections. Warn on missing metadata and nudge feature requests (search links) when a command has no prohelp docs.
* **2026-08-01** — `content-ref` CentrMark (`.cmk`) support with terminal plain-text rendering; format inferred from `.cmk` / `.md` / `.adoc` / `.sdl` when omitted.
* **2026-08-01** — Shell `help` wrapper (`prohelp wrapper install`), registration warnings, standard command metadata (`title`/`homepage`/`docs`/`issues`/`issues-ai`), `content-ref` for AsciiDoc/Markdown bodies, and https://openshellorg.github.io/prohelp/shell-help.html.
* **2026-07-25** — CI on push/PR (library + `prohelp` + `help`); release assets include both binaries for Linux/Windows/macOS.
* **2026-07-25** — Moved to OpenShellOrg (`openshellorg/prohelp`). Added orientation record schema, global `help` dispatcher binary, and crosslinks to `about` / `info` / `man`. Origin: Dev-Centr.
* **2026-05-27** — Relicense under GPL-3.0-or-later (replacing unstated/MIT references).
* **2026-05-27** — [Initial Release of Prohelp v0.1.0](changelog-details/2026-05-27%20-%20v0.1.0-release.md)
  * Complete core Dlang progressive library and CLI parser.
  * Unicode box-drawing visual zoning in static Text Mode.
  * Interactive TUI browser (Default Mode) with Shift-selection and Ctrl+C clipboard.
  * Comma-separated hybrid config suffixes and wildcard globbing.
