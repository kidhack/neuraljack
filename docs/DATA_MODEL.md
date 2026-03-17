# NeuralJack — Data Models

---

## OpenAI Export Format

When a user exports their data from ChatGPT (Settings → Data Controls → Export), they receive a `.zip` containing:

```
zip root/
├── conversations-000.json   ← chunk 1 of N, each is an array
├── conversations-001.json   ← chunk 2 of N
├── conversations-002.json   ← chunk 3 of N (you have 3)
├── memory.json              (optional)
└── user.json                (optional)
```

---

## Conversation Chunk Files Schema

`conversations-000.json`, `conversations-001.json`, etc. — Each file is an **array** of Conversation objects. Merge all chunks in sorted filename order to get the full conversation list. Parse with `JSONDecoder`.

```swift
// MARK: - Top-level
typealias OpenAIConversationsFile = [OpenAIConversation]

struct OpenAIConversation: Codable, Identifiable {
    let id: String
    let title: String
    let createTime: Double        // Unix timestamp
    let updateTime: Double        // Unix timestamp
    let mapping: [String: OpenAINode]
    let currentNode: String?      // ID of the last message node
    let conversationId: String?
    let gizmoId: String?          // Non-nil = custom GPT / project conversation
    let isArchived: Bool?
    
    // Computed
    var createdAt: Date { Date(timeIntervalSince1970: createTime) }
    var updatedAt: Date { Date(timeIntervalSince1970: updateTime) }
}

// CodingKeys for snake_case → camelCase
extension OpenAIConversation {
    enum CodingKeys: String, CodingKey {
        case id, title, mapping
        case createTime = "create_time"
        case updateTime = "update_time"
        case currentNode = "current_node"
        case conversationId = "conversation_id"
        case gizmoId = "gizmo_id"
        case isArchived = "is_archived"
    }
}
```

```swift
// MARK: - Node (message tree node)
struct OpenAINode: Codable {
    let id: String
    let parent: String?
    let children: [String]
    let message: OpenAIMessage?
}

struct OpenAIMessage: Codable {
    let id: String
    let author: OpenAIAuthor
    let createTime: Double?
    let content: OpenAIContent
    let status: String?         // "finished_successfully", "in_progress"
    let weight: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, author, content, status, weight
        case createTime = "create_time"
    }
}

struct OpenAIAuthor: Codable {
    let role: String            // "user" | "assistant" | "system" | "tool"
    let name: String?           // Tool name when role == "tool"
}

struct OpenAIContent: Codable {
    let contentType: String     // "text" | "code" | "tether_browsing_display" | "multimodal_text"
    let parts: [OpenAIContentPart]?
    
    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case parts
    }
}

// Parts can be String OR objects — use a custom decoder
enum OpenAIContentPart: Codable {
    case text(String)
    case unsupported              // code blocks, images, tool outputs — stripped
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .unsupported
        }
    }
    
    var textValue: String? {
        if case .text(let t) = self { return t }
        return nil
    }
}
```

---

## `memory.json` Schema

```swift
struct OpenAIMemoryFile: Codable {
    let memories: [OpenAIMemoryEntry]
}

struct OpenAIMemoryEntry: Codable, Identifiable {
    let id: String
    let text: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, text
        case createdAt = "created_at"
    }
}
```

> **Note:** The exact schema for `memory.json` varies across exports. Always use optional fields and fail gracefully if the file is absent.

---

## `user.json` Schema

```swift
struct OpenAIUser: Codable {
    let id: String?
    let email: String?
    let chatgptPlusUser: Bool?
    let phoneNumber: String?     // Do NOT store or display
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case chatgptPlusUser = "chatgpt_plus_user"
        case phoneNumber = "phone_number"
    }
}
```

---

## Internal NeuralJack Models

These are the app's internal representations, transformed from the OpenAI schema.

### `OpenAIExport` — Top-level parsed result
```swift
struct OpenAIExport {
    let user: OpenAIUser?
    let conversations: [OpenAIConversation]
    let memoryEntries: [OpenAIMemoryEntry]
    let projectGroups: [ProjectGroup]         // Conversations grouped by gizmoId
    
    var conversationCount: Int { conversations.count }
    var projectCount: Int { projectGroups.count }
    var memoryEntryCount: Int { memoryEntries.count }
    var dateRange: ClosedRange<Date>? { ... }
}
```

### `ProjectGroup` — ChatGPT Custom GPT grouping
```swift
struct ProjectGroup: Identifiable {
    let id: String                             // The gizmoId
    var name: String                           // Inferred from first conversation title prefix, or "Unnamed Project"
    var conversations: [OpenAIConversation]
}
```

