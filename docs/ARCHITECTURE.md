# NeuralJack — Architecture

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        NeuralJack.app                        │
│                                                              │
│  ┌──────────┐   ┌─────────────────┐   ┌─────────────────┐  │
│  │ SwiftUI  │ → │  ViewModels     │ → │    Services     │  │
│  │  Views   │   │  (@MainActor    │   │  (pure Swift)   │  │
│  │          │   │   @Observable)  │   │                 │  │
│  └──────────┘   └─────────────────┘   └────────┬────────┘  │
│                                                 │           │
│                         ┌───────────────────────┤           │
│                         ▼                       ▼           │
│                  ┌─────────────┐    ┌─────────────────────┐ │
│                  │   Models    │    │   External Calls    │ │
│                  │  (structs)  │    │  api.anthropic.com  │ │
│                  └─────────────┘    │  macOS Keychain     │ │
│                                     │  Local File System  │ │
│                                     └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer Definitions

### Views (`UI/`)
- Pure SwiftUI. Display state from ViewModels.
- Zero business logic, zero network calls, zero file I/O.
- Communicate user intent to ViewModels via method calls.

### ViewModels (`Features/*/`)
- Annotated `@MainActor @Observable`
- Own the UI-facing state for each feature
- Delegate work to Services; await results
- Handle `AppError` → translate to user-facing `errorMessage: String?`

### Services (`Services/`)
- Plain Swift classes (not actors, not observable)
- Injected into the SwiftUI environment at app root
- Own all side effects: networking, disk I/O, Keychain

### Models (`Models/`)
- Pure Swift structs
- `Codable` where they map to JSON
- No dependencies on UI framework or services

---

## Service Catalog

### `ZIPParserService`
```swift
actor ZIPParserService {
    func parse(zipURL: URL) async throws -> OpenAIExport
}
```
Responsibilities:
- Unzip to a temporary directory
- Decode `conversations.json` into `[OpenAIConversation]`
- Decode `memory.json` into `[MemoryEntry]` (optional)
- Decode `user.json` for display name
- Clean up temp directory after parse

### `AnthropicService`
```swift
class AnthropicService {
    func synthesizeMemoryCore(
        conversations: [OpenAIConversation],
        memoryEntries: [MemoryEntry],
        progress: @escaping (Double) -> Void
    ) async throws -> MemoryCore
    
    func validateAPIKey(_ key: String) async throws -> Bool
}
```
Responsibilities:
- Manage API key from KeychainService
- Batch conversations, run synthesis pipeline
- Handle rate limits (retry with backoff)
- Stream responses for long operations

### `KeychainService`
```swift
class KeychainService {
    static let shared = KeychainService()
    func save(key: String, for account: KeychainAccount) throws
    func load(for account: KeychainAccount) throws -> String
    func delete(for account: KeychainAccount) throws
}

enum KeychainAccount: String {
    case anthropicAPIKey = "com.neuraljack.anthropic-api-key"
}
```

### `ExportService`
```swift
class ExportService {
    func packageProjects(
        _ projects: [ProjectGroup],
        memoryCore: MemoryCore,
        to directory: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> [ClaudeProjectPackage]
    
    func exportConversations(
        _ conversations: [OpenAIConversation],
        to directory: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> ExportResult
}
```

### `GuidedImportService`
```swift
class GuidedImportService {
    // Opens claude.ai/projects in the default browser
    func openClaudeProjects()
    
    // Copies text to NSPasteboard
    func copyToClipboard(_ string: String)
    
    // Reveals the project package folder in Finder (highlights it)
    func revealInFinder(_ url: URL)
    
    // Persists HUD step progress across app restarts
    func saveProgress(_ progress: GuidedImportProgress)
    func loadProgress() -> GuidedImportProgress?
    func clearProgress()
}
```

---

## Memory Core Synthesis Pipeline

This is the core differentiator of the app. The pipeline runs in three phases:

```
Phase 1: Batch Extraction
━━━━━━━━━━━━━━━━━━━━━━━━
Conversations → Chunks of 20
For each chunk → API call with extraction prompt
Output: BatchExtract { facts, skills, preferences, topics }

Phase 2: Memory Merge  
━━━━━━━━━━━━━━━━━━━━━━━━
All BatchExtracts → Single API call with synthesis prompt
Output: RawMemoryCore (unformatted prose)

Phase 3: Formatting
━━━━━━━━━━━━━━━━━━━━━━━━
RawMemoryCore → Format into structured Markdown sections
Output: MemoryCore.markdown (ready to paste into Claude)
```

