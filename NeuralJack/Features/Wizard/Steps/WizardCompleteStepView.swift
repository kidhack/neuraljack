//
//  WizardCompleteStepView.swift
//  NeuralJack
//

import AppKit
import SwiftUI

struct WizardCompleteStepView: View {
    @Bindable var vm: WizardViewModel

    var body: some View {
        WizardStepShell(
            icon: "checkmark.seal.fill",
            title: "Data Prepped For Migration",
            subtitle: "Your ChatGPT data is ready. Use generated prompts to migrate to Claude."
        ) {
            VStack(spacing: 16) {
                summaryCard
                if vm.hasExportedProjects { exportFolderFilesCard }
                if vm.memoryCore != nil { importMemoryCoreCard }
                if vm.coworkMemoryPromptFileWritten { coworkMemoryPromptCard }
                if vm.includeExportLog { exportLogCard }
                sponsorCard
            }
        }
    }

    // MARK: - Summary

    private var projectsSummaryValue: String {
        "\(vm.migratedCount) of \(vm.projectGroups.count)"
    }

    private var conversationsSummaryValue: String {
        if vm.conversationsPackage != nil || vm.migratedCount > 0 {
            return "\(vm.totalExportedConversationFiles)"
        }
        if vm.hasUncategorizedConversations { return "Skipped" }
        return "None"
    }

    private var memoryCoreSummaryValue: String {
        if vm.memoryCore != nil { return "Generated" }
        if vm.coworkMemoryPromptFileWritten { return "Prompt file" }
        if vm.includeMemoryCore && vm.memoryCorePhase == .failed { return "Failed" }
        return "Skipped"
    }

    private var summaryCard: some View {
        WizardCard {
            WizardCardRow {
                Text("Ready For Migration")
                    .font(.neuralJackTitle2Semibold)
            }

            SummaryRowView(
                icon: "folder",
                label: "Projects",
                value: projectsSummaryValue,
                success: vm.migratedCount > 0
            )

            SummaryRowView(
                icon: "bubble.left.and.bubble.right",
                label: "Conversations",
                value: conversationsSummaryValue,
                success: vm.conversationsPackage != nil || vm.migratedCount > 0 || !vm.hasUncategorizedConversations
            )

            SummaryRowView(
                icon: "brain.head.profile",
                label: "Memory Core",
                value: memoryCoreSummaryValue,
                success: vm.memoryCore != nil || vm.coworkMemoryPromptFileWritten,
                divider: false
            )
        }
    }

    // MARK: - Generated Migration Prompts

