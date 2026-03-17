//
//  WizardProjectStepView.swift
//  NeuralJack
//

import SwiftUI

struct WizardProjectStepView: View {
    @Bindable var vm: WizardViewModel
    let projectIndex: Int

    @State private var coworkPromptCopied = false
    @State private var projectNameCopied = false
    @State private var showManualSteps = false

    var body: some View {
        if let group = projectGroup {
            WizardStepShell(
                icon: "folder.badge.plus",
                title: "Project \(projectIndex + 1) of \(vm.projectGroups.count): \(group.name)",
                subtitle: "\(group.conversations.count) conversation\(group.conversations.count == 1 ? "" : "s") — exporting creates files ready to upload into Claude"
            ) {
                VStack(spacing: 16) {
                    switch phase(for: group) {
                    case .ready:
                        readyView(group: group)
                    case .exporting:
                        exportingView(group: group)
                    case .done:
                        doneView(group: group)
                    case .failed:
                        failedView(group: group)
                    }
                }
            }
        } else {
            ContentUnavailableView("Project not found", systemImage: "folder")
        }
    }

    // MARK: - Helpers

    private var projectGroup: ProjectGroup? {
        vm.projectGroups.indices.contains(projectIndex) ? vm.projectGroups[projectIndex] : nil
    }

    private func phase(for group: ProjectGroup) -> WizardViewModel.ProjectPhase {
        vm.projectPhases[group.id] ?? .ready
    }

    private func progress(for group: ProjectGroup) -> Double {
        vm.projectProgress[group.id] ?? 0
    }

    private func errorMessage(for group: ProjectGroup) -> String? {
        vm.projectErrors[group.id]
    }

    private func migratedPackage(for group: ProjectGroup) -> ClaudeProjectPackage? {
        vm.migratedPackages[group.id]
    }

    // MARK: - Ready

