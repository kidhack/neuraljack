//
//  ImportViewModel.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation
import AppKit

/// Handles ZIP drop, parsing state, and migration settings.
@MainActor
@Observable
final class ImportViewModel {
    /// Equatable phase for use with SwiftUI's onChange(of:).
    enum StatePhase: Equatable {
        case idle
        case parsing
        case parsed
        case failed
    }

    enum State {
        case idle
        case parsing
        case parsed(OpenAIExport)
        case failed(AppError)

        var phase: StatePhase {
            switch self {
            case .idle: return .idle
            case .parsing: return .parsing
            case .parsed: return .parsed
            case .failed: return .failed
            }
        }
    }

    private let zipParser: ZIPParserService

    var state: State = .idle
    var parseProgressMessage: String = ""
    /// Incremented when a drop fails; used to trigger UI feedback (e.g. shake).
    private(set) var failedDropCount: Int = 0
    var selectedConversations: Set<String> = []
    var includeMemoryCore: Bool = true
    var includeExport: Bool = true
    var includeProjects: Bool = true
    var outputDirectory: URL = {
        // Use app's Documents folder (inside sandbox) so we can write without user picking.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("NeuralJack", isDirectory: true)
    }()

    init(zipParser: ZIPParserService) {
        self.zipParser = zipParser
    }

    /// Handles a dropped file or folder (from Dock or window drop).
    /// Validation is based only on content (presence of conversations.json), never filename.
    func handleDrop(url: URL) async {
        state = .parsing
        parseProgressMessage = ""
        do {
            let export = try await zipParser.parse(from: url) { [self] message in
                Task { @MainActor in
                    parseProgressMessage = message
                }
            }
            state = .parsed(export)
            selectedConversations = Set(export.conversations.map(\.id))
            // Default to same directory the ZIP/folder was imported from.
            outputDirectory = url.deletingLastPathComponent()
        } catch let error as AppError {
            failedDropCount += 1
            state = .failed(error)
        } catch {
            failedDropCount += 1
            state = .failed(.invalidZIPFile)
        }
    }

    /// Resets import state and clears selection.
    func clearImport() {
        state = .idle
        parseProgressMessage = ""
        selectedConversations = []
    }

    /// Presents NSOpenPanel to choose output directory; updates outputDirectory on selection.
    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.directoryURL = outputDirectory
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.outputDirectory = url
            }
        }
    }

    /// Builds migration settings from current state.
    func makeMigrationSettings() -> MigrationSettings? {
        guard case .parsed = state else { return nil }
        return MigrationSettings(
            selectedConversations: selectedConversations,
            includeMemoryCore: includeMemoryCore,
            includeExport: includeExport,
            includeProjects: includeProjects,
            outputDirectory: outputDirectory
        )
    }
}
