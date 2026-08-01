module prohelp.parser;

import std.stdio;
import std.string;
import std.conv : to;
import std.array;
import std.algorithm;
import std.path;
import std.file : getcwd;
import sdlang;
import prohelp.content;

public class Option {
    string[] flags;
    string description;
    string dominance = "medium"; // "high", "medium", "low"
}

public class Section {
    string name;
    string summary;
    string content;
    string contentRef;     // path relative to schema dir
    string contentFormat;  // text | asciidoc | markdown | centrmark | sdl
    bool inlineExpand = false;
    Section[] subsections;
    Option[] options;

    // Line budget calculation based on simulated Text Mode output format
    int calculateLineCount(int level) {
        // Unicode box borders and visual headers:
        // Top border + Title: 1 line
        // Description/Summary: 2 lines
        // Spacer: 1 line
        int count = 4;

        if (content.length > 0) {
            count += 2; // Content + spacer
        }

        if (subsections.length > 0) {
            count += 2; // Header + spacer
            count += subsections.length;
        }

        if (options.length > 0) {
            auto high = options.filter!(o => o.dominance == "high").array;
            auto med = options.filter!(o => o.dominance == "medium").array;
            auto low = options.filter!(o => o.dominance == "low").array;

            if (high.length > 0) {
                count += 2; // priority header + spacer
                count += high.length;
            }
            if (med.length > 0) {
                count += 2; // priority header + spacer
                count += med.length;
            }
            if (low.length > 0) {
                count += 2; // priority header + spacer
                count += low.length;
            }
        }

        // Bottom border line: 1
        count += 1;
        return count;
    }
}

public class LocaleInfo {
    string summary;
    string description;
}

public class Command {
    string name;           // binary / invocation name
    string title;          // full application name (optional; defaults to name)
    string summary;
    string description;
    string homepage;       // repository / project homepage
    string docsUrl;        // online documentation
    string issuesUrl;      // issue tracker entrypoint
    string issuesAiUrl;    // optional AI-prequalified report UI wrapping GitHub/etc.
    LocaleInfo[string] locales; // locale -> info
    Section[] sections;
    string schemaDir = "."; // directory of the schema file (for content-ref)

    // Recursive search through section path
    Section findSection(string[] path) {
        if (path.length == 0) return null;
        return findSectionRecursive(sections, path);
    }

    private Section findSectionRecursive(Section[] list, string[] path) {
        if (path.length == 0) return null;
        foreach (sec; list) {
            if (sec.name == path[0]) {
                if (path.length == 1) return sec;
                return findSectionRecursive(sec.subsections, path[1..$]);
            }
        }
        return null;
    }
}

// Main parser function that reads help.sdl from disk.
public Command parseHelpSDL(string filename) {
    import std.file : readText;
    return parseHelpSDLContent(readText(filename), filename);
}

// Parse help.sdl content from memory (embedded or interpreter preview).
public Command parseHelpSDLContent(string content, string sourceLabel) {
    Tag root;
    try {
        root = parseSource(content, sourceLabel);
    } catch (Exception e) {
        throw new Exception("prohelp schema parse error in '" ~ sourceLabel ~ "': " ~ e.msg);
    }

    auto cmd = parseHelpSDLRoot(root, sourceLabel);
    // Prefer directory of on-disk schemas; embedded labels fall back to cwd.
    if (sourceLabel.length && sourceLabel != "help.sdl" && !sourceLabel.startsWith("embedded")) {
        cmd.schemaDir = dirName(absolutePath(sourceLabel));
    } else {
        cmd.schemaDir = getcwd();
    }
    resolveContentRefs(cmd);
    return cmd;
}

private void resolveContentRefs(Command cmd) {
    void walk(Section sec) {
        if (sec.contentRef.length && sec.content.length == 0) {
            try {
                auto fmt = inferContentFormat(sec.contentRef, sec.contentFormat);
                sec.content = loadContentRef(cmd.schemaDir, sec.contentRef, fmt);
            } catch (Exception e) {
                stderr.writeln("prohelp warning: ", e.msg);
                sec.content = "(content-ref failed to load: " ~ sec.contentRef ~ ")";
            }
        }
        foreach (sub; sec.subsections) walk(sub);
    }
    foreach (sec; cmd.sections) walk(sec);
}

