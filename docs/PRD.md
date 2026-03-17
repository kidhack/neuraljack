# NeuralJack — Product Requirements Document

**Version:** 1.0  
**Platform:** macOS 13+ (Ventura)  
**Status:** Pre-development

---

## 1. Problem Statement

ChatGPT users who want to switch to Claude face a painful migration: months or years of conversations, custom GPT configurations, and "ChatGPT memory" have no migration path. There is no export tool, no import API on Claude's side, and no way to reconstruct context. Users either abandon their history or maintain two AI subscriptions indefinitely.

NeuralJack solves this by:
1. Parsing the official OpenAI data export
2. Synthesizing a **Memory Core** — a structured context file Claude can use as Project Instructions
3. Exporting conversations and project configs in Claude-compatible formats

---

## 2. Users

**Primary:** Power ChatGPT users (Pro/Plus subscribers) switching to or adding Claude.  
**Secondary:** Developers evaluating LLM switching costs.  
**Tertiary:** Teams migrating shared prompt libraries.

**User is assumed to:**
- Be comfortable with macOS
- Have or be willing to get an Anthropic API key
- Understand what ChatGPT memory / custom instructions are

---

## 3. User Stories

### Core (Must-Have — v1.0)

| ID | Story | Acceptance Criteria |
|---|---|---|
| US-01 | As a user, I can drag my OpenAI `.zip` onto the NeuralJack icon or window to start import | App opens, ZIP is validated, summary is shown within 5 seconds |
| US-02 | As a user, I can see a summary of what's in my export before committing to migration | Show: conversation count, date range, project count, memory entry count |
| US-03 | As a user, I can generate a Memory Core from my ChatGPT history | Claude API synthesizes a `memory-core.md` I can paste into Claude Project Instructions |
| US-04 | As a user, I can export all my conversations as organized Markdown files | One `.md` per conversation, organized in folders by month |
| US-05 | As a user, I can securely save my Anthropic API key in the app | Key stored in macOS Keychain, never in plain text |
| US-06 | As a user, I can see migration progress in real time | Progress bar + current operation label during all async steps |
| US-07 | As a user, I can copy my Memory Core to the clipboard in one click | "Copy to Clipboard" button on Memory Core view |
| US-08 | As a user, I can preview individual conversations before export | Sidebar list → detail view with rendered message bubbles |
| US-09 | As a user, the app tells me what to do next after migration completes | "Next Steps" panel with links to Claude Projects onboarding |

### Enhanced (Should-Have — v1.0)

| ID | Story | Acceptance Criteria |
|---|---|---|
| US-10 | As a user, I can select/deselect which conversations to include in Memory Core synthesis | Checkbox on each conversation in the list |
| US-11 | As a user, ChatGPT Projects / Custom GPTs are converted to Claude Project templates | Each converted project exported as a `.md` with system prompt + description |
| US-12 | As a user, ChatGPT Memory entries are included in Memory Core generation | `memory.json` content is part of synthesis input |
| US-13 | As a user, I can re-run Memory Core synthesis without re-importing | "Regenerate Memory Core" button persists the last parsed import state |
| US-14 | As a user, NeuralJack guides me step-by-step to create each Claude Project and upload the right files | Floating HUD panel walks me through claude.ai UI, one project at a time |
| US-15 | As a user, the guided import tells me exactly what to paste and what to drag | HUD shows pre-copied text and a visual indicator for which files to drag |
| US-16 | As a user, I can mark each guided step complete and move to the next | "Done" / "Next Step →" buttons advance the HUD; completed steps show a checkmark |
| US-17 | As a user, I can skip the guided import and do it myself later | "Skip for now" exits the HUD; project packages remain on disk |

### Future (Nice-to-Have — v2.0)

| ID | Story |
|---|---|
| US-14 | Search and filter conversations before export |
| US-15 | Multiple export format options (Markdown, JSON, plain text) |
| US-16 | Side-by-side diff view: ChatGPT Memory vs. generated Memory Core |
| US-17 | Scheduled re-synthesis as new ChatGPT exports are downloaded |

---

## 4. Functional Requirements

### 4.1 ZIP Import

- **FR-01:** App accepts `.zip` via drag-and-drop on app icon (Dock) and on the main window drop zone
- **FR-02:** App validates the ZIP contains `conversations.json` before proceeding; shows `AppError.missingConversationsJSON` if absent
- **FR-03:** ZIP file size limit: 500MB. Files larger than 500MB show a warning but still attempt parse
- **FR-04:** Parser must handle `conversations.json` files with 10,000+ conversations without hanging the UI (async parsing on background actor)
- **FR-05:** If a ZIP was previously imported in the same session, prompt user to confirm before overwriting

