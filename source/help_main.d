module help_main;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;
import prohelp.config;
import prohelp.intercept;
import prohelp.orientation;
import prohelp.parser;

version (ProhelpHelpBinary) {
    private enum embeddedHelpSdl = import("help.sdl");
}

private struct ResolvedBinary {
    string path;
}

private string[] pathEntries() {
    version (Windows) {
        auto p = environment.get("PATH", "");
        return p.split(";").filter!(s => s.length > 0).array;
    } else {
        auto p = environment.get("PATH", "");
        return p.split(":").filter!(s => s.length > 0).array;
    }
}

private string[] candidateNames(string command) {
    string[] names = [command];
    version (Windows) {
        auto pathext = environment.get("PATHEXT", ".EXE;.CMD;.BAT;.COM");
        foreach (ext; pathext.split(";")) {
            if (ext.length) {
                names ~= command ~ ext;
                names ~= command ~ ext.toLower();
            }
        }
    }
    return names;
}

/// Resolve all PATH matches for a command name (absolute paths).
public ResolvedBinary[] resolveAll(string command) {
    ResolvedBinary[] found;
    auto names = candidateNames(command);
    foreach (dir; pathEntries()) {
        foreach (name; names) {
            auto full = buildPath(dir, name);
            if (exists(full) && isFile(full)) {
                version (Windows) {
                    import std.uni : toLower;
                    auto key = full.toLower();
                } else {
                    auto key = full;
                }
                bool dupe = false;
                foreach (f; found) {
                    version (Windows) {
                        import std.uni : toLower;
                        if (f.path.toLower() == key) {
                            dupe = true;
                            break;
                        }
                    } else {
                        if (f.path == key) {
                            dupe = true;
                            break;
                        }
                    }
                }
                if (!dupe) {
                    found ~= ResolvedBinary(full);
                }
            }
        }
    }
    return found;
}

private bool whichExists(string cmd) {
    try {
        auto r = execute(["which", cmd]);
        return r.status == 0 && r.output.strip().length > 0;
    } catch (Exception) {
        return false;
    }
}

private bool commandOnPath(string cmd) {
    version (Windows) {
        try {
            auto r = execute(["where", cmd]);
            return r.status == 0;
        } catch (Exception) {
            return resolveAll(cmd).length > 0;
        }
    } else {
        return whichExists(cmd) || resolveAll(cmd).length > 0;
    }
}

private void printCrosslinks(string command) {
    writeln();
    writeln("See also:");
    writefln("  about %s              # short orientation card", command);
    writefln("  info %s               # Info manual (if installed)", command);
    writefln("  man %s                # man page (if installed)", command);
    writeln();
}

private string findAdjacentHelpSdl(string binaryPath) {
    string dir = dirName(binaryPath);
    string[] candidates = [
        buildPath(dir, "help.sdl"),
        buildPath(dir, "..", "help.sdl"),
        buildPath(dir, "share", "prohelp", baseName(binaryPath) ~ ".sdl"),
    ];
    foreach (c; candidates) {
        if (exists(c) && isFile(c)) return c;
    }
    return "";
}

private int runExternal(string[] argv) {
    try {
        auto pid = spawnProcess(argv);
        return wait(pid);
    } catch (Exception e) {
        stderr.writeln("help: failed to run ", argv.join(" "), ": ", e.msg);
        return 1;
    }
}

private ResolvedBinary pickBinary(string command, string forcedPath, ResolvedBinary[] matches, bool allowPrompt) {
    if (forcedPath.length) {
        if (!exists(forcedPath)) {
            stderr.writeln("help: --path not found: ", forcedPath);
            return ResolvedBinary.init;
        }
        return ResolvedBinary(forcedPath);
    }
    if (matches.length == 0) {
        return ResolvedBinary.init;
    }
    if (matches.length == 1 || !allowPrompt) {
        return matches[0];
    }

    writeln("Multiple binaries named '", command, "':");
    foreach (i, m; matches) {
        writefln("  [%d] %s", i + 1, m.path);
    }
    write("Pick index (or set --path=): ");
    stdout.flush();
    string line = readln().strip();
    if (!line.length) return ResolvedBinary.init;
    try {
        size_t idx = to!size_t(line);
        if (idx < 1 || idx > matches.length) {
            stderr.writeln("help: invalid index");
            return ResolvedBinary.init;
        }
        return matches[idx - 1];
    } catch (Exception) {
        stderr.writeln("help: expected a number");
        return ResolvedBinary.init;
    }
}