### Extraction Prompt (Phase 1)
Located at `Resources/Prompts/extraction-prompt.md`

```
You are analyzing a batch of ChatGPT conversations to extract memory-relevant information.

Extract ONLY facts that would help an AI assistant serve this user better, including:
- Personal facts (name, location, profession, if explicitly mentioned)
- Skills and expertise domains
- Communication preferences (formal/casual, verbose/concise, etc.)
- Recurring projects, goals, or topics
- Tools, languages, or frameworks they use regularly

Do NOT include: sensitive personal information, specific conversation content, opinions, one-off questions.

Output as JSON: { "facts": [], "skills": [], "preferences": [], "topics": [] }
```

### Synthesis Prompt (Phase 2)
Located at `Resources/Prompts/synthesis-prompt.md`

```
You are creating a Memory Core — a concise context document for an AI assistant.
You have been given extracted facts from a user's AI conversation history.
Synthesize these into a well-organized context document.

Format requirements:
- Markdown with specific section headers (see DATA_MODEL.md)
- Present tense, written as if describing the user to an AI
- Factual and specific — no vague generalities
- Maximum 800 words
- Do not include anything that sounds like PII beyond what was explicitly shared
```

---

## Guided Import HUD

The HUD is a floating `NSPanel` that lives outside the SwiftUI window hierarchy. It stays above the browser without stealing focus, so the user can interact with claude.ai freely.

### NSPanel Configuration
```swift
// GuidedImportPanel.swift
class GuidedImportPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        self.level = .floating            // Stays above browser
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false    // Stays visible when user clicks browser
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.title = "NeuralJack Guide"
    }
}
```

### HUD SwiftUI Content
The panel hosts a SwiftUI view via `NSHostingView`:
```swift
// GuidedImportHUDView.swift — hosted in the NSPanel
@MainActor @Observable
class GuidedImportHUDViewModel {
    var projects: [ClaudeProjectPackage]
    var currentProjectIndex: Int = 0
    var currentStepIndex: Int = 0
    
    var currentProject: ClaudeProjectPackage { projects[currentProjectIndex] }
    var currentStep: ImportStep { currentProject.steps[currentStepIndex] }
    var isLastStep: Bool { currentStepIndex == currentProject.steps.count - 1 }
    var isLastProject: Bool { currentProjectIndex == projects.count - 1 }
    
    func advanceStep() { ... }
    func skipProject() { ... }
    func skipAll() { ... }
    
    // Called on each step advance — triggers auto-actions
    private func executeAutoAction(for step: ImportStep) {
        switch step.autoAction {
        case .copyToClipboard(let string): service.copyToClipboard(string)
        case .revealInFinder(let url):     service.revealInFinder(url)
        case .none:                        break
        }
    }
}
```

### Step Auto-Actions
Each `ImportStep` may carry an optional auto-action that fires when the user taps "Done" on the *previous* step — so the action is ready before they need it:

```swift
enum StepAutoAction {
    case none
    case copyToClipboard(String)    // Silently copies; HUD says "copied to clipboard"
    case revealInFinder(URL)        // Opens Finder window showing the package folder
}
```

### HUD Positioning
```swift
// Anchor to right edge of main screen, vertically centered
func positionHUD(_ panel: NSPanel) {
    guard let screen = NSScreen.main else { return }
    let padding: CGFloat = 16
    let hudWidth: CGFloat = 340
    let hudHeight: CGFloat = panel.frame.height
    let x = screen.visibleFrame.maxX - hudWidth - padding
    let y = screen.visibleFrame.midY - hudHeight / 2
    panel.setFrameOrigin(NSPoint(x: x, y: y))
}
```

---

## Data Flow: ZIP Drop → Guided Claude Import