    private var exportFolderFilesCard: some View {
        WizardCard {
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Migrate Data")
                        .font(.neuralJackTitle2Semibold)
                    Text("Finish your migration to Claude using one of the two workflows.")
                        .font(.neuralJackCaption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Automated migration with Claude Cowork")
                            .font(.system(size: 16, weight: .medium))
                        exportFileRow(name: "claude-cowork-import-prompt.md", purpose: "Read instructions and paste prompt into Claude Cowork; it will grab project names from chatgpt.com via browser and imports to Claude.", openURL: vm.exportFolderFileURL(filename: "claude-cowork-import-prompt.md")) {
                            Button("Open Claude Cowork") {
                                launchClaudeCowork()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .focusable(false)
                        }
                        Divider()
                        Text("Guided migration with Claude Chat")
                            .font(.system(size: 16, weight: .medium))
                        exportFileRow(name: "claude-import-manual-prompt.md", purpose: "Read instructions and paste prompt into Claude; you will provide project names while Claude guides you step by step to migrate data.", openURL: vm.exportFolderFileURL(filename: "claude-import-manual-prompt.md"))
                    }
                    .font(.neuralJackCaption)
                }
            }
        }
    }

    private func exportFileRow<Trailing: View>(name: String, purpose: String, openURL: URL?, @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let url = openURL, FileManager.default.fileExists(atPath: url.path) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Text(name)
                                .font(.system(size: 12, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(name)
                            .font(.system(size: 12, design: .monospaced))
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                    }
                    trailing()
                }
                if !purpose.isEmpty {
                    Text(purpose)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
        }
    }

    private func exportFileRow(name: String, purpose: String, openURL: URL?) -> some View {
        exportFileRow(name: name, purpose: purpose, openURL: openURL) { EmptyView() }
    }

    private func launchClaudeCowork() {
        let appPaths = [
            "/Applications/Claude Cowork.app",
            "/Applications/Claude Desktop.app",
            "/Applications/Claude.app"
        ]
        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                return
            }
        }
        if let url = URL(string: "https://claude.ai") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Import Memory Core (API-generated)

    private var importMemoryCoreCard: some View {
        WizardCard {
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Memory Core")
                        .font(.neuralJackTitle2Semibold)
                    exportFileRow(
                        name: "memory-core.md",
                        purpose: "",
                        openURL: vm.memoryCoreFileURL(),
                        trailing: {
                            Button {
                                vm.memoryCore?.copyToClipboard()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .focusable(false)
                        }
                    )
                    if let core = vm.memoryCore {
                        Text("Context from \(core.sourceConversationCount) conversations. Go to Claude → Settings → Capabilities → \"Import memory from other AI providers\". Click \"Start Import\" and paste Memory Core.")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                }
            }
        }
    }

    // MARK: - Memory Core prompt file (Cowork)

    private var coworkMemoryPromptCard: some View {
        WizardCard {
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Memory Core")
                        .font(.neuralJackTitle2Semibold)
                    Text("Generate a Memory Core from your exported conversations using Claude Cowork.")
                        .font(.neuralJackCaption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                    exportFileRow(
                        name: "memory-core-cowork-prompt.md",
                        purpose: "Paste this prompt into Claude Cowork; it will generate a Memory Core document from the conversation files in your export folder.",
                        openURL: vm.exportFolderFileURL(filename: "memory-core-cowork-prompt.md")
                    )
                }
            }
        }
    }

    // MARK: - Export Log

    private var exportLogCard: some View {
        WizardCard {
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Export Log")
                            .font(.neuralJackTitle2Semibold)
                        Spacer(minLength: 8)
                        exportLogCardTrailing
                    }
                    if let err = vm.logExportError {
                        Text(err)
                            .font(.neuralJackCaption)
                            .foregroundStyle(.red)
                        Button("Retry") {
                            vm.exportLog()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .focusable(false)
                    }
                }
            }
        }
        .onAppear {
            if vm.includeExportLog && vm.logFileURL == nil && !vm.isExportingLog {
                vm.exportLog()
            }
        }
    }

    @ViewBuilder
    private var exportLogCardTrailing: some View {
        if let logURL = vm.logFileURL {
            Button {
                NSWorkspace.shared.open(logURL)
            } label: {
                Text(logURL.lastPathComponent)
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
            }
            .buttonStyle(.plain)
            .focusable(false)
        } else if vm.isExportingLog {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Saving…")
                    .font(.neuralJackCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sponsor

    private var sponsorCard: some View {
        WizardCard {
            WizardCardRow(divider: false) {
                HStack {
                    Text("Support NeuralJack")
                        .font(.neuralJackTitle2Semibold)
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/kidhack")!)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("Sponsor on GitHub →")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .focusable(false)
                }
            }
        }
    }
}

// MARK: - Summary Row

struct SummaryRowView: View {
    let icon: String
    let label: String
    let value: String
    let success: Bool
    var divider: Bool = true

    var body: some View {
        WizardCardRow(divider: divider) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(label)
                    .font(.neuralJackBody)
                Spacer()
                Text(value)
                    .font(.neuralJackCaption)
                    .foregroundStyle(success ? .green : .secondary)
                Image(systemName: success ? "checkmark.circle.fill" : "minus.circle")
                    .foregroundStyle(success ? .green : .secondary)
            }
        }
    }
}
