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
    @Environment(\.openWindow) private var openWindow

    private let zipParser: ZIPParserService
    private let anthropicService: AnthropicService
    private let exportService: ExportService
    @State private var importViewModel: ImportViewModel

    init() {
        let parser = ZIPParserService()
        zipParser = parser
        anthropicService = AnthropicService()
        exportService = ExportService(anthropicService: anthropicService)
        _importViewModel = State(initialValue: ImportViewModel(zipParser: parser))
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(importViewModel)
                .environment(\.zipParserService, zipParser)
                .environment(\.anthropicService, anthropicService)
                .environment(\.exportService, exportService)
                .environment(\.keychainService, KeychainService.shared)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 720, height: 720)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About NeuralJack") {
                    openWindow(id: "about")
                }
            }
            CommandGroup(replacing: .appSettings) {
                SettingsLink(label: { Text("API Key") })
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        Window("About NeuralJack", id: "about") {
            AboutView()
        }
        .defaultSize(width: 360, height: 420)
        .windowResizability(.contentSize)

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

    var keychainService: KeychainService {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }
}
