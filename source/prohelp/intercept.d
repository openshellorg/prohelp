module prohelp.intercept;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.file;
import prohelp.config;
import prohelp.parser;
import prohelp.renderer;
import prohelp.locale;
import prohelp.pager;
import prohelp.embedded;
import prohelp.registration;

// First-pass CLI Argument Interceptor
public bool intercept(string[] args, InterceptConfig config = InterceptConfig.init) {
    if (args.length < 2) return false;

    string trigger = args[1].toLower();

    bool matched = false;
    string configSuffix = "";

    string[] baseTriggers = ["?", "help", "--help", "-h", "--?"];
    foreach (t; baseTriggers) {
        if (trigger == t) {
            matched = true;
            break;
        } else if (trigger.startsWith(t ~ ":")) {
            matched = true;
            configSuffix = trigger[t.length + 1 .. $];
            break;
        }
    }

    if (!matched) return false;

    Command cmd;
    try {
        if (config.isConfigured) {
            cmd = loadCommand(config);
        } else {
            string schemaPath = "help.sdl";
            if (!exists(schemaPath)) {
                stderr.writeln("prohelp error: Mandatory schema file '" ~ schemaPath ~ "' was not found in the current directory.");
                return true;
            }
            cmd = parseHelpSDL(schemaPath);
        }
    } catch (Exception e) {
        stderr.writeln(e.msg);
        return true;
    }

    fillEmbeddedShellHelp(cmd);

    string schemaLabel = config.isConfigured
        ? (config.schemaLabel.length > 0 ? config.schemaLabel : "help.sdl")
        : "help.sdl";

    string localeCode = getSystemLocale();
    bool useTUI = false;

    if (configSuffix.length > 0) {
        string[] options = configSuffix.split(",");
        foreach (opt; options) {
            opt = opt.strip().toLower();
            if (opt == "i" || opt == "interactive" || opt == "viewport" || opt == "tui") {
                useTUI = true;
            } else if (opt == "text" || opt == "txt" || opt == "static") {
                useTUI = false;
            } else if (opt == "?") {
                writeln("Available translations in " ~ schemaLabel ~ ":");
                writeln("  - en (Default English)");
                foreach (lang; cmd.locales.keys) {
                    writeln("  - " ~ lang);
                }
                return true;
            } else {
                localeCode = opt;
            }
        }
    }

    string[] path;
    bool dumpSubtree = false;

    for (size_t i = 2; i < args.length; i++) {
        string token = args[i].strip();
        if (token == "*" || token == "all") {
            dumpSubtree = true;
        } else {
            path ~= token;
        }
    }

    if (path.length == 1 && path[0] == "?") {
        writeln("Available languages in " ~ schemaLabel ~ ":");
        writeln("  - en (English / Fallback)");
        foreach (lang; cmd.locales.keys) {
            writeln("  - " ~ lang);
        }
        return true;
    }

    if (localeCode != "en" && (localeCode in cmd.locales) is null) {
        localeCode = "en";
    }

    Section targetSection;
    if (path.length == 0) {
        auto rootSec = new Section();
        rootSec.name = cmd.name;
        rootSec.summary = cmd.summary;
        rootSec.content = cmd.description;
        rootSec.subsections = cmd.sections;
        targetSection = rootSec;
        if (!invokedAsHelpWrapper()) {
            warnIfHelpWrapperMissing(isStdoutTTY());
        }
    } else {
        targetSection = cmd.findSection(path);
        if (targetSection is null) {
            writefln("prohelp error: Category path '%s' not found.", path.join(" > "));
            return true;
        }
    }

    if (useTUI && isStdoutTTY()) {
        launchInteractiveTUI(cmd, path, localeCode);
    } else {
        bool color = isStdoutTTY();

        if (dumpSubtree) {
            printSubtreeRecursive(cmd, targetSection, path, localeCode, color);
        } else {
            string box = renderSectionBox(cmd, targetSection, path, localeCode, color);
            write(box);
            stdout.flush();
        }
    }

    return true;
}

private void printSubtreeRecursive(Command cmd, Section sec, string[] path, string localeCode, bool enableColor) {
    string box = renderSectionBox(cmd, sec, path, localeCode, enableColor);
    write(box);
    stdout.flush();

    foreach (sub; sec.subsections) {
        printSubtreeRecursive(cmd, sub, path ~ sub.name, localeCode, enableColor);
    }
}
