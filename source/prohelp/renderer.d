module prohelp.renderer;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.regex;
import prohelp.parser;
import prohelp.console;

version(Windows) {
    import core.sys.windows.windows;
} else {
    import core.sys.posix.sys.ioctl;
    import core.sys.posix.unistd;
}

// Queries dynamic terminal width and height
public void getTerminalSize(out int width, out int height) {
    width = 80;
    height = 24;

    version(Windows) {
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        CONSOLE_SCREEN_BUFFER_INFO csbi;
        if (GetConsoleScreenBufferInfo(hOut, &csbi)) {
            width = csbi.srWindow.Right - csbi.srWindow.Left + 1;
            height = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
        }
    } else {
        winsize w;
        if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
            width = w.ws_col;
            height = w.ws_row;
        }
    }

    if (width <= 0) width = 80;
    if (height <= 0) height = 24;
}

// Check if stdout is an interactive TTY (true color, raw paging applicable)
public bool isStdoutTTY() {
    version(Windows) {
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD mode;
        return GetConsoleMode(hOut, &mode) != 0;
    } else {
        return isatty(STDOUT_FILENO) != 0;
    }
}

// Helper to strip style tags from formatted text
public string stripStyles(string text) {
    auto colorTagRx = ctRegex!`<color=(#[0-9A-Fa-f]{6}|[a-zA-Z]+)>`;
    auto bgTagRx = ctRegex!`<bg=(#[0-9A-Fa-f]{6}|[a-zA-Z]+)>`;
    string clean = text.replaceAll(colorTagRx, "")
                       .replaceAll(bgTagRx, "")
                       .replace("<b>", "")
                       .replace("<bold>", "")
                       .replace("<d>", "")
                       .replace("<dim>", "")
                       .replace("</>", "")
                       .replace("</color>", "")
                       .replace("</b>", "")
                       .replace("</dim>", "");
    return clean;
}

// Replaces style tags with ANSI terminal sequences (or strips them if color is disabled)
public string parseColors(string text, bool enableColor = true) {
    if (!enableColor) return stripStyles(text);

    // Replace basic formatters
    text = text.replace("<b>", "\033[1m")
               .replace("<bold>", "\033[1m")
               .replace("<d>", "\033[2m")
               .replace("<dim>", "\033[2m")
               .replace("</>", "\033[0m")
               .replace("</color>", "\033[0m")
               .replace("</b>", "\033[0m")
               .replace("</dim>", "\033[0m");

    // Process Hex colors and standard colors
    auto colorTagRx = ctRegex!`<color=(#[0-9A-Fa-f]{6}|[a-zA-Z]+)>`;
    
    auto m = text.matchAll(colorTagRx);
    foreach (cap; m) {
        string tag = cap[0];
        string val = cap[1];
        string esc;

        if (val.startsWith("#")) {
            // Hex color e.g., #FF5500
            if (val.length == 7) {
                try {
                    int r = to!int(val[1..3], 16);
                    int g = to!int(val[3..5], 16);
                    int b = to!int(val[5..7], 16);
                    esc = "\033[38;2;" ~ r.to!string ~ ";" ~ g.to!string ~ ";" ~ b.to!string ~ "m";
                } catch (Exception) {
                    esc = ""; // ignore bad hex
                }
            }
        } else {
            // Named colors
            switch (val.toLower()) {
                case "red": esc = "\033[31m"; break;
                case "green": esc = "\033[32m"; break;
                case "yellow": esc = "\033[33m"; break;
                case "blue": esc = "\033[34m"; break;
                case "magenta": esc = "\033[35m"; break;
                case "cyan": esc = "\033[36m"; break;
                case "white": esc = "\033[37m"; break;
                case "dim": esc = "\033[2m"; break;
                case "bold": esc = "\033[1m"; break;
                default: esc = ""; break;
            }
        }
        text = text.replace(tag, esc);
    }

    return text;
}