    @ViewBuilder
    private func readyView(group: ProjectGroup) -> some View {
        WizardCard {
            WizardCardRow(divider: false) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.system(size: 18, weight: .medium))
                        Text("\(group.conversations.count) conversation\(group.conversations.count == 1 ? "" : "s")")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                }
            }
        }

        Button {
            Task { await vm.migrateProject(at: projectIndex) }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("Export Project Files")
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.return, modifiers: [])
        .focusable(false)

        Button("Skip this project") {
            vm.skipProject(at: projectIndex)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.neuralJackCaption)
        .focusable(false)
    }

    // MARK: - Exporting

    @ViewBuilder
    private func exportingView(group: ProjectGroup) -> some View {
        WizardCard {
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Exporting \(group.name)…")
                            .font(.neuralJackBody)
                    }
                    ProgressView(value: progress(for: group)).tint(Color.accentColor)
                }
            }
        }
    }

    // MARK: - Done

    @ViewBuilder
    private func doneView(group: ProjectGroup) -> some View {
        // Success banner
        WizardCard {
            WizardCardRow(divider: false) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.neuralJackBody)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Files exported")
                            .font(.system(size: 18, weight: .medium))
                        if let pkg = migratedPackage(for: group) {
                            Text("\(pkg.conversationCount) conversation file\(pkg.conversationCount == 1 ? "" : "s") written")
                                .font(.neuralJackCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        vm.revealPackage(for: group)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }

        // Import into Claude
        importSection(group: group)

        // Next
        nextButton(group: group)
    }

    @ViewBuilder
    private func importSection(group: ProjectGroup) -> some View {
        WizardCard {
            WizardCardRow {
                Text("Import into Claude")
                    .font(.neuralJackTitle2Semibold)
            }

            if vm.useCowork {
                coworkSection(group: group)
            }

            manualSection(group: group)
        }
    }

    // MARK: - Cowork Section

    @ViewBuilder
    private func coworkSection(group: ProjectGroup) -> some View {
        WizardCardRow {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.rays").foregroundStyle(Color.accentColor)
                    Text("Automated via Claude Desktop")
                        .font(.system(size: 18, weight: .medium))
                }
                Text("Paste this prompt into Claude Desktop to automate project creation in claude.ai.")
                    .font(.neuralJackCaption)
                    .foregroundStyle(.secondary)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(vm.coworkPrompt(for: group), forType: .string)
                    coworkPromptCopied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        coworkPromptCopied = false
                    }
                } label: {
                    Label(
                        coworkPromptCopied ? "Copied!" : "Copy Automation Prompt",
                        systemImage: coworkPromptCopied ? "checkmark" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }

    // MARK: - Manual Section

    @ViewBuilder
    private func manualSection(group: ProjectGroup) -> some View {
        WizardCardRow(divider: false) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation { showManualSteps.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "list.number")
                            .foregroundStyle(vm.useCowork ? Color.gray : Color.accentColor)
                        Text(vm.useCowork ? "Manual steps (alternative)" : "Step-by-step guide")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(vm.useCowork ? .secondary : .primary)
                        Spacer()
                        Image(systemName: showManualSteps ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                            .font(.neuralJackCaption)
                    }
                }
                .buttonStyle(.plain)

                if showManualSteps, let pkg = migratedPackage(for: group) {
                    Divider()
                    ManualImportStepsView(group: group, package: pkg, projectNameCopied: $projectNameCopied)
                }
            }
        }
    }

    // MARK: - Failed

    @ViewBuilder
    private func failedView(group: ProjectGroup) -> some View {
        WizardCard {
            WizardCardRow {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.neuralJackBody)
                    Text("Export failed").font(.system(size: 18, weight: .medium))
                }
            }
            if let err = errorMessage(for: group) {
                WizardCardRow(divider: false) {
                    Text(err).font(.neuralJackCaption).foregroundStyle(.secondary)
                }
            }
        }

        HStack(spacing: 12) {
            Button {
                Task { await vm.migrateProject(at: projectIndex) }
            } label: {
                Text("Try again").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .focusable(false)

            Button {
                vm.skipProject(at: projectIndex)
            } label: {
                Text("Skip").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .focusable(false)
        }
    }

    // MARK: - Next Button

    @ViewBuilder
    private func nextButton(group: ProjectGroup) -> some View {
        let isLastProject = projectIndex == vm.projectGroups.count - 1
        Button {
            vm.nextStep()
        } label: {
            HStack {
                Text(isLastProject ? "Continue" : "Next Project")
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.return, modifiers: [])
        .focusable(false)
    }
}

// MARK: - Manual Import Steps

struct ManualImportStepsView: View {
    let group: ProjectGroup
    let package: ClaudeProjectPackage
    @Binding var projectNameCopied: Bool

    private struct ManualStep: Identifiable {
        let id: Int
        let text: String
        let action: Action

        enum Action {
            case none
            case openURL(String)
            case copyName
            case revealFinder
        }
    }

    private var steps: [ManualStep] {
        [
            .init(id: 1, text: "Open **claude.ai/projects** in your browser", action: .openURL("https://claude.ai/projects")),
            .init(id: 2, text: "Click **New Project** in the sidebar", action: .none),
            .init(id: 3, text: "Enter the project name below, then click **Create**", action: .copyName),
            .init(id: 4, text: "Click **Add content** in the knowledge panel", action: .none),
            .init(id: 5, text: "Drag files from Finder into the upload area", action: .revealFinder),
            .init(id: 6, text: "Click the pencil icon next to **Project Instructions**", action: .none),
            .init(id: 7, text: "Paste the contents of `_project-instructions.md` and click **Save**", action: .none),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(step.id)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.accentColor))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(step.text))
                            .font(.neuralJackCaption)
                        actionButton(for: step)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButton(for step: ManualStep) -> some View {
        switch step.action {
        case .none:
            EmptyView()

        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                Button("Open claude.ai →") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .focusable(false)
            }

        case .copyName:
            HStack(spacing: 6) {
                Text(group.name)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(group.name, forType: .string)
                    projectNameCopied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        projectNameCopied = false
                    }
                } label: {
                    Label(
                        projectNameCopied ? "Copied!" : "Copy name",
                        systemImage: projectNameCopied ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .focusable(false)
            }

        case .revealFinder:
            Button("Show files in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: package.packageDirectory.path)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .focusable(false)
        }
    }
}
