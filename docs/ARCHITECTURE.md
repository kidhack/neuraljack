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
Located at `Resources/Prompts/extraction-prompt.txt`

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
Located at `Resources/Prompts/synthesis-prompt.txt`

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

## Data Flow: ZIP Drop → Wizard → Complete

```
User drops ZIP
     │
     ▼
AppDelegate.application(_:openFiles:)  OR  MainWindowView.dropDestination
     │
     ▼
ImportViewModel.handleDrop(url: URL)
     │
     └── ZIPParserService.parse(from:)
              └── returns OpenAIExport
     │
     ▼
MainWindowView.onChange(of: importViewModel.state.phase)
     │  when .parsed → creates WizardViewModel(export: ...)
     ▼
WizardView (step-by-step)
     │  Steps: setup → dataSummary → memoryCore → projects → conversations → complete
     │
     ├── WizardSetupStepView        — API key / Cowork choice, output folder
     ├── WizardDataSummaryStepView  — Data overview, options (Memory Core, export log)
     ├── WizardMemoryCoreStepView   — Generate Memory Core (API) or write Cowork prompt
     ├── WizardProjectSelectionView — Select projects to export
     ├── WizardConversationsStepView — Export projects + optional uncategorized
     └── WizardCompleteStepView    — Summary, open export folder, links to prompts
     │
     └── WizardViewModel runs: AnthropicService.synthesizeMemoryCore, ExportService
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
    ├── [State: .idle / .failed]  → WelcomeView (DropZoneView)
    ├── [State: .parsing]         → ImportProgressView
    └── [State: .parsed]          → WizardView
                                      ├── WizardSetupStepView
                                      ├── WizardDataSummaryStepView
                                      ├── WizardMemoryCoreStepView
                                      ├── WizardProjectSelectionView
                                      ├── WizardConversationsStepView
                                      └── WizardCompleteStepView

Settings (SwiftUI Settings scene)
└── PreferencesView
    └── API key entry, validation, Keychain
```

---

## Error Handling Strategy

All errors are typed as `AppError`. Services throw `AppError`. ViewModels catch and translate to user-facing messages. Example (WizardViewModel):

```swift
do {
    try await anthropicService.synthesizeMemoryCore(...)
} catch let error as AppError {
    memoryCoreError = error.errorDescription
} catch {
    memoryCoreError = "Memory Core generation failed: \(error.localizedDescription)"
}
```

Errors surface as a `.safeAreaInset(edge: .top)` error banner in MainWindowView (import errors) or inline in wizard steps.

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