// Wraps text into lines not exceeding target width
public string[] wrapText(string text, size_t maxWidth) {
    if (text.length == 0) return [""];
    
    string[] lines;
    string[] sourceLines = text.split("\n");

    foreach (sLine; sourceLines) {
        string rawLine = stripStyles(sLine);
        if (rawLine.length <= maxWidth) {
            lines ~= sLine; // Preserves tags
            continue;
        }

        string currentLine = "";
        size_t currentRawLength = 0;
        
        // Read word by word to keep styles intact
        string[] words = sLine.split(" ");
        foreach (word; words) {
            string rawWord = stripStyles(word);
            
            if (currentRawLength + rawWord.length + (currentLine.length > 0 ? 1 : 0) > maxWidth) {
                if (currentLine.length > 0) {
                    lines ~= currentLine;
                    currentLine = word;
                    currentRawLength = rawWord.length;
                } else {
                    // Word itself is wider than maxWidth, hard wrap
                    lines ~= word;
                }
            } else {
                if (currentLine.length > 0) {
                    currentLine ~= " " ~ word;
                    currentRawLength += 1 + rawWord.length;
                } else {
                    currentLine = word;
                    currentRawLength = rawWord.length;
                }
            }
        }
        if (currentLine.length > 0) {
            lines ~= currentLine;
        }
    }
    return lines;
}

/// Terminal columns for styled text (style tags ignored; each code point = 1 col).
/// Box-drawing is one column; do not use `.length` (UTF-8 byte length) for layout.
public int displayWidth(string styled) {
    int n = 0;
    foreach (dchar c; stripStyles(styled))
        n++;
    return n;
}

/// Full-width top/bottom edge: `┌──── title ────┐` totaling `boxWidth` columns.
private string framedEdge(string leftCorner, string rightCorner, string title, int boxWidth,
    BoxChars bx, bool enableColor)
{
    int inner = boxWidth - 2; // between corners
    int titleW = displayWidth(title);
    if (titleW > inner - 2)
        titleW = inner - 2;
    int left = (inner - titleW) / 2;
    if (left < 1) left = 1;
    int right = inner - titleW - left;
    if (right < 1) {
        right = 1;
        left = inner - titleW - right;
        if (left < 1) left = 1;
    }
    string line = leftCorner ~ replicate(bx.h, left) ~ title ~ replicate(bx.h, right) ~ rightCorner;
    return parseColors("<color=dim>" ~ line ~ "</>\n", enableColor);
}

/// Section divider: `├─ Label ────┤` totaling `contentWidth + 4` (= boxWidth) columns.
/// `label` should include surrounding spaces, e.g. `" Content "`.
private string framedDivider(string label, int contentWidth, BoxChars bx, bool enableColor) {
    // lj(1) + h(1) + label + dashes + rj(1) == contentWidth + 4
    int labelW = displayWidth(label);
    int dashes = contentWidth + 1 - labelW;
    if (dashes < 2) dashes = 2;
    string line = bx.lj ~ bx.h ~ label ~ replicate(bx.h, dashes) ~ bx.rj;
    return parseColors("<color=dim>" ~ line ~ "</>\n", enableColor);
}

/// Content row: dim pipes, undimmed body. Total width `contentWidth + 4`.
private string framedRow(string inner, int contentWidth, BoxChars bx, bool enableColor) {
    int pad = contentWidth - displayWidth(inner);
    if (pad < 0) pad = 0;
    return parseColors(
        "<color=dim>" ~ bx.v ~ "</> " ~ inner ~ replicate(" ", pad)
            ~ " <color=dim>" ~ bx.v ~ "</>\n",
        enableColor);
}