### 4.2 Conversation Parsing

- **FR-06:** Parse all conversations with: `id`, `title`, `create_time`, `update_time`, message array
- **FR-07:** For each message, capture: `role` (user/assistant/system/tool), `content` (text), `create_time`
- **FR-08:** Conversations with zero user messages are excluded from Memory Core synthesis (but still exported)
- **FR-09:** Tool call messages (code interpreter, browser, DALL-E) are stripped from synthesis input but preserved in export

### 4.3 Memory Core Synthesis

- **FR-10:** Memory Core synthesis uses the Anthropic Messages API with `claude-opus-4-5`
- **FR-11:** Conversations are batched in groups of 20 per API call
- **FR-12:** Each batch extracts: facts about the user, skills, preferences, recurring topics, communication style
- **FR-13:** A final synthesis pass combines batch outputs into a single structured Memory Core
- **FR-14:** Memory Core is formatted as Markdown with these sections: `# About Me`, `## Professional Context`, `## Knowledge & Skills`, `## Preferences & Style`, `## Recurring Topics`, `## Context Notes`
- **FR-15:** Synthesis can be cancelled at any time; partial results are discarded
- **FR-16:** After synthesis, Memory Core is displayed in a scrollable preview with syntax highlighting

### 4.4 Project Migration & Packaging

- **FR-17:** Detect ChatGPT "projects" from conversations that share a non-default project ID in the export
- **FR-18:** For each detected project, create a Claude Project Package — a local folder containing:
  - `project-instructions.md` — the synthesized system prompt (ready to paste into Claude Project Instructions)
  - `memory-core.md` — the Memory Core (ready to upload as a knowledge file)
  - `conversations/` — all conversation `.md` files for this project (ready to bulk-upload)
  - `IMPORT_GUIDE.txt` — human-readable instructions for manual import
- **FR-19:** If no projects are detected, treat all conversations as belonging to one default "General" package
- **FR-20:** Package folder names are sanitized for the filesystem (no special chars, max 60 chars)

### 4.5 Guided Claude Import (HUD Flow)

- **FR-21:** After migration completes, a "Import into Claude →" button launches the Guided Import HUD
- **FR-22:** The HUD is an `NSPanel` floating window (`NSWindowStyleMask.nonactivatingPanel`) that stays above browser windows without stealing focus
- **FR-23:** HUD dimensions: 340pt wide × variable height, anchored to the right edge of the screen, vertically centered
- **FR-24:** On HUD launch, NeuralJack opens `https://claude.ai/projects` in the user's default browser via `NSWorkspace.shared.open(_:)`
- **FR-25:** The HUD guides the user through **one project at a time**, with a project switcher at the top (e.g. "Project 2 of 3")
- **FR-26:** For each project, the HUD presents these steps in sequence:

  | Step | Instruction | Auto-action |
  |---|---|---|
  | 1 | "Click **New Project** in the sidebar" | None — user clicks |
  | 2 | "Name this project: [project name]" | Auto-copies project name to clipboard |
  | 3 | "Paste the name, then click **Create project**" | None |
  | 4 | "Click **Add content** in the project knowledge panel" | None |
  | 5 | "Drag these files into the upload area:" + file list | Auto-reveals package folder in Finder via `NSWorkspace.shared.selectFile` |
  | 6 | "Click **Project Instructions** (the pencil icon)" | None |
  | 7 | "Paste the instructions below:" + inline preview | Auto-copies `project-instructions.md` content to clipboard |
  | 8 | "Click **Save**" | None |

- **FR-27:** Each step has a **"Done →"** button the user taps to advance; no automatic DOM detection
- **FR-28:** A **"Skip this project"** button skips to the next project; a **"Skip all"** button exits the HUD
- **FR-29:** Completed projects are marked with a checkmark in the project switcher and persisted in `UserDefaults` so the HUD can resume if closed and reopened
- **FR-30:** The HUD includes a persistent footer: *"NeuralJack is not affiliated with Anthropic. It cannot automate claude.ai — only guide you."*

### 4.6 Conversation Export

- **FR-31:** Export all conversations to a user-selected output folder
- **FR-32:** File structure mirrors the project packaging: `[OutputFolder]/NeuralJack-Export/[ProjectName]/conversations/[conversation-title].md`
- **FR-33:** Each `.md` file includes: title as H1, conversation date, message bubbles in format `**You:**` / `**Assistant:**`
- **FR-34:** Export completes in under 30 seconds for up to 5,000 conversations on modern hardware

