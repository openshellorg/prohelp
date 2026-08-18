module prohelp.check;

import std.algorithm;
import std.array;
import std.conv : to;
import std.file;
import std.path;
import std.stdio;
import std.string;
import prohelp.config;
import prohelp.console;
import prohelp.nudge;
import prohelp.parser;

enum FindingLevel { error, warning, info }

struct Finding {
    FindingLevel level;
    string where;
    string message;
}

struct CheckReport {
    string schemaPath;
    Finding[] findings;
    int errors;
    int warnings;
    int infos;

    bool passed(bool strict) const {
        if (errors > 0) return false;
        if (strict && warnings > 0) return false;
        return true;
    }
}

/// Default schema lookup in the working directory.
string defaultSchemaPath() {
    static immutable names = [
        "help.sdl", "help.md", "help.markdown",
        "help.adoc", "help.asciidoc", "help.cmk"
    ];
    foreach (name; names) {
        if (exists(name) && isFile(name)) return name;
    }
    return "help.sdl";
}

bool looksEmpty(string value) {
    auto t = value.strip();
    if (!t.length) return true;
    auto lower = t.toLower();
    if (lower == "todo" || lower == "tbd" || lower == "n/a" || lower == "xxx")
        return true;
    if (lower.startsWith("todo ") || lower.startsWith("(required)")
            || lower.startsWith("your "))
        return true;
    return t.canFind("TODO");
}

Command loadSchemaForCheck(string path) {
    if (isSdlSchemaPath(path))
        return parseHelpSDL(path, false);
    return loadCommand(InterceptConfig.fromFile(path));
}

CheckReport checkSchemaFile(string path) {
    CheckReport report;
    report.schemaPath = path;
    if (!exists(path) || !isFile(path)) {
        add(report, FindingLevel.error, path, "schema file not found");
        return report;
    }
    Command cmd;
    try {
        cmd = loadSchemaForCheck(path);
    } catch (Exception e) {
        add(report, FindingLevel.error, path, e.msg);
        return report;
    }
    checkCommand(report, cmd);
    return report;
}

void checkCommand(ref CheckReport report, Command cmd) {
    if (!cmd.name.length)
        add(report, FindingLevel.error, "command", "missing command name");

    void requireField(string field, string value, FindingLevel level = FindingLevel.warning) {
        if (looksEmpty(value))
            add(report, level, "command", field ~ " is empty — fill it so help is usable");
    }

    requireField("summary", cmd.summary);
    requireField("description", cmd.description);
    foreach (field; essentialMetaFields) {
        string value;
        if (field == "homepage") value = cmd.homepage;
        else if (field == "docs") value = cmd.docsUrl;
        else if (field == "issues") value = cmd.issuesUrl;
        if (looksEmpty(value))
            add(report, FindingLevel.warning, "command",
                "essential field `" ~ field ~ "` is empty (discovery / contact)");
    }

    if (!cmd.sections.length)
        add(report, FindingLevel.warning, "command",
            "no sections — readers cannot drill into topics");

    int rootLines = commandRootLineCount(cmd);
    if (rootLines > 20) {
        add(report, FindingLevel.warning, "command",
            "level 0 layout exceeds the 20-line budget (" ~ rootLines.to!string ~ " lines)");
    } else {
        add(report, FindingLevel.info, "command",
            "level 0 layout " ~ rootLines.to!string ~ "/20 lines");
    }

    foreach (lang, loc; cmd.locales) {
        auto where = "locale '" ~ lang ~ "'";
        if (looksEmpty(loc.summary))
            add(report, FindingLevel.warning, where, "summary is empty");
        if (looksEmpty(loc.description))
            add(report, FindingLevel.warning, where, "description is empty");
    }

    foreach (sec; cmd.sections)
        walkSection(report, sec, sec.name, 1);
}

