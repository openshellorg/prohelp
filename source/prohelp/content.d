module prohelp.content;

import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.string;

/// How external body text is interpreted when pulled into a section.
enum ContentFormat {
    text,
    asciidoc,
    markdown,
    sdl
}

ContentFormat parseContentFormat(string s) {
    auto l = s.strip().toLower();
    if (l == "adoc" || l == "asciidoc" || l == "asciidoctor") return ContentFormat.asciidoc;
    if (l == "md" || l == "markdown") return ContentFormat.markdown;
    if (l == "sdl" || l == "sdlang") return ContentFormat.sdl;
    return ContentFormat.text;
}

/**
 * Load section body from a path. Formats are lightly normalized into plain
 * progressive-help text (not a full doc toolchain). Prefer keeping one
 * authoring source (e.g. AsciiDoc) and referencing it from help.sdl.
 */
string loadContentRef(string schemaDir, string refPath, ContentFormat fmt) {
    auto full = buildNormalizedPath(schemaDir, refPath);
    if (!exists(full) || !isFile(full)) {
        throw new Exception("prohelp content-ref not found: " ~ full);
    }
    string raw = readText(full);
    final switch (fmt) with (ContentFormat) {
        case text:
        case sdl:
            return raw.strip();
        case markdown:
            return markdownToPlain(raw);
        case asciidoc:
            return asciidocToPlain(raw);
    }
}

/// Strip common Markdown chrome into readable terminal text.
string markdownToPlain(string raw) {
    auto outLines = appender!(string[])();
    foreach (line; raw.splitLines()) {
        auto t = line.stripRight();
        if (t.startsWith("#")) {
            while (t.length && t[0] == '#') t = t[1 .. $];
            t = t.strip();
            if (t.length) outLines.put(t);
            continue;
        }
        if (t.startsWith("```")) continue;
        t = t.replace("**", "").replace("__", "").replace("`", "");
        outLines.put(t);
    }
    return outLines.data.join("\n").strip();
}

/// Strip common AsciiDoc chrome into readable terminal text.
string asciidocToPlain(string raw) {
    auto outLines = appender!(string[])();
    bool inSource;
    foreach (line; raw.splitLines()) {
        auto t = line.stripRight();
        if (t.startsWith("[source") || t == "----" || t == "====" || t == "****") {
            if (t == "----") inSource = !inSource;
            continue;
        }
        if (t.startsWith("=")) {
            while (t.length && t[0] == '=') t = t[1 .. $];
            t = t.strip();
            if (t.length) outLines.put(t);
            continue;
        }
        if (t.startsWith(":")) continue; // attributes
        if (t.startsWith("include::")) {
            outLines.put(t);
            continue;
        }
        // list markers
        if (t.startsWith("* ") || t.startsWith("- ")) t = "• " ~ t[2 .. $];
        if (t.startsWith(". ")) t = "• " ~ t[2 .. $];
        t = t.replace("`+", "").replace("+`", "").replace("`", "");
        t = t.replace("**", "").replace("__", "");
        outLines.put(t);
    }
    return outLines.data.join("\n").strip();
}
