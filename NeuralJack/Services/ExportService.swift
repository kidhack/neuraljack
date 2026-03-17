//
//  ExportService.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation

/// Packages and exports project files to disk in NeuralJack format.
/// See docs/DATA_MODEL.md for the export structure.
final class ExportService {
    private let anthropicService: AnthropicService

    init(anthropicService: AnthropicService = AnthropicService()) {
        self.anthropicService = anthropicService
    }

    /// Exports to [exportFolderName]/ with project-based structure.
    /// - Parameters:
    ///   - projectGroups: Groups from OpenAIExport (filter by selectedConversations first).
    ///   - memoryCore: Synthesized Memory Core; written to root when non-nil and non-empty. Omit when skipped.
    ///   - outputDirectory: User's chosen output folder (e.g. ~/Documents).
    ///   - exportFolderName: Name of the export folder inside outputDirectory (e.g. "NeuralJack Export 202503161430").
    ///   - includeProjects: Create project folders and _project-instructions.md.
    ///   - includeExport: Write conversation markdown files.
    func exportToNeuralJackFormat(
        _ projectGroups: [ProjectGroup],
        memoryCore: MemoryCore?,
        to outputDirectory: URL,
        exportFolderName: String = "NeuralJack-Export",
        includeProjects: Bool,
        includeExport: Bool,
        progress: @escaping (Double) -> Void
    ) async throws -> (packages: [ClaudeProjectPackage], result: ExportResult) {
        let start = Date()
        let accessing = outputDirectory.startAccessingSecurityScopedResource()
        defer { if accessing { outputDirectory.stopAccessingSecurityScopedResource() } }

        print("[Export] Starting export to: \(outputDirectory.path)")
        print("[Export] Output dir exists: \(FileManager.default.fileExists(atPath: outputDirectory.path))")
        print("[Export] Projects count: \(projectGroups.count)")
        let totalConvs = projectGroups.reduce(0) { $0 + $1.conversations.count }
        print("[Export] Total conversations: \(totalConvs)")

        let parentDir = outputDirectory.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parentDir.path) else {
            print("[Export] ❌ Parent directory does not exist: \(parentDir.path)")
            throw AppError.exportFailed("Output parent directory does not exist")
        }

        guard !projectGroups.isEmpty else {
            print("[Export] ❌ No project groups to export")
            throw AppError.exportFailed("No project groups to export")
        }