private Command parseHelpSDLRoot(Tag root, string sourceLabel) {
    Tag cmdTag = root.getTag("command");
    if (cmdTag is null) {
        throw new Exception("prohelp schema error: Root 'command' tag is missing in '" ~ sourceLabel ~ "'");
    }

    if (cmdTag.values.length == 0 || cmdTag.values[0].peek!string() is null) {
        throw new Exception("prohelp schema error: 'command' tag must have a name value (string) in '" ~ sourceLabel ~ "'");
    }

    auto cmd = new Command();
    cmd.name = cmdTag.values[0].get!string();

    foreach (child; cmdTag.tags) {
        if (child.name == "summary") {
            cmd.summary = child.values[0].get!string();
        } else if (child.name == "description") {
            cmd.description = child.values[0].get!string();
        } else if (child.name == "title" || child.name == "full-name" || child.name == "app-name") {
            if (child.values.length) cmd.title = child.values[0].get!string();
        } else if (child.name == "homepage" || child.name == "repo" || child.name == "repository") {
            if (child.values.length) cmd.homepage = child.values[0].get!string();
        } else if (child.name == "docs" || child.name == "docs-url" || child.name == "documentation") {
            if (child.values.length) cmd.docsUrl = child.values[0].get!string();
        } else if (child.name == "issues" || child.name == "issues-url") {
            if (child.values.length) cmd.issuesUrl = child.values[0].get!string();
        } else if (child.name == "issues-ai" || child.name == "issues-ai-url" || child.name == "report") {
            if (child.values.length) cmd.issuesAiUrl = child.values[0].get!string();
        } else if (child.name == "locale") {
            parseLocale(child, cmd);
        } else if (child.name == "section") {
            auto sec = new Section();
            parseSection(child, sec, 0);
            cmd.sections ~= sec;
        }
    }

    if (!cmd.title.length) cmd.title = cmd.name;

    // Check sliding-scale line budgets for Level 0
    int rootLines = 6 + cast(int)cmd.sections.length;
    if (rootLines > 20) {
        stderr.writeln("prohelp warning: Level 0 root help page layout exceeds the 20-line single-screen budget (" ~
            rootLines.to!string ~ " lines calculated). Consider merging categories or making sections inline.");
    }

    return cmd;
}

private void parseLocale(Tag locTag, Command cmd) {
    if (locTag.values.length == 0 || locTag.values[0].peek!string() is null) return;
    string lang = locTag.values[0].get!string().toLower();
    
    auto info = new LocaleInfo();
    foreach (child; locTag.tags) {
        if (child.name == "summary") {
            info.summary = child.values[0].get!string();
        } else if (child.name == "description") {
            info.description = child.values[0].get!string();
        }
    }
    cmd.locales[lang] = info;
}

private void parseSection(Tag secTag, Section sec, int level) {
    if (secTag.values.length == 0 || secTag.values[0].peek!string() is null) {
        throw new Exception("prohelp schema error: 'section' tag must specify a string name.");
    }
    sec.name = secTag.values[0].get!string();

    foreach (child; secTag.tags) {
        if (child.name == "summary") {
            sec.summary = child.values[0].get!string();
        } else if (child.name == "content") {
            sec.content = child.values[0].get!string();
        } else if (child.name == "content-ref" || child.name == "content_ref" || child.name == "content-file") {
            if (child.values.length) sec.contentRef = child.values[0].get!string();
            foreach (sub; child.tags) {
                if (sub.name == "format" && sub.values.length)
                    sec.contentFormat = sub.values[0].get!string();
            }
        } else if (child.name == "content-format") {
            if (child.values.length) sec.contentFormat = child.values[0].get!string();
        } else if (child.name == "inline") {
            sec.inlineExpand = child.values[0].get!bool();
        } else if (child.name == "section") {
            auto sub = new Section();
            parseSection(child, sub, level + 1);
            sec.subsections ~= sub;
        } else if (child.name == "option") {
            sec.options ~= parseOption(child, "medium");
        } else if (child.name == "dominance") {
            if (child.values.length > 0 && child.values[0].peek!string() !is null) {
                string dom = child.values[0].get!string();
                foreach (optTag; child.tags) {
                    if (optTag.name == "option") {
                        sec.options ~= parseOption(optTag, dom);
                    }
                }
            }
        }
    }

    // Validate progressive line budgets for deeper sections
    int calculatedLines = sec.calculateLineCount(level + 1);
    int budget = (level == 0) ? 40 : 60;
    if (calculatedLines > budget) {
        stderr.writeln("prohelp warning: Section '" ~ sec.name ~ "' (Level " ~ 
            (level + 1).to!string ~ ") exceeds its " ~ budget.to!string ~ 
            "-line budget (" ~ calculatedLines.to!string ~ " lines calculated). Please organize into deeper subsections.");
    }
}

private Option parseOption(Tag optTag, string dominance) {
    auto opt = new Option();
    opt.dominance = dominance;

    if (optTag.values.length > 1) {
        for (size_t i = 0; i < optTag.values.length - 1; i++) {
            if (optTag.values[i].peek!string() !is null) {
                opt.flags ~= optTag.values[i].get!string();
            }
        }
        if (optTag.values[$ - 1].peek!string() !is null) {
            opt.description = optTag.values[$ - 1].get!string();
        }
    } else if (optTag.values.length == 1) {
        if (optTag.values[0].peek!string() !is null) {
            opt.description = optTag.values[0].get!string();
        }
    }
    return opt;
}
