# NeuralJack — UI Specification

---

## Design Philosophy

NeuralJack is a **native macOS utility app**, not a web app in a wrapper. It follows Apple's Human Interface Guidelines strictly. The design should feel as comfortable as Finder, TextEdit, or Preview — familiar, precise, and calm.

**Tone:** Technical confidence without intimidation. This app handles someone's AI memory history — treat it as important and personal.

**Visual character:**
- Clean surfaces, generous whitespace
- System fonts and colors only
- Subtle iconography via SF Symbols
- No gradients, shadows, or decorative chrome beyond what macOS provides

---

## Window Specifications

| Property | Value |
|---|---|
| Minimum size | 900 × 600 pt |
| Default size | 1100 × 720 pt |
| Style mask | `.titled`, `.closable`, `.miniaturizable`, `.resizable` |
| Title bar | Standard macOS title bar with unified toolbar |
| Appearance | Follows system (auto light/dark) |

---

## Screen Inventory

### Screen 1: Welcome / Drop Zone
**When shown:** First launch OR no file loaded  
**Purpose:** Get the user to drop their ZIP

```
┌─────────────────────────────────────────────┐
│  ● ─ ■   NeuralJack                    [⚙]  │  ← toolbar with Settings gear
├─────────────────────────────────────────────┤
│                                             │
│          NeuralJack icon (128pt)            │  ← app icon, centered
│                                             │
│      Migrate ChatGPT → Claude               │  ← .largeTitle weight
│                                             │
│   ╔═══════════════════════════════════╗     │
│   ║                                   ║     │
│   ║   [archivebox.and.rectangle icon] ║     │  ← SF Symbol, 64pt, .secondary
│   ║                                   ║     │
│   ║   Drop your OpenAI export here    ║     │  ← .title3
│   ║   chatgpt-export-YYYY-MM-DD.zip   ║     │  ← .caption, .secondary
│   ║                                   ║     │
│   ╚═══════════════════════════════════╝     │  ← dashed border, 16pt radius
│                                             │
│          or  [Choose File…]                 │  ← .link button style
│                                             │
│   ─────────────────────────────────────     │
│   Don't have an export yet?  Get one →      │  ← .footnote, link to OpenAI
│                                             │
└─────────────────────────────────────────────┘
```

**SwiftUI notes:**
- Drop zone: `.dropDestination(for: URL.self)` on the dashed rectangle
- Dashed border: `RoundedRectangle(cornerRadius: 16).strokeBorder(.secondary, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))`
- On hover (`.onHover`): border strokes to `.accentColor`, animates with `.easeInOut(duration: 0.15)`
- On invalid drop: `withAnimation(.default) { shakeOffset = 10 }` then reset

---

### Screen 2: Import Progress
**When shown:** ZIP is being parsed  
**Duration:** Typically 1-5 seconds

```
┌─────────────────────────────────────────────┐
│  ● ─ ■   NeuralJack                         │
├─────────────────────────────────────────────┤
│                                             │
│              Parsing export…                │  ← .title2
│                                             │
│   ████████████████░░░░░░░░░░░░   67%        │  ← ProgressView(.linear)
│                                             │
│   Reading conversations.json               │  ← .caption, .secondary, animated
│                                             │
└─────────────────────────────────────────────┘
```

---

### Screen 3: Import Summary
**When shown:** Parse complete, before migration begins

```
┌─────────────────────────────────────────────┐
│  ● ─ ■   NeuralJack           [← Start Over]│
├─────────────────────────────────────────────┤
│                                             │
│  ✅  Export parsed successfully             │  ← .headline, green checkmark
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  👤  Alex Johnson                   │    │  ← user.json display name
│  │  📅  Jan 2023 – Feb 2025            │    │  ← date range
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │   847   │  │    3    │  │   42    │     │
│  │  convos │  │projects │  │ memories│     │  ← stat cards
│  └─────────┘  └─────────┘  └─────────┘     │
│                                             │
│  What to migrate:                           │
│  ☑ Generate Memory Core  (needs API key)    │
│  ☑ Export conversations as Markdown         │
│  ☑ Export project templates                 │
│                                             │
│  Output folder:  ~/Documents/NeuralJack  [⋯]│
│                                             │
│                  [Start Migration →]         │  ← .bordered prominent button
│                                             │
└─────────────────────────────────────────────┘
```

**SwiftUI notes:**
- Stat cards: `RoundedRectangle` with `.fill(.quaternary)`, number in `.largeTitle`, label in `.caption`
- Checkboxes: native `Toggle` with `.checkbox` style
- "Start Migration" button: `.buttonStyle(.borderedProminent)`, full width on narrower layouts

