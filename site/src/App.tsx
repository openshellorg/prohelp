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
    <div class="app-container">
      
      {/* Header */}
      <header class="header animate-fade-in" style="animation-delay: 0.1s">
        <div class="brand-logo">
          <svg class="w-6 h-6" style="width: 24px; height: 24px; color: var(--accent-teal);" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 8.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25A2.25 2.25 0 0 1 13.5 18v-2.25Z" />
          </svg>
          <span class="brand-text code-font">PROHELP</span>
        </div>
        <nav class="nav-links">
          <a href="https://github.com/dev-centr/devcentr/blob/main/docs/modules/specifications/pages/prohelp.adoc" target="_blank" class="nav-link">Specifications</a>
          <a href="https://github.com/openshellorg/prohelp" target="_blank" class="nav-link">
            GitHub
            <svg style="width: 16px; height: 16px;" fill="currentColor" viewBox="0 0 24 24"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
          </a>
        </nav>
      </header>

      {/* Hero Section */}
      <main class="hero-grid flex-grow">
        
        <div class="hero-content animate-fade-in" style="animation-delay: 0.2s">
          <h1 class="hero-title">
            Progressive & Professional <br/>
            <span class="gradient-teal">Command-Line Help</span>
          </h1>
          <p class="hero-description">
            Cognitive-budgeted CLI navigation, 24-bit TrueColor boxed panels, and zero-dependency terminal browsers. A drop-in replacement that looks and feels like the future.
          </p>

          {/* Action Row */}
          <div class="action-row">
            <a href="https://github.com/dev-centr/devcentr/blob/main/docs/modules/specifications/pages/prohelp.adoc" target="_blank" class="cta-button">
              Explore Specifications
            </a>
            
            {/* Pipable code copy */}
            <button onClick={copyInstallCmd} class="copy-button code-font">
              <span class="text-teal">dub add prohelp</span>
              <span class="text-gray-sm">{copiedText() || "Copy"}</span>
            </button>
          </div>
        </div>

        {/* Dynamic Simulator Section */}
        <div class="simulator-container animate-fade-in" style="animation-delay: 0.3s">
          
          {/* Mode Selector Tabs */}
          <div class="tab-row">
            <button 
              onClick={() => setActiveTab("text")}
              class={`tab-button ${activeTab() === "text" ? "active" : ""}`}
            >
              Text Mode (Static)
            </button>
            <button 
              onClick={() => {
                setActiveTab("interactive");
                setTuiPath([]);
                setTuiSearch("");
              }}
              class={`tab-button ${activeTab() === "interactive" ? "active" : ""}`}
            >
              Interactive Mode (TUI)
            </button>
          </div>

          {/* Simulator Box */}
          <div class="terminal-window">
            
            {/* Header bar */}
            <div class="terminal-header">
              <div class="window-dots">
                <span class="dot dot-red"></span>
                <span class="dot dot-yellow"></span>
                <span class="dot dot-green"></span>
              </div>
              <span class="terminal-title code-font">prohelp_simulator - {activeTab() === "text" ? "text_mode" : "interactive_tui"}</span>
              <div style="width: 48px;"></div>
            </div>

            {/* Content Window */}
            <div class="terminal-viewport code-font">
              
              {/* STATIC TEXT MODE */}
              <Show when={activeTab() === "text"}>
                
                {/* Simulated command */}
                <div class="viewport-note">
                  Z:\code\tar-demo&gt; <span class="viewport-text-white">tar ?{activeSectionKey() !== "root" ? ":" + activeSectionKey() : ""}</span>
                </div>

                {/* Simulated Unicode Box rendering */}
                <div class="unicode-panel">
                  
                  {/* Title / Summary */}
                  <div class="panel-header">
                    <span>┌─ tar {activeSectionKey() !== "root" && " > " + tarData[activeSectionKey()].title.split(" > ").slice(1).join(" > ")} </span>
                    <span class="panel-level">Level {activeSectionKey() === "root" ? "0" : (tarData[activeSectionKey()].title.split(">").length - 1)}</span>
                  </div>

                  {/* Summary content */}
                  <div class="panel-body">
                    {tarData[activeSectionKey()].summary}
                    <Show when={tarData[activeSectionKey()].content}>
                      <div class="panel-detail">
                        {tarData[activeSectionKey()].content}
                      </div>
                    </Show>
                  </div>

                  {/* Subsections listed as clickable choices */}
                  <Show when={tarData[activeSectionKey()].sections}>
                    <div style="border-top: 1px solid var(--border-stone); padding-top: 0.5rem; margin-top: 0.5rem;">
                      <div class="panel-section-title">Sections (Click to navigate):</div>
                      <div class="panel-list">
                        {tarData[activeSectionKey()].sections?.map(s => (
                          <button 
                            onClick={() => setActiveSectionKey(s)} 
                            class="panel-button"
                          >
                            <span> {s}</span>
                            <span class="panel-button-desc">{tarData[s].summary}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                  </Show>

                  {/* Options with dominance priorities */}
                  <Show when={tarData[activeSectionKey()].options}>
                    <div style="border-top: 1px solid var(--border-stone); padding-top: 0.5rem; margin-top: 0.5rem; display: flex; flex-direction: column; gap: 0.5rem;">
                      <div class="panel-section-title">Options:</div>
                      {tarData[activeSectionKey()].options?.map(o => (
                        <div class="panel-option-row">
                          <span class={o.dom === "high" ? "option-flag-high" : "option-flag-normal"}>{o.flags}</span>
                          <span class="option-desc">{o.desc}</span>
                        </div>
                      ))}
                    </div>
                  </Show>

                  {/* Visual Footer Info */}
                  <div class="panel-footer">
                    <span>Locale: en-US</span>
                    <button 
                      onClick={() => setActiveSectionKey("root")} 
                      class="panel-back-btn"
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
                <div class="tui-panel">
                  
                  {/* TUI Header */}
                  <div class="tui-header">
                    <span>tar {tuiPath().length > 0 && " > " + tuiPath().join(" > ")}</span>
                    <span class="tui-level">Level {tuiPath().length}</span>
                  </div>

                  {/* Search Bar */}
                  <div class="tui-search-bar">
                    <span class="tui-search-label">Search:</span>
                    <input 
                      type="text" 
                      value={tuiSearch()} 
                      onInput={(e) => setTuiSearch(e.currentTarget.value)}
                      placeholder="Type to filter..." 
                      class="tui-search-input" 
                    />
                    <Show when={tuiSearch().length > 0}>
                      <button onClick={() => setTuiSearch("")} class="tui-clear-btn">Esc</button>
                    </Show>
                  </div>

                  {/* Main List */}
                  <div class="tui-body">
                    
                    {/* Render Filtered items */}
                    {tuiFilteredItems().map((item) => (
                      <div class="tui-row">
                        <div class="tui-row-left">
                          <span class="tui-type-badge">
                            {item.type === "section" ? "[sec]" : "[opt]"}
                          </span>
                          
                          {/* Clicking sub-sections drills down */}
                          <Show when={item.type === "section"} fallback={<span class="tui-item-flag">{item.name}</span>}>
                            <button 
                              onClick={() => {
                                setTuiPath([...tuiPath(), item.name]);
                                setTuiSearch("");
                              }}
                              class="tui-item-btn"
                            >
                              {item.name}
                            </button>
                          </Show>
                        </div>
                        <span class="tui-item-summary">{item.summary}</span>
                      </div>
                    ))}

                    <Show when={tuiFilteredItems().length === 0}>
                      <div class="tui-empty">No options match your query</div>
                    </Show>

                  </div>

                  {/* Navigation footer */}
                  <div class="tui-footer">
                    <div class="tui-footer-btns">
                      <button 
                        onClick={() => {
                          const p = [...tuiPath()];
                          p.pop();
                          setTuiPath(p);
                          setTuiSearch("");
                        }}
                        disabled={tuiPath().length === 0}
                        class="tui-footer-btn"
                      >
                        [Esc] Back
                      </button>
                      <button onClick={() => { setTuiPath([]); setTuiSearch(""); }} class="tui-footer-btn">[Top]</button>
                    </div>
                    <span>[Shift] Select  [Ctrl+C] Copy</span>
                  </div>

                </div>

              </Show>

            </div>

            {/* Footer simulator note */}
            <div class="terminal-status-bar">
              {activeTab() === "text" 
                ? "Static Progressive Help: Pipable, lightweight, budgeted layout" 
                : "Full-Screen Console Viewport: Real-time search, drilling, cell copy"}
            </div>

          </div>

        </div>

      </main>

      {/* Feature asymmetric panels */}
      <section id="features" class="feature-section">
        
        {/* Panel 1 */}
        <div class="feature-card span-2">
          <div class="feature-tag">Architectural Budgeting</div>
          <h3>Strict Sliding-Scale Line Budgets</h3>
          <p>
            Stop creating help pages that require scrollbars. Prohelp enforces budgets at build time: Level 0 commands are strictly capped at 20 lines to ensure a single, scrolling-free terminal landing page. Budgets slide cleanly to 40 and 60 lines as users drill down.
          </p>
        </div>

        {/* Panel 2 */}
        <div class="feature-card">
          <div class="feature-tag">Pipe Friendly</div>
          <h3>Unicode Box Zoning</h3>
          <p>
            Beautiful visual panels utilizing standard Unicode box-drawing glyphs printed line-by-line. They remain 100% compatible with Unix pipes (`|`), redirections (`&gt;`), and standard log dumps.
          </p>
        </div>

        {/* Panel 3 */}
        <div class="feature-card">
          <div class="feature-tag">Developer Integration</div>
          <h3>1-Line Interceptor Hook</h3>
          <p>
            Drop Prohelp directly at the very top of your `main` entry function. The library filters command-line arguments on the first pass, exiting after displaying help and keeping your normal argument parsing code completely untouched.
          </p>
        </div>

        {/* Panel 4 */}
        <div class="feature-card span-2">
          <div class="feature-tag">Subtree Extraction</div>
          <h3>Hierarchical Wildcard Globbing</h3>
          <p>
            AI agents, search engines, and DevOps scripts can append `*` wildcards to paths (e.g. `tar ? operations *`) to dump only specific sections, saving thousands of tokens and removing manual text clutter.
          </p>
        </div>

      </section>

      {/* Code Integration Block */}
      <section class="code-section">
        <h3 class="code-title code-font">// 1-Line Drop-In Integration (Dlang)</h3>
        <pre class="code-block code-font">
<span class="code-keyword">import</span> prohelp;

<span class="code-keyword">void</span> <span class="text-teal">main</span>(string[] args) &#123;
    <span class="code-keyword">if</span> (prohelp.<span class="text-teal">intercept</span>(args)) <span class="code-keyword">return</span>; <span class="code-keyword">// Intercepts and exits if help or ? is queried</span>

    <span class="code-keyword">// Normal command logic and argument parsing continues here...</span>
&#125;
        </pre>
      </section>

      {/* Footer */}
      <footer class="footer">
        <span>© {new Date().getFullYear()} dev-centr. Dedicated to pixel-perfect console interactions.</span>
        <div class="footer-links">
          <a href="https://github.com/openshellorg/prohelp/blob/main/LICENSE" class="footer-link">PCDL-1.0 License</a>
          <span>·</span>
          <a href="https://github.com/dev-centr/devcentr/blob/main/docs/modules/specifications/pages/prohelp.adoc" class="footer-link">Specifications Spec</a>
        </div>
      </footer>

    </div>
  );
}
