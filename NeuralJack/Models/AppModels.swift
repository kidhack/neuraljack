//
//  AppModels.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import AppKit
import Foundation

// MARK: - OpenAIExport

struct OpenAIExport {
    let user: OpenAIUser?
    let conversations: [OpenAIConversation]
    let memoryEntries: [OpenAIMemoryEntry]
    let projectGroups: [ProjectGroup]

    var conversationCount: Int { conversations.count }
    var projectCount: Int { projectGroups.count }
    var memoryEntryCount: Int { memoryEntries.count }

    var dateRange: ClosedRange<Date>? {
        let dates = conversations.flatMap { c in [c.createdAt, c.updatedAt] }
        guard let min = dates.min(), let max = dates.max() else { return nil }
        return min...max
    }
}

// MARK: - ProjectGroup

struct ProjectGroup: Identifiable {
    let id: String
    var name: String
    var conversations: [OpenAIConversation]
}

// MARK: - Message (normalized, flattened from node tree)

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

// MARK: - MemoryCore

struct MemoryCore {
    let markdown: String
    let generatedAt: Date
    let sourceConversationCount: Int
    let sourceMemoryEntryCount: Int
    let tokenCount: Int?

    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }
}

// MARK: - ClaudeProjectTemplate

struct ClaudeProjectTemplate: Identifiable {
    let id: String
    let name: String
    let projectInstructions: String
    let memoryCoreMarkdown: String

    var markdownRepresentation: String {
        """
        # \(name)

        ## Project Instructions
        \(projectInstructions)

        ## Memory Core
        \(memoryCoreMarkdown)
        """
    }
}

// MARK: - ProjectMetadata (written to each project folder for Cowork import)

struct ProjectMetadata: Codable {
    let gizmoId: String
    let exportFolderName: String
    let conversationCount: Int
}

// MARK: - ClaudeProjectPackage

struct ClaudeProjectPackage: Identifiable {
    let id: String
    let name: String
    let packageDirectory: URL
    let projectInstructionsFile: URL
    let memoryCoreFile: URL
    let conversationFiles: [URL]
    let conversationCount: Int
}

// MARK: - Migration

struct MigrationSettings {
    let selectedConversations: Set<String>
    let includeMemoryCore: Bool
    let includeExport: Bool
    let includeProjects: Bool
    let outputDirectory: URL
}

enum StepState {
    case pending
    case inProgress(Double)
    case done
    case failed
}

// MARK: - Guided Import HUD

struct ImportStep: Identifiable {
    let id: Int
    let instruction: String
    let autoAction: StepAutoAction
    let actionStatusLabel: String?
}

enum StepAutoAction: Codable {
    case none
    case copyToClipboard(String)
    case revealInFinder(URL)
}

struct GuidedImportProgress: Codable {
    let packageIDs: [String]
    var completedPackageIDs: Set<String>
    var currentPackageID: String
    var currentStepIndex: Int
    var outputDirectory: URL
}

// MARK: - ExportResult

struct ExportResult {
    let outputDirectory: URL
    let packages: [ClaudeProjectPackage]
    let exportedConversations: Int
    let skippedConversations: Int
    let durationSeconds: Double
}

// MARK: - Node Tree Traversal

/// Reconstructs the conversation thread from ChatGPT's tree structure.
/// Collects all user/assistant messages from every node in the mapping (all branches).
func linearize(conversation: OpenAIConversation) -> [Message] {
    let mapping = conversation.mapping
    var result: [Message] = []
    for (_, node) in mapping {
        guard let msg = node.message else { continue }
        guard let role = MessageRole(rawValue: msg.author.role),
              (role == .user || role == .assistant),
              !extractText(from: msg.content).isEmpty
        else { continue }
        let text = extractText(from: msg.content)
        let date = msg.createTime.map { Date(timeIntervalSince1970: $0) } ?? conversation.createdAt
        result.append(Message(id: msg.id, role: role, text: text, createdAt: date))
    }
    result.sort { $0.createdAt < $1.createdAt }
    return result
}

private func extractText(from content: OpenAIContent) -> String {
    guard let parts = content.parts else { return "" }
    return parts.compactMap { $0.textValue }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

private extension MessageRole {
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "user", "human": self = .user
        case "assistant", "model": self = .assistant
        case "system": self = .system
        case "tool": self = .tool
        default: return nil
        }
    }
}
