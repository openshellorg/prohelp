module prohelp.dispatch;

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
import prohelp.registration;

private string[] pathEntries() {
    version (Windows) {
        return environment.get("PATH", "").split(";").filter!(s => s.length > 0).array;
    } else {
        return environment.get("PATH", "").split(":").filter!(s => s.length > 0).array;
    }
}

private string[] candidateNames(string command) {
    string[] names = [command];
    version (Windows) {
        foreach (ext; environment.get("PATHEXT", ".EXE;.CMD;.BAT").split(";")) {
            if (ext.length) names ~= command ~ ext;
        }
    }
    return names;
}

private string[] resolveAll(string command) {
    string[] found;
    foreach (dir; pathEntries()) {
        foreach (name; candidateNames(command)) {
            auto full = buildPath(dir, name);
            if (exists(full) && isFile(full)) {
                version (Windows) {
                    import std.uni : toLower;
                    auto key = full.toLower();
                    if (!found.map!(a => a.toLower()).canFind(key)) found ~= full;
                } else {
                    if (!found.canFind(full)) found ~= full;
                }
            }
        }
    }
    return found;
}

private bool commandOnPath(string cmd) {
    try {
        version (Windows) {
            return execute(["where", cmd]).status == 0;
        } else {
            return execute(["sh", "-c", "command -v " ~ cmd ~ " >/dev/null 2>&1"]).status == 0;
        }
    } catch (Exception) {
        return resolveAll(cmd).length > 0;
    }
}

private string findAdjacentHelpSdl(string binaryPath) {
    string dir = dirName(binaryPath);
    foreach (c; [buildPath(dir, "help.sdl"), buildPath(dir, "..", "help.sdl")]) {
        if (exists(c) && isFile(c)) return c;
    }
    return "";
}

private int runExternal(string[] argv) {
    try {
        return wait(spawnProcess(argv));
    } catch (Exception e) {
        stderr.writeln("prohelp: failed to run ", argv.join(" "), ": ", e.msg);
        return 1;
    }
}

private void printCrosslinks(string command) {
    writeln();
    writeln("See also:");
    writefln("  about %s", command);
    writefln("  info %s", command);
    writefln("  man %s", command);
    writefln("  prohelp ? shell-help   # configure shell help wrapper");
    writeln();
}

/**
 * Dispatcher used by the shell `help` function (`prohelp --as-help`) and
 * optionally the legacy `help` binary. Extends shell help to PATH topics.
 */
public int runAsHelp(string[] topics) {
    auto banner = registrationBannerLine();
    if (banner.length) {
        writeln(banner);
        writeln("Docs: ", shellHelpDocsUrl);
        writeln();
    } else {
        warnIfHelpWrapperMissing(isStdoutTTYCompat());
    }

    if (topics.length == 0) {
        writeln("Usage: help <command>     # via prohelp shell wrapper");
        writeln("       prohelp --as-help <command>");
        writeln();
        writeln("Configure wrapper:  prohelp wrapper install");
        writeln("Learn more:         prohelp ? shell-help");
        writeln("Web:                ", shellHelpDocsUrl);
        return 0;
    }

    string command = topics[0];
    string[] nav = topics.length > 1 ? topics[1 .. $] : [];
    auto matches = resolveAll(command);
    string chosen = matches.length ? matches[0] : "";

    Orientation orient = tryLoadOrientationNear(chosen, command);
    if (orient is null && chosen.length) {
        auto sdl = findAdjacentHelpSdl(chosen);
        if (sdl.length) {
            try {
                orient = fromCommand(parseHelpSDL(sdl));
            } catch (Exception e) {
                stderr.writeln("prohelp: ", e.msg);
            }
        }
    }

    if (chosen.length) {
        auto sdl = findAdjacentHelpSdl(chosen);
        if (sdl.length) {
            if (orient !is null) write(renderOrientationCard(orient, false));
            string[] helpArgs = [command, "?"];
            if (nav.length) helpArgs ~= nav;
            intercept(helpArgs, InterceptConfig.fromFile(sdl));
            printCrosslinks(command);
            return 0;
        }
    }

    if (orient !is null) write(renderOrientationCard(orient));

    if (commandOnPath("info")) {
        if (runExternal(["info", command]) == 0) {
            printCrosslinks(command);
            return 0;
        }
    }
    if (commandOnPath("man")) {
        if (runExternal(["man", command]) == 0) {
            printCrosslinks(command);
            return 0;
        }
    }
    if (chosen.length) {
        writeln("(falling back to ", chosen, " --help)");
        runExternal([chosen, "--help"]);
        printCrosslinks(command);
        return 0;
    }

    stderr.writefln("prohelp: nothing found for '%s'", command);
    printCrosslinks(command);
    return 1;
}

private bool isStdoutTTYCompat() {
    import prohelp.renderer : isStdoutTTY;
    return isStdoutTTY();
}
