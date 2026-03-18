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

- **Parses ChatGPT exports** — Uses your official export ZIP (Settings → Data Controls → Export). No scraping or third-party APIs.
- **Builds a Memory Core** — A structured context document to paste into Claude (Settings → Capabilities → Import memory). Generate via API key in-app, or get a Cowork prompt file.
- **Exports by project** — Markdown per conversation, grouped by ChatGPT project, ready for Claude.
- **Guides you in** — Step-by-step prompts for Cowork or manual import.

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

- **macOS 15+** (Sequoia or later)
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

## Installation

Get `NeuralJack.dmg` from the [latest release](https://github.com/kidhack/neuraljack/releases/latest). Open the DMG and drag NeuralJack.app to Applications.

## Version history

- **[Download latest build](https://github.com/kidhack/neuraljack/releases/latest)** — Newest version with pre-built DMG
- **[All releases](https://github.com/kidhack/neuraljack/releases)** — Full version history and older builds

---

## Build from source

```bash
git clone https://github.com/kidhack/neuraljack.git
cd neuraljack
open NeuralJack.xcodeproj
```

Build and run in Xcode (⌘R). No extra dependencies beyond the Swift packages in the project.

---

## Releasing

To create a distributable DMG for a new version:

```bash
./scripts/package-release.sh 1.0
```

This builds the app (Release config) and creates `dist/NeuralJack-1.0.dmg`. For the classic drag-to-install layout (app icon, arrow, Applications folder), install [create-dmg](https://github.com/create-dmg/create-dmg) first:

```bash
brew install create-dmg
```

Then:

1. Create a [GitHub Release](https://github.com/kidhack/neuraljack/releases/new) with tag `v1.0` (or matching version)
2. Upload the DMG as a release asset
3. Add release notes

Requires full Xcode (not just Command Line Tools). For signed/notarized distribution, use Xcode’s Archive → Distribute App flow or add signing steps to the script.

---

## License & support

- **License** — See [LICENSE](LICENSE) in this repo.
- **Sponsor** — [GitHub Sponsors](https://github.com/sponsors/kidhack) — appreciated if NeuralJack helps you switch to Claude.

---

*NeuralJack — bridge your ChatGPT history into Claude.*
