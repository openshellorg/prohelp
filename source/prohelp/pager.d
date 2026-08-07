module prohelp.pager;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import prohelp.parser;
import prohelp.renderer;
import prohelp.clipboard;
import prohelp.console;

version(Windows) {
    import core.sys.windows.windows;
} else {
    import core.sys.posix.termios;
    import core.sys.posix.unistd;
    import core.sys.posix.sys.select;
}

public class TUIState {
    Command cmd;
    Section activeSection;
    string[] path;
    string localeCode;

    // Viewport bounds
    int width;
    int height;

    // Search query
    string searchQuery = "";
    bool searchFocused = false;

    // List navigation
    int selectedIndex = 0;
    string[] filteredItemNames;
    bool isDrilledDown = false;

    // Scroll offset
    int scrollOffset = 0;

    // Highlight / Selection
    bool highlightMode = false;
    int selectStartRow = -1, selectStartCol = -1;
    int selectEndRow = -1, selectEndCol = -1;

    // Terminal virtual screen buffer for copy-parsing
    char[][] screenBuffer;

    this(Command cmd, string localeCode) {
        this.cmd = cmd;
        this.localeCode = localeCode;
        
        // Initial setup at root level
        auto rootSec = new Section();
        rootSec.name = cmd.name;
        rootSec.summary = cmd.summary;
        rootSec.content = cmd.description;
        rootSec.subsections = cmd.sections;
        this.activeSection = rootSec;
        
        updateTerminalSize();
    }

    void updateTerminalSize() {
        getTerminalSize(width, height);
        
        // Resize screen buffer
        screenBuffer = new char[][](height);
        foreach (i; 0 .. height) {
            screenBuffer[i] = new char[](width);
            screenBuffer[i][] = ' ';
        }
    }

    void clearScreenBuffer() {
        foreach (row; 0 .. height) {
            screenBuffer[row][] = ' ';
        }
    }
}

// Global hook to restore console state on POSIX
version(Posix) {
    private termios originalTermios;
    private bool termiosSaved = false;

    extern(C) void restoreTerminalPOSIX() {
        if (termiosSaved) {
            tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios);
        }
    }
}

// Starts the full-screen human TUI browser
public void launchInteractiveTUI(Command cmd, string[] initialPath, string localeCode) {
    prepareConsoleOutput();
    TUIState state = new TUIState(cmd, localeCode);
    
    // Drill down to initial path if provided
    if (initialPath.length > 0) {
        Section cur = state.activeSection;
        foreach (p; initialPath) {
            bool found = false;
            foreach (sub; cur.subsections) {
                if (sub.name == p) {
                    state.activeSection = sub;
                    state.path ~= p;
                    cur = sub;
                    found = true;
                    break;
                }
            }
            if (!found) break;
        }
    }

    // Set up console raw modes
    version(Windows) {
        HANDLE hInput = GetStdHandle(STD_INPUT_HANDLE);
        HANDLE hOutput = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD origInputMode, origOutputMode;
        GetConsoleMode(hInput, &origInputMode);
        GetConsoleMode(hOutput, &origOutputMode);

        // Enable raw input, disable standard editing/echoing, enable virtual terminal processing (TrueColor)
        SetConsoleMode(hInput, origInputMode & ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT));
        SetConsoleMode(hOutput, origOutputMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);

        scope(exit) {
            SetConsoleMode(hInput, origInputMode);
            SetConsoleMode(hOutput, origOutputMode);
            // Clear screen on exit
            write("\033[2J\033[H");
            stdout.flush();
        }
    } else {
        termios raw;
        tcgetattr(STDIN_FILENO, &originalTermios);
        termiosSaved = true;
        
        raw = originalTermios;
        raw.c_lflag &= ~(ICANON | ECHO | ISIG); // Raw input, disable echo & signals
        tcsetattr(STDIN_FILENO, TCSANOW, &raw);

        scope(exit) {
            restoreTerminalPOSIX();
            write("\033[2J\033[H");
            stdout.flush();
        }
    }

    // TUI Loop
    bool running = true;
    state.updateTerminalSize();
    
    while (running) {
        renderTUIFrame(state);
        
        // Wait for keyboard inputs
        running = processKeyboardInput(state);
    }
}

