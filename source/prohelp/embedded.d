module prohelp.embedded;

import std.algorithm;
import std.string;
import prohelp.content;
import prohelp.parser;

version (ProhelpExecutable) {
    private enum embeddedShellHelpAdoc = import("shell-help.adoc");
}

/// Fill shell-help section body when content-ref cannot resolve (installed binary).
public void fillEmbeddedShellHelp(Command cmd) {
    version (ProhelpExecutable) {
        auto sec = cmd.findSection(["shell-help"]);
        if (sec is null) return;
        if (!sec.content.length || sec.content.canFind("content-ref failed")) {
            sec.content = asciidocToPlain(embeddedShellHelpAdoc);
        }
    }
}
