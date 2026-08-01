module prohelp.document;

import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.stdio;
import std.string;
import prohelp.content;
import prohelp.frontmatter;
import prohelp.parser;

/**
 * Author an entire prohelp schema as Markdown, AsciiDoc, or CentrMark.
 * Frontmatter (or AsciiDoc attributes) supply command metadata; headings
 * become the section tree; remaining prose is section content.
 */

Command parseHelpDocument(string filename) {
    return parseHelpDocumentContent(readText(filename), filename);
}

Command parseHelpDocumentContent(string content, string sourceLabel) {
    auto fmt = inferDocumentFormat(sourceLabel);
    string hint = formatHint(fmt);

    auto fm = extractFrontmatter(content, hint);
    auto cmd = new Command();
    applyFrontmatter(cmd, fm, sourceLabel);
    buildSectionsFromBody(cmd, fm.body, fmt);

    if (!cmd.name.length) {
        throw new Exception("prohelp document schema error: missing `name` in frontmatter of '"
            ~ sourceLabel ~ "' (also accepted: command, binary)");
    }
    if (!cmd.title.length) cmd.title = cmd.name;

    if (sourceLabel.length && !sourceLabel.startsWith("embedded")) {
        try {
            cmd.schemaDir = dirName(absolutePath(sourceLabel));
        } catch (Exception) {
            cmd.schemaDir = getcwd();
        }
    } else {
        cmd.schemaDir = getcwd();
    }

    return cmd;
}

private ContentFormat inferDocumentFormat(string sourceLabel) {
    auto fmt = inferContentFormat(sourceLabel, "");
    if (fmt == ContentFormat.markdown || fmt == ContentFormat.asciidoc
            || fmt == ContentFormat.centrmark)
        return fmt;
    auto ext = extension(sourceLabel).toLower();
    if (ext == ".adoc" || ext == ".asciidoc") return ContentFormat.asciidoc;
    if (ext == ".cmk") return ContentFormat.centrmark;
    return ContentFormat.markdown;
}

private string formatHint(ContentFormat fmt) {
    final switch (fmt) with (ContentFormat) {
        case asciidoc: return "asciidoc";
        case markdown: return "markdown";
        case centrmark: return "centrmark";
        case text: case sdl: return "markdown";
    }
}

private void applyFrontmatter(Command cmd, const Frontmatter fm, string sourceLabel) {
    cmd.name = getField(fm, "name", "command", "binary");
    if (!cmd.name.length) {
        auto base = baseName(sourceLabel, extension(sourceLabel));
        if (base != "help" && base.length) {
            if (base.endsWith(".help")) base = base[0 .. $ - 5];
            cmd.name = base;
        }
    }

    cmd.title = getField(fm, "title", "full-name", "app-name", "full_name");
    cmd.summary = getField(fm, "summary", "abstract");
    cmd.description = getField(fm, "description", "desc");
    cmd.homepage = getField(fm, "homepage", "repo", "repository", "url");
    cmd.docsUrl = getField(fm, "docs", "docs-url", "documentation", "docs_url");
    cmd.issuesUrl = getField(fm, "issues", "issues-url", "bugs", "tracker");
    cmd.issuesAiUrl = getField(fm, "issues-ai", "issues-ai-url", "report", "report-ui");
}

private struct Heading {
    int level;
    string title;
    string[] lines;
}

private void buildSectionsFromBody(Command cmd, string body, ContentFormat fmt) {
    auto lines = normalizeNewlines(body).splitLines();
    Heading preamble;
    Heading[] headings;
    int currentIdx = -1; // -1 = preamble

    foreach (line; lines) {
        int level;
        string title;
        if (matchHeading(line, fmt, level, title)) {
            headings ~= Heading(level, title, []);
            currentIdx = cast(int) headings.length - 1;
            continue;
        }
        if (currentIdx < 0) preamble.lines ~= line;
        else headings[currentIdx].lines ~= line;
    }

    auto preambleText = renderBlock(preamble.lines, fmt);
    if (preambleText.length && !cmd.description.length)
        cmd.description = preambleText;

    size_t start = 0;
    if (headings.length && headings[0].level == 1) {
        if (!cmd.title.length || cmd.title == cmd.name)
            cmd.title = headings[0].title;
        auto h1body = renderBlock(headings[0].lines, fmt);
        if (h1body.length) {
            if (!cmd.summary.length) {
                foreach (l; h1body.splitLines()) {
                    if (l.strip().length) {
                        cmd.summary = l.strip();
                        break;
                    }
                }
            }
            // Only fold H1 prose into description when frontmatter omitted it
            if (!cmd.description.length) cmd.description = h1body;
        }
        start = 1;
    }

    // stack holds open sections; depths parallel
    Section[] stack;
    int[] depths;
    foreach (h; headings[start .. $]) {
        auto sec = new Section();
        sec.name = slugify(h.title);
        sec.summary = h.title;
        sec.content = renderBlock(h.lines, fmt);

        int depth = h.level < 2 ? 2 : h.level;
        while (stack.length && depths[$ - 1] >= depth) {
            stack = stack[0 .. $ - 1];
            depths = depths[0 .. $ - 1];
        }

        if (!stack.length) {
            cmd.sections ~= sec;
        } else {
            stack[$ - 1].subsections ~= sec;
        }
        stack ~= sec;
        depths ~= depth;
    }
}

private bool matchHeading(string line, ContentFormat fmt, out int level, out string title) {
    auto t = line.stripRight();
    if (fmt == ContentFormat.asciidoc) {
        if (!t.length || t[0] != '=') return false;
        level = 0;
        while (level < t.length && t[level] == '=') level++;
        if (level == 0 || level > 6) return false;
        title = t[level .. $].strip();
        return title.length > 0;
    }
    if (!t.length || t[0] != '#') return false;
    level = 0;
    while (level < t.length && t[level] == '#') level++;
    if (level == 0 || level > 6) return false;
    if (level < t.length && t[level] != ' ' && t[level] != '\t') return false;
    title = t[level .. $].strip();
    while (title.length && title[$ - 1] == '#') title = title[0 .. $ - 1].strip();
    return title.length > 0;
}

private string renderBlock(string[] lines, ContentFormat fmt) {
    auto raw = lines.join("\n").strip();
    if (!raw.length) return "";
    final switch (fmt) with (ContentFormat) {
        case markdown: return markdownToPlain(raw);
        case asciidoc: return asciidocToPlain(raw);
        case centrmark:
            import prohelp.centrmark : centrmarkToPlain;
            return centrmarkToPlain(raw);
        case text: case sdl: return raw;
    }
}

private string slugify(string title) {
    auto s = title.strip().toLower();
    auto app = appender!string();
    bool dash;
    foreach (dchar c; s) {
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
            app.put(c);
            dash = false;
        } else if (!dash) {
            app.put('-');
            dash = true;
        }
    }
    auto out_ = app.data.strip('-');
    return out_.length ? out_ : "section";
}

private string normalizeNewlines(string input) {
    return input.replace("\r\n", "\n").replace("\r", "\n");
}
