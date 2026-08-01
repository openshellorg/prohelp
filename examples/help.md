---
name: demo-md
title: Markdown prohelp demo
summary: Entire progressive-help schema authored as Markdown with YAML frontmatter
description: Prefer this when your docs already live in Markdown. Headings become sections.
homepage: https://github.com/openshellorg/prohelp
docs: https://openshellorg.github.io/prohelp/shell-help.html
issues: https://github.com/openshellorg/prohelp/issues
---

# Markdown prohelp demo

This file is a complete `help.md` schema. Place it next to your binary (or pass
`prohelp path/to/help.md ?`).

## Usage

Run progressive help with the usual triggers:

- `yourcmd ?`
- `yourcmd ? usage`
- `prohelp help.md ?`

## Metadata

Frontmatter fields map to the standard prohelp metadata shown at the top of
help pages: `title`, `homepage`, `docs`, `issues`, and optional `issues-ai`.

### Missing fields

Prohelp only warns about empty *essential* discovery fields (`homepage`,
`docs`, `issues`). If those are set in frontmatter (or in `help.sdl`), there
is no notice — content fields like `summary` are optional for warnings.
