//
//  WizardViewModel.swift
//  NeuralJack
//

import AppKit
import Foundation

/// Orchestrates the step-by-step migration wizard.
/// Replaces the old ImportSummary → MigrationProgress → Results dashboard flow.
@MainActor
@Observable
final class WizardViewModel {

    // MARK: - Step Definition

    enum Step: Equatable {
        case setup
        case dataSummary
        case memoryCore
        case projects
        case conversations
        case complete

        var title: String {
            switch self {
            case .setup:         return "Connect Claude"
            case .dataSummary:   return "Your Data"
            case .memoryCore:    return "Memory Core"
            case .projects:      return "Projects"
            case .conversations: return "Conversations"
            case .complete:      return "All Done"
            }
        }
    }

    // MARK: - Services

    private let anthropicService: AnthropicService
    private let exportService: ExportService

    // MARK: - Source

    let export: OpenAIExport

    // MARK: - Setup Step State

    var apiKeyInput: String = ""
    var hasAPIKey: Bool = false
    var isValidatingKey: Bool = false
    var keyValidationError: String?
    var keyValidationSuccess: Bool = false
    var useCowork: Bool = false
    var outputDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeuralJack", isDirectory: true)
    }()

    /// True when the user has explicitly selected the output folder via NSOpenPanel (grants write permission).
    var hasUserChosenOutputDirectory: Bool = false

    /// Options set on the Your Data screen; control which steps run.
    var includeMemoryCore: Bool = false
    var includeExportLog: Bool = false

    /// On Memory Core Setup step: true = use API key to generate; false = write Cowork prompt to output folder.
    var useAPIKeyForMemoryCore: Bool = true

    // MARK: - Memory Core Step State

    enum MemoryCorePhase { case ready, generating, done, skipped, failed }
    var memoryCorePhase: MemoryCorePhase = .ready
    var memoryCoreProgress: Double = 0
    var memoryCore: MemoryCore?
    var memoryCoreError: String?

    /// True when the Cowork memory-core prompt file was written to the export folder (user chose not to use API key).
    var coworkMemoryPromptFileWritten: Bool = false

    /// Snapshot of selected project indices when the user left the Projects step (used to detect changes when they go back).
    private(set) var projectIndicesAtMemoryCoreCommit: Set<Int>? = nil

    // MARK: - Project Step State

    /// Indices of project groups selected for export. All selected by default.
    var selectedProjectIndices: Set<Int> = []

    enum ProjectPhase { case ready, exporting, done, failed }
    var projectPhases: [String: ProjectPhase] = [:]
    var projectProgress: [String: Double] = [:]
    var projectErrors: [String: String] = [:]
    var migratedPackages: [String: ClaudeProjectPackage] = [:]

    /// When batch-exporting, current index (1-based) and total for "Exporting 2 of 5" label.
    var exportingProjectCurrent: Int = 0
    var exportingProjectTotal: Int = 0

    // MARK: - Conversations Step State

    var conversationsPhase: ProjectPhase = .ready
    var conversationsProgress: Double = 0
    var conversationsPackage: ClaudeProjectPackage?
    var conversationsError: String?

    // MARK: - Completion Step State

    var isExportingLog: Bool = false
    var logFileURL: URL?
    var logExportError: String?

    // MARK: - Navigation

    var currentStep: Step = .dataSummary

    // MARK: - Init

    /// Export folder name with timestamp, e.g. "NeuralJack Export 202503161430"
    private let exportFolderName: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmm"
        return "NeuralJack Export " + f.string(from: Date())
    }()

    init(export: OpenAIExport, anthropicService: AnthropicService, exportService: ExportService, defaultOutputDirectory: URL? = nil) {
        self.export = export
        self.anthropicService = anthropicService
        self.exportService = exportService
        self.hasAPIKey = (try? KeychainService.shared.load(for: .anthropicAPIKey)) != nil
        self.useAPIKeyForMemoryCore = self.hasAPIKey
        if let dir = defaultOutputDirectory {
            self.outputDirectory = dir
        }
        self.selectedProjectIndices = Set(export.projectGroups.indices)
    }

    // MARK: - Computed

    var projectGroups: [ProjectGroup] { export.projectGroups }

    var uncategorizedConversations: [OpenAIConversation] {
        let projectIds = Set(export.projectGroups.flatMap(\.conversations).map(\.id))
        return export.conversations.filter { !projectIds.contains($0.id) }
    }

    var hasUncategorizedConversations: Bool { !uncategorizedConversations.isEmpty }

    var stepList: [Step] {
        var steps: [Step] = [.dataSummary]
        if !projectGroups.isEmpty {
            steps.append(.projects)
        }
        if includeMemoryCore && !projectGroups.isEmpty {
            steps.append(.memoryCore)
        }
        if hasUncategorizedConversations { steps.append(.conversations) }
        steps.append(.complete)
        return steps
    }

    var currentStepIndex: Int {
        stepList.firstIndex(of: currentStep) ?? 0
    }

    var totalSteps: Int { stepList.count }

    var canGoBack: Bool {
        currentStepIndex > 0 && !isCurrentStepBusy
    }

    var isCurrentStepBusy: Bool {
        switch currentStep {
        case .memoryCore:
            return memoryCorePhase == .generating
        case .projects:
            return projectGroups.indices.contains(where: { projectPhases[projectGroups[$0].id] == .exporting })
        case .conversations:
            return conversationsPhase == .exporting
        case .complete:
            return isExportingLog
        default:
            return isValidatingKey
        }
    }

    var selectedProjectsCount: Int { selectedProjectIndices.count }

    var allSelectedProjectsDone: Bool {
        selectedProjectIndices.allSatisfy { index in
            guard projectGroups.indices.contains(index) else { return true }
            return migratedPackages[projectGroups[index].id] != nil
        }
    }

    var allProjectsDone: Bool {
        projectGroups.allSatisfy { group in
            migratedPackages[group.id] != nil
        }
    }

    var migratedCount: Int { migratedPackages.count }

    /// True when any projects or uncategorized conversations were exported (has prompt files).
    var hasExportedProjects: Bool { migratedCount > 0 || conversationsPackage != nil }

    /// Total conversation files exported across all migrated projects.
    var totalExportedConversationCount: Int {
        migratedPackages.values.reduce(0) { $0 + $1.conversationCount }
    }

    /// Total conversation files exported (projects + uncategorized).
    var totalExportedConversationFiles: Int {
        totalExportedConversationCount + (conversationsPackage?.conversationCount ?? 0)
    }

    // MARK: - Navigation

    func nextStep() {
        let idx = currentStepIndex
        guard idx < stepList.count - 1 else { return }
        currentStep = stepList[idx + 1]
    }

    func previousStep() {
        let idx = currentStepIndex
        guard idx > 0 else { return }
        currentStep = stepList[idx - 1]
    }

    func goTo(_ step: Step) {
        guard stepList.contains(step) else { return }
        currentStep = step
    }

    // MARK: - Footer primary button (used by WizardNavBar)

    var primaryFooterButtonTitle: String {
        switch currentStep {
        case .dataSummary:
            return "Start Migration"
        case .setup:
            return hasAPIKey ? "Continue" : "Continue without API key"
        case .projects:
            if isCurrentStepBusy { return "Exporting…" }
            if allSelectedProjectsDone || selectedProjectsCount == 0 { return "Continue" }
            return "Export \(selectedProjectsCount) selected"
        case .conversations:
            if conversationsPhase == .exporting { return "Exporting…" }
            if conversationsPackage != nil { return "Continue" }
            if conversationsPhase == .failed { return "Skip" }
            return "Export Conversations"
        case .complete:
            return "Open Export Folder"
        case .memoryCore:
            if memoryCorePhase == .generating { return "Generating…" }
            return "Continue"
        }
    }

    var primaryFooterButtonDisabled: Bool {
        if isCurrentStepBusy { return true }
        if currentStep == .dataSummary, !hasUserChosenOutputDirectory { return true }
        if currentStep == .projects, selectedProjectsCount == 0 { return true }
        if currentStep == .memoryCore, useAPIKeyForMemoryCore, !hasAPIKey { return true }
        return false
    }

    func handlePrimaryFooterAction() async {
        switch currentStep {
        case .dataSummary, .setup:
            nextStep()
        case .memoryCore:
            if useAPIKeyForMemoryCore && hasAPIKey {
                await generateMemoryCore()
            } else {
                do {
                    let prompt = makeCoworkMemoryPrompt()
                    try exportService.writeCoworkMemoryPrompt(prompt, to: outputDirectory, exportFolderName: exportFolderName)
                    memoryCorePhase = .skipped
                    coworkMemoryPromptFileWritten = true
                    nextStep()
                } catch {
                    memoryCoreError = "Could not write prompt to export folder. Try choosing a different folder in Your Data."
                    memoryCorePhase = .failed
                }
            }
        case .projects:
            if allSelectedProjectsDone || selectedProjectsCount == 0 {
                projectIndicesAtMemoryCoreCommit = selectedProjectIndices
                nextStep()
            } else {
                await exportSelectedProjects()
                if allSelectedProjectsDone {
                    projectIndicesAtMemoryCoreCommit = selectedProjectIndices
                    nextStep()
                }
            }
        case .conversations:
            if conversationsPackage != nil {
                nextStep()
            } else if conversationsPhase == .failed {
                nextStep()
            } else {
                await exportUncategorized()
                if conversationsPackage != nil {
                    nextStep()
                }
            }
        case .complete:
            openOutputFolder()
        }
    }

    // MARK: - API Key Management

    func refreshAPIKeyStatus() {
        let wasKey = hasAPIKey
        hasAPIKey = (try? KeychainService.shared.load(for: .anthropicAPIKey)) != nil
        if !hasAPIKey && wasKey {
            // Key removed — disable memory file option and skip memory core step if we're on it
            includeMemoryCore = false
            if currentStep == .memoryCore {
                currentStep = stepList.first ?? .dataSummary
            }
        }
    }

    func validateAndSaveKey() async {
        guard !apiKeyInput.isEmpty else { return }
        isValidatingKey = true
        keyValidationError = nil
        keyValidationSuccess = false

        do {
            let valid = try await anthropicService.validateAPIKey(apiKeyInput)
            if valid {
                try KeychainService.shared.save(key: apiKeyInput, for: .anthropicAPIKey)
                hasAPIKey = true
                keyValidationSuccess = true
                apiKeyInput = ""
            } else {
                keyValidationError = "Key appears invalid. Check it and try again."
            }
        } catch let error as AppError {
            keyValidationError = error.errorDescription ?? error.localizedDescription
        } catch {
            keyValidationError = "Could not validate: \(error.localizedDescription)"
        }

        isValidatingKey = false
    }

    func removeAPIKey() {
        try? KeychainService.shared.delete(for: .anthropicAPIKey)
        hasAPIKey = false
        keyValidationSuccess = false
    }

    func maskedAPIKey() -> String? {
        guard hasAPIKey,
              let key = try? KeychainService.shared.load(for: .anthropicAPIKey) else { return nil }
        let prefix = String(key.prefix(12))
        return prefix + String(repeating: "•", count: 8)
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Select where to save your export. NeuralJack needs permission to write files here."
        panel.directoryURL = outputDirectory
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.outputDirectory = url
                self?.hasUserChosenOutputDirectory = true
            }
        }
    }

    /// Prompts the user to select the output folder via NSOpenPanel if not yet chosen. Returns true if we have write access.
    func requestOutputDirectoryAccessIfNeeded() async -> Bool {
        if hasUserChosenOutputDirectory { return true }
        return await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Select Export Folder"
            panel.message = "NeuralJack needs permission to save your export. Please select a folder (e.g. Documents or Desktop)."
            panel.directoryURL = outputDirectory
            panel.begin { [weak self] response in
                Task { @MainActor in
                    if response == .OK, let url = panel.url, let self = self {
                        self.outputDirectory = url
                        self.hasUserChosenOutputDirectory = true
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    /// Builds a prompt the user can paste into Claude Desktop Cowork to generate a Memory Core from the export (when they don't use an API key).
    /// References only selected projects and uses full paths to their export folders.
    func makeCoworkMemoryPrompt() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        let rangeStr: String
        if let range = export.dateRange {
            rangeStr = "\(df.string(from: range.lowerBound)) – \(df.string(from: range.upperBound))"
        } else {
            rangeStr = "—"
        }
        let selectedGroups = selectedProjectIndices.sorted().compactMap { projectGroups.indices.contains($0) ? projectGroups[$0] : nil }
        let exportRoot = outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true)
        let projectsDir = exportRoot.appendingPathComponent("projects", isDirectory: true)
        let projectPaths = selectedGroups.map { group in
            let folderName = exportService.projectExportFolderName(for: group)
            return projectsDir.appendingPathComponent(folderName, isDirectory: true).path
        }
        let selectedConversationCount = selectedGroups.reduce(0) { $0 + $1.conversations.count }
        let projectNames = selectedGroups.map(\.name).joined(separator: ", ")
        let pathsBlock = projectPaths.isEmpty ? "" : """
        **Paths to exported project folders (use these to read the conversation files):**
        \(projectPaths.map { "- \($0)" }.joined(separator: "\n"))

        """
        return """
        I exported my ChatGPT data and want to create a **Memory Core** — a short context document (facts, preferences, background) from my conversation history that I can reuse in Claude.

        **Export summary:**
        - **Conversations (selected):** \(selectedConversationCount)
        - **Projects (selected):** \(selectedGroups.isEmpty ? "None" : projectNames)
        - **Date range:** \(rangeStr)

        **Path to my export folder:** \(exportRoot.path)
        (Open or add this folder in Claude so you can read the exported conversation files.)

        \(pathsBlock)Please generate a Memory Core document for me:
        - Markdown, under ~800 words
        - Present tense, written as if describing me to an AI
        - Factual and specific (no vague generalities)
        - Based on the exported conversation data in the paths above. If you have access to my exported files, use them; otherwise use this summary and any details I add below.

        I'll paste the result into my Claude project instructions.
        """
    }

    // MARK: - Memory Core

    func generateMemoryCore() async {
        guard hasAPIKey else { return }
        let selectedConversations = selectedProjectIndices.flatMap { projectGroups[$0].conversations }
        guard !selectedConversations.isEmpty else {
            memoryCoreError = "Select at least one project to generate Memory Core."
            memoryCorePhase = .failed
            return
        }
        memoryCorePhase = .generating
        memoryCoreProgress = 0
        memoryCoreError = nil

        do {
            let core = try await anthropicService.synthesizeMemoryCore(
                conversations: selectedConversations,
                memoryEntries: export.memoryEntries,
                progress: { [weak self] p in
                    Task { @MainActor in self?.memoryCoreProgress = p }
                }
            )
            do {
                try exportService.writeMemoryCoreOnly(core, to: outputDirectory, exportFolderName: exportFolderName)
                memoryCore = core
                memoryCorePhase = .done
                writeImportPromptIfNeeded()
                goTo(.complete)
            } catch {
                memoryCoreError = "Could not write to the export folder. Try choosing a different folder in Your Data."
                memoryCorePhase = .failed
            }
        } catch let error as AppError {
            memoryCoreError = error.errorDescription ?? error.localizedDescription
            memoryCorePhase = .failed
        } catch {
            memoryCoreError = error.localizedDescription
            memoryCorePhase = .failed
        }
    }

    func skipMemoryCore() {
        memoryCorePhase = .skipped
        nextStep()
    }

    /// Call when project selection may have changed (e.g. from Projects step). Resets Memory Core state so a new one can be generated for the new selection.
    func checkProjectSelectionChangedAndResetMemoryCoreIfNeeded() {
        guard let committed = projectIndicesAtMemoryCoreCommit else { return }
        guard selectedProjectIndices != committed else { return }
        resetMemoryCoreForNewProjectSelection()
    }

    /// Resets Memory Core step so the user can generate a new memory core (e.g. after changing project selection).
    func resetMemoryCoreForNewProjectSelection() {
        memoryCorePhase = .ready
        memoryCore = nil
        coworkMemoryPromptFileWritten = false
        memoryCoreError = nil
        projectIndicesAtMemoryCoreCommit = selectedProjectIndices
    }

    // MARK: - Project Migration

    func migrateProject(at index: Int) async {
        guard projectGroups.indices.contains(index) else { return }
        let group = projectGroups[index]

        projectPhases[group.id] = .exporting
        projectProgress[group.id] = 0
        projectErrors[group.id] = nil

        do {
            let (pkgs, _) = try await exportService.exportToNeuralJackFormat(
                [group],
                memoryCore: memoryCore,
                to: outputDirectory,
                exportFolderName: exportFolderName,
                includeProjects: true,
                includeExport: true,
                progress: { [weak self] p in
                    Task { @MainActor in self?.projectProgress[group.id] = p }
                }
            )
            migratedPackages[group.id] = pkgs.first
            projectPhases[group.id] = .done
        } catch let error as AppError {
            projectErrors[group.id] = error.errorDescription ?? error.localizedDescription
            projectPhases[group.id] = .failed
        } catch {
            projectErrors[group.id] = error.localizedDescription
            projectPhases[group.id] = .failed
        }
    }

    func skipProject(at index: Int) {
        guard projectGroups.indices.contains(index) else { return }
        nextStep()
    }

    func toggleProjectSelection(_ index: Int) {
        guard projectGroups.indices.contains(index) else { return }
        if selectedProjectIndices.contains(index) {
            selectedProjectIndices.remove(index)
        } else {
            selectedProjectIndices.insert(index)
        }
    }

    /// True when every project is selected.
    var allProjectsSelected: Bool {
        !projectGroups.isEmpty && selectedProjectIndices.count == projectGroups.count
    }

    /// True when some (but not all) projects are selected.
    var someProjectsSelected: Bool {
        let n = selectedProjectIndices.count
        return n > 0 && n < projectGroups.count
    }

    func setAllProjectsSelected(_ selected: Bool) {
        if selected {
            selectedProjectIndices = Set(projectGroups.indices)
        } else {
            selectedProjectIndices = []
        }
    }

    /// Exports all selected projects in order. Sets exportingProjectCurrent/Total for progress label.
    func exportSelectedProjects() async {
        let sorted = selectedProjectIndices.sorted()
        exportingProjectTotal = sorted.count
        for (oneBased, index) in sorted.enumerated() {
            exportingProjectCurrent = oneBased + 1
            await migrateProject(at: index)
        }
        exportingProjectCurrent = 0
        exportingProjectTotal = 0
        writeImportPromptIfNeeded()
    }

    // MARK: - Uncategorized Conversations

    func exportUncategorized() async {
        guard !uncategorizedConversations.isEmpty else { return }
        conversationsPhase = .exporting
        conversationsProgress = 0
        conversationsError = nil

        let group = ProjectGroup(id: "general", name: "General Conversations", conversations: uncategorizedConversations)

        do {
            let (pkgs, _) = try await exportService.exportToNeuralJackFormat(
                [group],
                memoryCore: memoryCore,
                to: outputDirectory,
                exportFolderName: exportFolderName,
                includeProjects: false,
                includeExport: true,
                progress: { [weak self] p in
                    Task { @MainActor in self?.conversationsProgress = p }
                }
            )
            conversationsPackage = pkgs.first
            conversationsPhase = .done
            writeImportPromptIfNeeded()
        } catch let error as AppError {
            conversationsError = error.errorDescription ?? error.localizedDescription
            conversationsPhase = .failed
        } catch {
            conversationsError = error.localizedDescription
            conversationsPhase = .failed
        }
    }

    // MARK: - Import Prompt (written to export folder)

    private func writeImportPromptIfNeeded() {
        var folderNames: [String] = migratedPackages.values.map { $0.packageDirectory.lastPathComponent }
        var projectMetadata: [(gizmoId: String, folderName: String, conversationCount: Int)] = migratedPackages.map { ($0.key, $0.value.packageDirectory.lastPathComponent, $0.value.conversationCount) }
        if let pkg = conversationsPackage {
            folderNames.append(pkg.packageDirectory.lastPathComponent)
            projectMetadata.append((pkg.id, pkg.packageDirectory.lastPathComponent, pkg.conversationCount))
        }
        do {
            try exportService.writeImportPrompt(
                to: outputDirectory,
                exportFolderName: exportFolderName,
                projectFolderNames: folderNames,
                hasMemoryCore: memoryCore != nil
            )
            try exportService.writeCoworkImportPrompt(
                to: outputDirectory,
                exportFolderName: exportFolderName,
                projectMetadata: projectMetadata,
                hasMemoryCore: memoryCore != nil
            )
        } catch {
            print("[Wizard] Could not write import prompts: \(error)")
        }
    }

    // MARK: - Cowork Prompt (legacy, used by WizardProjectStepView)

    func coworkPrompt(for group: ProjectGroup) -> String {
        let projectDir: URL
        if let pkg = migratedPackages[group.id] {
            projectDir = pkg.packageDirectory
        } else {
            let folderName = group.id == "general" ? "Uncategorized" : group.name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
            projectDir = outputDirectory
                .appendingPathComponent(exportFolderName)
                .appendingPathComponent("projects")
                .appendingPathComponent(folderName)
        }

        let hasInstructions = memoryCore != nil

        return """
        I need your help creating a new project in Claude.ai. Please open a browser and complete these steps:

        **Project Name:** \(group.name)
        **Conversations:** \(group.conversations.count) files to upload
        **Files location:** \(projectDir.path)

        **Steps:**
        1. Navigate to https://claude.ai/projects
        2. Click "New Project" in the left sidebar
        3. Set the project name to exactly: **\(group.name)**
        4. Click "Create project"
        5. In the knowledge panel, click "Add content"
        6. Upload all `.md` files from: `\(projectDir.appendingPathComponent("conversations").path)`\(hasInstructions ? "\n        7. Click the pencil icon next to \"Project Instructions\"\n        8. Copy the contents of `_project-instructions.md` from the project folder and paste them in\n        9. Click Save" : "")

        Once complete, confirm the project "\(group.name)" is visible in Claude.ai.
        """
    }

    // MARK: - Export Log

    func exportLog() {
        isExportingLog = true
        logExportError = nil

        let projectSummary = projectGroups.map { group -> String in
            let status = migratedPackages[group.id] != nil ? "✓ Exported" : "⊘ Skipped"
            return "- \(group.name) (\(group.conversations.count) conversations) — \(status)"
        }.joined(separator: "\n")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var generatedFiles: [String] = ["- **log.md** — This migration log"]
        if memoryCore != nil {
            generatedFiles.append("- **memory-core.md** — Context document for Claude project instructions")
        }
        if hasExportedProjects {
            generatedFiles.append("- **claude-cowork-import-prompt.md** — Prompt for Claude Cowork (automated import)")
            generatedFiles.append("- **claude-import-manual-prompt.md** — Prompt for manual import via Claude Chat")
            for (_, pkg) in migratedPackages.sorted(by: { $0.value.packageDirectory.lastPathComponent < $1.value.packageDirectory.lastPathComponent }) {
                let folder = pkg.packageDirectory.lastPathComponent
                generatedFiles.append("- **projects/\(folder)/** — _project-instructions.md, _project-metadata.json, conversations/*.md (\(pkg.conversationCount) file\(pkg.conversationCount == 1 ? "" : "s"))")
            }
        }
        let generatedFilesSection = generatedFiles.joined(separator: "\n")

        let log = """
        # NeuralJack Migration Log
        *Generated: \(dateFormatter.string(from: Date()))*

        ---

        ## Source Data
        - **Account:** \(export.user?.email ?? export.user?.id ?? "Unknown")
        - **Conversations:** \(export.conversationCount)
        - **Projects:** \(export.projectCount)

        ## What Was Done
        - **Output folder:** \(outputDirectory.appendingPathComponent(exportFolderName).path)
        - **Memory Core generated:** \(memoryCore != nil ? "Yes" : "No")
        - **Projects exported:** \(migratedPackages.count) of \(projectGroups.count)
        - **Uncategorized conversations:** \(conversationsPackage != nil ? "Exported" : "Skipped")

        ## Generated Files
        \(generatedFilesSection)

        ## Projects
        \(projectSummary)

        ---

        *Generated by NeuralJack*
        *https://github.com/kidhack/NeuralJack*
        """

        do {
            let exportRoot = outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true)
            try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
            let logURL = exportRoot.appendingPathComponent("log.md")
            try log.write(to: logURL, atomically: true, encoding: .utf8)
            logFileURL = logURL
        } catch {
            logExportError = error.localizedDescription
        }

        isExportingLog = false
    }

    // MARK: - Helpers

    func outputFolderPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let full = outputDirectory.path
        return full.hasPrefix(home) ? "~" + full.dropFirst(home.count) : full
    }

    /// URL for memory-core.md in the export folder (after first export). Use for "View in Finder".
    func memoryCoreFileURL() -> URL {
        outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true).appendingPathComponent("memory-core.md")
    }

    /// URL for a file in the export folder (e.g. prompt .md files).
    func exportFolderFileURL(filename: String) -> URL {
        outputDirectory.appendingPathComponent(exportFolderName, isDirectory: true).appendingPathComponent(filename)
    }

    func openOutputFolder() {
        let exportDir = outputDirectory.appendingPathComponent(exportFolderName)
        let target = FileManager.default.fileExists(atPath: exportDir.path) ? exportDir : outputDirectory
        NSWorkspace.shared.open(target)
    }

    func openClaudeProjects() {
        guard let url = URL(string: "https://claude.ai/projects") else { return }
        NSWorkspace.shared.open(url)
    }

    func revealPackage(for group: ProjectGroup) {
        guard let pkg = migratedPackages[group.id] else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: pkg.packageDirectory.path)
    }

    private func emptyMemoryCore() -> MemoryCore {
        MemoryCore(
            markdown: "",
            generatedAt: Date(),
            sourceConversationCount: 0,
            sourceMemoryEntryCount: 0,
            tokenCount: nil
        )
    }
}