### 4.7 API Key Management

- **FR-35:** Anthropic API key stored exclusively in Keychain under service `com.neuraljack.anthropic-api-key`
- **FR-36:** Key is validated on save by making a minimal API call (`max_tokens: 1`)
- **FR-37:** If key validation fails, show specific error (invalid key vs. network error)
- **FR-38:** User can update or delete the saved key from Preferences

---

## 5. Non-Functional Requirements

| Category | Requirement |
|---|---|
| **Performance** | ZIP parsing < 5s for files up to 100MB on M1 Mac |
| **Performance** | UI remains responsive (60fps) during all background operations |
| **Privacy** | Zero telemetry, zero analytics, zero crash reporting to external servers |
| **Privacy** | No user data stored beyond the current session (except API key in Keychain) |
| **Reliability** | App must not crash on malformed or partial OpenAI export ZIPs |
| **Accessibility** | Full VoiceOver support for all interactive elements |
| **Accessibility** | Minimum contrast ratios per WCAG AA |
| **Distribution** | App signed and notarized for Gatekeeper compatibility; direct download DMG (no App Store in v1) |

---

## 6. User Flows

### Primary Flow: First-Time Migration

```
1. User launches NeuralJack for the first time
2. App shows Welcome screen + API key prompt
3. User enters Anthropic API key → validated → saved to Keychain
4. App shows main window with drop zone
5. User drags OpenAI .zip onto drop zone
6. Progress bar: "Parsing export..." (2-5 seconds)
7. ImportSummaryView: "Found 847 conversations · 3 projects · 42 memory entries"
8. User reviews, selects all (default), clicks "Start Migration"
9. Split progress view:
   □ [✓] Parsing conversations   
   □ [▶] Generating Memory Core... (42%)  
   □ [ ] Packaging project files  
   □ [ ] Exporting conversations  
10. Migration completes
11. Results screen: Memory Core preview + project packages summary
12. User clicks "Import into Claude →" → Guided Import HUD launches
```

### Secondary Flow: API Key Not Present

```
At step 8, user clicks "Start Migration"
→ Preferences sheet slides in automatically
→ "Anthropic API key required for Memory Core generation"
→ User enters key → validated
→ Sheet dismisses → migration continues
```

### Error Flow: Invalid ZIP

```
User drops a non-OpenAI zip
→ Brief shake animation on drop zone
→ Error banner: "This doesn't look like an OpenAI export. Make sure you're using the file from ChatGPT Settings → Data Controls → Export Data."
→ Drop zone resets
```

### Guided Import Flow (Post-Migration)

```
Results screen → User clicks "Import into Claude →"
→ HUD appears, anchored right side of screen
→ NSWorkspace opens https://claude.ai/projects in default browser
→ HUD shows: "Project 1 of 3 — [Project Name]"

  Step 1: "Click New Project in the sidebar"
          [Done →]

  Step 2: "[Project Name] has been copied to your clipboard"
          "Paste it into the project name field"
          [Done →]

  Step 3: "Click Create project"
          [Done →]

  Step 4: "Click Add content in the knowledge panel"
          [Done →]  
          → Auto-reveals project folder in Finder

  Step 5: "Drag these 12 files into the upload area:
           • memory-core.md
           • conversation-1.md … conversation-11.md"
          [Done →]

  Step 6: "Click the pencil icon next to Project Instructions"
          [Done →]
          → Auto-copies project-instructions.md to clipboard

  Step 7: "Paste the instructions (⌘V) and click Save"
          [Done →]

  ✅ Project complete! 
  [Next Project →]  [Skip Remaining]

→ After all projects: HUD shows completion summary
→ "All 3 projects set up. You're ready to use Claude."
→ HUD closes
```

---

## 7. Out of Scope (v1.0)

- **Fully automated** import into Claude.ai (no public API exists for project/file management)
- Browser automation or DOM manipulation of claude.ai (ToS violation risk)
- Syncing new ChatGPT conversations incrementally
- Handling ChatGPT Team/Enterprise exports (different schema)
- Any OpenAI API calls
- Windows or Linux builds

---

## 8. Success Metrics (Post-Launch)

- < 2% crash rate on import
- Memory Core generation success rate > 95% for valid exports
- p95 migration time < 3 minutes for 1,000 conversations