private void walkSection(ref CheckReport report, Section sec, string path, int displayLevel) {
    auto where = "section '" ~ path ~ "'";
    if (looksEmpty(sec.summary))
        add(report, FindingLevel.warning, where, "summary is empty");

    bool hasBody = sec.content.length > 0 || sec.contentRef.length > 0
        || sec.options.length > 0 || sec.examples.length > 0
        || sec.subsections.length > 0;
    if (!hasBody)
        add(report, FindingLevel.warning, where,
            "empty — add content, options, examples, or child sections");

    if (sec.subsections.length == 0 && sec.options.length == 0
            && looksEmpty(sec.content) && !sec.contentRef.length
            && !sec.examples.length) {
        // already flagged empty
    } else if (sec.subsections.length == 0 && sec.options.length == 0
            && sec.examples.length == 0) {
        add(report, FindingLevel.info, where,
            "no options or examples — fine for prose, thin for a CLI leaf");
    }

    foreach (i, ex; sec.examples) {
        if (looksEmpty(ex.command))
            add(report, FindingLevel.warning, where,
                "example #" ~ (i + 1).to!string ~ " has no command string");
    }

    int lines = sec.calculateLineCount(displayLevel);
    int budget = sectionLineBudget(displayLevel);
    if (lines > budget) {
        add(report, FindingLevel.warning, where,
            "exceeds the " ~ budget.to!string ~ "-line budget (" ~
            lines.to!string ~ " lines)");
    }

    foreach (sub; sec.subsections)
        walkSection(report, sub, path ~ " / " ~ sub.name, displayLevel + 1);
}

private void add(ref CheckReport report, FindingLevel level, string where, string message) {
    report.findings ~= Finding(level, where, message);
    final switch (level) {
        case FindingLevel.error: report.errors++; break;
        case FindingLevel.warning: report.warnings++; break;
        case FindingLevel.info: report.infos++; break;
    }
}

int printCheckReport(const CheckReport report, bool strict, bool color) {
    prepareConsoleOutput();
    auto dim = color ? "\033[2m" : "";
    auto bold = color ? "\033[1m" : "";
    auto reset = color ? "\033[0m" : "";
    auto red = color ? "\033[31m" : "";
    auto yellow = color ? "\033[33m" : "";
    auto cyan = color ? "\033[36m" : "";

    string label(FindingLevel level) {
        final switch (level) {
            case FindingLevel.error: return red ~ "error" ~ reset;
            case FindingLevel.warning: return yellow ~ "warning" ~ reset;
            case FindingLevel.info: return cyan ~ "info" ~ reset;
        }
    }

    writeln(bold, "prohelp check: ", reset, report.schemaPath);
    foreach (f; report.findings) {
        if (f.level == FindingLevel.info && !strict)
            continue;
        writeln("  ", label(f.level), ": ", f.where, " — ", f.message);
    }

    write(dim, report.errors.to!string, " errors, ",
        report.warnings.to!string, " warnings, ",
        report.infos.to!string, " info", reset, "\n");

    if (!strict && report.warnings > 0) {
        writeln(dim, "Ship gate: prohelp check --strict  (fails on warnings)", reset);
        writeln(dim, "CI:        uses: dev-centr/prohelp/.github/workflows/check-schema.yml", reset);
    }

    if (report.passed(strict)) {
        writeln(color ? "\033[32m" : "", "ok", reset,
            strict ? " (strict)" : " (warnings are advisory)");
        return 0;
    }
    writeln(red, "failed", reset, strict ? " (strict)" : "");
    return 1;
}

int runCheckCommand(string[] args) {
    bool strict = false;
    string path;
    foreach (arg; args) {
        if (arg == "--strict" || arg == "-s") {
            strict = true;
            continue;
        }
        if (arg == "--help" || arg == "-h" || arg == "?") {
            writeln("Usage: prohelp check [path] [--strict]");
            writeln("  Default path: help.sdl (or help.md / help.adoc in cwd)");
            writeln("  --strict  treat completeness warnings as failures (CI ship gate)");
            return 0;
        }
        if (arg.startsWith("-")) {
            stderr.writeln("prohelp check: unknown flag ", arg);
            return 2;
        }
        if (path.length) {
            stderr.writeln("prohelp check: extra argument ", arg);
            return 2;
        }
        path = arg;
    }
    if (!path.length) path = defaultSchemaPath();

    auto report = checkSchemaFile(path);
    import prohelp.renderer : isStdoutTTY;
    return printCheckReport(report, strict, isStdoutTTY());
}

unittest {
    auto cmd = new Command();
    cmd.name = "demo";
    CheckReport report;
    report.schemaPath = "memory";
    checkCommand(report, cmd);
    assert(report.warnings > 0);
    assert(report.passed(false));
    assert(!report.passed(true));
}
