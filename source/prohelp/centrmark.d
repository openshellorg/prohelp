module prohelp.centrmark;

import std.algorithm;
import std.array;
import std.regex;
import std.string;

/**
 * CentrMark (.cmk) → plain text for progressive-help bodies.
 *
 * Terminal-oriented subset renderer for CommonMark-like prose plus CentrMark
 * directives (`::: name`, `@inline[...]`, fenced `((` blockquotes), and SDL
 * frontmatter. Not a conformance port of the AGPL reference engine
 * (https://github.com/dev-centr/centrmark); use that for full AST/HTML.
 */

string centrmarkToPlain(string raw) {
    auto lines = normalizeNewlines(raw).splitLines();
    size_t i = 0;

    // Skip SDL frontmatter fence
    if (i < lines.length && lines[i].strip() == "---") {
        i++;
        while (i < lines.length && lines[i].strip() != "---")
            i++;
        if (i < lines.length)
            i++; // closing ---
    }

    auto outLines = appender!(string[])();
    while (i < lines.length) {
        auto line = lines[i];
        auto trimmed = line.strip();

        if (!trimmed.length) {
            outLines.put("");
            i++;
            continue;
        }

        // Fenced code ```
        if (trimmed.startsWith("```")) {
            i++;
            while (i < lines.length && !lines[i].strip().startsWith("```")) {
                outLines.put("  " ~ lines[i]);
                i++;
            }
            if (i < lines.length)
                i++; // closing fence
            continue;
        }

        // Blockquote (( ... ))
        if (trimmed == "((") {
            i++;
            outLines.put("❝");
            while (i < lines.length && lines[i].strip() != "))") {
                outLines.put("  " ~ inlineToPlain(lines[i].stripRight()));
                i++;
            }
            if (i < lines.length)
                i++;
            outLines.put("❞");
            continue;
        }

        // Block directive ::: name ... :::
        if (trimmed.startsWith(":::")) {
            auto open = trimmed[3 .. $].strip();
            string name = open;
            auto bracket = open.indexOf('[');
            if (bracket >= 0)
                name = open[0 .. bracket].strip();
            else {
                auto sp = open.indexOf(' ');
                if (sp >= 0)
                    name = open[0 .. sp].strip();
            }
            if (!name.length)
                name = "note";
            outLines.put("[" ~ name.toUpper() ~ "]");
            i++;
            while (i < lines.length && !lines[i].strip().startsWith(":::")) {
                auto body = lines[i].stripRight();
                if (body.length)
                    outLines.put(inlineToPlain(body));
                else
                    outLines.put("");
                i++;
            }
            if (i < lines.length)
                i++; // closing :::
            continue;
        }

        // Heading # ## ###
        if (trimmed.startsWith("#")) {
            size_t n = 0;
            while (n < trimmed.length && trimmed[n] == '#')
                n++;
            auto rest = trimmed[n .. $].strip();
            outLines.put(inlineToPlain(rest));
            i++;
            continue;
        }

        // Unordered list
        if (trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("+ ")) {
            outLines.put("• " ~ inlineToPlain(trimmed[2 .. $]));
            i++;
            continue;
        }

        // Ordered list 1. / 1)
        auto ol = matchFirst(trimmed, ctRegex!(`^\d+[.)]\s+(.*)$`));
        if (ol) {
            outLines.put("• " ~ inlineToPlain(ol[1]));
            i++;
            continue;
        }

        // Paragraph / prose line
        outLines.put(inlineToPlain(line.stripRight()));
        i++;
    }

    return outLines.data.join("\n").strip();
}

private string normalizeNewlines(string input) {
    return input.replace("\r\n", "\n").replace("\r", "\n");
}

private string inlineToPlain(string s) {
    auto t = s;
    // Inline directives first (before MD links, which would eat [props](payload)).
    t = replaceAll(t, ctRegex!(`@([A-Za-z][\w-]*)\[[^\]]*\]\(([^)]*)\)`), "$2");
    t = replaceAll(t, ctRegex!(`@([A-Za-z][\w-]*)\(([^)]*)\)`), "$2");
    t = replaceAll(t, ctRegex!(`@([A-Za-z][\w-]*)\[([^\]]*)\]`), "$2");
    t = replaceAll(t, ctRegex!(`@([A-Za-z][\w-]*)\b`), "");
    // Semantic / wiki-style [[target|label]] → label
    t = replaceAll(t, ctRegex!(`\[\[([^\]|]+)\|([^\]]+)\]\]`), "$2");
    t = replaceAll(t, ctRegex!(`\[\[([^\]]+)\]\]`), "$1");
    // Links [text](url) → text (url)
    t = replaceAll(t, ctRegex!(`\[([^\]]+)\]\(([^)]+)\)`), "$1 ($2)");
    // Emphasis / code
    t = t.replace("**", "").replace("__", "");
    t = replaceAll(t, ctRegex!(`(?<!\w)_([^_]+)_(?!\w)`), "$1");
    t = t.replace("`", "");
    return t.strip();
}

unittest {
    auto plain = centrmarkToPlain(`---
title "Demo"
---

# Hello

Status: @badge[color="success"](Stable). Ask @mention[openshell].

::: warning [title="Note"]
Migrate soon.
:::

- one
- two
`);
    assert(plain.canFind("Hello"));
    assert(plain.canFind("Stable"));
    assert(plain.canFind("Ask openshell."));
    assert(plain.canFind("[WARNING]"));
    assert(plain.canFind("Migrate soon."));
    assert(plain.canFind("• one"));
}
