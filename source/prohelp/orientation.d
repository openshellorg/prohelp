module prohelp.orientation;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.stdio;
import std.string;
import sdlang;
import prohelp.parser;

/// Short orientation card for a command — not a manual.
public class Orientation {
    string name;
    string summary;
    string description;
    string history;
    string[] seeAlso;
    string[] binaryPaths;
}

/// Parse an orientation.sdl (or pack fragment) from disk.
public Orientation parseOrientationSDL(string filename) {
    return parseOrientationSDLContent(readText(filename), filename);
}

/// Parse orientation SDL from memory.
public Orientation parseOrientationSDLContent(string content, string sourceLabel) {
    Tag root = parseSource(content, sourceLabel);
    Tag oTag = root.getTag("orientation");
    if (oTag is null) {
        throw new Exception("orientation schema error: root 'orientation' missing in '" ~ sourceLabel ~ "'");
    }
    if (oTag.values.length == 0 || oTag.values[0].peek!string() is null) {
        throw new Exception("orientation schema error: 'orientation' needs a name in '" ~ sourceLabel ~ "'");
    }

    auto o = new Orientation();
    o.name = oTag.values[0].get!string();

    if (auto s = oTag.getTag("summary")) {
        if (s.values.length) o.summary = s.values[0].get!string();
    }
    if (auto d = oTag.getTag("description")) {
        if (d.values.length) o.description = d.values[0].get!string();
    }
    if (auto h = oTag.getTag("history")) {
        if (h.values.length) o.history = h.values[0].get!string();
    }
    foreach (t; oTag.tags) {
        if (t.name == "see-also" || t.name == "see_also") {
            foreach (v; t.values) {
                if (v.peek!string() !is null) {
                    o.seeAlso ~= v.get!string();
                }
            }
        }
        if (t.name == "binary" || t.name == "path") {
            if (t.values.length && t.values[0].peek!string() !is null) {
                o.binaryPaths ~= t.values[0].get!string();
            }
        }
    }

    if (o.seeAlso.length == 0) {
        o.seeAlso = ["help", "info", "man"];
    }
    return o;
}

/// Build a minimal orientation from a prohelp Command (summary/description only).
public Orientation fromCommand(Command cmd) {
    auto o = new Orientation();
    o.name = cmd.name;
    o.summary = cmd.summary;
    o.description = cmd.description;
    o.seeAlso = ["help", "info", "man"];
    return o;
}

/// Render a short orientation card suitable for `about <name>` / `help` prelude.
public string renderOrientationCard(Orientation o, bool includeSeeAlso = true) {
    auto lines = appender!string();
    lines.put(o.name);
    lines.put(" — orientation\n");
    lines.put("────────────────────────────────────────\n");
    if (o.summary.length) {
        lines.put(o.summary);
        lines.put("\n");
    }
    if (o.description.length) {
        lines.put("\n");
        lines.put(o.description);
        lines.put("\n");
    }
    if (o.history.length) {
        lines.put("\nBackground\n");
        lines.put(o.history);
        lines.put("\n");
    }
    if (o.binaryPaths.length) {
        lines.put("\nBinaries on PATH / resolved:\n");
        foreach (p; o.binaryPaths) {
            lines.put("  ");
            lines.put(p);
            lines.put("\n");
        }
    }
    if (includeSeeAlso) {
        if (o.seeAlso.length == 0) {
            o.seeAlso = ["help", "info", "man"];
        }
        lines.put("\nDig deeper:\n");
        string n = o.name;
        bool hasHelp, hasInfo, hasMan;
        foreach (s; o.seeAlso) {
            auto lower = s.toLower();
            if (lower == "help") hasHelp = true;
            else if (lower == "info") hasInfo = true;
            else if (lower == "man") hasMan = true;
            else {
                lines.put("  ");
                lines.put(s);
                lines.put(" ");
                lines.put(n);
                lines.put("\n");
            }
        }
        if (hasHelp) {
            lines.put("  help ");
            lines.put(n);
            lines.put("                 # progressive help (prohelp)\n");
        }
        if (hasInfo) {
            lines.put("  info ");
            lines.put(n);
            lines.put("                 # Info manual (OpenShellOrg / GNU)\n");
        }
        if (hasMan) {
            lines.put("  man ");
            lines.put(n);
            lines.put("                  # traditional man page\n");
        }
    }
    lines.put("\n");
    return lines.data;
}

/// Try to load orientation.sdl next to a binary or from a well-known pack path.
public Orientation tryLoadOrientationNear(string binaryPath, string commandName) {
    string[] candidates;
    if (binaryPath.length) {
        string dir = dirName(binaryPath);
        candidates ~= buildPath(dir, "orientation.sdl");
        candidates ~= buildPath(dir, "help", "orientation.sdl");
        candidates ~= buildPath(dir, commandName ~ ".orientation.sdl");
    }
    candidates ~= buildPath(".", "orientation.sdl");
    candidates ~= buildPath(".", "orientations", commandName ~ ".sdl");

    foreach (c; candidates) {
        if (exists(c) && isFile(c)) {
            try {
                return parseOrientationSDL(c);
            } catch (Exception e) {
                stderr.writeln("prohelp orientation warning: ", e.msg);
            }
        }
    }
    return null;
}

/// Emit orientation SDL text (for extractors / caches).
public string orientationToSDL(Orientation o) {
    auto buf = appender!string();
    buf.put("orientation \"");
    buf.put(o.name);
    buf.put("\" {\n");
    if (o.summary.length) {
        buf.put("    summary \"");
        buf.put(escapeSdl(o.summary));
        buf.put("\"\n");
    }
    if (o.description.length) {
        buf.put("    description \"");
        buf.put(escapeSdl(o.description));
        buf.put("\"\n");
    }
    if (o.history.length) {
        buf.put("    history \"");
        buf.put(escapeSdl(o.history));
        buf.put("\"\n");
    }
    if (o.seeAlso.length) {
        buf.put("    see-also");
        foreach (s; o.seeAlso) {
            buf.put(" \"");
            buf.put(escapeSdl(s));
            buf.put("\"");
        }
        buf.put("\n");
    }
    foreach (p; o.binaryPaths) {
        buf.put("    binary \"");
        buf.put(escapeSdl(p));
        buf.put("\"\n");
    }
    buf.put("}\n");
    return buf.data;
}

private string escapeSdl(string s) {
    return s.replace(`\`, `\\`).replace(`"`, `\"`).replace("\n", `\n`);
}
