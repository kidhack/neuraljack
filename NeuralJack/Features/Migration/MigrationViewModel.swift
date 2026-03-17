//
//  MigrationViewModel.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation

/// Handles the migration pipeline: Memory Core synthesis, packaging, and export.
@MainActor
@Observable
final class MigrationViewModel {
    enum Phase {
        case idle
        case running
        case complete
    }

    enum Step: String, CaseIterable {
        case parseConversations
        case generateMemoryCore
        case packageProjects
        case exportConversations
    }

    private let anthropicService: AnthropicService
    private let exportService: ExportService

    var phase: Phase = .idle
    var stepStates: [Step: StepState] = [:]
    var memoryCore: MemoryCore?
    var packages: [ClaudeProjectPackage]?
    var exportResult: ExportResult?
    var errorMessage: String?
    private var isCancelled = false

    init(anthropicService: AnthropicService, exportService: ExportService) {
        self.anthropicService = anthropicService
        self.exportService = exportService
        for step in Step.allCases {
            stepStates[step] = .pending
        }
    }

    func startMigration(export: OpenAIExport, settings: MigrationSettings) async {
        phase = .running
        isCancelled = false
        errorMessage = nil
        memoryCore = nil
        packages = nil
        exportResult = nil
        for step in Step.allCases {
            stepStates[step] = .pending
        }
        stepStates[.parseConversations] = .done

        let selectedIds = settings.selectedConversations
        let selectedConversations = export.conversations.filter { selectedIds.contains($0.id) }
        let rawGroups = settings.includeProjects ? export.projectGroups : [ProjectGroup(id: "general", name: "Uncategorized", conversations: selectedConversations)]
        let projectGroups = rawGroups.map { group in
            ProjectGroup(
                id: group.id,
                name: group.name,
                conversations: group.conversations.filter { selectedIds.contains($0.id) }
            )
        }.filter { !$0.conversations.isEmpty }

        if settings.includeMemoryCore {
            stepStates[.generateMemoryCore] = .inProgress(0)
            do {
                let core = try await anthropicService.synthesizeMemoryCore(
                    conversations: selectedConversations,
                    memoryEntries: export.memoryEntries,
                    progress: { [weak self] p in
                        Task { @MainActor in
                            self?.stepStates[.generateMemoryCore] = .inProgress(p)
                        }
                    }
                )
                guard !isCancelled else { return }
                memoryCore = core
                stepStates[.generateMemoryCore] = .done
            } catch let error as AppError {
                stepStates[.generateMemoryCore] = .failed
                errorMessage = error.errorDescription ?? error.localizedDescription
                phase = .idle
                return
            } catch {
                stepStates[.generateMemoryCore] = .failed
                errorMessage = "Memory Core generation failed: \(error.localizedDescription)"
                phase = .idle
                return
            }
        } else {
            stepStates[.generateMemoryCore] = .done
        }

        let core = memoryCore ?? MemoryCore(
            markdown: "",
            generatedAt: Date(),
            sourceConversationCount: 0,
            sourceMemoryEntryCount: 0,
            tokenCount: nil
        )

        let shouldExport = settings.includeProjects || settings.includeExport
        if shouldExport {
            stepStates[.packageProjects] = .inProgress(0)
            stepStates[.exportConversations] = .inProgress(0)
            do {
                let (pkgs, result) = try await exportService.exportToNeuralJackFormat(
                    projectGroups.isEmpty ? [ProjectGroup(id: "general", name: "Uncategorized", conversations: selectedConversations)] : projectGroups,
                    memoryCore: core,
                    to: settings.outputDirectory,
                    includeProjects: settings.includeProjects,
                    includeExport: settings.includeExport,
                    progress: { [weak self] p in
                        Task { @MainActor in
                            self?.stepStates[.packageProjects] = .inProgress(p)
                            self?.stepStates[.exportConversations] = .inProgress(p)
                        }
                    }
                )
                guard !isCancelled else { return }
                packages = pkgs
                exportResult = result
                stepStates[.packageProjects] = .done
                stepStates[.exportConversations] = .done
            } catch let error as AppError {
                stepStates[.packageProjects] = .failed
                stepStates[.exportConversations] = .failed
                errorMessage = error.errorDescription ?? error.localizedDescription
                phase = .idle
                return
            } catch {
                stepStates[.packageProjects] = .failed
                stepStates[.exportConversations] = .failed
                errorMessage = "Export failed: \(error.localizedDescription)"
                phase = .idle
                return
            }
        } else {
            stepStates[.packageProjects] = .done
            stepStates[.exportConversations] = .done
        }
        phase = .complete
    }

    func cancel() {
        isCancelled = true
        phase = .idle
    }

    func reset() {
        phase = .idle
        memoryCore = nil
        packages = nil
        exportResult = nil
        errorMessage = nil
        for step in Step.allCases { stepStates[step] = .pending }
    }
}
