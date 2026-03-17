# NeuralJack

```
  ███╗   ██╗███████╗██╗   ██╗██████╗  █████╗ ██╗     
  ████╗  ██║██╔════╝██║   ██║██╔══██╗██╔══██╗██║     
  ██╔██╗ ██║█████╗  ██║   ██║██████╔╝███████║██║     
  ██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██╔══██║██║     
  ██║ ╚████║███████╗╚██████╔╝██║  ██║██║  ██║███████╗
  ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
                         ██╗ █████╗  ██████╗██╗  ██╗
                         ██║██╔══██╗██╔════╝██║ ██╔╝
                         ██║███████║██║     █████╔╝ 
                    ██   ██║██╔══██║██║     ██╔═██╗ 
                    ███████║██║  ██║╚██████╗██║  ██╗
                    ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

   ChatGPT → Claude migration assistant for Mac
```

**NeuralJack** turns your ChatGPT export into everything you need to move to Claude. Drop your OpenAI data ZIP into the app, pick your options, and get a **Memory Core**, organized conversation exports, and step-by-step import prompts—so you don’t leave your history or context behind.

---

## What it does

- **Parses the official OpenAI export** — Uses the ZIP you get from ChatGPT (Settings → Data Controls → Export data). No scraping, no third-party APIs.
- **Builds a Memory Core** — A single, structured context document (facts, preferences, skills, style) that you can paste into Claude (e.g. **Claude → Settings → Capabilities → “Import memory from other AI providers”**). Generate it with your Anthropic API key, or get a prompt file to run in Claude Cowork.
- **Exports conversations by project** — Markdown per conversation, grouped by ChatGPT project, in a folder layout that’s easy to use in Claude.
- **Guides you into Claude** — Prompts and instructions for Cowork or manual import so you know exactly what to paste and where.

---

## Quick start

1. **Export your ChatGPT data**  
   ChatGPT → Settings → Data Controls → **Export data** → download the ZIP.

2. **Open NeuralJack**  
   Drag the ZIP onto the app (or onto the window) and follow the wizard.

3. **Choose your path**
   - **Your Data** — Pick an output folder and whether you want a Memory Core and export log.
   - **Memory Core Setup** — Use an API key to generate the Memory Core in the app, or get a **memory-core-cowork-prompt.md** to run in Claude Cowork.
   - **Select Projects** — Choose which projects to export; the Memory Core (or prompt) uses only these.
   - **Export** — Projects and (optionally) uncategorized conversations are written to your output folder.

4. **Use the output**
   - **memory-core.md** or **memory-core-cowork-prompt.md** — For Claude memory import (Settings → Capabilities).
   - **claude-cowork-import-prompt.md** / **claude-import-manual-prompt.md** — For bringing projects and conversations into Claude.

---

## Requirements

- **macOS 13+** (Ventura or later)
- **Anthropic API key** — Optional for Memory Core *generation*; if you skip it, you get the Cowork prompt file instead. Required for in-app synthesis (stored in Keychain).

---

## Output layout

```
Your chosen folder/
└── NeuralJack-Export [timestamp]/
    ├── memory-core.md              # Context for Claude (if generated via API)
    ├── memory-core-cowork-prompt.md # Prompt for Claude Cowork (if no API key)
    ├── claude-cowork-import-prompt.md
    ├── claude-import-manual-prompt.md
    └── projects/
        ├── ProjectName/
        │   ├── _project-instructions.md
        │   ├── _project-metadata.json
        │   └── … conversation .md files
        └── …
```

---

## Build from source

```bash
git clone https://github.com/kidhack/neuraljack.git
cd neuraljack
open NeuralJack.xcodeproj
```

Build and run in Xcode (⌘R). No extra dependencies beyond the Swift packages in the project.

---

## License & support

- **License** — See [LICENSE](LICENSE) in this repo.
- **Sponsor** — [GitHub Sponsors](https://github.com/sponsors/kidhack) — appreciated if NeuralJack helps you switch to Claude.

---

*NeuralJack — bridge your ChatGPT history into Claude.*
