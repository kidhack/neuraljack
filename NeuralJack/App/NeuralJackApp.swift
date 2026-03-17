//
//  NeuralJackApp.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import SwiftUI

@main
struct NeuralJackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let zipParser: ZIPParserService
    private let anthropicService: AnthropicService
    private let exportService: ExportService
    private let guidedImportService: GuidedImportService
    private let coworkPluginService: CoworkPluginService
    @State private var importViewModel: ImportViewModel
    @State private var migrationViewModel: MigrationViewModel
    @State private var guidedImportViewModel: GuidedImportViewModel

    init() {
        let parser = ZIPParserService()
        zipParser = parser
        anthropicService = AnthropicService()
        exportService = ExportService(anthropicService: anthropicService)
        guidedImportService = GuidedImportService()
        coworkPluginService = CoworkPluginService()
        _importViewModel = State(initialValue: ImportViewModel(zipParser: parser))
        _migrationViewModel = State(initialValue: MigrationViewModel(anthropicService: anthropicService, exportService: exportService))
        _guidedImportViewModel = State(initialValue: GuidedImportViewModel(guidedImportService: guidedImportService))
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(importViewModel)
                .environment(migrationViewModel)
                .environment(guidedImportViewModel)
                .environment(\.zipParserService, zipParser)
                .environment(\.anthropicService, anthropicService)
                .environment(\.exportService, exportService)
                .environment(\.coworkPluginService, coworkPluginService)
                .environment(\.keychainService, KeychainService.shared)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 720, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink(label: { Text("API Key") })
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environment(\.keychainService, KeychainService.shared)
                .environment(\.anthropicService, anthropicService)
        }
    }
}

// MARK: - Environment Keys

private struct ZIPParserServiceKey: EnvironmentKey {
    static let defaultValue: ZIPParserService = ZIPParserService()
}

private struct AnthropicServiceKey: EnvironmentKey {
    static let defaultValue: AnthropicService = AnthropicService()
}

private struct ExportServiceKey: EnvironmentKey {
    static let defaultValue: ExportService = ExportService()
}

private struct CoworkPluginServiceKey: EnvironmentKey {
    static let defaultValue: CoworkPluginService = CoworkPluginService()
}

private struct KeychainServiceKey: EnvironmentKey {
    static let defaultValue: KeychainService = KeychainService.shared
}

extension EnvironmentValues {
    var zipParserService: ZIPParserService {
        get { self[ZIPParserServiceKey.self] }
        set { self[ZIPParserServiceKey.self] = newValue }
    }

    var anthropicService: AnthropicService {
        get { self[AnthropicServiceKey.self] }
        set { self[AnthropicServiceKey.self] = newValue }
    }

    var exportService: ExportService {
        get { self[ExportServiceKey.self] }
        set { self[ExportServiceKey.self] = newValue }
    }

    var coworkPluginService: CoworkPluginService {
        get { self[CoworkPluginServiceKey.self] }
        set { self[CoworkPluginServiceKey.self] = newValue }
    }

    var keychainService: KeychainService {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }
}
