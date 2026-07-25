import { createSignal, Show } from "solid-js";

interface SectionData {
  title: string;
  summary: string;
  content?: string;
  sections?: string[];
  options?: { flags: string; desc: string; dom: string }[];
}

export default function App() {
  const [activeTab, setActiveTab] = createSignal<"text" | "interactive">("text");
  const [tuiPath, setTuiPath] = createSignal<string[]>([]);
  const [tuiSearch, setTuiSearch] = createSignal<string>("");
  const [copiedText, setCopiedText] = createSignal<string | null>(null);

  // Simulated help.sdl data for tar
  const tarData: Record<string, SectionData> = {
    root: {
      title: "tar",
      summary: "Tape archiver utility",
      content: "An archiver utility used to combine multiple files into a single archive file, often referred to as a 'tarball'.",
      sections: ["usage", "operations", "modifiers"],
    },
    usage: {
      title: "tar > usage",
      summary: "Common command usage patterns",
      content: "tar [operation] [options] [files...]\n\nExamples:\n - Create gzip archive: tar -czf archive.tar.gz /dir\n - Extract archive:    tar -xf archive.tar",
    },
    operations: {
      title: "tar > operations",
      summary: "Main operation modes",
      sections: ["creation", "extraction", "listing"],
    },
    creation: {
      title: "tar > operations > creation",
      summary: "Creating new archives",
      options: [
        { flags: "-c, --create", desc: "Create a new archive from files", dom: "high" },
        { flags: "-A, --catenate, --concatenate", desc: "Append tar files to an archive", dom: "med" }
      ]
    },
    extraction: {
      title: "tar > operations > extraction",
      summary: "Extracting files from archives",
      options: [
        { flags: "-x, --extract, --get", desc: "Extract files from an archive", dom: "high" }
      ]
    },
    listing: {
      title: "tar > operations > listing",
      summary: "Listing archive contents",
      options: [
        { flags: "-t, --list", desc: "List the contents of an archive", dom: "high" }
      ]
    },
    modifiers: {
      title: "tar > modifiers",
      summary: "Operation modifiers that change behavior",
      sections: ["archiving-formats", "file-selection"],
    },
    "archiving-formats": {
      title: "tar > modifiers > archiving-formats",
      summary: "Compression options and archive formats",
      options: [
        { flags: "-z, --gzip, --gunzip", desc: "Filter the archive through gzip", dom: "high" },
        { flags: "-j, --bzip2", desc: "Filter the archive through bzip2", dom: "high" },
        { flags: "-J, --xz", desc: "Filter the archive through xz", dom: "low" }
      ]
    },
    "file-selection": {
      title: "tar > modifiers > file-selection",
      summary: "Selecting files to include or exclude",
      options: [
        { flags: "-C, --directory", desc: "Change to directory before operating", dom: "med" },
        { flags: "--exclude", desc: "Exclude files matching a pattern", dom: "low" }
      ]
    }
  };

  const [activeSectionKey, setActiveSectionKey] = createSignal<string>("root");

  const copyInstallCmd = () => {
    navigator.clipboard.writeText("dub add prohelp");
    setCopiedText("Copied!");
    setTimeout(() => setCopiedText(null), 2000);
  };

  // TUI Active Items
  const tuiFilteredItems = () => {
    const curKey = tuiPath().length === 0 ? "root" : tuiPath()[tuiPath().length - 1];
    const node = tarData[curKey];
    if (!node) return [];

    let rawList: { name: string; type: "section" | "option"; summary: string }[] = [];
    if (node.sections) {
      node.sections.forEach(s => {
        const target = tarData[s];
        rawList.push({ name: s, type: "section", summary: target ? target.summary : "" });
      });
    }
    if (node.options) {
      node.options.forEach(o => {
        rawList.push({ name: o.flags, type: "option", summary: o.desc });
      });
    }

    if (tuiSearch().length === 0) return rawList;
    return rawList.filter(item => 
      item.name.toLowerCase().includes(tuiSearch().toLowerCase()) ||
      item.summary.toLowerCase().includes(tuiSearch().toLowerCase())
    );
  };

  return (
    <div class="min-h-screen flex flex-col relative px-4 md:px-12 py-6 bg-radial from-[#161619] to-[#0c0c0e]">
      
      {/* Header */}
      <header class="w-full max-w-6xl mx-auto flex items-center justify-between border-b border-[#2e2e33]/60 pb-4 mb-12 animate-fade-in" style="animation-delay: 0.1s">
        <div class="flex items-center gap-3">
          <svg class="w-6 h-6 text-[#06b6d4]" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 8.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25A2.25 2.25 0 0 1 13.5 18v-2.25Z" />
          </svg>
          <span class="text-xl font-bold tracking-widest text-white code-font">PROHELP</span>
        </div>
        <nav class="flex items-center gap-6">
          <a href="https://github.com/dev-centr/devcentr/blob/main/docs/modules/specifications/pages/prohelp.adoc" target="_blank" class="text-sm font-medium text-[#a1a1aa] hover:text-white transition-colors">Specifications</a>
          <a href="https://github.com/openshellorg/prohelp" target="_blank" class="text-sm font-medium text-[#a1a1aa] hover:text-white transition-colors flex items-center gap-1">
            GitHub
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
          </a>
        </nav>
      </header>

      {/* Hero Section */}
      <main class="w-full max-w-6xl mx-auto flex-grow grid grid-cols-1 lg:grid-cols-12 gap-12 items-center mb-16">
        
        <div class="lg:col-span-6 flex flex-col gap-6 animate-fade-in" style="animation-delay: 0.2s">
          <h1 class="text-4xl md:text-5xl font-extrabold tracking-tight text-white leading-tight">
            Progressive <br/>
            <span class="text-transparent bg-clip-text bg-gradient-to-r from-[#06b6d4] to-[#22d3ee]">Command-Line Help</span>
          </h1>
          <p class="text-lg text-[#a1a1aa] leading-relaxed">
            Cognitive-budgeted CLI navigation, 24-bit TrueColor boxed panels, and zero-dependency terminal browsers. A drop-in replacement that looks and feels like the future.
          </p>

          {/* Action Row */}
          <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-4 mt-2">
            <a href="https://github.com/dev-centr/devcentr/blob/main/docs/modules/specifications/pages/prohelp.adoc" target="_blank" class="px-6 py-3 bg-[#06b6d4] hover:bg-[#22d3ee] text-black font-semibold text-center transition-all duration-150 shadow-[0_0_15px_rgba(6,182,212,0.3)]" style="border-radius: var(--radius-sharp)">
              Explore Specifications
            </a>
            
            {/* Pipable code copy */}
            <button onClick={copyInstallCmd} class="flex items-center justify-between gap-4 px-4 py-3 bg-[#1d1d20] hover:bg-[#26262b] border border-[#2e2e33] code-font text-sm text-left transition-colors" style="border-radius: var(--radius-sharp)">
              <span class="text-[#22d3ee]">dub add prohelp</span>
              <span class="text-xs text-[#a1a1aa] min-w-[50px] text-right">{copiedText() || "Copy"}</span>
            </button>
          </div>
        </div>

        {/* Dynamic Simulator Section */}
        <div class="lg:col-span-6 flex flex-col gap-4 animate-fade-in" style="animation-delay: 0.3s">
          
          {/* Mode Selector Tabs */}
          <div class="flex border-b border-[#2e2e33] pb-px">
            <button 
              onClick={() => setActiveTab("text")}
              class={`px-4 py-2 text-sm font-semibold border-b-2 transition-all ${activeTab() === "text" ? "border-[#06b6d4] text-[#06b6d4]" : "border-transparent text-[#a1a1aa] hover:text-white"}`}
            >
              Text Mode (Static)
            </button>
            <button 
              onClick={() => {
                setActiveTab("interactive");
                setTuiPath([]);
                setTuiSearch("");
              }}
              class={`px-4 py-2 text-sm font-semibold border-b-2 transition-all ${activeTab() === "interactive" ? "border-[#06b6d4] text-[#06b6d4]" : "border-transparent text-[#a1a1aa] hover:text-white"}`}
            >
              Interactive Mode (TUI)
            </button>
          </div>

          {/* Simulator Box */}
          <div class="w-full bg-[#0c0c0e] border border-[#2e2e33] shadow-2xl overflow-hidden" style="border-radius: var(--radius-sharp)">
            
            {/* Header bar */}
            <div class="bg-[#141416] border-b border-[#2e2e33] px-4 py-2 flex items-center justify-between">
              <div class="flex items-center gap-1.5">
                <span class="w-3 h-3 rounded-full bg-[#ef4444]/60"></span>
                <span class="w-3 h-3 rounded-full bg-[#eab308]/60"></span>
                <span class="w-3 h-3 rounded-full bg-[#22c55e]/60"></span>
              </div>
              <span class="text-xs text-[#a1a1aa] code-font">prohelp_simulator - {activeTab() === "text" ? "text_mode" : "interactive_tui"}</span>
              <div class="w-12"></div>
            </div>

            {/* Content Window */}
            <div class="p-4 md:p-6 min-h-[360px] flex flex-col justify-start code-font text-xs md:text-sm leading-relaxed overflow-x-auto">
              
              {/* STATIC TEXT MODE */}
              <Show when={activeTab() === "text"}>
                
                {/* Simulated command */}
                <div class="mb-4 text-[#a1a1aa]">
                  Z:\code\tar-demo&gt; <span class="text-white">tar ?{activeSectionKey() !== "root" ? ":" + activeSectionKey() : ""}</span>
                </div>

                {/* Simulated Unicode Box rendering */}
                <div class="border border-[#2e2e33] bg-[#141416] p-4 text-[#f4f4f5] max-w-lg mx-auto" style="border-radius: var(--radius-sharp)">
                  
                  {/* Title / Summary */}
                  <div class="text-[#06b6d4] font-bold border-b border-[#2e2e33] pb-2 mb-2 flex items-center justify-between">
                    <span>┌─ tar {activeSectionKey() !== "root" && " > " + tarData[activeSectionKey()].title.split(" > ").slice(1).join(" > ")} </span>
                    <span class="text-[#a1a1aa] text-xs">Level {activeSectionKey() === "root" ? "0" : (tarData[activeSectionKey()].title.split(">").length - 1)}</span>
                  </div>

                  {/* Summary content */}
                  <div class="mb-3 text-zinc-300">
                    {tarData[activeSectionKey()].summary}
                    <Show when={tarData[activeSectionKey()].content}>
                      <div class="mt-2 text-[#a1a1aa] text-xs leading-normal">
                        {tarData[activeSectionKey()].content}
                      </div>
                    </Show>
                  </div>

                  {/* Subsections listed as clickable choices */}
                  <Show when={tarData[activeSectionKey()].sections}>
                    <div class="border-t border-[#2e2e33] pt-2 mt-2">
                      <div class="text-zinc-500 font-bold mb-2">Sections (Click to navigate):</div>
                      <div class="flex flex-col gap-1.5 pl-2">
                        {tarData[activeSectionKey()].sections?.map(s => (
                          <button 
                            onClick={() => setActiveSectionKey(s)} 
                            class="text-left text-[#22d3ee] hover:underline flex items-center justify-between"
                          >
                            <span> {s}</span>
                            <span class="text-xs text-[#a1a1aa]">{tarData[s].summary}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                  </Show>

                  {/* Options with dominance priorities */}
                  <Show when={tarData[activeSectionKey()].options}>
                    <div class="border-t border-[#2e2e33] pt-2 mt-2 flex flex-col gap-2">
                      <div class="text-zinc-500 font-bold">Options:</div>
                      {tarData[activeSectionKey()].options?.map(o => (
                        <div class="flex items-start justify-between pl-2">
                          <span class={o.dom === "high" ? "text-[#22d3ee] font-semibold" : "text-zinc-400"}>{o.flags}</span>
                          <span class="text-[#a1a1aa] text-right text-xs max-w-[200px]">{o.desc}</span>
                        </div>
                      ))}
                    </div>
                  </Show>

                  {/* Visual Footer Info */}
                  <div class="border-t border-[#2e2e33] pt-2 mt-3 text-[10px] text-zinc-500 flex justify-between">
                    <span>Locale: en-US</span>
                    <button 
                      onClick={() => setActiveSectionKey("root")} 
                      class="text-[#06b6d4] hover:underline"
                      disabled={activeSectionKey() === "root"}
                    >
                      [Back to Top]
                    </button>
                  </div>

                </div>

              </Show>

              {/* INTERACTIVE MODE (TUI) */}
              <Show when={activeTab() === "interactive"}>
                
                {/* TUI Mockup Viewport */}
                <div class="w-full max-w-lg mx-auto border border-[#2e2e33] bg-[#0c0c0e] text-[#f4f4f5]" style="border-radius: var(--radius-sharp)">
                  
                  {/* TUI Header */}
                  <div class="bg-[#1d1d20]/80 px-3 py-1.5 border-b border-[#2e2e33] flex items-center justify-between text-zinc-400 text-xs">
                    <span>tar {tuiPath().length > 0 && " > " + tuiPath().join(" > ")}</span>
                    <span class="text-[#06b6d4] font-bold">Level {tuiPath().length}</span>
                  </div>

                  {/* Search Bar */}
                  <div class="px-3 py-2 border-b border-[#2e2e33] flex items-center gap-2">
                    <span class="text-[#22d3ee] text-xs">Search:</span>
                    <input 
                      type="text" 
                      value={tuiSearch()} 
                      onInput={(e) => setTuiSearch(e.currentTarget.value)}
                      placeholder="Type to filter..." 
                      class="bg-transparent border-none outline-none text-[#22d3ee] w-full text-xs font-semibold" 
                    />
                    <Show when={tuiSearch().length > 0}>
                      <button onClick={() => setTuiSearch("")} class="text-zinc-500 hover:text-white text-xs">Esc</button>
                    </Show>
                  </div>

                  {/* Main List */}
                  <div class="p-3 min-h-[180px] flex flex-col gap-1.5">
                    
                    {/* Render Filtered items */}
                    {tuiFilteredItems().map((item) => (
                      <div class="flex items-center justify-between py-0.5 px-1 hover:bg-[#1d1d20] group rounded" style="border-radius: var(--radius-sharp)">
                        <div class="flex items-center gap-2">
                          <span class="text-zinc-600 text-xs font-bold w-12">
                            {item.type === "section" ? "[sec]" : "[opt]"}
                          </span>
                          
                          {/* Clicking sub-sections drills down */}
                          <Show when={item.type === "section"} fallback={<span class="text-yellow-400 font-medium text-xs">{item.name}</span>}>
                            <button 
                              onClick={() => {
                                setTuiPath([...tuiPath(), item.name]);
                                setTuiSearch("");
                              }}
                              class="text-left text-[#06b6d4] font-bold hover:underline text-xs"
                            >
                              {item.name}
                            </button>
                          </Show>
                        </div>
                        <span class="text-zinc-500 text-xs truncate max-w-[200px]">{item.summary}</span>
                      </div>
                    ))}

                    <Show when={tuiFilteredItems().length === 0}>
                      <div class="text-center text-zinc-600 my-auto">No options match your query</div>
                    </Show>

                  </div>

                  {/* Navigation footer */}
                  <div class="bg-[#1d1d20]/80 px-3 py-1.5 border-t border-[#2e2e33] flex items-center justify-between text-[10px] text-zinc-500">
                    <div class="flex gap-2">
                      <button 
                        onClick={() => {
                          const p = [...tuiPath()];
                          p.pop();
                          setTuiPath(p);
                          setTuiSearch("");
                        }}
                        disabled={tuiPath().length === 0}
                        class="text-[#22d3ee] disabled:text-zinc-600"
                      >
                        [Esc] Back
                      </button>
                      <button onClick={() => { setTuiPath([]); setTuiSearch(""); }} class="text-[#22d3ee]">[Top]</button>
                    </div>
                    <span>[Shift] Select  [Ctrl+C] Copy</span>
                  </div>

                </div>

              </Show>

            </div>

            {/* Footer simulator note */}
            <div class="bg-[#141416] border-t border-[#2e2e33] px-4 py-2 text-[10px] text-zinc-500 text-center">
              {activeTab() === "text" 
                ? "Static Progressive Help: Pipable, lightweight, budgeted layout" 
                : "Full-Screen Console Viewport: Real-time search, drilling, cell copy"}
            </div>

          </div>

        </div>

      </main>

      {/* Feature asymmetric panels */}
      <section id="features" class="w-full max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6 mb-16">
        
        {/* Panel 1 */}
        <div class="md:col-span-2 p-6 bg-[#141416] border border-[#2e2e33] flex flex-col gap-3" style="border-radius: var(--radius-sharp)">
          <div class="text-[#06b6d4] font-bold text-xs uppercase tracking-widest">Architectural Budgeting</div>
          <h3 class="text-lg font-bold text-white">Strict Sliding-Scale Line Budgets</h3>
          <p class="text-sm text-[#a1a1aa] leading-relaxed">
            Stop creating help pages that require scrollbars. Prohelp enforces budgets at build time: Level 0 commands are strictly capped at 20 lines to ensure a single, scrolling-free terminal landing page. Budgets slide cleanly to 40 and 60 lines as users drill down.
          </p>
        </div>

        {/* Panel 2 */}
        <div class="p-6 bg-[#141416] border border-[#2e2e33] flex flex-col gap-3" style="border-radius: var(--radius-sharp)">
          <div class="text-[#06b6d4] font-bold text-xs uppercase tracking-widest">Pipe Friendly</div>
          <h3 class="text-lg font-bold text-white">Unicode Box Zoning</h3>
          <p class="text-sm text-[#a1a1aa] leading-relaxed">
            Beautiful visual panels utilizing standard Unicode box-drawing glyphes printed line-by-line. They remain 100% compatible with Unix pipes (`|`), redirections (`&gt;`), and standard log dumps.
          </p>
        </div>

        {/* Panel 3 */}
        <div class="p-6 bg-[#141416] border border-[#2e2e33] flex flex-col gap-3" style="border-radius: var(--radius-sharp)">
          <div class="text-[#06b6d4] font-bold text-xs uppercase tracking-widest">Developer Integration</div>
          <h3 class="text-lg font-bold text-white">1-Line Interceptor Hook</h3>
          <p class="text-sm text-[#a1a1aa] leading-relaxed">
            Drop Prohelp directly at the very top of your `main` entry function. The library filters command-line arguments on the first pass, exiting after displaying help and keeping your normal argument parsing code completely untouched.
          </p>
        </div>

        {/* Panel 4 */}
        <div class="md:col-span-2 p-6 bg-[#141416] border border-[#2e2e33] flex flex-col gap-3" style="border-radius: var(--radius-sharp)">
          <div class="text-[#06b6d4] font-bold text-xs uppercase tracking-widest">Subtree Extraction</div>
          <h3 class="text-lg font-bold text-white">Hierarchical Wildcard Globbing</h3>
          <p class="text-sm text-[#a1a1aa] leading-relaxed">
            AI agents, search engines, and DevOps scripts can append `*` wildcards to paths (e.g. `tar ? operations *`) to dump only specific sections, saving thousands of tokens and removing manual text clutter.
          </p>
        </div>

      </section>

      {/* Code Integration Block */}
      <section class="w-full max-w-6xl mx-auto border border-[#2e2e33] bg-[#0c0c0e] p-6 mb-16" style="border-radius: var(--radius-sharp)">
        <h3 class="text-lg font-bold text-white mb-4 code-font">// 1-Line Drop-In Integration (Dlang)</h3>
        <pre class="bg-[#141416] p-4 text-xs md:text-sm text-zinc-300 overflow-x-auto code-font border border-[#2e2e33] leading-relaxed" style="border-radius: var(--radius-sharp)">
<span class="text-zinc-500">import</span> prohelp;

<span class="text-zinc-500">void</span> <span class="text-[#06b6d4]">main</span>(string[] args) &#123;
    <span class="text-zinc-500">if</span> (prohelp.<span class="text-[#22d3ee]">intercept</span>(args)) <span class="text-zinc-500">return</span>; <span class="text-zinc-500">// Intercepts and exits if help or ? is queried</span>

    <span class="text-zinc-400">// Normal command logic and argument parsing continues here...</span>
&#125;
        </pre>
      </section>

      {/* Footer */}
      <footer class="w-full max-w-6xl mx-auto border-t border-[#2e2e33]/60 pt-6 mt-auto flex flex-col sm:flex-row items-center justify-between text-xs text-[#a1a1aa] gap-4">
        <span>© {new Date().getFullYear()} dev-centr. Dedicated to pixel-perfect console interactions.</span>
        <div class="flex gap-4">
          <a href="https://github.com/openshellorg/prohelp/blob/main/LICENSE" class="hover:text-white transition-colors">GPL-3.0</a>
          <span>·</span>
          <a href="https://github.com/dev-centr/devcentr/blob/main/docs/modules/specifications/pages/prohelp.adoc" class="hover:text-white transition-colors">Specification</a>
        </div>
      </footer>

    </div>
  );
}
