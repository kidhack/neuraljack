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

- **Parses ChatGPT data** — Cleans OpenAI data export for migration to Claude.
- **Builds a Memory Core** — Context document to paste into Claude.
- **Exports by project** — Markdown per conversation, grouped by ChatGPT project, ready for Claude.
- **Creates prompted guides** — Step-by-step migration prompts for Cowork or manual import.

---

## Quick start

1. **Export your ChatGPT data**  
   - ChatGPT → Settings → [Data Controls](https://chatgpt.com/#settings/DataControls) → **Export data** → download the ZIP.

2. **Open NeuralJack**  
    - Import the data ZIP or extracted folder.

3. **Customize Your Migration Path**
   - **Parse Your Data** — Pick an output folder.
   - **Select Projects** — Choose which projects to export; the Memory Core (or prompt) uses only these.
   - **Memory Core** — Optionally use Claude API to generate a Memory Core or export a prompt to run in Claude Cowork.
   - **Export** — Projects, conversations, and prompts are written to your output folder.

4. **Use the output**
   - Conversations sorted by project to import to Claude.
   - Prompt files to guide you and Claude to migrate data.


---

## Installation

Download the latest release of [NeuralJack.dmg](https://github.com/kidhack/neuraljack/releases/download/v1.0/NeuralJack-1.0.dmg). Open the DMG and drag NeuralJack.app to Applications.

## Version history

- **[Download latest build](https://github.com/kidhack/neuraljack/releases/latest)** — Newest version with pre-built DMG
- **[All releases](https://github.com/kidhack/neuraljack/releases)** — Full version history and older builds

---

## Requirements

- **macOS 15+** (Sequoia or later)
- **Anthropic API key** — Optional for Memory Core generation.

---

## Output architecture

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