### `Message` — Normalized message (flattened from node tree)
```swift
struct Message: Identifiable {
    let id: String
    let role: MessageRole
    let text: String
    let createdAt: Date
}

enum MessageRole {
    case user
    case assistant
    case system
    case tool
}
```

### `MemoryCore` — Output of synthesis pipeline
```swift
struct MemoryCore {
    let markdown: String           // Full formatted Memory Core content
    let generatedAt: Date
    let sourceConversationCount: Int
    let sourceMemoryEntryCount: Int
    let tokenCount: Int?           // Approximate, for UI display
    
    // Convenience
    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }
}
```

### `ClaudeProjectPackage` — Output of project packaging (replaces ClaudeProjectTemplate)
```swift
struct ClaudeProjectPackage: Identifiable {
    let id: String                          // gizmoId or "general"
    let name: String
    let packageDirectory: URL               // Local folder on disk
    let projectInstructionsFile: URL        // _project-instructions.md
    let memoryCoreFile: URL                 // memory-core.md
    let conversationFiles: [URL]            // conversations/*.md
    let conversationCount: Int
}
```

### `ImportStep` — A single step in the Guided Import HUD
```swift
struct ImportStep: Identifiable {
    let id: Int
    let instruction: String                 // Displayed in HUD
    let autoAction: StepAutoAction          // Fires when user taps Done on prev step
    let actionStatusLabel: String?          // e.g. "Project name copied"
}

enum StepAutoAction {
    case none
    case copyToClipboard(String)
    case revealInFinder(URL)
}
```

### `GuidedImportProgress` — Persisted HUD state (UserDefaults)
```swift
struct GuidedImportProgress: Codable {
    let packageIDs: [String]
    var completedPackageIDs: Set<String>
    var currentPackageID: String
    var currentStepIndex: Int
    var outputDirectory: URL
}
```

### `ExportResult` — Result of full migration
```swift
struct ExportResult {
    let outputDirectory: URL
    let packages: [ClaudeProjectPackage]
    let exportedConversations: Int
    let skippedConversations: Int
    let durationSeconds: Double
}
```

---

## Memory Core Output Format

The final `MemoryCore.markdown` always has this structure:

```markdown
# Memory Core
> Generated by NeuralJack from [N] conversations on [Date]

## About Me
[Personal facts explicitly mentioned in conversations: name, location, profession]

## Professional Context
[Work role, company type, industry, team size — only if mentioned]

## Knowledge & Skills
[Domains of expertise, programming languages, tools, frameworks]

## Communication Preferences
[How the user likes to receive information: bullet points vs prose, level of detail, tone]

## Recurring Topics & Projects
[Ongoing projects, frequent topics, regular tasks]

## Context Notes
[Other relevant patterns or preferences that don't fit above categories]

---
*This Memory Core was synthesized from your ChatGPT conversation history. 
Review and edit before pasting into Claude Project Instructions.*
```

---

## Conversation Markdown Export Format

```
NeuralJack-Export/
├── projects/
│   ├── Project Name One/
│   │   ├── _project-instructions.md    ← synthesized system prompt
│   │   └── conversations/
│   │       ├── 2024-03-01 Conversation Title.md
│   │       └── 2024-05-12 Another Chat.md
│   ├── Project Name Two/
│   │   ├── _project-instructions.md
│   │   └── conversations/
│   │       └── 2023-11-08 Some Chat.md
│   └── Uncategorized/
│       └── conversations/
│           └── 2024-01-15 Random Chat.md
└── memory-core.md
```

Each exported conversation:

```markdown
# [Conversation Title]
*[Date] · [Message count] messages*

---

**You:** [user message text]

**Claude:** [assistant message text]

**You:** [next user message]

...
```

> Note: The export uses "Claude" as the assistant label (not "ChatGPT") to match the migration context.

**Folder naming:** Sanitize project names for filesystem (remove `/ \ : * ? " < > |`, replace with hyphen, trim whitespace, max 60 chars). If empty, use "Unnamed Project". Conversations with no project (gizmoId == nil) go in `Uncategorized/`.

**Conversation filename:** `[YYYY-MM-DD] [Title].md` — date from createTime, title sanitized same as project names, max 80 chars total.

---

## Node Tree Traversal

ChatGPT's `conversations.json` stores messages in a tree structure (not a linear array), because conversations can have branching edits. To reconstruct the canonical conversation thread:

```swift
func linearize(conversation: OpenAIConversation) -> [Message] {
    // 1. Start from currentNode
    // 2. Walk up the parent chain to find root
    // 3. Walk down the children chain, always taking children[0]
    //    (first child = main branch; later children = edit branches — skip)
    // 4. Map each node's message to a Message struct
    // 5. Filter: keep only role == .user or .assistant with non-empty text
}
```
