//
//  WizardConversationsStepView.swift
//  NeuralJack
//

import SwiftUI

struct WizardConversationsStepView: View {
    @Bindable var vm: WizardViewModel

    var body: some View {
        WizardStepShell(
            icon: "bubble.left.and.bubble.right",
            title: "General Conversations",
            subtitle: "These \(vm.uncategorizedConversations.count) conversation\(vm.uncategorizedConversations.count == 1 ? " was" : "s were") not part of a specific ChatGPT project."
        ) {
            VStack(spacing: 16) {
                switch vm.conversationsPhase {
                case .ready:
                    readyView
                case .exporting:
                    exportingView
                case .done:
                    doneView
                case .failed:
                    failedView
                }
            }
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: 16) {
            WizardCard {
                WizardCardRow(divider: false) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vm.uncategorizedConversations.count) conversations")
                                .font(.system(size: 16, weight: .medium))
                            Text("Exported as Markdown files to your output folder")
                                .font(.neuralJackCaption)
                                .foregroundStyleNeuralJackSecondary()
                        }
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundStyleNeuralJackSecondary()
                    }
                }
            }
        }
    }

    // MARK: - Exporting

    private var exportingView: some View {
        WizardCard {
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Exporting conversations…")
                            .font(.neuralJackBody)
                    }
                    ProgressView(value: vm.conversationsProgress)
                        .tint(Color.accentColor)
                }
            }
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 16) {
            WizardCard {
                WizardCardRow(divider: false) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.neuralJackBody)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conversations exported")
                                .font(.system(size: 16, weight: .medium))
                            if let pkg = vm.conversationsPackage {
                                Text("\(pkg.conversationCount) files written")
                                    .font(.neuralJackCaption)
                                    .foregroundStyleNeuralJackSecondary()
                            }
                        }
                        Spacer()
                        Button {
                            if let pkg = vm.conversationsPackage {
                                NSWorkspace.shared.selectFile(
                                    nil,
                                    inFileViewerRootedAtPath: pkg.packageDirectory.path
                                )
                            }
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Failed

    private var failedView: some View {
        VStack(spacing: 16) {
            WizardCard {
                WizardCardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.neuralJackBody)
                        Text("Export failed")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                if let err = vm.conversationsError {
                    WizardCardRow(divider: false) {
                        Text(err).font(.neuralJackCaption).foregroundStyleNeuralJackSecondary()
                    }
                }
            }

            Button {
                Task { await vm.exportUncategorized() }
            } label: {
                Text("Try again").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .focusable(false)
        }
    }
}