private void renderTUIFrame(TUIState state) {
    state.updateTerminalSize();
    state.clearScreenBuffer();
    auto bx = boxChars();

    auto sb = appender!string();
    // Clear viewport using terminal sequences
    sb.put("\033[2J\033[H");

    // 1. Header Row
    string hierarchy = state.cmd.name;
    if (state.path.length > 0) hierarchy ~= " > " ~ state.path.join(" > ");
    hierarchy ~= " (Locale: " ~ state.localeCode ~ ")";
    string header = " " ~ hierarchy ~ " ";
    int headPad = state.width - 2 - cast(int)header.length;
    if (headPad < 0) headPad = 0;
    string headerLine = bx.tl ~ header ~ replicate(bx.h, headPad) ~ bx.tr;
    sb.put("\033[2m" ~ headerLine ~ "\033[0m\n");
    
    // Copy header text into screen buffer
    string rawHeader = stripStyles(headerLine);
    foreach (col; 0 .. min(state.width, rawHeader.length)) {
        state.screenBuffer[0][col] = rawHeader[col];
    }

    // 2. Search / Filter bar
    string focusIndicator = state.searchFocused ? "<color=cyan>█</>" : " ";
    string searchBox = " Search: [ " ~ state.searchQuery ~ focusIndicator ~ replicate(" ", max(0, state.width - 15 - cast(int)state.searchQuery.length)) ~ " ]";
    sb.put(parseColors(searchBox ~ "\n", true));
    string rawSearch = stripStyles(searchBox);
    foreach (col; 0 .. min(state.width, rawSearch.length)) {
        state.screenBuffer[1][col] = rawSearch[col];
    }

    // Divider
    string div = bx.lj ~ replicate(bx.h, state.width - 2) ~ bx.rj;
    sb.put("\033[2m" ~ div ~ "\033[0m\n");
    foreach (col; 0 .. min(state.width, div.length)) {
        state.screenBuffer[2][col] = div[col];
    }

    // 3. Compile Content List
    string[] items;
    state.filteredItemNames = [];

    // Filter subsections
    foreach (sub; state.activeSection.subsections) {
        if (state.searchQuery.length == 0 || sub.name.toLower().indexOf(state.searchQuery.toLower()) != -1) {
            state.filteredItemNames ~= sub.name;
            items ~= "  <color=green>section</>  <color=bold>" ~ sub.name ~ "</>" ~ replicate(" ", max(1, 15 - cast(int)sub.name.length)) ~ "<color=dim>" ~ sub.summary ~ "</>";
        }
    }
    // Filter options
    foreach (opt; state.activeSection.options) {
        string flagsStr = opt.flags.join(", ");
        if (state.searchQuery.length == 0 || flagsStr.toLower().indexOf(state.searchQuery.toLower()) != -1 || opt.description.toLower().indexOf(state.searchQuery.toLower()) != -1) {
            state.filteredItemNames ~= flagsStr;
            string tier = opt.dominance == "high" ? "<color=cyan>high</>" : (opt.dominance == "low" ? "<color=dim>low</>" : "med ");
            items ~= "  " ~ tier ~ "  <color=yellow>" ~ flagsStr ~ "</>" ~ replicate(" ", max(1, 20 - cast(int)flagsStr.length)) ~ "<color=dim>" ~ opt.description ~ "</>";
        }
    }

    // Clamping selection index
    if (state.selectedIndex >= items.length) {
        state.selectedIndex = max(0, cast(int)items.length - 1);
    }

    // Print content area
    int contentAreaHeight = state.height - 6; // header(1), search(1), div(1), footer(2), border(1)
    
    foreach (i; 0 .. contentAreaHeight) {
        int itemIdx = i + state.scrollOffset;
        string line;
        
        if (itemIdx < items.length) {
            bool isSelected = (itemIdx == state.selectedIndex);
            string prefix = isSelected ? "\033[1;36m█\033[0m" : " ";
            line = prefix ~ " " ~ items[itemIdx];
        } else {
            line = "  "; // Empty row spacer
        }

        // Pad line to viewport width
        string rawLine = stripStyles(line);
        int pad = state.width - 1 - cast(int)rawLine.length;
        if (pad < 0) pad = 0;
        
        string fullLine = line ~ replicate(" ", pad) ~ "\033[2m" ~ bx.v ~ "\033[0m";
        sb.put(parseColors(fullLine ~ "\n", true));

        // Copy raw characters to virtual screen buffer
        string cleanLine = stripStyles(fullLine);
        foreach (col; 0 .. min(state.width, cleanLine.length)) {
            state.screenBuffer[3 + i][col] = cleanLine[col];
        }
    }

    // 4. Divider and Footer
    string bottomDiv = bx.lj ~ replicate(bx.h, state.width - 2) ~ bx.rj;
    sb.put("\033[2m" ~ bottomDiv ~ "\033[0m\n");
    foreach (col; 0 .. min(state.width, bottomDiv.length)) {
        state.screenBuffer[state.height - 2][col] = bottomDiv[col];
    }

    // Footer guides
    string hToggle = state.highlightMode ? "<color=red>[Highlight: ON]</>" : "<color=green>[Highlight: OFF]</>";
    string footer = " [Arrows] Move  [Shift/v] Highlight  " ~ hToggle ~ "  [Ctrl+F] Find  [Ctrl+Esc] Exit";
    int footPad = state.width - 2 - cast(int)stripStyles(footer).length;
    if (footPad < 0) footPad = 0;
    string footerLine = bx.bl ~ footer ~ replicate(bx.h, footPad) ~ bx.br;
    sb.put(parseColors(footerLine, true));
    
    string rawFooter = stripStyles(footerLine);
    foreach (col; 0 .. min(state.width, rawFooter.length)) {
        state.screenBuffer[state.height - 1][col] = rawFooter[col];
    }

    // If Highlight Mode is active, we apply visual overlays on screen buffer using ANSI sequences
    if (state.highlightMode && state.selectStartRow != -1) {
        // Draw frame with color replacements manually (we print the output, but in this case, 
        // we can redraw highlighted selection lines using standard terminal VT cursor sequences).
        write(maybeAsciiBoxes(sb.data));
        stdout.flush();

        // Overlay the inverted rectangle
        int rStart = min(state.selectStartRow, state.selectEndRow);
        int rEnd = max(state.selectStartRow, state.selectEndRow);
        int cStart = min(state.selectStartCol, state.selectEndCol);
        int cEnd = max(state.selectStartCol, state.selectEndCol);

        for (int r = rStart; r <= rEnd; r++) {
            if (r < 0 || r >= state.height) continue;
            // ANSI cursor reposition (1-indexed)
            writef("\033[%d;%dH\033[7m", r + 1, cStart + 1);
            
            // Print selected characters
            int span = cEnd - cStart + 1;
            if (span > 0 && cStart + span <= state.width) {
                write(cast(string)state.screenBuffer[r][cStart .. cStart + span]);
            }
            write("\033[27m"); // turn off invert
        }
        stdout.flush();
    } else {
        // Flat output
        write(maybeAsciiBoxes(sb.data));
        stdout.flush();
    }
}