```
User drops ZIP
     │
     ▼
AppDelegate.application(_:openFiles:)
OR
ImportDropDelegate.performDrop(info:)
     │
     ▼
ImportViewModel.handleDrop(url: URL)
     │
     ├── ZIPParserService.parse(zipURL:)
     │        └── returns OpenAIExport
     │
     ▼
MigrationViewModel.startMigration()
     │
     ├── AnthropicService.synthesizeMemoryCore(...)
     │        ├── Phase 1: batchExtract() × N batches
     │        ├── Phase 2: synthesize(extracts:)
     │        └── Phase 3: format(raw:)
     │        └── returns MemoryCore
     │
     ├── ExportService.packageProjects(...)
     │        ├── Per project: write project-instructions.md
     │        ├── Per project: write memory-core.md
     │        ├── Per project: write conversations/*.md
     │        └── returns [ClaudeProjectPackage]
     │
     └── ExportService.exportConversations(...)   ← flat backup archive
     │
     ▼
ResultsViewModel
     │ (user clicks "Import into Claude →")
     ▼
GuidedImportViewModel.start(packages: [ClaudeProjectPackage])
     ├── GuidedImportService.openClaudeProjects()  → NSWorkspace opens browser
     ├── GuidedImportPanel.show()                  → floating HUD appears
     └── Step-by-step: user advances, auto-actions fire per step
```

---

## Drag and Drop Implementation

Two entry points for file drops:

### 1. App Icon / Dock (AppDelegate)
```swift
// AppDelegate.swift
func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    let url = URL(fileURLWithPath: filename)
    guard url.pathExtension == "zip" else { return false }
    NotificationCenter.default.post(name: .zipFileDropped, object: url)
    return true
}
```

### 2. Main Window Drop Zone (SwiftUI)
```swift
// DropZoneView.swift
.dropDestination(for: URL.self) { urls, _ in
    guard let zipURL = urls.first,
          zipURL.pathExtension == "zip" else { return false }
    viewModel.handleDrop(url: zipURL)
    return true
}
```

---

## Window Architecture

```
NeuralJackApp (WindowGroup)
└── MainWindowView
    ├── [State: .empty]      → WelcomeDropZoneView
    ├── [State: .importing]  → ImportProgressView
    ├── [State: .reviewing]  → NavigationSplitView
    │                            ├── Sidebar: ConversationListView
    │                            └── Detail: ConversationDetailView
    ├── [State: .migrating]  → MigrationProgressView
    └── [State: .done]       → ResultsView
                                 ├── MemoryCorePreviewView
                                 ├── ProjectPackagesView
                                 ├── ExportedFilesView
                                 └── NextStepsView
                                      └── [Import into Claude →] button
                                           └── launches GuidedImportPanel

GuidedImportPanel (NSPanel — floating, non-activating)
└── GuidedImportHUDView (NSHostingView)
    ├── ProjectSwitcherView   (e.g. "Project 2 of 3 ✓✓○")
    ├── CurrentStepView       (instruction text + auto-action label)
    ├── StepActionsView       ([Done →]  [Skip Project]  [Skip All])
    └── DisclaimerFooterView  ("NeuralJack cannot automate claude.ai…")

PreferencesWindow (Settings scene)
└── PreferencesView
    ├── APIKeyView
    └── AboutView
```

---

## Error Handling Strategy

All errors are typed as `AppError`. Services throw `AppError`. ViewModels catch and translate:

```swift
@MainActor @Observable
class MigrationViewModel {
    var errorMessage: String? = nil
    
    func startMigration() async {
        do {
            try await service.doWork()
        } catch let error as AppError {
            self.errorMessage = error.errorDescription
        } catch {
            self.errorMessage = "An unexpected error occurred. Please try again."
        }
    }
}
```

Errors surface as a `.safeAreaInset(edge: .top)` red banner, auto-clearing after 8 seconds.

---

## Xcode Project Setup

### Swift Package Dependencies
```swift
// Package.swift (or via Xcode SPM UI)
dependencies: [
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
]
```

### Build Settings
- `SWIFT_STRICT_CONCURRENCY = complete`
- `SWIFT_VERSION = 5.10`
- `MACOSX_DEPLOYMENT_TARGET = 13.0`
- Hardened Runtime: enabled (required for notarization)
- Entitlements: `com.apple.security.network.client` (Anthropic API calls only)

### Code Signing & Distribution
- Developer ID Application certificate
- Notarization via `notarytool`
- DMG distribution (no Mac App Store — avoids App Review for v1)
