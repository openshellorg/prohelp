module prohelp.console;

import std.process;
import std.string;

version (Windows) {
    import core.sys.windows.windows;
}

/**
 * Windows consoles often start on an OEM code page (e.g. 437). Prohelp writes
 * UTF-8 (Unicode box drawing). Without switching the console to UTF-8, those
 * bytes mojibake. Call prepareConsoleOutput() before printing help.
 *
 * Env overrides:
 *   PROHELP_ASCII=1     force ASCII boxes / punctuation
 *   PROHELP_UNICODE=1   force Unicode (still attempts UTF-8 console setup)
 */

private bool gPrepared = false;
private bool gUtf8Console = true;

/// Box-drawing glyphs for static/TUI frames.
struct BoxChars {
    string tl, tr, bl, br, h, v, lj, rj;
}

private bool envTruthy(string name) {
    auto v = environment.get(name, "");
    if (v.length == 0)
        return false;
    if (v == "1")
        return true;
    return v == "true" || v == "TRUE" || v == "yes" || v == "YES";
}

void prepareConsoleOutput() {
    if (gPrepared)
        return;
    gPrepared = true;

    version (Windows) {
        bool attached = consoleAttached();
        bool utf8 = tryEnableUtf8Console();
        gUtf8Console = !attached || utf8;
    } else {
        gUtf8Console = true;
    }
}

bool useUnicodeBoxes() {
    if (!gPrepared)
        prepareConsoleOutput();
    if (envTruthy("PROHELP_ASCII"))
        return false;
    if (envTruthy("PROHELP_UNICODE"))
        return true;
    return gUtf8Console;
}

BoxChars boxChars() {
    // Always build frames with Unicode; maybeAsciiBoxes() transliterates if needed.
    BoxChars bx;
    bx.tl = "\xE2\x94\x8C"; // ┌
    bx.tr = "\xE2\x94\x90"; // ┐
    bx.bl = "\xE2\x94\x94"; // └
    bx.br = "\xE2\x94\x98"; // ┘
    bx.h  = "\xE2\x94\x80"; // ─
    bx.v  = "\xE2\x94\x82"; // │
    bx.lj = "\xE2\x94\x9C"; // ├
    bx.rj = "\xE2\x94\xA4"; // ┤
    return bx;
}

string maybeAsciiBoxes(string text) {
    if (useUnicodeBoxes())
        return text;
    // Byte-level UTF-8 box drawing → ASCII (avoid source-level Unicode glyphs here).
    enum utl = "\xE2\x94\x8C";
    enum utr = "\xE2\x94\x90";
    enum ubl = "\xE2\x94\x94";
    enum ubr = "\xE2\x94\x98";
    enum uh  = "\xE2\x94\x80";
    enum uv  = "\xE2\x94\x82";
    enum ulj = "\xE2\x94\x9C";
    enum urj = "\xE2\x94\xA4";
    return text
        .replace(utl, "+").replace(utr, "+")
        .replace(ubl, "+").replace(ubr, "+")
        .replace(ulj, "+").replace(urj, "+")
        .replace(uv, "|").replace(uh, "-");
}

string dashEm() {
    return useUnicodeBoxes() ? "\xE2\x80\x94" : "--"; // —
}

string arrowRight() {
    return useUnicodeBoxes() ? "\xE2\x86\x92" : "->"; // →
}

version (Windows) {
    private bool consoleAttached() {
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        if (hOut is null || hOut == INVALID_HANDLE_VALUE)
            return false;
        DWORD mode;
        return GetConsoleMode(hOut, &mode) != 0;
    }

    private bool tryEnableUtf8Console() {
        enum UINT CP_UTF8_LOCAL = 65001;
        SetConsoleOutputCP(CP_UTF8_LOCAL);
        SetConsoleCP(CP_UTF8_LOCAL);

        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        if (hOut !is null && hOut != INVALID_HANDLE_VALUE) {
            DWORD mode;
            if (GetConsoleMode(hOut, &mode)) {
                SetConsoleMode(hOut, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
            }
        }
        return GetConsoleOutputCP() == CP_UTF8_LOCAL;
    }
}