// Dynamic parser to extract formatted Markdown from grid cells
private string extractMarkdownFromBuffer(TUIState state) {
    int rStart = min(state.selectStartRow, state.selectEndRow);
    int rEnd = max(state.selectStartRow, state.selectEndRow);
    int cStart = min(state.selectStartCol, state.selectEndCol);
    int cEnd = max(state.selectStartCol, state.selectEndCol);

    auto md = appender!string();
    md.put("```markdown\n");

    for (int r = rStart; r <= rEnd; r++) {
        if (r < 0 || r >= state.height) continue;
        string line = cast(string)state.screenBuffer[r][cStart .. min(state.width, cEnd + 1)];
        line = line.stripRight();
        
        // Clean up UI borders
        auto bx = boxChars();
        line = line.replace("┌", "").replace("┐", "").replace("└", "").replace("┘", "")
                   .replace("├", "").replace("┤", "").replace("│", "").replace("─", "")
                   .replace(bx.tl, "").replace(bx.tr, "").replace(bx.bl, "").replace(bx.br, "")
                   .replace(bx.lj, "").replace(bx.rj, "").replace(bx.v, "");
        // Horizontal ASCII "-" is also prose; leave content hyphens intact.
        // Unicode box horizontals are stripped above.
        
        if (line.strip().length > 0) {
            md.put(line ~ "\n");
        }
    }
    md.put("```\n");
    return md.data;
}

