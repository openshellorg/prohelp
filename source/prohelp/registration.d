module prohelp.registration;

import std.algorithm;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;
import prohelp.console;

/// Canonical docs URL for shell `help` wrapper setup.
enum shellHelpDocsUrl = "https://openshellorg.github.io/prohelp/shell-help.html";

/// GitHub issues for packaging / wrapper install failures.
enum prohelpIssuesUrl = "https://github.com/openshellorg/prohelp/issues";

enum prohelpHomepageUrl = "https://github.com/openshellorg/prohelp";

/**
 * True when the current process was entered through a shell `help` function
 * that sets PROHELP_AS_HELP=1 (see `prohelp wrapper install`).
 */
bool invokedAsHelpWrapper() {
    auto v = environment.get("PROHELP_AS_HELP", "");
    return v == "1" || v.toLower() == "true" || v.toLower() == "yes";
}

/**
 * True when the installer left a marker that a wrapper is configured for
 * this login (optional; functions may exist without the marker).
 */
bool wrapperInstallMarkerPresent() {
    auto home = environment.get("HOME", environment.get("USERPROFILE", ""));
    if (!home.length) return false;
    auto marker = buildPath(home, ".config", "prohelp", "wrapper-installed");
    return exists(marker);
}

/// Best-effort: is `prohelp` resolvable on PATH?
bool prohelpOnPath() {
    try {
        version (Windows) {
            auto r = execute(["where", "prohelp"]);
            return r.status == 0;
        } else {
            auto r = execute(["sh", "-c", "command -v prohelp >/dev/null 2>&1"]);
            return r.status == 0;
        }
    } catch (Exception) {
        return false;
    }
}

struct RegistrationStatus {
    bool asHelpWrapper;
    bool installMarker;
    bool onPath;
    bool looksConfigured;
}

RegistrationStatus probeRegistration() {
    RegistrationStatus s;
    s.asHelpWrapper = invokedAsHelpWrapper();
    s.installMarker = wrapperInstallMarkerPresent();
    s.onPath = true; // if we're running, something found us; still check PATH for install quality
    try {
        s.onPath = prohelpOnPath();
    } catch (Exception) {}
    // Configured if wrapper env is set OR marker exists (PATH alone is not enough)
    s.looksConfigured = s.asHelpWrapper || s.installMarker;
    return s;
}

/**
 * Emit a short warning when the shell `help` wrapper is missing.
 * Callers should still print normal help afterward.
 */
void warnIfHelpWrapperMissing(bool enableColor = true) {
    auto s = probeRegistration();
    if (s.looksConfigured) return;
    if (environment.get("PROHELP_QUIET", "") == "1") return;

    prepareConsoleOutput();

    auto dim = enableColor ? "\033[2m" : "";
    auto bold = enableColor ? "\033[1m" : "";
    auto reset = enableColor ? "\033[0m" : "";
    auto yellow = enableColor ? "\033[33m" : "";

    stderr.writeln(yellow, bold, "prohelp notice:", reset, " the shell `help` wrapper is not active in this session.");
    stderr.writeln(dim, "  Builtins still use the shell's own help; PATH commands need the wrapper.", reset);
    stderr.writeln(dim, "  Docs: ", shellHelpDocsUrl, reset);
    stderr.writeln(dim, "  Setup:  prohelp ? shell-help", reset);
    stderr.writeln(dim, "          prohelp wrapper status", reset);
    stderr.writeln(dim, "          prohelp wrapper install", reset);
    stderr.writeln(dim, "  If a package installed prohelp without the wrapper, that is an installer/", reset);
    stderr.writeln(dim, "  maintainer bug ", dashEm(), " report it (include distro/package name) at:", reset);
    stderr.writeln(dim, "  ", prohelpIssuesUrl, reset);
    stderr.writeln();
}

string registrationBannerLine() {
    if (invokedAsHelpWrapper()) {
        prepareConsoleOutput();
        return "prohelp: extending shell `help` (builtins " ~ arrowRight() ~ " shell; PATH "
            ~ arrowRight() ~ " prohelp/man/info)";
    }
    return "";
}
