# NeuralJack — Cursor Getting Started Guide

This file tells you exactly which prompts to run in Cursor, in order, to scaffold the project.

---

## Prerequisites

1. Xcode 15+ installed
2. Create a new macOS App project in Xcode:
   - Product Name: `NeuralJack`
   - Team: Your developer team
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: macOS 13.0
   - Uncheck: "Include Tests" (we'll add manually)
3. Add `NeuralJack.xcodeproj` to this repo root
4. Add ZIPFoundation via SPM: File → Add Package → `https://github.com/weichsel/ZIPFoundation.git`
5. Open project in Cursor

---

## Prompt Sequence for Cursor

Run these prompts **in order**. Each builds on the previous.

---

### Step 1: App Shell & Entry Point

```
Read .cursorrules, docs/ARCHITECTURE.md, and docs/DATA_MODEL.md.

Create the following files exactly as described in the architecture:

1. NeuralJack/App/NeuralJackApp.swift
   - SwiftUI @main App struct
   - WindowGroup with MainWindowView
   - Settings scene with PreferencesView
   - Inject services into environment: ZIPParserService, AnthropicService, ExportService, KeychainService.shared
   - Listen for NSNotification named "zipFileDropped" and route to ImportViewModel
   
2. NeuralJack/App/AppDelegate.swift
   - NSApplicationDelegate
   - Implement application(_:openFile:) for Dock icon drops
   - Post "zipFileDropped" notification with the URL

3. NeuralJack/Models/AppError.swift
   - AppError enum as specified in .cursorrules
   - All cases with LocalizedError conformance
   - errorDescription and recoverySuggestion for every case
```

---

### Step 2: Core Data Models

```
Read docs/DATA_MODEL.md carefully.

Create the following model files in NeuralJack/Models/:

1. OpenAIModels.swift — All OpenAI export structs:
   OpenAIConversation, OpenAINode, OpenAIMessage, OpenAIAuthor, 
   OpenAIContent, OpenAIContentPart (with custom Codable), 
   OpenAIMemoryFile, OpenAIMemoryEntry, OpenAIUser

2. AppModels.swift — Internal NeuralJack structs:
   OpenAIExport, ProjectGroup, Message, MessageRole, 
   MemoryCore (with copyToClipboard()), ClaudeProjectTemplate 
   (with markdownRepresentation), ExportResult

Include the linearize(conversation:) function in AppModels.swift 
as a free function that takes an OpenAIConversation and returns [Message],
following the node tree traversal logic in DATA_MODEL.md.
```

---

### Step 3: Services

```
Read docs/ARCHITECTURE.md Service Catalog section and Guided Import HUD section.

Create the following services in NeuralJack/Services/:

1. KeychainService.swift
   - Static shared instance
   - save/load/delete using Security framework directly (no wrappers)
   - KeychainAccount enum with anthropicAPIKey case

2. ZIPParserService.swift
   - actor ZIPParserService
   - parse(zipURL: URL) async throws -> OpenAIExport
   - Uses ZIPFoundation to unzip to FileManager.default.temporaryDirectory
   - Decodes conversations.json, memory.json (optional), user.json (optional)
   - Groups conversations by gizmoId to produce ProjectGroups
   - Cleans up temp directory in defer block
   - Throws AppError.invalidZIPFile or .missingConversationsJSON as appropriate

3. AnthropicService.swift
   - Regular class (not actor)
   - validateAPIKey(_ key: String) async throws -> Bool
   - synthesizeMemoryCore(conversations:memoryEntries:progress:) async throws -> MemoryCore
   - synthesizeProjectInstructions(project: ProjectGroup) async throws -> String
     → Single API call; returns a concise system prompt for the project
   - Private helper: makeAPIRequest(messages:systemPrompt:maxTokens:) async throws -> String

4. ExportService.swift
   - packageProjects(_:memoryCore:to:progress:) async throws -> [ClaudeProjectPackage]
     → Per project: create subfolder, write project-instructions.md, memory-core.md, conversations/*.md
     → Sanitize folder names: alphanumeric + spaces + hyphens only, max 60 chars
     → Returns array of ClaudeProjectPackage with all file URLs populated
   - exportConversations(_:to:progress:) async throws -> ExportResult (flat backup)

5. GuidedImportService.swift
   - openClaudeProjects() → NSWorkspace.shared.open(URL(string: "https://claude.ai/projects")!)
   - copyToClipboard(_ string: String) → NSPasteboard.general
   - revealInFinder(_ url: URL) → NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: ...)
   - saveProgress(_ progress: GuidedImportProgress) → UserDefaults
   - loadProgress() -> GuidedImportProgress? → UserDefaults
   - clearProgress() → UserDefaults

6. PromptLoader.swift
   - enum PromptLoader with static func load(_ name: String) -> String
   - Loads from Bundle.main Resources/Prompts/
```

---

### Step 4: Prompts Resource Files

```
Create two prompt files in NeuralJack/Resources/Prompts/:

1. extraction-prompt.txt
   Use the extraction prompt from ARCHITECTURE.md Memory Core Synthesis section.
   Format as plain text (not Swift string).

2. synthesis-prompt.txt
   Use the synthesis prompt from ARCHITECTURE.md Memory Core Synthesis section.
   Format as plain text (not Swift string).

Then create NeuralJack/Services/PromptLoader.swift:
   - enum PromptLoader
   - static func load(_ name: String) -> String
   - Loads from Bundle.main, fatal error if missing (programmer error)
```

---

### Step 5: ViewModels

```
Read docs/PRD.md user flows and .cursorrules ViewModel rules.

Create ViewModels in the appropriate Features/ subdirectories:

1. Features/Import/ImportViewModel.swift (@MainActor @Observable)
   - State enum: .idle, .parsing, .parsed(OpenAIExport), .failed(AppError)
   - handleDrop(url: URL) async
   - clearImport()
   - Properties: selectedConversations: Set<String>, includeMemoryCore: Bool, 
     includeExport: Bool, includeProjects: Bool, outputDirectory: URL

2. Features/Migration/MigrationViewModel.swift (@MainActor @Observable)
   - Step enum: parseConversations / generateMemoryCore / packageProjects / exportConversations
   - MigrationStep state: pending/inProgress(Double)/done/failed
   - startMigration(export: OpenAIExport, settings: MigrationSettings) async
   - cancel()
   - Result properties: memoryCore: MemoryCore?, packages: [ClaudeProjectPackage]?, exportResult: ExportResult?

3. Features/GuidedImport/GuidedImportViewModel.swift (@MainActor @Observable)
   - packages: [ClaudeProjectPackage]
   - currentPackageIndex: Int
   - currentStepIndex: Int
   - Computed: currentPackage, currentStep, isLastStep, isLastProject
   - stepStates: [Int: StepState] (completed steps marked)
   - start(packages:) — loads saved progress from GuidedImportService, positions and shows NSPanel
   - advanceStep() — executes auto-action, advances index, saves progress
   - skipProject() — marks project skipped, advances to next
   - skipAll() — dismisses panel, clears progress
   - completedPackageIDs: Set<String> — persisted

4. Features/Preferences/PreferencesViewModel.swift (@MainActor @Observable)
   - apiKey: String (not stored; only used for entry)
   - savedKeyMasked: String (shows "sk-ant-••••••••" format)
   - validationState: .idle / .validating / .valid / .invalid(String)
   - saveAndValidate() async
   - removeKey()
```

---

### Step 6: Views — Foundation

```
Read docs/UI_SPEC.md completely.

Create reusable components in NeuralJack/UI/Components/:

1. DropZoneView.swift
   - Dashed rounded rectangle as specified in UI_SPEC.md
   - isTargeted binding for hover state
   - onDrop closure callback
   - Implements .dropDestination(for: URL.self)

2. StatCardView.swift
   - value: String, label: String, icon: String (SF Symbol name)
   - Rounded rect background, large number, small label

3. StepRowView.swift
   - title: String, state: StepState, progress: Double?
   - StepState: pending/inProgress/done/failed
   - Animated spinner for inProgress state

4. ErrorBannerView.swift
   - message: String, onDismiss: () -> Void
   - Red/pink background, xmark dismiss button
   - Posts .accessibilityAnnouncement on appear
```

---

### Step 7: Views — Screens

```
Create screen views in NeuralJack/Features/:

1. Features/Import/WelcomeView.swift — Screen 1 from UI_SPEC.md
2. Features/Import/ImportProgressView.swift — Screen 2
3. Features/Import/ImportSummaryView.swift — Screen 3
4. Features/Migration/MigrationProgressView.swift — Screen 4
5. Features/Results/ResultsView.swift — Screen 5 (NavigationSplitView)
   Sub-views: MemoryCoreView, ProjectPackagesView, ConversationsExportView, NextStepsView
   Include "Import into Claude →" button wired to GuidedImportViewModel.start()
6. Features/GuidedImport/GuidedImportHUDView.swift — Screen 6 (HUD content only)
   - ProjectSwitcherView: progress dots + "Project N of M" label
   - CurrentStepView: instruction text + auto-action status label
   - StepActionsView: "Done →" (primary) + "Skip Project" (secondary)
   - DisclaimerFooterView: small gray disclaimer text
7. Features/GuidedImport/GuidedImportPanel.swift — NSPanel wrapper (AppKit)
   - Subclass NSPanel with correct style mask (see .cursorrules NSPanel Rules)
   - Hosts GuidedImportHUDView via NSHostingView
   - positionOnScreen() method: right edge of NSScreen.main, vertically centered
   - show() / hide() methods
8. Features/Preferences/PreferencesView.swift — Screen 7

Then create NeuralJack/UI/Windows/MainWindowView.swift:
   - Switch between screens based on app state
   - Wire ImportViewModel, MigrationViewModel from environment
   - Handle "zipFileDropped" notification routing
```

---

### Step 8: Polish & Edge Cases

```
After all views compile and run:

1. Add shake animation to WelcomeView for invalid drop
2. Add keyboard shortcut ⌘, to open Preferences
3. Add "Drag ZIP here" to app's NSServicesMenu / accepted file types in Info.plist
   - Add LSItemContentTypes: ["org.pkware.zip-archive"] to Info.plist
   - Add Document Types for .zip in Xcode target settings
4. Wire ⌘C shortcut on MemoryCoreView copy button
5. Add .onOpenURL handler for future deep link support
6. Ensure all ProgressView animations work correctly
7. Test with an actual OpenAI export ZIP
```

---

## Fixture Files for Testing

Place these in `NeuralJack/Tests/Fixtures/`:

```
sample-conversations.json   — 5 conversations with varied content
sample-memory.json          — 3 memory entries
sample-user.json            — Test user object
```

Use `@testable import NeuralJack` to test parsers directly.

---

## Useful Debug Commands

```bash
# Check your signing identity
security find-identity -v -p codesigning

# Validate the app bundle
codesign --verify --deep --strict --verbose=2 NeuralJack.app

# Notarize (after Developer ID setup)
xcrun notarytool submit NeuralJack.dmg --apple-id EMAIL --team-id TEAMID --wait
```
