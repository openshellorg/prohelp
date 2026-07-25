# 2026-07-25 — OpenShellOrg move + orientation + global help

## Summary

Prohelp is now hosted at [openshellorg/prohelp](https://github.com/openshellorg/prohelp) (transferred from `dev-centr/prohelp`). GitHub redirects keep old URLs working.

## Changes

* **Ownership:** OpenShellOrg; Dev-Centr remains the historical origin and continues to cross-link the spec.
* **Orientation schema:** `prohelp.orientation` loads/renders short `orientation "name" { ... }` SDL cards (summary, description, history, see-also, binaries) for `about` / `help --orient`.
* **Global `help` binary:** DUB config `help` builds a PATH-aware dispatcher that disambiguates duplicate command names, prefers adjacent `help.sdl`, then `info`/`man`, then `--help`, and always prints see-also crosslinks.
* **Example:** `examples/orientation-tar.sdl`.
