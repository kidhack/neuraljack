//
//  ImportSummaryView.swift
//  NeuralJack
//

import SwiftUI
import AppKit

struct ImportSummaryView: View {
    @Environment(ImportViewModel.self) private var importViewModel
    @Environment(MigrationViewModel.self) private var migrationViewModel
    @State private var hasAPIKey = false
    @State private var showMemoryCoreInfo = false

    var body: some View {
        if case .parsed(let export) = importViewModel.state {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    userInfoCard(export: export)

                    Divider()

                    HStack(spacing: 16) {
                        StatCardView(value: "\(export.conversationCount)", label: "conversations")
                        StatCardView(value: "\(export.projectCount)", label: "projects")
                    }

                    migrationOptionsCard(vm: importViewModel, hasAPIKey: hasAPIKey, showMemoryCoreInfo: $showMemoryCoreInfo)

                    Button {
                        startMigration(export: export)
                    } label: {
                        HStack {
                            Text("Start Migration")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minHeight: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!hasAnyOptionChecked)
                }
                .padding(24)
            }
            .onAppear {
                hasAPIKey = (try? KeychainService.shared.load(for: KeychainAccount.anthropicAPIKey)) != nil
                if !hasAPIKey {
                    importViewModel.includeMemoryCore = false
                }
            }
            .onChange(of: hasAPIKey) { _, newValue in
                if !newValue {
                    importViewModel.includeMemoryCore = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                let keyExists = (try? KeychainService.shared.load(for: KeychainAccount.anthropicAPIKey)) != nil
                hasAPIKey = keyExists
                if keyExists {
                    migrationViewModel.errorMessage = nil
                    importViewModel.includeMemoryCore = true
                } else {
                    importViewModel.includeMemoryCore = false
                }
            }
        }
    }

    @ViewBuilder
    private func userInfoCard(export: OpenAIExport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Data parsed")
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)

            if let user = export.user, let name = user.email ?? user.id {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(name)
                        .font(.neuralJackBody)
                    if let range = export.dateRange {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(rangeFormatted(range))
                            .font(.neuralJackBody)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let range = export.dateRange {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(rangeFormatted(range))
                        .font(.neuralJackBody)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }

    @ViewBuilder
    private func migrationOptionsCard(vm: ImportViewModel, hasAPIKey: Bool, showMemoryCoreInfo: Binding<Bool>) -> some View {
        @Bindable var bindable = vm
        VStack(alignment: .leading, spacing: 0) {
            Text("Select Data to Migrate:")
                .font(.neuralJackTitle2Semibold)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 4) {
                    Toggle(isOn: $bindable.includeMemoryCore) {
                        Text("Generate Memory Core")
                            .font(.neuralJackBody)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(!hasAPIKey)
                    .opacity(hasAPIKey ? 1 : 0.4)

                    Button {
                        showMemoryCoreInfo.wrappedValue.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.neuralJackBody)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: showMemoryCoreInfo, arrowEdge: .bottom) {
                        MemoryCoreInfoPopover(hasAPIKey: hasAPIKey)
                    }
                }

                Toggle(isOn: $bindable.includeExport) {
                    Text("Export conversations as Markdown")
                        .font(.neuralJackBody)
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $bindable.includeProjects) {
                    Text("Export Project Templates")
                        .font(.neuralJackBody)
                }
                .toggleStyle(.checkbox)
            }
            .padding()

            Divider()

            HStack(spacing: 8) {
                Text("Output Location:")
                    .font(.neuralJackBody)
                Text(shortenedPath(importViewModel.outputDirectory))
                    .font(.neuralJackCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(importViewModel.outputDirectory.path)
                Button {
                    importViewModel.chooseOutputDirectory()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Choose output folder")
            }
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }

    private var hasAnyOptionChecked: Bool {
        importViewModel.includeMemoryCore || importViewModel.includeExport || importViewModel.includeProjects
    }

    private func shortenedPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let full = url.path
        if full.hasPrefix(home) {
            return "~" + full.dropFirst(home.count)
        }
        return full
    }

    private func startMigration(export: OpenAIExport) {
        guard let settings = importViewModel.makeMigrationSettings() else { return }
        Task {
            await migrationViewModel.startMigration(export: export, settings: settings)
        }
    }

    private func rangeFormatted(_ range: ClosedRange<Date>) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: range.lowerBound)) – \(formatter.string(from: range.upperBound))"
    }
}

// MARK: - Memory Core Info Popover

struct MemoryCoreInfoPopover: View {
    let hasAPIKey: Bool
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Memory Core")
                .font(.neuralJackTitle2Semibold)

            Text("Claude analyzes your conversation history and synthesizes it into a structured context file you can paste into any Claude Project.")
                .font(.neuralJackBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !hasAPIKey {
                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "key.slash")
                        .foregroundStyle(.orange)
                    Text("Requires an Anthropic API Key")
                        .font(.neuralJackBody)
                        .foregroundStyle(.primary)
                }

                Button("Add API Key in Settings") {
                    openSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
