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
| Minimum size | 720 × 720 pt |
| Default size | 720 × 720 pt |
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

### Screens 3–6: Wizard (step-by-step)
**When shown:** After parse completes, the main window shows a single wizard with steps: **Connect Claude** (API key / output folder) → **Your Data** (options) → **Memory Core** (generate or Cowork prompt) → **Select Projects** → **Conversations** (export) → **All Done** (summary, open folder, links to prompts). Each step uses a shared card shell (`WizardStepShell`, `WizardCard`) with Back / primary action in a footer bar. Minimum width 720pt, content max width 600pt.

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