---

### Screen 4: Migration Progress (Split)
**When shown:** Migration running

```
┌─────────────────────────────────────────────┐
│  ● ─ ■   NeuralJack           [Cancel]      │
├─────────────────────────────────────────────┤
│                                             │
│  Migration in progress…                     │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │                                       │  │
│  │  ✅  Parsed 847 conversations         │  │
│  │                                       │  │
│  │  ⟳   Generating Memory Core          │  │
│  │      ████████████░░░░░  58%  (12/20  │  │
│  │      batches)                         │  │
│  │                                       │  │
│  │  ○   Exporting conversations          │  │
│  │                                       │  │
│  │  ○   Exporting project templates      │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  Estimated time remaining: ~1 minute        │  ← .caption, .secondary
│                                             │
└─────────────────────────────────────────────┘
```

**SwiftUI notes:**
- Each step row: icon (system symbol) + label + optional sub-progress
- Step states: `.pending` (gray circle), `.inProgress` (animated spinner), `.done` (green checkmark), `.failed` (red xmark)
- Cancel button: `.destructive` role, shows confirmation alert before cancelling

---

### Screen 5: Results
**When shown:** Migration complete

```
┌────────────────────────────────────────────────────────────┐
│  ● ─ ■   NeuralJack                          [New Import] │
├──────────────────┬─────────────────────────────────────────┤
│  RESULTS         │                                         │
│                  │    🧠 Memory Core                       │
│  🧠 Memory Core  │    ─────────────────────────────────    │
│  📦 Projects (3) │    # Memory Core                        │
│  📁 Conversations│    > Generated from 847 conversations   │
│  📋 Next Steps   │                                         │
│                  │    ## About Me                          │
│                  │    Software engineer in San Francisco…   │
│                  │                                         │
│                  │    ## Professional Context              │
│                  │    Works at a Series B startup…         │
│                  │                                         │
│                  │    …                                     │
│                  │                                         │
│                  │    [Copy to Clipboard ⌘C]  [Save As…]  │
│                  │                                         │
│                  ├─────────────────────────────────────────┤
│                  │                                         │
│                  │  [  Import into Claude →  ]             │
│                  │   Opens guided setup for 3 projects     │
│                  │                                         │
└──────────────────┴─────────────────────────────────────────┘
```

**SwiftUI notes:**
- Layout: `NavigationSplitView` with `.sidebar` list on left, detail on right
- Memory Core preview: `ScrollView` + rendered markdown via `AttributedString`
- "Copy to Clipboard": `.keyboardShortcut("c", modifiers: .command)`
- "Import into Claude →": `.buttonStyle(.borderedProminent)`, full width, pinned to bottom of detail area via `.safeAreaInset(edge: .bottom)`
- Subtext "Opens guided setup for N projects" in `.caption` `.secondary` below button

---

### Screen 6: Guided Import HUD (Floating Panel)
**When shown:** User clicks "Import into Claude →" on Results screen  
**Window type:** `NSPanel` with `.hudWindow` + `.nonactivatingPanel` style  
**Position:** Right edge of screen, vertically centered, 16pt margin  
**Width:** 340pt fixed. Height: dynamic based on step content.

```
┌─────────────────────────────────────┐
│  NeuralJack Guide             [✕]  │  ← NSPanel title bar
├─────────────────────────────────────┤
│                                     │
│  Project 2 of 3                     │  ← .caption .secondary
│  ✅ Work Projects  ▶ Personal  ○ AI │  ← project progress dots
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Step 4 of 8                        │  ← .caption .secondary
│                                     │
│  Click "Add content" in the         │  ← .body, wraps naturally
│  knowledge panel on the right       │
│  side of your new project.          │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  📋  12 files ready in Finder       │  ← auto-action status
│      Click "Done" to reveal them    │  ← .caption .secondary
│                                     │
│  ─────────────────────────────────  │
│                                     │
│        [Skip Project]  [Done →]     │  ← primary action right-aligned
│                                     │
│  ─────────────────────────────────  │
│  NeuralJack cannot automate         │  ← .caption2 .tertiary
│  claude.ai — only guide you.        │
└─────────────────────────────────────┘
```

**When auto-action fires (clipboard copy):**
```
│  ─────────────────────────────────  │
│                                     │
│  ✅  Project name copied            │  ← green, .caption
│      "Personal Assistant"           │  ← .caption .monospaced
│                                     │
```

**When auto-action fires (Finder reveal):**
```
│  ─────────────────────────────────  │
│                                     │
│  📂  Finder window opened           │  ← .caption
│      ~/Documents/NeuralJack-Export/ │  
│      Personal/                      │
│                                     │
```

