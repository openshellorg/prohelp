module prohelp.nudge;

import std.process;
import std.stdio;
import std.string;
import prohelp.frontmatter;
import prohelp.parser;
import prohelp.console;

/**
 * Nudge authors/users when essential project-metadata is missing from a
 * loaded schema, or when a PATH command has no prohelp schema at all.
 *
 * Warnings are emptiness checks only: if a field is set in help.sdl or in
 * Markdown/AsciiDoc/CentrMark frontmatter, that field is never warned about.
 */

/// Essential project-discovery metadata (contact / docs surface).
/// Content fields (summary, description, title, issues-ai) are not essential.
enum string[] essentialMetaFields = ["homepage", "docs", "issues"];

struct MetaCheck {
    string[] missing; // essential fields with no data
}

MetaCheck checkCommandMetadata(const Command cmd) {
    MetaCheck c;
    if (!cmd.homepage.length) c.missing ~= "homepage";
    if (!cmd.docsUrl.length) c.missing ~= "docs";
    if (!cmd.issuesUrl.length) c.missing ~= "issues";
    return c;
}

/**
 * Warn only for essential fields that are empty after parsing the schema.
 * Present fields (SDL tags or frontmatter) never produce a notice.
 * Includes a search-engine link seeded with the binary name (or schema path).
 */
void warnMissingCommandMetadata(const Command cmd, string schemaPath = "", bool enableColor = true) {
    if (environment.get("PROHELP_QUIET", "") == "1") return;
    auto check = checkCommandMetadata(cmd);
    if (!check.missing.length) return;

    prepareConsoleOutput();

    auto subject = cmd.name.length ? cmd.name : schemaPath;
    if (!subject.length) subject = "this-command";

    auto dim = enableColor ? "\033[2m" : "";
    auto bold = enableColor ? "\033[1m" : "";
    auto reset = enableColor ? "\033[0m" : "";
    auto yellow = enableColor ? "\033[33m" : "";

    stderr.writeln(yellow, bold, "prohelp notice:", reset, " schema for `", subject,
        "` has no data for essential field(s): ", check.missing.join(", "), ".");
    stderr.writeln(dim, "  Set them in help.sdl or in Markdown/AsciiDoc/CentrMark frontmatter.", reset);
    stderr.writeln(dim, "  (Present fields are fine ", dashEm(), " only empty essentials are listed.)", reset);
    foreach (field; check.missing) {
        auto q = missingMetaSearchQuery(subject, field);
        stderr.writeln(dim, "  Find ", field, ": ", searchEngineUrl(q), reset);
    }
    stderr.writeln();
}

/**
 * When a command is not registered with prohelp (no adjacent help schema),
 * tell the user and nudge a feature request upstream via a filled search URL.
 */
void nudgeMissingProhelpDocs(string command, string binaryPath = "", bool enableColor = true) {
    if (environment.get("PROHELP_QUIET", "") == "1") return;

    prepareConsoleOutput();

    auto subject = command.length ? command : binaryPath;
    if (!subject.length) subject = "this command";
    auto searchSubject = binaryPath.length ? binaryPath : command;

    auto dim = enableColor ? "\033[2m" : "";
    auto bold = enableColor ? "\033[1m" : "";
    auto reset = enableColor ? "\033[0m" : "";
    auto yellow = enableColor ? "\033[33m" : "";

    stderr.writeln(yellow, bold, "prohelp notice:", reset, " `", subject,
        "` does not ship prohelp documentation (no help.sdl / help.md / help.adoc nearby).");
    stderr.writeln(dim, "  Falling back to info/man/--help when available.", reset);
    stderr.writeln(dim, "  If you maintain or use this project, consider opening a feature request", reset);
    stderr.writeln(dim, "  asking them to add a prohelp schema (SDL or Markdown/AsciiDoc with frontmatter).", reset);
    stderr.writeln(dim, "  Search / start here: ", searchEngineUrl(featureRequestSearchQuery(searchSubject)), reset);
    stderr.writeln(dim, "  Prohelp authoring: https://github.com/openshellorg/prohelp", reset);
    stderr.writeln();
}