private void printUsage() {
    writeln("Usage: help <command> [nav...]");
    writeln("       help --path=<binary> <command> [nav...]");
    writeln("       help --orient <command>");
    writeln();
    writeln("Global progressive help dispatcher (OpenShellOrg prohelp).");
    writeln("Disambiguates PATH collisions, then tries:");
    writeln("  1. Adjacent help.sdl / orientation pack");
    writeln("  2. info (OpenShellOrg TUI or classic) / man");
    writeln("  3. <command> --help");
    writeln();
}

void main(string[] argv) {
    string[] args = argv.length > 1 ? argv[1 .. $].dup : [];
    string forcedPath;
    bool orientOnly = false;

    while (args.length) {
        if (args[0] == "-h" || args[0] == "--help" || args[0] == "?") {
            printUsage();
            return;
        }
        if (args[0] == "--orient" || args[0] == "-o") {
            orientOnly = true;
            args = args[1 .. $];
            continue;
        }
        if (args[0].startsWith("--path=")) {
            forcedPath = args[0]["--path=".length .. $];
            args = args[1 .. $];
            continue;
        }
        if (args[0] == "--path") {
            if (args.length < 2) {
                stderr.writeln("help: --path needs a value");
                return;
            }
            forcedPath = args[1];
            args = args[2 .. $];
            continue;
        }
        break;
    }

    if (args.length == 0) {
        printUsage();
        return;
    }

    string command = args[0];
    string[] nav = args.length > 1 ? args[1 .. $] : [];

    auto matches = resolveAll(command);
    auto chosen = pickBinary(command, forcedPath, matches, !orientOnly);
    if (chosen.path.length == 0 && matches.length == 0 && forcedPath.length == 0) {
        stderr.writefln("help: command not found on PATH: %s", command);
        // still try info/man by name
    }

    Orientation orient = tryLoadOrientationNear(chosen.path, command);
    if (orient is null && chosen.path.length) {
        string sdl = findAdjacentHelpSdl(chosen.path);
        if (sdl.length) {
            try {
                auto cmd = parseHelpSDL(sdl);
                orient = fromCommand(cmd);
            } catch (Exception e) {
                stderr.writeln("help: help.sdl parse warning: ", e.msg);
            }
        }
    }
    if (orient !is null && chosen.path.length) {
        bool has = false;
        foreach (p; orient.binaryPaths) {
            if (p == chosen.path) has = true;
        }
        if (!has) orient.binaryPaths ~= chosen.path;
        foreach (m; matches) {
            bool already = false;
            foreach (p; orient.binaryPaths) {
                if (p == m.path) already = true;
            }
            if (!already) orient.binaryPaths ~= m.path;
        }
    }

    if (orientOnly) {
        if (orient is null) {
            orient = new Orientation();
            orient.name = command;
            orient.summary = "(no orientation pack or help.sdl found)";
            if (chosen.path.length) orient.binaryPaths ~= chosen.path;
            foreach (m; matches) {
                if (m.path != chosen.path) orient.binaryPaths ~= m.path;
            }
        }
        write(renderOrientationCard(orient));
        return;
    }

    // 1) Adjacent help.sdl via prohelp intercept
    if (chosen.path.length) {
        string sdl = findAdjacentHelpSdl(chosen.path);
        if (sdl.length) {
            if (orient !is null) {
                write(renderOrientationCard(orient, false));
            }
            string[] helpArgs = [command, "?"];
            if (nav.length) helpArgs ~= nav;
            else helpArgs = [command, "?"];
            // If user passed help-style nav starting with ?, use as-is
            if (nav.length && (nav[0] == "?" || nav[0].startsWith("?") || nav[0] == "help"
                    || nav[0].startsWith("help") || nav[0] == "-h" || nav[0] == "--help")) {
                helpArgs = [command] ~ nav;
            } else if (nav.length) {
                helpArgs = [command, "?"] ~ nav;
            }
            intercept(helpArgs, InterceptConfig.fromFile(sdl));
            printCrosslinks(command);
            return;
        }
    }

    // Orientation-only prelude if we have one
    if (orient !is null) {
        write(renderOrientationCard(orient));
    }

    // 2) info TUI / classic info / man
    if (commandOnPath("info")) {
        // Prefer openshellorg info if it shadows — just run `info`
        int st = runExternal(["info", command]);
        if (st == 0) {
            printCrosslinks(command);
            return;
        }
    }
    if (commandOnPath("man")) {
        int st = runExternal(["man", command]);
        if (st == 0) {
            printCrosslinks(command);
            return;
        }
    }

    // 3) Fallback: command --help
    if (chosen.path.length) {
        writeln("(falling back to ", chosen.path, " --help)");
        runExternal([chosen.path, "--help"]);
        printCrosslinks(command);
        return;
    }

    stderr.writefln("help: nothing found for '%s'", command);
    printCrosslinks(command);
}
