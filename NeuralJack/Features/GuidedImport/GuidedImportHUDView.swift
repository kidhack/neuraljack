//
//  GuidedImportHUDView.swift
//  NeuralJack
//

import AppKit
import SwiftUI

struct GuidedImportHUDView: View {
    @Environment(GuidedImportViewModel.self) private var viewModel

    var body: some View {
        if viewModel.packages.isEmpty {
            ContentUnavailableView("No packages", systemImage: "folder")
                .frame(width: 340)
        } else if viewModel.isComplete {
            completionView
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ProjectSwitcherView(viewModel: viewModel)
                CurrentStepView(viewModel: viewModel)
                StepActionsView(viewModel: viewModel)
                Spacer(minLength: 0)
                DisclaimerFooterView()
            }
            .padding(24)
            .frame(width: 340)
        }
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 66))
                .foregroundStyle(.green)

            Text("All \(viewModel.packages.count) project\(viewModel.packages.count == 1 ? "" : "s") imported")
                .font(.neuralJackBody)

            Text("Your ChatGPT history is now available in Claude Projects.")
                .font(.neuralJackBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button("Open claude.ai →") {
                    guard let url = URL(string: "https://claude.ai/projects") else { return }
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)

                Button("Close") {
                    viewModel.skipAll()
                }
                .buttonStyle(.bordered)
                .focusable(false)
            }
        }
        .padding(32)
        .frame(width: 340)
    }
}

struct ProjectSwitcherView: View {
    @Bindable var viewModel: GuidedImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project \(viewModel.currentPackageIndex + 1) of \(viewModel.packages.count)")
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(Array(viewModel.packages.enumerated()), id: \.element.id) { index, pkg in
                    Circle()
                        .fill(fillForProject(index: index))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    private func fillForProject(index: Int) -> Color {
        if viewModel.completedPackageIDs.contains(viewModel.packages[index].id) {
            return .green
        }
        if index == viewModel.currentPackageIndex {
            return Color.accentColor
        }
        return Color.primary.opacity(0.2)
    }
}

struct CurrentStepView: View {
    @Bindable var viewModel: GuidedImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let step = viewModel.currentStep {
                Text("Step \(viewModel.currentStepIndex + 1) of \(8)")
                    .font(.neuralJackCaption)
                    .foregroundStyle(.secondary)

                Text(step.instruction)
                    .font(.neuralJackBody)

                if let label = step.actionStatusLabel {
                    Text(label)
                        .font(.neuralJackCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StepActionsView: View {
    @Bindable var viewModel: GuidedImportViewModel

    var body: some View {
        HStack {
            Button("Skip Project") {
                viewModel.skipProject()
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .focusable(false)

            Spacer()

            Button("Done →") {
                viewModel.advanceStep()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .focusable(false)
        }
    }
}

struct DisclaimerFooterView: View {
    var body: some View {
        Text("NeuralJack cannot automate claude.ai — only guide you.")
            .font(.neuralJackCaption)
            .foregroundStyle(.tertiary)
    }
}