**Completion state (all projects done):**
```
┌─────────────────────────────────────┐
│  NeuralJack Guide             [✕]  │
├─────────────────────────────────────┤
│                                     │
│         ✅                          │  ← large checkmark, centered
│                                     │
│    All 3 projects imported          │  ← .title3
│                                     │
│  Your ChatGPT history is now        │
│  available in Claude Projects.      │  ← .body .secondary
│                                     │
│        [Open claude.ai →]           │  ← opens browser
│        [Close]                      │
│                                     │
└─────────────────────────────────────┘
```

**SwiftUI/AppKit notes:**
- Panel is created imperatively in `GuidedImportPanel.swift` (AppKit), content hosted via `NSHostingView<GuidedImportHUDView>`
- Project dots: `HStack` of `Circle()` sized 8pt, `.fill(.green)` for done, `.fill(.accentColor)` for current, `.fill(.quaternary)` for pending
- "Done →" button: `.borderedProminent`, `.keyboardShortcut(.return)`
- "Skip Project": `.bordered`, `.destructive` tint
- Footer text: smallest readable size, `.tertiary` label color — visually recessed
- Panel does NOT appear in macOS Mission Control / app switcher (`.collectionBehavior = .auxiliary`)

### Screen 7: Preferences
**When shown:** Toolbar gear → opens Settings (⌘,)  
**Implementation:** Use SwiftUI `Settings` scene

```
┌─────────────────────────────────────────────┐
│  NeuralJack — Preferences                   │
├─────────────────────────────────────────────┤
│  [General]  [API Keys]                      │  ← toolbar tabs
├─────────────────────────────────────────────┤
│                                             │
│  Anthropic API Key                          │
│                                             │
│  ┌─────────────────────────────┐ [Verify]  │
│  │ sk-ant-••••••••••••••••••   │            │  ← SecureField
│  └─────────────────────────────┘            │
│  ✅ Key verified                            │  ← or ❌ Invalid key
│                                             │
│  Your key is stored securely in the         │
│  macOS Keychain and never leaves your Mac   │
│  except when calling api.anthropic.com.     │
│                                             │
│  Get a key at console.anthropic.com →       │  ← link
│                                             │
│  [Remove Key]                               │  ← .destructive
│                                             │
└─────────────────────────────────────────────┘
```

---

## Component Library

### `StatCardView`
Reusable stat display with large number + label.
```swift
StatCardView(value: "847", label: "conversations", icon: "bubble.left.and.bubble.right")
```

### `StepRowView`
Migration step indicator with status icon.
```swift
StepRowView(title: "Generating Memory Core", state: .inProgress, progress: 0.58)
```

### `DropZoneView`
The drag-and-drop target rectangle.
```swift
DropZoneView(isTargeted: $isTargeted) { url in
    viewModel.handleDrop(url: url)
}
```

### `ErrorBannerView`
Top-of-view error display.
```swift
ErrorBannerView(message: error.localizedDescription, onDismiss: { viewModel.clearError() })
```

---

## SF Symbol Usage Reference

| Context | Symbol |
|---|---|
| Drop zone | `archivebox.and.rectangle` |
| Conversations | `bubble.left.and.bubble.right` |
| Memory Core | `brain.head.profile` |
| Projects | `folder` |
| Export | `square.and.arrow.up` |
| Settings | `gear` |
| Copy | `doc.on.doc` |
| Step: pending | `circle` |
| Step: in progress | `arrow.trianglehead.2.clockwise` (animated) |
| Step: done | `checkmark.circle.fill` (green) |
| Step: failed | `xmark.circle.fill` (red) |
| API key saved | `lock.fill` |

---

## Animation Guidelines

- All transitions: `.easeInOut(duration: 0.2)` or system defaults
- Progress bars: use `ProgressView` with `.animation(.linear)` on value binding
- Step state changes: `.transition(.scale.combined(with: .opacity))`
- Error banner appear/dismiss: `.transition(.move(edge: .top).combined(with: .opacity))`
- Drop zone hover: `.animation(.easeInOut(duration: 0.15), value: isTargeted)`
- **No** spring animations on utility actions (only appropriate for game-like UI)

---

## Accessibility

- All interactive elements have `.accessibilityLabel` and `.accessibilityHint`
- Progress views include `.accessibilityValue` with spoken progress ("58 percent")
- Error banners post `.accessibilityAnnouncement` when they appear
- Minimum tap target: 44×44pt (use `.contentShape(Rectangle())` where needed)
- Color is never the sole indicator of state (always pair with icon/text)
