module prohelp.wrapper;

import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;
import prohelp.registration;

private string configDir() {
    auto home = environment.get("HOME", environment.get("USERPROFILE", "."));
    return buildPath(home, ".config", "prohelp");
}

private string snippetPath(string shell) {
    return buildPath(configDir(), "wrapper." ~ shell);
}

private string markerPath() {
    return buildPath(configDir(), "wrapper-installed");
}

private string bashZshFunction() {
    return q"EOS
# >>> prohelp wrapper >>>
# Installed by: prohelp wrapper install
# Docs: https://openshellorg.github.io/prohelp/shell-help.html
help() {
  export PROHELP_AS_HELP=1
  if [ "$#" -eq 0 ]; then
    command prohelp --as-help
    return $?
  fi
  if builtin help "$1" >/dev/null 2>&1; then
    if [ -z "${PROHELP_QUIET:-}" ] && [ ! -f "${HOME}/.config/prohelp/noticed-builtin" ]; then
      printf '%s\n' "prohelp: shell builtin — showing builtin help. PATH commands work via this same \`help\`." >&2
      printf '%s\n' "         docs: https://openshellorg.github.io/prohelp/shell-help.html" >&2
      mkdir -p "${HOME}/.config/prohelp" 2>/dev/null || true
      : > "${HOME}/.config/prohelp/noticed-builtin" 2>/dev/null || true
    fi
    builtin help "$@"
    return $?
  fi
  command prohelp --as-help "$@"
}
# <<< prohelp wrapper <<<
EOS";
}

private string fishFunction() {
    return q"EOS
# >>> prohelp wrapper >>>
function help
  set -lx PROHELP_AS_HELP 1
  command prohelp --as-help $argv
end
# <<< prohelp wrapper <<<
EOS";
}

private string nuFunction() {
    return q"EOS
# >>> prohelp wrapper >>>
def help [...topics: string] {
  $env.PROHELP_AS_HELP = "1"
  if ($topics | is-empty) {
    ^prohelp --as-help
  } else {
    ^prohelp --as-help ...$topics
  }
}
# <<< prohelp wrapper <<<
EOS";
}

private string pwshFunction() {
    return q"EOS
# >>> prohelp wrapper >>>
function help {
  param([Parameter(ValueFromRemainingArguments=$true)]$Topics)
  $env:PROHELP_AS_HELP = '1'
  if (-not $Topics -or $Topics.Count -eq 0) {
    & prohelp --as-help
    return
  }
  $name = [string]$Topics[0]
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd -and ($cmd.CommandType -eq 'Cmdlet' -or $cmd.CommandType -eq 'Function' -or $cmd.CommandType -eq 'Alias')) {
    if (-not $env:PROHELP_QUIET -and -not (Test-Path "$HOME/.config/prohelp/noticed-builtin")) {
      Write-Host "prohelp: PowerShell topic — showing Get-Help. External PATH apps use this same help." -ForegroundColor DarkYellow
      Write-Host "         docs: https://openshellorg.github.io/prohelp/shell-help.html" -ForegroundColor DarkYellow
      New-Item -ItemType Directory -Force -Path "$HOME/.config/prohelp" | Out-Null
      New-Item -ItemType File -Force -Path "$HOME/.config/prohelp/noticed-builtin" | Out-Null
    }
    Get-Help @Topics
    return
  }
  & prohelp --as-help @Topics
}
# <<< prohelp wrapper <<<
EOS";
}

private string detectShell() {
    auto sh = environment.get("SHELL", "");
    auto base = baseName(sh).toLower();
    if (base.canFind("zsh")) return "zsh";
    if (base.canFind("fish")) return "fish";
    if (base.canFind("nu")) return "nu";
    if (base.canFind("bash") || base == "sh") return "bash";
    if (environment.get("PSModulePath", "").length) return "pwsh";
    return "bash";
}

private string rcPathFor(string shell) {
    auto home = environment.get("HOME", environment.get("USERPROFILE", "."));
    if (shell == "bash") return buildPath(home, ".bashrc");
    if (shell == "zsh") return buildPath(home, ".zshrc");
    if (shell == "fish") return buildPath(home, ".config", "fish", "config.fish");
    if (shell == "nu") return buildPath(home, ".config", "nushell", "config.nu");
    if (shell == "pwsh") return buildPath(home, ".config", "powershell", "Microsoft.PowerShell_profile.ps1");
    return buildPath(home, ".bashrc");
}

private string snippetFor(string shell) {
    if (shell == "fish") return fishFunction();
    if (shell == "nu") return nuFunction();
    if (shell == "pwsh") return pwshFunction();
    return bashZshFunction();
}