        let exportRoot = outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        } catch {
            print("[Export] ❌ FAILED creating export root: \(error)")
            print("[Export] ❌ Localized: \(error.localizedDescription)")
            throw AppError.exportFailed("Could not create output directory: \(error.localizedDescription)")
        }

        let projectsDir = exportRoot.appendingPathComponent("projects", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        } catch {
            print("[Export] ❌ FAILED creating projects dir: \(error)")
            throw AppError.exportFailed("Could not create projects directory: \(error.localizedDescription)")
        }

        if let core = memoryCore, !core.markdown.isEmpty {
            let memoryCoreURL = exportRoot.appendingPathComponent("memory-core.md")
            print("[Export] Writing file: \(memoryCoreURL.path)")
            do {
                try core.markdown.write(to: memoryCoreURL, atomically: true, encoding: .utf8)
            } catch {
                print("[Export] ❌ FAILED writing memory-core.md: \(error)")
                throw AppError.exportFailed("Could not write memory-core.md: \(error.localizedDescription)")
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let messageFormatter = DateFormatter()
        messageFormatter.dateStyle = .medium
        messageFormatter.timeStyle = .short

        var packages: [ClaudeProjectPackage] = []
        var totalExported = 0
        var totalSkipped = 0
        let total = Double(projectGroups.count)
        for (index, group) in projectGroups.enumerated() {
            let folderName = group.id == "general" ? "Uncategorized" : sanitizeProjectName(group.name)
            let projectDir = projectsDir.appendingPathComponent(folderName, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
            } catch {
                print("[Export] ❌ FAILED creating project dir \(folderName): \(error)")
                throw AppError.exportFailed("Could not create project folder '\(folderName)': \(error.localizedDescription)")
            }

            print("[Export] Creating project folder: \(folderName) (\(group.conversations.count) conversations)")

            let instructionsContent = placeholderProjectInstructions(
                projectName: group.name,
                conversationCount: group.conversations.count,
                dateRange: dateRange(for: group.conversations)
            )
            let instructionsFile = projectDir.appendingPathComponent("_project-instructions.md")
            print("[Export] Writing file: \(instructionsFile.path)")
            do {
                try instructionsContent.write(to: instructionsFile, atomically: true, encoding: .utf8)
            } catch {
                print("[Export] ❌ FAILED writing _project-instructions.md: \(error)")
                throw AppError.exportFailed("Could not write project instructions: \(error.localizedDescription)")
            }

            let metadata = ProjectMetadata(gizmoId: group.id, exportFolderName: folderName, conversationCount: group.conversations.count)
            let metadataFile = projectDir.appendingPathComponent("_project-metadata.json")
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(metadata).write(to: metadataFile)
            } catch {
                print("[Export] ❌ FAILED writing _project-metadata.json: \(error)")
                throw AppError.exportFailed("Could not write project metadata: \(error.localizedDescription)")
            }

            let convDir = projectDir.appendingPathComponent("conversations", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: convDir, withIntermediateDirectories: true)
            } catch {
                print("[Export] ❌ FAILED creating conversations dir: \(error)")
                throw AppError.exportFailed("Could not create conversations directory: \(error.localizedDescription)")
            }

            var conversationFiles: [URL] = []
            if includeExport {
                for conv in group.conversations {
                    let messages = linearize(conversation: conv)
                    if messages.isEmpty {
                        totalSkipped += 1
                        continue
                    }
                    let markdown = formatConversationMarkdown(title: conv.title, messages: messages, formatter: messageFormatter)
                    let fileName = conversationFileName(title: conv.title, createdAt: conv.createdAt, dateFormatter: dateFormatter)
                    let fileURL = convDir.appendingPathComponent(fileName)
                    print("[Export] Writing file: \(fileURL.path)")
                    do {
                        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
                    } catch {
                        print("[Export] ❌ FAILED writing conversation \(fileName): \(error)")
                        throw AppError.exportFailed("Could not write conversation file: \(error.localizedDescription)")
                    }
                    conversationFiles.append(fileURL)
                    totalExported += 1
                }
            }

            let memoryCoreFile = exportRoot.appendingPathComponent("memory-core.md")
            packages.append(ClaudeProjectPackage(
                id: group.id,
                name: group.name,
                packageDirectory: projectDir,
                projectInstructionsFile: instructionsFile,
                memoryCoreFile: memoryCoreFile,
                conversationFiles: conversationFiles,
                conversationCount: conversationFiles.count
            ))

            progress((Double(index + 1)) / total)
        }

        let duration = Date().timeIntervalSince(start)
        let result = ExportResult(
            outputDirectory: exportRoot,
            packages: packages,
            exportedConversations: totalExported,
            skippedConversations: totalSkipped,
            durationSeconds: duration
        )
        return (packages, result)
    }

    /// Writes claude-import-manual-prompt.md to the export folder. Paste into Claude chat; you provide project names and it guides you step by step.
    func writeImportPrompt(
        to outputDirectory: URL,
        exportFolderName: String,
        projectFolderNames: [String],
        hasMemoryCore: Bool
    ) throws {
        let accessing = outputDirectory.startAccessingSecurityScopedResource()
        defer { if accessing { outputDirectory.stopAccessingSecurityScopedResource() } }
        let exportRoot = outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        let exportPath = exportRoot.path
        let projectsList = projectFolderNames.isEmpty
            ? ""
            : projectFolderNames.map { "- \($0)" }.joined(separator: "\n")
        let prompt = """
        # NeuralJack — Migrate manually with Claude Chat

        ## Instructions for you (do not paste this section)

        1. Open [Claude](https://claude.ai) in a new chat.
        2. Copy **only** the section below titled **"Prompt for Claude"** (from the line after the divider to the end).
        3. Paste it into the chat. The export path is already included so Claude can reference it.

        ---

        ## Prompt for Claude

        Copy everything below this line and paste into Claude chat.

        ---

        I have exported my ChatGPT conversations into a folder. Help me import them into Claude.ai projects.

        **Export folder path:**
        `\(exportPath)`

        **Folder structure:**
        - `projects/` — One subfolder per project, each containing:
          - `conversations/` — Markdown files of the conversations
          - `_project-instructions.md` — Suggested project instructions
        \(hasMemoryCore ? "- `memory-core.md` — My context document (paste into Project Instructions)\n" : "")

        **Project folders to import:**
        \(projectsList.isEmpty ? "(none)" : projectsList)

        **What I need you to do:**

        1. For **each** project folder above, ask me: "What name do you want for the project: [folder name]?" Use my answer or the folder name if I say to keep it.

        2. For each project:
           - Read the conversation markdown files in that project's `conversations/` subfolder.
           - Use them as context to generate or refine project instructions (what Claude should know and how to behave for that project).
           - If `_project-instructions.md` exists, use it as a starting point and improve it based on the conversations.
           - Guide me to create the project in claude.ai, upload the conversation files, and add the project instructions.

        3. Help me complete each project before moving to the next.
        """
        let url = exportRoot.appendingPathComponent("claude-import-manual-prompt.md")
        try prompt.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Writes claude-cowork-import-prompt.md for use with Claude Cowork.
    /// Paste into Cowork; it uses browser automation to get project names from chatgpt.com and import to Claude.
    func writeCoworkImportPrompt(
        to outputDirectory: URL,
        exportFolderName: String,
        projectMetadata: [(gizmoId: String, folderName: String, conversationCount: Int)],
        hasMemoryCore: Bool
    ) throws {
        let accessing = outputDirectory.startAccessingSecurityScopedResource()
        defer { if accessing { outputDirectory.stopAccessingSecurityScopedResource() } }
        let exportRoot = outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        let exportPath = exportRoot.path
        let projectsList = projectMetadata.isEmpty
            ? "(none)"
            : projectMetadata.map { "- \($0.folderName) (gizmoId: \($0.gizmoId), \($0.conversationCount) conversations)" }.joined(separator: "\n")
        let prompt = """
        # NeuralJack — Migrate with Claude Cowork

        ## Instructions for you (do not paste this section)

        1. Open **Claude Cowork** (native app only).
        2. Copy **only** the section below titled **"Prompt for Claude"** (from the line after the divider to the end).
        3. Paste it into Cowork. The export path is already included so Claude can read your files and use browser automation to match ChatGPT project names.

        ---

        ## Prompt for Claude

        Copy everything below this line and paste into Claude Cowork.

        ---

        I exported my ChatGPT conversations with NeuralJack. The project folders may have placeholder names like `Project 1a2b3c4d` instead of my actual project names from ChatGPT.

        **Export folder path:**
        `\(exportPath)`

        **Please do the following (using browser automation):**

        1. **Read my export structure**
           - Use the export path above; structure: `projects/[folder-name]/conversations/*.md`, `_project-instructions.md`, and `_project-metadata.json`
           - Each project folder has `_project-metadata.json` with `gizmoId` to match ChatGPT projects

        2. **Get real project names from ChatGPT**
           - Navigate to https://chatgpt.com
           - Ensure I'm logged in (or guide me to log in)
           - Open the projects sidebar or projects list
           - For each project, capture: project ID (gizmo ID from URL or DOM) and display name
           - Build a mapping: gizmoId → display name

        3. **Map export folders to ChatGPT names**
           - Project folders and their gizmoIds:
           \(projectsList)
           - Match each folder's gizmoId to the corresponding ChatGPT project
           - Use the ChatGPT display name for the Claude project

        4. **Create Claude projects and import**
           - For each project: go to claude.ai, create a new project using the **ChatGPT display name**
           - Upload all `.md` files from that project's `conversations/` subfolder
           - If `_project-instructions.md` exists, add its contents to Project Instructions

        5. **Memory Core**\(hasMemoryCore ? """
           - Add contents of `memory-core.md` (at export root) to project instructions where appropriate.
           """ : "\n           - (None in this export)")
        """
        let url = exportRoot.appendingPathComponent("claude-cowork-import-prompt.md")
        try prompt.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Writes only the memory core to [exportFolderName]/memory-core.md.
    /// Use when the user generates a memory core but has no projects to export yet.
    func writeMemoryCoreOnly(_ memoryCore: MemoryCore, to outputDirectory: URL, exportFolderName: String = "NeuralJack-Export") throws {
        let accessing = outputDirectory.startAccessingSecurityScopedResource()
        defer { if accessing { outputDirectory.stopAccessingSecurityScopedResource() } }
        let exportRoot = outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        let url = exportRoot.appendingPathComponent("memory-core.md")
        try memoryCore.markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Writes the Cowork memory-core prompt to [exportFolderName]/memory-core-cowork-prompt.md.
    func writeCoworkMemoryPrompt(_ prompt: String, to outputDirectory: URL, exportFolderName: String) throws {
        let accessing = outputDirectory.startAccessingSecurityScopedResource()
        defer { if accessing { outputDirectory.stopAccessingSecurityScopedResource() } }
        let exportRoot = outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        let url = exportRoot.appendingPathComponent("memory-core-cowork-prompt.md")
        try prompt.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Legacy API (for backward compatibility during migration)

    func packageProjects(
        _ projects: [ProjectGroup],
        memoryCore: MemoryCore,
        to directory: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> [ClaudeProjectPackage] {
        let (packages, _) = try await exportToNeuralJackFormat(
            projects,
            memoryCore: memoryCore,
            to: directory,
            includeProjects: true,
            includeExport: true,
            progress: progress
        )
        return packages
    }

    func exportConversations(
        _ conversations: [OpenAIConversation],
        to directory: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> ExportResult {
        let group = ProjectGroup(id: "general", name: "Uncategorized", conversations: conversations)
        let (_, result) = try await exportToNeuralJackFormat(
            [group],
            memoryCore: nil,
            to: directory,
            includeProjects: true,
            includeExport: true,
            progress: progress
        )
        return result
    }

    /// Folder name used under exportRoot/projects/ for this group (e.g. "Uncategorized" or sanitized name).
    func projectExportFolderName(for group: ProjectGroup) -> String {
        group.id == "general" ? "Uncategorized" : sanitizeProjectName(group.name)
    }

    // MARK: - Private helpers

    private func sanitizeProjectName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var result = name.unicodeScalars
            .map { invalid.contains($0) ? "-" : String($0) }
            .joined()
        result = result.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "  ", with: " ")
        if result.isEmpty { result = "Unnamed Project" }
        return String(result.prefix(60))
    }

    private func conversationFileName(title: String, createdAt: Date, dateFormatter: DateFormatter) -> String {
        let datePart = dateFormatter.string(from: createdAt)
        let sanitizedTitle = sanitizeProjectName(title)
        let base = "\(datePart) \(sanitizedTitle).md"
        return String(base.prefix(80))
    }

    private func placeholderProjectInstructions(projectName: String, conversationCount: Int, dateRange: String) -> String {
        """
        # \(projectName)
        ## Claude Project Instructions

        > This file will be populated with a synthesized system prompt
        > after Memory Core generation completes.
        >
        > Paste the contents into Claude Project Instructions when
        > setting up this project in claude.ai.

        ## Conversations in this project: \(conversationCount)
        ## Date range: \(dateRange)
        """
    }

    private func dateRange(for conversations: [OpenAIConversation]) -> String {
        let dates = conversations.map(\.createdAt)
        guard let min = dates.min(), let max = dates.max() else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: min)) – \(formatter.string(from: max))"
    }

    private func formatConversationMarkdown(title: String, messages: [Message], formatter: DateFormatter) -> String {
        var lines: [String] = ["# \(title)", ""]
        if let first = messages.first {
            lines.append("*\(formatter.string(from: first.createdAt)) · \(messages.count) messages*")
        }
        lines.append("")
        lines.append("---")
        lines.append("")
        for msg in messages {
            let label = msg.role == .user ? "You" : "Claude"
            lines.append("**\(label):** \(msg.text)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
