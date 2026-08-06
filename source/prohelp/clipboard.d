module prohelp.clipboard;

import std.stdio;
import std.string;
import std.process;
import std.array;

version(Windows) {
    import core.sys.windows.windows;
    pragma(lib, "user32");

    extern(Windows) BOOL OpenClipboard(HWND hWndNewOwner);
    extern(Windows) BOOL CloseClipboard();
    extern(Windows) BOOL EmptyClipboard();
    extern(Windows) HANDLE SetClipboardData(UINT uFormat, HANDLE hMem);
    extern(Windows) HGLOBAL GlobalAlloc(UINT uFlags, size_t dwBytes);
    extern(Windows) LPVOID GlobalLock(HGLOBAL hMem);
    extern(Windows) BOOL GlobalUnlock(HGLOBAL hMem);

    enum GMEM_MOVEABLE = 0x0002;
    enum CF_UNICODETEXT = 13;
}

public bool copyToClipboard(string text) {
    if (text.length == 0) return false;

    version(Windows) {
        if (!OpenClipboard(null)) return false;
        EmptyClipboard();

        // Convert string to UTF-16 wide characters for Windows Unicode Clipboard
        import std.utf : toUTF16;
        wstring wtext = toUTF16(text) ~ '\0';
        size_t bytes = wtext.length * wchar.sizeof;

        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, bytes);
        if (hMem is null) {
            CloseClipboard();
            return false;
        }

        void* pMem = GlobalLock(hMem);
        if (pMem !is null) {
            import core.stdc.string : memcpy;
            memcpy(pMem, wtext.ptr, bytes);
            GlobalUnlock(hMem);
            SetClipboardData(CF_UNICODETEXT, hMem);
        }

        CloseClipboard();
        return true;
    } else {
        // POSIX Clipboard integration
        string[] tools = ["pbcopy", "wl-copy", "xclip", "xsel"];
        
        foreach (toolName; tools) {
            string[] args;
            if (toolName == "pbcopy") args = ["pbcopy"];
            else if (toolName == "wl-copy") args = ["wl-copy"];
            else if (toolName == "xclip") args = ["xclip", "-selection", "clipboard"];
            else if (toolName == "xsel") args = ["xsel", "-b"];

            try {
                // Try executing the tool and feeding the stream
                auto pipes = pipeProcess(args, Redirect.stdin);
                pipes.stdin.write(text);
                pipes.stdin.flush();
                pipes.stdin.close();
                
                int status = wait(pipes.pid);
                if (status == 0) return true; // Successfully copied
            } catch (Exception e) {
                // Keep searching for a valid clipboard tool
                continue;
            }
        }
        return false;
    }
}