private string sourceLine(string shell, string snippet) {
    if (shell == "fish")
        return "\n# >>> prohelp wrapper >>>\ntest -f " ~ snippet ~ "; and source " ~ snippet ~ "\n# <<< prohelp wrapper <<<\n";
    if (shell == "nu")
        return "\n# >>> prohelp wrapper >>>\nsource " ~ snippet ~ "\n# <<< prohelp wrapper <<<\n";
    if (shell == "pwsh")
        return "\n# >>> prohelp wrapper >>>\nif (Test-Path '" ~ snippet ~ "') { . '" ~ snippet ~ "' }\n# <<< prohelp wrapper <<<\n";
    return "\n# >>> prohelp wrapper >>>\n[ -f \"" ~ snippet ~ "\" ] && . \"" ~ snippet ~ "\"\n# <<< prohelp wrapper <<<\n";
}

public int wrapperStatus() {
    auto s = probeRegistration();
    writeln("prohelp wrapper status");
    writeln("────────────────────────");
    writefln("  PROHELP_AS_HELP (this process): %s", s.asHelpWrapper ? "yes" : "no");
    writefln("  install marker:                 %s", s.installMarker ? "yes" : "no");
    writefln("  prohelp on PATH:                %s", s.onPath ? "yes" : "no");
    writefln("  looks configured:               %s", s.looksConfigured ? "yes" : "no");
    writeln();
    writeln("Docs: ", shellHelpDocsUrl);
    if (!s.looksConfigured) {
        writeln("Run:  prohelp wrapper install");
        writeln("Or:   prohelp ? shell-help");
    }
    return s.looksConfigured ? 0 : 1;
}

public int wrapperInstall(string shellArg) {
    auto shell = shellArg.length ? shellArg : detectShell();
    auto allowed = ["bash", "zsh", "fish", "nu", "pwsh"];
    if (!allowed.canFind(shell)) {
        stderr.writeln("prohelp wrapper: unsupported shell '", shell, "' (cmd.exe is not supported).");
        stderr.writeln("Use: bash | zsh | fish | nu | pwsh");
        return 2;
    }

    mkdirRecurse(configDir());
    auto snip = snippetPath(shell);
    std.file.write(snip, snippetFor(shell));
    std.file.write(markerPath(), "shell=" ~ shell ~ "\n");

    auto rc = rcPathFor(shell);
    mkdirRecurse(dirName(rc));
    string block = sourceLine(shell, snip);
    string existing = exists(rc) ? readText(rc) : "";
    if (!existing.canFind(">>> prohelp wrapper >>>")) {
        append(rc, block);
        writefln("Appended source block to %s", rc);
    } else {
        writeln("RC already contains a prohelp wrapper block: ", rc);
    }
    writefln("Wrote snippet: %s", snip);
    writeln();
    writeln("Reload your shell, then:  prohelp wrapper status");
    writeln("Docs: ", shellHelpDocsUrl);
    writeln();
    writeln("Package maintainers: shipping prohelp without this wrapper is incomplete.");
    writeln("Report packaging bugs at: ", prohelpIssuesUrl);
    return 0;
}

public int wrapperUninstall(string shellArg) {
    auto shell = shellArg.length ? shellArg : detectShell();
    auto snip = snippetPath(shell);
    if (exists(snip)) {
        remove(snip);
        writeln("Removed ", snip);
    }
    if (exists(markerPath())) {
        remove(markerPath());
        writeln("Removed install marker");
    }
    auto rc = rcPathFor(shell);
    if (exists(rc)) {
        auto text = readText(rc);
        auto start = text.indexOf("# >>> prohelp wrapper >>>");
        auto endMark = "# <<< prohelp wrapper <<<";
        auto end = text.indexOf(endMark);
        if (start >= 0 && end > start) {
            end += endMark.length;
            while (end < text.length && (text[end] == '\n' || text[end] == '\r')) end++;
            text = text[0 .. start] ~ text[end .. $];
            std.file.write(rc, text);
            writeln("Removed block from ", rc);
        }
    }
    writeln("Done. Open a new shell so the old function is gone.");
    return 0;
}

private string parseShellFlag(string[] args) {
    for (size_t i = 0; i < args.length; i++) {
        if (args[i].startsWith("--shell=")) return args[i]["--shell=".length .. $];
        if (args[i] == "--shell" && i + 1 < args.length) return args[i + 1];
    }
    return "";
}

public int runWrapperCommand(string[] args) {
    if (args.length == 0 || args[0] == "status") return wrapperStatus();
    if (args[0] == "install") return wrapperInstall(parseShellFlag(args[1 .. $]));
    if (args[0] == "uninstall") return wrapperUninstall(parseShellFlag(args[1 .. $]));
    stderr.writeln("Usage: prohelp wrapper status|install|uninstall [--shell=bash|zsh|fish|nu|pwsh]");
    return 2;
}
