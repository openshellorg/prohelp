module help_main;

import std.stdio;
import prohelp.dispatch;

/**
 * Legacy binary name `help`. Prefer the shell function from
 * `prohelp wrapper install` (builtins beat PATH on bash/zsh).
 * This binary remains for Windows/cmd-adjacent use and explicit help.exe calls.
 */
void main(string[] argv) {
    string[] topics = argv.length > 1 ? argv[1 .. $] : [];
    if (topics.length && (topics[0] == "-h" || topics[0] == "--help")) {
        writeln("help — prohelp PATH dispatcher (prefer: prohelp wrapper install)");
        writeln("Usage: help <command>");
        writeln("Docs:  https://openshellorg.github.io/prohelp/shell-help.html");
        return;
    }
    import core.stdc.stdlib : exit;
    exit(cast(ubyte) runAsHelp(topics));
}