// Render a Section as a zoned box (Unicode when console is UTF-8; ASCII otherwise)
public string renderSectionBox(Command cmd, Section sec, string[] path, string localeCode, bool enableColor = true) {
    prepareConsoleOutput();
    auto bx = boxChars();

    int termWidth, termHeight;
    getTerminalSize(termWidth, termHeight);

    // Clamp visual box width for premium layout
    int boxWidth = termWidth - 4;
    if (boxWidth < 50) boxWidth = 50;
    if (boxWidth > 80) boxWidth = 80;

    int contentWidth = boxWidth - 4; // between "│ " and " │"

    string title = cmd.name;
    if (path.length > 0) {
        title ~= " > " ~ path.join(" > ");
    }
    title = " " ~ title ~ " ";

    string summary = sec.summary;
    string lowerLoc = localeCode.toLower();
    if (path.length == 0) {
        if (auto pLoc = lowerLoc in cmd.locales) {
            if (pLoc.summary.length > 0) summary = pLoc.summary;
        }
    }

    auto sb = appender!string();
    sb.put(framedEdge(bx.tl, bx.tr, title, boxWidth, bx, enableColor));

    // Project metadata near the top (docs / repo / issues)
    if (path.length == 0) {
        string[] metaLines;
        if (cmd.title.length && cmd.title != cmd.name)
            metaLines ~= "App: " ~ cmd.title ~ "  (" ~ cmd.name ~ ")";
        if (cmd.docsUrl.length) metaLines ~= "Docs: " ~ cmd.docsUrl;
        if (cmd.homepage.length) metaLines ~= "Repo: " ~ cmd.homepage;
        if (cmd.issuesUrl.length) metaLines ~= "Issues: " ~ cmd.issuesUrl;
        if (cmd.issuesAiUrl.length) metaLines ~= "Report UI: " ~ cmd.issuesAiUrl;
        if (metaLines.length) {
            foreach (ml; metaLines) {
                foreach (line; wrapText("<color=cyan>" ~ ml ~ "</>", contentWidth))
                    sb.put(framedRow(line, contentWidth, bx, enableColor));
            }
            sb.put(framedRow("", contentWidth, bx, enableColor));
        }
    }

    if (summary.length > 0) {
        foreach (line; wrapText(summary, contentWidth))
            sb.put(framedRow(line, contentWidth, bx, enableColor));

        string desc = cmd.description;
        if (path.length == 0) {
            if (auto pLoc = lowerLoc in cmd.locales) {
                if (pLoc.description.length > 0) desc = pLoc.description;
            }
        }
        if (path.length == 0 && desc.length > 0) {
            sb.put(framedRow("", contentWidth, bx, enableColor));
            foreach (line; wrapText(desc, contentWidth))
                sb.put(framedRow(line, contentWidth, bx, enableColor));
        }
    }

    if (sec.content.length > 0) {
        sb.put(framedDivider(" Content ", contentWidth, bx, enableColor));
        foreach (line; wrapText(sec.content, contentWidth))
            sb.put(framedRow(line, contentWidth, bx, enableColor));
    }

    if (sec.subsections.length > 0) {
        sb.put(framedDivider(
            " Sections (Run: '" ~ cmd.name ~ " ?:<section>' to view) ",
            contentWidth, bx, enableColor));

        foreach (sub; sec.subsections) {
            string line = "  <color=green>" ~ sub.name ~ "</>";

            if (sub.inlineExpand && sub.subsections.length > 0) {
                string[] kids;
                foreach (k; sub.subsections) kids ~= k.name;
                line ~= " <color=dim>[" ~ kids.join("|") ~ "]</>";
            }

            int pad = contentWidth - displayWidth(line);
            if (pad > 32) {
                string sum = sub.summary;
                if (displayWidth(sum) > 28) sum = sum[0 .. 25] ~ "...";
                line ~= replicate(" ", pad - displayWidth(sum) - 2) ~ "<color=dim>" ~ sum ~ "</>";
            }

            sb.put(framedRow(line, contentWidth, bx, enableColor));
        }
    }

    if (sec.options.length > 0) {
        string[] dominanceTiers = ["high", "medium", "low"];
        string[] tierHeaders = ["HIGH PRIORITY", "MEDIUM PRIORITY", "LOW PRIORITY/ADVANCED"];
        string[] tierColors = ["cyan", "dim", "dim"];

        foreach (tIdx, tier; dominanceTiers) {
            auto tierOpts = sec.options.filter!(o => o.dominance == tier).array;
            if (tierOpts.length == 0) continue;

            sb.put(framedDivider(
                " Option Group: " ~ tierHeaders[tIdx] ~ " ",
                contentWidth, bx, enableColor));

            foreach (opt; tierOpts) {
                string flagCol = tierColors[tIdx];
                string flagsStr = opt.flags.join(", ");
                string line = "  <color=" ~ flagCol ~ ">" ~ flagsStr ~ "</>";
                int pad = contentWidth - displayWidth(line);
                if (pad > 25) {
                    string desc = opt.description;
                    if (displayWidth(desc) > 30) desc = desc[0 .. 27] ~ "...";
                    line ~= replicate(" ", pad - displayWidth(desc) - 2) ~ "<color=dim>" ~ desc ~ "</>";
                }
                sb.put(framedRow(line, contentWidth, bx, enableColor));
            }
        }
    }

    sb.put(framedDivider(" Info ", contentWidth, bx, enableColor));
    sb.put(framedRow(
        "  Locale: " ~ localeCode ~ "   |   (?:i for interactive)",
        contentWidth, bx, enableColor));
    sb.put(framedRow(
        "  Escape: Filename 'help' or '?' can be passed as './help' or './?'",
        contentWidth, bx, enableColor));
    sb.put(framedEdge(bx.bl, bx.br, "", boxWidth, bx, enableColor));

    return sb.data;
}
