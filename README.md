<a id="readme-top"></a>
<div align="center">
<a href="https://github.com/openshellorg/prohelp/graphs/contributors"><img src="https://img.shields.io/github/contributors/openshellorg/prohelp.svg?style=for-the-badge" alt="Contributors"></a>
<a href="https://github.com/openshellorg/prohelp/network/members"><img src="https://img.shields.io/github/forks/openshellorg/prohelp.svg?style=for-the-badge" alt="Forks"></a>
<a href="https://github.com/openshellorg/prohelp/stargazers"><img src="https://img.shields.io/github/stars/openshellorg/prohelp.svg?style=for-the-badge" alt="Stars"></a>
<a href="https://github.com/openshellorg/prohelp/issues"><img src="https://img.shields.io/github/issues/openshellorg/prohelp.svg?style=for-the-badge" alt="Issues"></a>
<a href="https://github.com/openshellorg/prohelp/blob/main/LICENSE"><img src="https://img.shields.io/github/license/openshellorg/prohelp.svg?style=for-the-badge" alt="License"></a>
<br />
<h3 align="center">Prohelp: Progressive CLI Help</h3>
<p align="center">
Progressive & Professional Help CLI Interceptor and Library.<br />
<a href="https://openshellorg.github.io/prohelp/">Explore the docs</a><br />
<br />
<a href="https://github.com/openshellorg/prohelp/issues">Report Bug</a>
&middot;
<a href="https://github.com/openshellorg/prohelp/issues">Request Feature</a>
</p>
</div>


## About The Project

The standard command-line help interface (`--help` or `help`) is broken. It dumps massive walls of unreadable text — and shell `help` refuses to cover PATH binaries.

**Prohelp** is a progressive help specification and reference library: a *professional-grade*, budget-enforced terminal documentation system with Unicode box panels, locale-aware rendering, and an optional full-screen TUI. It also installs a shell **`help` function** (bash/zsh/fish/nu/pwsh — not cmd) that keeps builtin help for builtins and routes PATH topics through prohelp/man/info.

Docs for the wrapper: https://openshellorg.github.io/prohelp/shell-help.html

Prohelp is **not** a full command-line application framework. It solves progressive *help* only. For building CLI tools, use a framework and wire Prohelp in.

<p align="right">(<a href="#readme-top">back to top</a>)</p>
## Installation

### Prerequisites

* [D Compiler (DMD or LDC)](https://dlang.org/)
* [DUB (D Package Manager)](https://dub.pm/)

### Build

```powershell
dub build -c executable
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>
## Usage

### CLI usage

```powershell
prohelp
prohelp ?
prohelp ?:i
```

### Preview mode (schema interpreter)

```powershell
prohelp examples/tar.sdl ?
prohelp examples/tar.sdl ? operations
prohelp -f myapp/help.sdl ?:de,i
```

### Author a schema

```powershell
prohelp init --name myapp          # writes help.sdl immediately
prohelp fill                       # questionnaire (or init --fill)
prohelp check                      # report empty / weak fields
prohelp check --strict             # fail for CI
prohelp help.sdl ?
```

Downstream repos opt into the ship gate:

```yaml
jobs:
  prohelp:
    uses: openshellorg/prohelp/.github/workflows/check-schema.yml@main
    with:
      schema-path: help.sdl
      strict: true
```

### Shell `help` wrapper (recommended)

```shell
prohelp wrapper install          # bash/zsh/fish/nu/pwsh — not cmd
prohelp wrapper status
# reload shell, then:
help tar
```

### Drop-in intercept (library)

```d
import prohelp.intercept;

void main(string[] args) {
    if (prohelp.intercept(args)) return;
    // Your CLI framework or hand-rolled parser continues here...
}
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>
## Key Features

* **Default Static Box Zoning**: Generates gorgeous, Unicode-boxed information panels compatible with pipes, redirects, and log files.
* **Opt-in TUI Viewport**: Full-screen terminal browser with filter search and keyboard navigation.
* **1-Line Integration API**: Drop into standard application `main` entries with a single line of code.
* **Hierarchical Globbing (`*`)**: Subtree glob extraction for targeted documentation chunks.
* **Multilingual Localization**: Native OS locale auto-detection with explicit overrides.
* **Sliding-scale Line Budgets**: Enforces strict screen boundaries during development.
* **Authoring loop**: `prohelp init` writes a shaped `help.sdl`; `prohelp fill` is the questionnaire; `prohelp check --strict` is the CI ship gate (reusable workflow included).

See [Changelog](CHANGELOG.md).

## License

Prohelp is licensed under the [Prohelp Copyleft and Disclosure License (PCDL) Version 1.0](LICENSE).

<p align="right">(<a href="#readme-top">back to top</a>)</p>
## Contact

Open Shell Org — openshell@devcentr.org

* Project: https://github.com/openshellorg/prohelp
* Site: https://openshellorg.github.io

<p align="right">(<a href="#readme-top">back to top</a>)</p>
