# NeuralJack 1.0

**ChatGPT → Claude migration assistant for Mac**

NeuralJack turns your ChatGPT export into everything you need to move to Claude. Drop your OpenAI data ZIP into the app, pick your options, and get a **Memory Core**, organized conversation exports, and step-by-step import prompts—so you don't leave your history or context behind.

---

## What's in this release

- **Parse official ChatGPT exports** — Uses the ZIP from ChatGPT (Settings → Data Controls → Export data). No scraping, no third-party APIs.
- **Build a Memory Core** — A single, structured context document you can paste into Claude (Settings → Capabilities → Import memory). Generate it with your Anthropic API key, or get a prompt file to run in Claude Cowork.
- **Export conversations by project** — Markdown per conversation, grouped by ChatGPT project, in a folder layout ready for Claude.
- **Guided migration** — Prompts and instructions for Cowork or manual import so you know exactly what to paste and where.

---

## Getting started

1. **Export from ChatGPT** — Settings → Data Controls → **Export data** → download the ZIP.
2. **Open NeuralJack** — Drag the ZIP onto the app or window and follow the wizard.
3. **Choose your path** — Pick an output folder, configure Memory Core (API key or Cowork prompt), select projects, and export.
4. **Import into Claude** — Use the generated `memory-core.md` and project folders in Claude.

---

## Requirements

- **macOS 15+** (Sequoia or later)
- **Anthropic API key** — Optional for Memory Core generation; if skipped, you get a Cowork prompt file instead. Required for in-app synthesis (stored in Keychain).

---

## Download

- **NeuralJack-1.0.dmg** — Drag NeuralJack.app to Applications to install.

---

*NeuralJack — bridge your ChatGPT history into Claude.*
