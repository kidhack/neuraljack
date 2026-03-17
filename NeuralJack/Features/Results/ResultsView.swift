//
//  ResultsView.swift
//  NeuralJack
//

import AppKit
import SwiftUI

enum ResultsDetail: String, CaseIterable {
    case memoryCore = "Memory Core"
    case projects = "Projects"
    case conversations = "Conversations"
    case nextSteps = "Next Steps"
}

struct ResultsView: View {
    @Environment(MigrationViewModel.self) private var migrationViewModel
    @Environment(GuidedImportViewModel.self) private var guidedImportViewModel
    @Environment(\.coworkPluginService) private var coworkPluginService
    @State private var selectedDetail: ResultsDetail? = .memoryCore
    @State private var hudPanel: GuidedImportPanel?
    @State private var coworkPluginError: String?

    var body: some View {
        NavigationSplitView {
            List(ResultsDetail.allCases, id: \.self, selection: $selectedDetail) { detail in
                NavigationLink(value: detail) {
                    Label(detail.rawValue, systemImage: iconFor(detail))
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                if let detail = selectedDetail {
                    switch detail {
                    case .memoryCore:
                        if let core = migrationViewModel.memoryCore {
                            MemoryCoreView(memoryCore: core)
                        } else {
                            ContentUnavailableView("No Memory Core", systemImage: "brain.head.profile")
                        }
                    case .projects:
                        if let packages = migrationViewModel.packages {
                            ProjectPackagesView(packages: packages)
                        } else {
                            ContentUnavailableView("No Projects", systemImage: "folder")
                        }
                    case .conversations:
                        if let result = migrationViewModel.exportResult {
                            ConversationsExportView(exportResult: result)
                        } else {
                            ContentUnavailableView("No Export", systemImage: "square.and.arrow.up")
                        }
                    case .nextSteps:
                        NextStepsView(
                            packageCount: migrationViewModel.packages?.count ?? 0,
                            onImportIntoClaude: { launchGuidedImport() }
                        )
                    }
                } else {
                    ContentUnavailableView("Select an item", systemImage: "sidebar.leading")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if migrationViewModel.packages?.isEmpty == false, let outputDir = migrationViewModel.exportResult?.outputDirectory {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ready to Import into Claude")
                            .font(.neuralJackTitle2Semibold)

                        if let err = coworkPluginError {
                            Text(err)
                                .font(.neuralJackCaption)
                                .foregroundStyle(.red)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Button("Generate Cowork Plugin") {
                                generateCoworkPlugin(outputDirectory: outputDir)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .focusable(false)

                            Text("Automated · Requires Claude Desktop")
                                .font(.neuralJackCaption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Button("Step-by-step Guide →") {
                                launchGuidedImport()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .focusable(false)

                            Text("Manual · Works in any browser")
                                .font(.neuralJackCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
    }

    private func generateCoworkPlugin(outputDirectory: URL) {
        guard let packages = migrationViewModel.packages, !packages.isEmpty else { return }
        coworkPluginError = nil
        do {
            _ = try coworkPluginService.generatePlugin(packages: packages, outputDirectory: outputDirectory)
        } catch {
            coworkPluginError = error.localizedDescription
        }
    }

    private func launchGuidedImport() {
        guard let packages = migrationViewModel.packages, !packages.isEmpty else { return }
        let panel = GuidedImportPanel(viewModel: guidedImportViewModel)
        hudPanel = panel
        guidedImportViewModel.start(packages: packages)
    }

    private func iconFor(_ detail: ResultsDetail) -> String {
        switch detail {
        case .memoryCore: return "brain.head.profile"
        case .projects: return "folder"
        case .conversations: return "square.and.arrow.up"
        case .nextSteps: return "list.bullet.clipboard"
        }
    }
}
