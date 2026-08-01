module prohelp.config;

import std.path;
import std.string;
import prohelp.document;
import prohelp.parser;

/// Schema source for a single intercept invocation.
public struct InterceptConfig {
    string schemaPath = "";
    string schemaContent = "";
    string schemaLabel = "help.sdl";

    @property bool isConfigured() const {
        return schemaPath.length > 0 || schemaContent.length > 0;
    }

    static InterceptConfig fromFile(string path) {
        InterceptConfig config;
        config.schemaPath = path;
        config.schemaLabel = path;
        return config;
    }

    static InterceptConfig fromContent(string content, string label = "help.sdl") {
        InterceptConfig config;
        config.schemaContent = content;
        config.schemaLabel = label;
        return config;
    }

    /// Host-application default: `help.sdl` in the working directory.
    static InterceptConfig cwdDefault() {
        return fromFile("help.sdl");
    }
}

/// True when path looks like a prohelp schema (SDL or document formats).
bool isHelpSchemaPath(string path) {
    auto lower = path.toLower();
    return lower.endsWith(".sdl")
        || lower.endsWith(".md")
        || lower.endsWith(".markdown")
        || lower.endsWith(".adoc")
        || lower.endsWith(".asciidoc")
        || lower.endsWith(".cmk");
}

bool isSdlSchemaPath(string path) {
    return path.toLower().endsWith(".sdl");
}

public Command loadCommand(const InterceptConfig config) {
    if (config.schemaContent.length > 0) {
        if (isSdlSchemaPath(config.schemaLabel) || config.schemaLabel == "help.sdl"
                || config.schemaLabel.startsWith("embedded")) {
            return parseHelpSDLContent(config.schemaContent, config.schemaLabel);
        }
        return parseHelpDocumentContent(config.schemaContent, config.schemaLabel);
    }

    string path = config.schemaPath.length > 0 ? config.schemaPath : "help.sdl";
    if (isSdlSchemaPath(path)) return parseHelpSDL(path);
    return parseHelpDocument(path);
}
