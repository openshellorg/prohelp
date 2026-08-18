module prohelp.scaffold;

import std.algorithm;
import std.array;
import std.conv : to;
import std.file;
import std.path;
import std.stdio;
import std.string;
import prohelp.check;
import prohelp.config;
import prohelp.parser;
import prohelp.renderer : isStdinTTY;

private string sdlQuote(string s) {
    auto escaped = s.replace(`\`, `\\`).replace(`"`, `\"`)
        .replace("\r\n", "\n").replace("\n", `\n`);
    return `"` ~ escaped ~ `"`;
}

string emitHelpSdl(Command cmd) {
    auto sb = appender!string();
    sb.put("command ");
    sb.put(sdlQuote(cmd.name.length ? cmd.name : "myapp"));
    sb.put(" {\n");

    void field(string name, string value) {
        sb.put("    ");
        sb.put(name);
        sb.put(" ");
        sb.put(sdlQuote(value));
        sb.put("\n");
    }

    field("title", cmd.title.length ? cmd.title : cmd.name);
    field("summary", cmd.summary);
    field("description", cmd.description);
    field("homepage", cmd.homepage);
    field("docs", cmd.docsUrl);
    field("issues", cmd.issuesUrl);
    if (cmd.issuesAiUrl.length)
        field("issues-ai", cmd.issuesAiUrl);
    sb.put("\n");

    auto langs = cmd.locales.keys.array;
    langs.sort();
    foreach (lang; langs) {
        auto loc = cmd.locales[lang];
        sb.put("    locale ");
        sb.put(sdlQuote(lang));
        sb.put(" {\n");
        sb.put("        summary ");
        sb.put(sdlQuote(loc.summary));
        sb.put("\n");
        sb.put("        description ");
        sb.put(sdlQuote(loc.description));
        sb.put("\n    }\n\n");
    }

    foreach (sec; cmd.sections)
        emitSection(sb, sec, 1);

    sb.put("}\n");
    return sb.data;
}

private void emitSection(ref Appender!string sb, Section sec, int depth) {
    auto pad = replicate("    ", depth);
    sb.put(pad);
    sb.put("section ");
    sb.put(sdlQuote(sec.name));
    sb.put(" {\n");
    auto inner = replicate("    ", depth + 1);
    sb.put(inner);
    sb.put("summary ");
    sb.put(sdlQuote(sec.summary));
    sb.put("\n");
    if (sec.content.length) {
        sb.put(inner);
        sb.put("content ");
        sb.put(sdlQuote(sec.content));
        sb.put("\n");
    }
    if (sec.contentRef.length) {
        sb.put(inner);
        sb.put("content-ref ");
        sb.put(sdlQuote(sec.contentRef));
        if (sec.contentFormat.length) {
            sb.put(" {\n");
            sb.put(inner);
            sb.put("    format ");
            sb.put(sdlQuote(sec.contentFormat));
            sb.put("\n");
            sb.put(inner);
            sb.put("}\n");
        } else {
            sb.put("\n");
        }
    }
    if (sec.inlineExpand) {
        sb.put(inner);
        sb.put("inline true\n");
    }
    foreach (ex; sec.examples) {
        sb.put(inner);
        sb.put("example ");
        sb.put(sdlQuote(ex.title));
        sb.put(" ");
        sb.put(sdlQuote(ex.command));
        sb.put("\n");
    }

    string[] tiers = ["high", "medium", "low"];
    foreach (tier; tiers) {
        auto opts = sec.options.filter!(o => o.dominance == tier).array;
        if (!opts.length) continue;
        if (tier == "medium" && opts.length == sec.options.length
                && sec.options.all!(o => o.dominance == "medium")) {
            foreach (opt; opts)
                emitOption(sb, inner, opt);
        } else {
            sb.put(inner);
            sb.put("dominance ");
            sb.put(sdlQuote(tier));
            sb.put(" {\n");
            auto optPad = inner ~ "    ";
            foreach (opt; opts)
                emitOption(sb, optPad, opt);
            sb.put(inner);
            sb.put("}\n");
        }
    }

    foreach (sub; sec.subsections)
        emitSection(sb, sub, depth + 1);

    sb.put(pad);
    sb.put("}\n");
}

private void emitOption(ref Appender!string sb, string pad, Option opt) {
    sb.put(pad);
    sb.put("option");
    foreach (flag; opt.flags) {
        sb.put(" ");
        sb.put(sdlQuote(flag));
    }
    sb.put(" ");
    sb.put(sdlQuote(opt.description));
    sb.put("\n");
}

Command starterCommand(string name) {
    auto cmd = new Command();
    cmd.name = name.length ? name : "myapp";
    cmd.title = cmd.name;
    cmd.summary = "";
    cmd.description = "";
    cmd.homepage = "";
    cmd.docsUrl = "";
    cmd.issuesUrl = "";

    auto usage = new Section();
    usage.name = "usage";
    usage.summary = "How to invoke this command";
    usage.content = cmd.name ~ " [options]";
    auto ex = new Example();
    ex.title = "Show progressive help";
    ex.command = cmd.name ~ " ?";
    usage.examples ~= ex;
    cmd.sections ~= usage;
    return cmd;
}

int runInitCommand(string[] args) {
    string path;
    string name;
    bool force = false;
    bool doFill = false;

    for (size_t i = 0; i < args.length; i++) {
        auto arg = args[i];
        if (arg == "--force" || arg == "-f") {
            force = true;
            continue;
        }
        if (arg == "--fill" || arg == "--interactive") {
            doFill = true;
            continue;
        }
        if (arg == "--no-fill") {
            doFill = false;
            continue;
        }
        if (arg == "--name" && i + 1 < args.length) {
            name = args[++i];
            continue;
        }
        if (arg.startsWith("--name=")) {
            name = arg["--name=".length .. $];
            continue;
        }
        if (arg == "--help" || arg == "-h" || arg == "?") {
            writeln("Usage: prohelp init [path] [--name NAME] [--force] [--fill]");
            writeln("  Writes a blank-but-shaped help.sdl, then optionally runs `prohelp fill`.");
            writeln("  Default path: ./help.sdl");
            return 0;
        }
        if (arg.startsWith("-")) {
            stderr.writeln("prohelp init: unknown flag ", arg);
            return 2;
        }
        if (path.length) {
            stderr.writeln("prohelp init: extra argument ", arg);
            return 2;
        }
        path = arg;
    }

    if (!path.length) path = "help.sdl";
    if (exists(path) && isDir(path))
        path = buildPath(path, "help.sdl");
    if (!name.length)
        name = baseName(stripExtension(path)) == "help"
            ? baseName(getcwd())
            : baseName(stripExtension(path));
    if (name == "." || name == "help" || !name.length)
        name = "myapp";

    if (exists(path) && !force) {
        stderr.writeln("prohelp init: '", path, "' already exists. Pass --force to overwrite,");
        stderr.writeln("              or run: prohelp fill ", path);
        return 2;
    }

    auto dir = dirName(path);
    if (dir.length && dir != "." && !exists(dir))
        mkdirRecurse(dir);

    auto text = emitHelpSdl(starterCommand(name));
    std.file.write(path, text);
    writeln("Wrote ", path);
    writeln("Next:");
    writeln("  prohelp fill ", path);
    writeln("  prohelp check ", path);
    writeln("  prohelp ", path, " ?");

    if (doFill)
        return runFillCommand([path]);
    return 0;
}

private string prompt(string label, string current) {
    if (current.length)
        stdout.write(label, " [", current, "]: ");
    else
        stdout.write(label, ": ");
    stdout.flush();
    auto line = readln();
    if (line is null) return current;
    line = line.strip();
    return line.length ? line : current;
}

private bool promptYes(string label, bool defaultYes) {
    stdout.write(label, defaultYes ? " [Y/n]: " : " [y/N]: ");
    stdout.flush();
    auto line = readln();
    if (line is null) return defaultYes;
    line = line.strip().toLower();
    if (!line.length) return defaultYes;
    return line == "y" || line == "yes";
}

private void applySet(Command cmd, string key, string value) {
    auto k = key.strip().toLower().replace("_", "-");
    if (k == "name" || k == "command") cmd.name = value;
    else if (k == "title" || k == "full-name" || k == "app-name") cmd.title = value;
    else if (k == "summary") cmd.summary = value;
    else if (k == "description") cmd.description = value;
    else if (k == "homepage" || k == "repo" || k == "repository") cmd.homepage = value;
    else if (k == "docs" || k == "docs-url" || k == "documentation") cmd.docsUrl = value;
    else if (k == "issues" || k == "issues-url") cmd.issuesUrl = value;
    else if (k == "issues-ai" || k == "issues-ai-url" || k == "report") cmd.issuesAiUrl = value;
    else throw new Exception("unknown --set field: " ~ key
        ~ " (name, title, summary, description, homepage, docs, issues, issues-ai)");
}

private void fillInteractive(Command cmd) {
    writeln("Fill empty fields. Enter keeps the current value. Ctrl+C to abort.");
    cmd.name = prompt("Command name (binary)", cmd.name);
    cmd.title = prompt("Title (full app name)", cmd.title.length ? cmd.title : cmd.name);
    cmd.summary = prompt("Summary (one line)", cmd.summary);
    cmd.description = prompt("Description", cmd.description);
    cmd.homepage = prompt("Homepage / repo URL", cmd.homepage);
    cmd.docsUrl = prompt("Docs URL", cmd.docsUrl);
    cmd.issuesUrl = prompt("Issues URL", cmd.issuesUrl);

    foreach (sec; cmd.sections) {
        writeln();
        writeln("Section '", sec.name, "':");
        sec.summary = prompt("  summary", sec.summary);
        sec.content = prompt("  content (syntax / body)", sec.content);
        if (!sec.examples.length && promptYes("  add an example?", true)) {
            auto ex = new Example();
            ex.title = prompt("  example title", "Show progressive help");
            ex.command = prompt("  example command", cmd.name ~ " ?");
            sec.examples ~= ex;
        }
    }

    if (promptYes("Add another section?", false)) {
        auto sec = new Section();
        sec.name = prompt("  section name", "options");
        sec.summary = prompt("  summary", "");
        sec.content = prompt("  content", "");
        if (sec.name.length)
            cmd.sections ~= sec;
    }
}

int runFillCommand(string[] args) {
    string path;
    string[string] sets;
    bool noPrompt = false;

    for (size_t i = 0; i < args.length; i++) {
        auto arg = args[i];
        if (arg == "--no-prompt" || arg == "--non-interactive") {
            noPrompt = true;
            continue;
        }
        if (arg == "--help" || arg == "-h" || arg == "?") {
            writeln("Usage: prohelp fill [path] [--set field=value] [--no-prompt]");
            writeln("  Questionnaire over an existing schema (created by `prohelp init`).");
            writeln("  --set can be repeated: --set summary=\"Does a thing\" --set homepage=https://…");
            return 0;
        }
        string rest;
        if (arg.startsWith("--set="))
            rest = arg["--set=".length .. $];
        else if (arg == "--set" && i + 1 < args.length)
            rest = args[++i];
        if (rest.length) {
            auto eq = rest.indexOf('=');
            if (eq <= 0) {
                stderr.writeln("prohelp fill: --set needs field=value");
                return 2;
            }
            sets[rest[0 .. eq]] = rest[eq + 1 .. $];
            continue;
        }
        if (arg.startsWith("-")) {
            stderr.writeln("prohelp fill: unknown flag ", arg);
            return 2;
        }
        if (path.length) {
            stderr.writeln("prohelp fill: extra argument ", arg);
            return 2;
        }
        path = arg;
    }

    if (!path.length) path = defaultSchemaPath();
    if (!exists(path) || !isFile(path)) {
        stderr.writeln("prohelp fill: '", path, "' not found. Run: prohelp init ", path);
        return 2;
    }
    if (!isSdlSchemaPath(path)) {
        stderr.writeln("prohelp fill: questionnaire writes SDL. Convert ", path, " or init a help.sdl.");
        return 2;
    }

    Command cmd;
    try {
        cmd = parseHelpSDL(path, false);
    } catch (Exception e) {
        stderr.writeln(e.msg);
        return 1;
    }

    foreach (key, value; sets) {
        try {
            applySet(cmd, key, value);
        } catch (Exception e) {
            stderr.writeln("prohelp fill: ", e.msg);
            return 2;
        }
    }

    bool wantPrompt = !noPrompt;
    if (wantPrompt && !isStdinTTY()) {
        if (!sets.length) {
            stderr.writeln("prohelp fill: stdin is not a terminal.");
            stderr.writeln("  Use --set field=value, or run in a TTY.");
            return 2;
        }
        wantPrompt = false;
    }

    if (wantPrompt)
        fillInteractive(cmd);

    std.file.write(path, emitHelpSdl(cmd));
    writeln("Updated ", path);
    writeln("Check it:  prohelp check ", path);
    writeln("Preview:   prohelp ", path, " ?");
    return 0;
}

unittest {
    auto cmd = starterCommand("demo");
    auto text = emitHelpSdl(cmd);
    assert(text.canFind(`command "demo"`));
    auto round = parseHelpSDLContent(text, "memory", false);
    assert(round.name == "demo");
    assert(round.sections.length == 1);
    assert(round.sections[0].examples.length == 1);
}
