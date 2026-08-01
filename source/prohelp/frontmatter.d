module prohelp.frontmatter;

import std.algorithm;
import std.array;
import std.conv : to;
import std.regex;
import std.string;
import std.uri : encodeComponent;

/**
 * Lightweight frontmatter extraction for prohelp document schemas.
 * Supports YAML-ish `---` fences (Markdown/CentrMark), CentrMark SDL fences,
 * and AsciiDoc `:attr:` document headers.
 */

struct Frontmatter {
    string[string] fields; // normalized keys → values
    string body;           // remainder after frontmatter
    bool present;
}

/// Keys we map onto Command metadata (aliases folded in apply).
enum string[] recommendedMetaKeys = [
    "name", "title", "summary", "description",
    "homepage", "docs", "issues", "issues-ai"
];

Frontmatter extractFrontmatter(string raw, string formatHint = "") {
    auto text = normalizeNewlines(raw);
    auto fmt = formatHint.strip().toLower();

    if (fmt == "asciidoc" || fmt == "adoc" || fmt == "asciidoctor"
            || (!fmt.length && looksLikeAsciiDocHeader(text))) {
        return extractAsciiDocHeader(text);
    }

    if (text.stripLeft().startsWith("---")) {
        return extractFencedFrontmatter(text);
    }

    Frontmatter empty;
    empty.body = text;
    return empty;
}

string getField(const Frontmatter fm, string[] aliases...) {
    foreach (a; aliases) {
        auto key = normalizeKey(a);
        if (auto p = key in fm.fields) {
            if ((*p).length) return *p;
        }
    }
    return "";
}

/// DuckDuckGo search URL with a filled query (privacy-friendly default).
string searchEngineUrl(string query) {
    return "https://duckduckgo.com/?q=" ~ encodeComponent(query);
}

string missingMetaSearchQuery(string commandOrPath, string field) {
    auto subject = commandOrPath.length ? commandOrPath : "cli";
    return subject ~ " " ~ field ~ " OR github OR documentation OR \"issue tracker\"";
}

string featureRequestSearchQuery(string commandOrPath) {
    auto subject = commandOrPath.length ? commandOrPath : "this project";
    return "\"" ~ subject ~ "\" prohelp OR \"progressive help\" OR help.sdl feature request OR issue";
}

private string normalizeNewlines(string input) {
    // Strip UTF-8 BOM (common from Windows editors / PowerShell Set-Content)
    if (input.length >= 3 && input[0] == cast(char)0xEF && input[1] == cast(char)0xBB && input[2] == cast(char)0xBF)
        input = input[3 .. $];
    else if (input.length && input[0] == '\uFEFF')
        input = input[1 .. $];
    return input.replace("\r\n", "\n").replace("\r", "\n");
}

private string normalizeKey(string k) {
    return k.strip().toLower().replace("_", "-").replace(" ", "-");
}

private bool looksLikeAsciiDocHeader(string text) {
    auto lines = text.splitLines();
    size_t i = 0;
    while (i < lines.length && !lines[i].strip().length) i++;
    if (i >= lines.length) return false;
    auto t = lines[i].strip();
    if (t.startsWith("=") && !t.startsWith("===")) return true;
    if (t.startsWith(":") && t.canFind(":")) return true;
    return false;
}

private Frontmatter extractFencedFrontmatter(string text) {
    Frontmatter fm;
    auto lines = text.splitLines();
    size_t i = 0;
    while (i < lines.length && !lines[i].strip().length) i++;
    if (i >= lines.length || lines[i].strip() != "---") {
        fm.body = text;
        return fm;
    }
    i++; // open fence
    auto block = appender!string();
    while (i < lines.length && lines[i].strip() != "---") {
        block.put(lines[i]);
        block.put("\n");
        i++;
    }
    if (i < lines.length) i++; // close fence
    fm.present = true;
    parseFrontmatterBlock(block.data, fm.fields);
    fm.body = lines[i .. $].join("\n");
    return fm;
}

private Frontmatter extractAsciiDocHeader(string text) {
    Frontmatter fm;
    auto lines = text.splitLines();
    size_t i = 0;
    while (i < lines.length && !lines[i].strip().length) i++;

    // Optional document title (= Title)
    if (i < lines.length && lines[i].strip().startsWith("=") && !lines[i].strip().startsWith("==")) {
        auto title = lines[i].strip();
        while (title.length && title[0] == '=') title = title[1 .. $];
        title = title.strip();
        if (title.length) {
            fm.fields["title"] = title;
            fm.present = true;
        }
        i++;
    }

    // Attribute lines :name: value
    while (i < lines.length) {
        auto t = lines[i].strip();
        if (!t.length) {
            i++;
            break;
        }
        auto m = matchFirst(t, ctRegex!(`^:([A-Za-z][\w-]*):\s*(.*)$`));
        if (!m) break;
        fm.fields[normalizeKey(m[1])] = m[2].strip();
        fm.present = true;
        i++;
    }

    fm.body = lines[i .. $].join("\n");
    return fm;
}

/**
 * Accept YAML-ish `key: value`, `key: "value"`, and CentrMark/SDL
 * `key "value"` / `key { ... }` (flat string values only).
 */
unittest {
    auto fm = extractFrontmatter(`---
name: tar
homepage: https://example.com
issues: https://example.com/issues
---

# Hello
`);
    assert(fm.present);
    assert(getField(fm, "name") == "tar");
    assert(getField(fm, "homepage").canFind("example.com"));
    assert(fm.body.canFind("# Hello"));
    assert(searchEngineUrl("tar homepage").canFind("duckduckgo.com"));
}

private void parseFrontmatterBlock(string block, ref string[string] fields) {
    foreach (line; block.splitLines()) {
        auto t = line.strip();
        if (!t.length || t.startsWith("#")) continue;

        // SDL-ish: key "value"
        auto sdl = matchFirst(t, ctRegex!(`^([A-Za-z][\w-]*)\s+"(.*)"\s*$`));
        if (sdl) {
            fields[normalizeKey(sdl[1])] = sdl[2];
            continue;
        }

        // YAML-ish: key: value / key: "value" / key: 'value'
        auto yaml = matchFirst(t, ctRegex!(`^([A-Za-z][\w-]*)\s*:\s*(.*)$`));
        if (yaml) {
            auto val = yaml[2].strip();
            if (val.length >= 2 && ((val[0] == '"' && val[$ - 1] == '"')
                    || (val[0] == '\'' && val[$ - 1] == '\''))) {
                val = val[1 .. $ - 1];
            }
            // skip nested YAML objects/arrays for MVP
            if (val == "|" || val == ">" || val.startsWith("{") || val.startsWith("["))
                continue;
            fields[normalizeKey(yaml[1])] = val;
            continue;
        }
    }
}
