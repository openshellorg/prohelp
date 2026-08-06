# 2026-08-06 - Windows User32 link for clipboard

## Summary

Windows builds of apps that link `prohelp` failed with undefined symbols (`OpenClipboard`, `EmptyClipboard`, `CloseClipboard`, `SetClipboardData`) from `prohelp.clipboard`.

## Changes

* Declare `libs-windows` / `libs-windows-x86*` as `user32`.
* `pragma(lib, "user32")` in `clipboard.d` so the dependency travels with the object even when consumers forget `libs`.