private bool processKeyboardInput(TUIState state) {
    version(Windows) {
        HANDLE hInput = GetStdHandle(STD_INPUT_HANDLE);
        INPUT_RECORD[128] records;
        DWORD read;
        
        if (ReadConsoleInputW(hInput, records.ptr, 128, &read)) {
            foreach (i; 0 .. read) {
                if (records[i].EventType == KEY_EVENT) {
                    auto keyEvent = records[i].Event.KeyEvent;
                    
                    // Capture Shift release toggle exactly as requested
                    if (keyEvent.wVirtualKeyCode == VK_SHIFT) {
                        if (!keyEvent.bKeyDown) {
                            state.highlightMode = !state.highlightMode;
                            if (state.highlightMode) {
                                state.selectStartRow = state.selectedIndex + 3 - state.scrollOffset;
                                state.selectStartCol = 4;
                                state.selectEndRow = state.selectStartRow;
                                state.selectEndCol = state.width - 4;
                            } else {
                                state.selectStartRow = -1;
                            }
                        }
                        return true;
                    }

                    // Process on key down
                    if (keyEvent.bKeyDown) {
                        wchar ch = keyEvent.uChar.UnicodeChar;
                        WORD vk = keyEvent.wVirtualKeyCode;
                        DWORD ctrl = keyEvent.dwControlKeyState;

                        // Ctrl+Esc to exit
                        if (vk == VK_ESCAPE && (ctrl & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED))) {
                            return false;
                        }
                        
                        // Ctrl+C copy
                        if (vk == 'C' && (ctrl & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED))) {
                            if (state.highlightMode && state.selectStartRow != -1) {
                                string md = extractMarkdownFromBuffer(state);
                                copyToClipboard(md);
                            }
                            return true;
                        }

                        // Ctrl+F focus find
                        if (vk == 'F' && (ctrl & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED))) {
                            state.searchFocused = true;
                            state.searchQuery = "";
                            state.highlightMode = false;
                            return true;
                        }

                        if (state.highlightMode) {
                            // Highlight mode adjustments
                            if (vk == VK_UP) {
                                state.selectEndRow = max(0, state.selectEndRow - 1);
                            } else if (vk == VK_DOWN) {
                                state.selectEndRow = min(state.height - 1, state.selectEndRow + 1);
                            } else if (vk == VK_LEFT) {
                                state.selectEndCol = max(0, state.selectEndCol - 1);
                            } else if (vk == VK_RIGHT) {
                                state.selectEndCol = min(state.width - 1, state.selectEndCol + 1);
                            } else if (vk == VK_ESCAPE) {
                                state.highlightMode = false;
                                state.selectStartRow = -1;
                            }
                        } else {
                            // Standard Navigation and Typing
                            if (vk == VK_UP) {
                                if (state.selectedIndex > 0) state.selectedIndex--;
                            } else if (vk == VK_DOWN) {
                                state.selectedIndex++;
                            } else if (vk == VK_ESCAPE) {
                                if (state.searchQuery.length > 0) {
                                    state.searchQuery = "";
                                } else if (state.path.length > 0) {
                                    // Backtrack one level
                                    state.path.popBack();
                                    state.activeSection = state.cmd.findSection(state.path);
                                    if (state.activeSection is null) {
                                        // Back to root
                                        auto rootSec = new Section();
                                        rootSec.name = state.cmd.name;
                                        rootSec.summary = state.cmd.summary;
                                        rootSec.content = state.cmd.description;
                                        rootSec.subsections = state.cmd.sections;
                                        state.activeSection = rootSec;
                                    }
                                }
                            } else if (vk == VK_RETURN) {
                                // Drill down
                                if (state.selectedIndex < state.filteredItemNames.length) {
                                    string selectName = state.filteredItemNames[state.selectedIndex];
                                    foreach (sub; state.activeSection.subsections) {
                                        if (sub.name == selectName) {
                                            state.path ~= sub.name;
                                            state.activeSection = sub;
                                            state.selectedIndex = 0;
                                            state.searchQuery = "";
                                            break;
                                        }
                                    }
                                }
                            } else if (vk == VK_BACK) {
                                if (state.searchQuery.length > 0) {
                                    state.searchQuery = state.searchQuery[0 .. $ - 1];
                                }
                            } else if (ch >= 32 && ch < 127) {
                                state.searchQuery ~= ch.to!string;
                            }
                        }
                    }
                }
            }
        }
        return true;
    } else {
        // POSIX keyboard processing
        char[16] buf;
        ssize_t n = read(STDIN_FILENO, buf.ptr, 16);
        if (n <= 0) return true;

        // ANSI escape parser
        if (buf[0] == '\033') {
            if (n == 1) {
                // Raw Escape key
                if (state.highlightMode) {
                    state.highlightMode = false;
                    state.selectStartRow = -1;
                } else if (state.searchQuery.length > 0) {
                    state.searchQuery = "";
                } else if (state.path.length > 0) {
                    // Backtrack
                    state.path.popBack();
                    state.activeSection = state.cmd.findSection(state.path);
                    if (state.activeSection is null) {
                        auto rootSec = new Section();
                        rootSec.name = state.cmd.name;
                        rootSec.summary = state.cmd.summary;
                        rootSec.content = state.cmd.description;
                        rootSec.subsections = state.cmd.sections;
                        state.activeSection = rootSec;
                    }
                    state.selectedIndex = 0;
                }
                return true;
            }

            // Arrow keys
            if (buf[1] == '[') {
                char code = buf[2];
                if (state.highlightMode) {
                    if (code == 'A') state.selectEndRow = max(0, state.selectEndRow - 1); // Up
                    else if (code == 'B') state.selectEndRow = min(state.height - 1, state.selectEndRow + 1); // Down
                    else if (code == 'D') state.selectEndCol = max(0, state.selectEndCol - 1); // Left
                    else if (code == 'C') state.selectEndCol = min(state.width - 1, state.selectEndCol + 1); // Right
                } else {
                    if (code == 'A') {
                        if (state.selectedIndex > 0) state.selectedIndex--;
                    } else if (code == 'B') {
                        state.selectedIndex++;
                    }
                }
                return true;
            }
            return true;
        }

        // Ctrl+Esc raw byte representation fallback: Ctrl+[ is 27, which we handled.
        // POSIX raw signals Ctrl+C (value 3)
        if (buf[0] == 3) {
            if (state.highlightMode && state.selectStartRow != -1) {
                string md = extractMarkdownFromBuffer(state);
                copyToClipboard(md);
                return true;
            }
            return false; // Exit if not in highlight mode
        }

        // Ctrl+F (value 6)
        if (buf[0] == 6) {
            state.searchFocused = true;
            state.searchQuery = "";
            state.highlightMode = false;
            return true;
        }

        // Ctrl+Esc replacement on POSIX (let's check for standard Ctrl+K or custom key or just 'q' to quit)
        if (buf[0] == 'q' && !state.highlightMode) {
            return false;
        }

        // Highlight toggle alternate 'v' key for POSIX (since VK_SHIFT is Windows-specific)
        if (buf[0] == 'v') {
            state.highlightMode = !state.highlightMode;
            if (state.highlightMode) {
                state.selectStartRow = state.selectedIndex + 3 - state.scrollOffset;
                state.selectStartCol = 4;
                state.selectEndRow = state.selectStartRow;
                state.selectEndCol = state.width - 4;
            } else {
                state.selectStartRow = -1;
            }
            return true;
        }

        if (state.highlightMode) {
            return true; // Ignore typing in highlight mode
        }

        if (buf[0] == 10 || buf[0] == 13) {
            // Enter key
            if (state.selectedIndex < state.filteredItemNames.length) {
                string selectName = state.filteredItemNames[state.selectedIndex];
                foreach (sub; state.activeSection.subsections) {
                    if (sub.name == selectName) {
                        state.path ~= sub.name;
                        state.activeSection = sub;
                        state.selectedIndex = 0;
                        state.searchQuery = "";
                        break;
                    }
                }
            }
            return true;
        }

        if (buf[0] == 127 || buf[0] == 8) {
            // Backspace
            if (state.searchQuery.length > 0) {
                state.searchQuery = state.searchQuery[0 .. $ - 1];
            }
            return true;
        }

        // Regular character typing
        if (buf[0] >= 32 && buf[0] < 127) {
            state.searchQuery ~= buf[0].to!string;
            return true;
        }

        return true;
    }
}
