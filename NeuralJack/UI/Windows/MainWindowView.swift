//
//  MainWindowView.swift
//  NeuralJack
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @Environment(ImportViewModel.self) private var importViewModel
    @Environment(\.anthropicService) private var anthropicService
    @Environment(\.exportService) private var exportService
    @State private var isDropTargeted = false
    @State private var wizardViewModel: WizardViewModel?
    @State private var hasAPIKey = false

    var body: some View {
        Group {
            switch importViewModel.state {
            case .idle, .failed:
                WelcomeView(isTargeted: $isDropTargeted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                    .animation(.easeInOut(duration: 0.15), value: isDropTargeted)

            case .parsing:
                ImportProgressView()

            case .parsed:
                if let vm = wizardViewModel {
                    WizardView(vm: vm)
                } else {
                    // Briefly shown while onChange fires — show a spinner
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 720)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { @MainActor in
                await importViewModel.handleDrop(url: url)
            }
            return true
        } isTargeted: {
            switch importViewModel.state {
            case .idle, .failed: isDropTargeted = $0
            default: isDropTargeted = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if hasAPIKey {
                    SettingsLink(label: { Text("API Key") })
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if let error = importError {
                ErrorBannerView(message: error) {
                    importViewModel.clearImport()
                    wizardViewModel = nil
                }
            }
        }
        .onAppear {
            hasAPIKey = (try? KeychainService.shared.load(for: .anthropicAPIKey)) != nil
            // Avoid default focus on a button so focus ring isn’t distracting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSApp.mainWindow?.makeFirstResponder(nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAPIKey = (try? KeychainService.shared.load(for: .anthropicAPIKey)) != nil
        }
        .onChange(of: importViewModel.state.phase) { _, newPhase in
            switch newPhase {
            case .parsed:
                if case .parsed(let export) = importViewModel.state {
                    wizardViewModel = WizardViewModel(
                        export: export,
                        anthropicService: anthropicService,
                        exportService: exportService,
                        defaultOutputDirectory: importViewModel.outputDirectory
                    )
                }
            case .idle:
                wizardViewModel = nil
            case .parsing, .failed:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zipFileDropped)) { notification in
            guard let url = notification.object as? URL else { return }
            Task { @MainActor in
                await importViewModel.handleDrop(url: url)
            }
        }
    }

    private var importError: String? {
        guard case .failed(let appError) = importViewModel.state else { return nil }
        return appError.errorDescription
    }
}
