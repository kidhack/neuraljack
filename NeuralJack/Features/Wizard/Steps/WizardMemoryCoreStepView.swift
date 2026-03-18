//
//  WizardMemoryCoreStepView.swift
//  NeuralJack
//

import SwiftUI

struct WizardMemoryCoreStepView: View {
    @Bindable var vm: WizardViewModel
    @State private var showFullPreview = false

    var body: some View {
        WizardStepShell(
            icon: "brain.head.profile",
            title: "Memory Core Setup",
            subtitle: "Enter your Claude API key to automatically generate a memory core based off selected projects. If you don't have an API key, a generated prompt for Claude will be created."
        ) {
            switch vm.memoryCorePhase {
            case .ready:
                setupFormView
            case .generating:
                generatingView
            case .done:
                doneView
            case .skipped:
                skippedView
            case .failed:
                failedView
            }
        }
    }

    // MARK: - Setup Form (Use API key toggle + key input or prompt message)

    private var setupFormView: some View {
        VStack(spacing: 16) {
            WizardCard {
                WizardCardRow {
                    Toggle("Use API key", isOn: $vm.useAPIKeyForMemoryCore)
                        .font(.neuralJackCardHeaderSemibold)
                        .toggleStyle(.switch)
                }

                if vm.useAPIKeyForMemoryCore {
                    if vm.hasAPIKey {
                        WizardCardRow(divider: false) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(vm.maskedAPIKey() ?? "API key saved")
                                    .font(.system(size: 16, design: .monospaced))
                                Spacer()
                                Button("Remove") {
                                    vm.removeAPIKey()
                                }
                                .buttonStyle(.bordered)
                                .focusable(false)
                                .controlSize(.small)
                                .tint(.red)
                            }
                        }
                    } else {
                        WizardCardRow(divider: false) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .center, spacing: 8) {
                                    SecureField("sk-ant-...", text: $vm.apiKeyInput)
                                        .textFieldStyle(.roundedBorder)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Button {
                                        Task { await vm.validateAndSaveKey() }
                                    } label: {
                                        if vm.isValidatingKey {
                                            ProgressView()
                                                .controlSize(.small)
                                                .frame(width: 56)
                                        } else {
                                            Text("Verify")
                                                .frame(width: 56)
                                        }
                                    }
                                    .buttonStyle(NeuralJackProminentButtonStyle())
                                    .focusable(false)
                                    .disabled(vm.apiKeyInput.isEmpty || vm.isValidatingKey)
                                    .keyboardShortcut(.return, modifiers: [])
                                }

                                if let error = vm.keyValidationError {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text(error)
                                            .font(.neuralJackCaption)
                                            .foregroundStyle(.red)
                                    }
                                }

                                if vm.keyValidationSuccess {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Key saved.")
                                            .font(.neuralJackCaption)
                                            .foregroundStyle(.green)
                                    }
                                }

                                Text("Your key is stored securely in the macOS Keychain.")
                                    .font(.neuralJackCaption)
                                    .foregroundStyleNeuralJackSecondary()

                                Link("Get a key at console.anthropic.com →",
                                     destination: URL(string: "https://console.anthropic.com")!)
                                    .font(.neuralJackCaption)
                            }
                        }
                    }
                } else {
                    WizardCardRow(divider: false) {
                        Text("Claude memory core prompt will be generated in your output folder.")
                            .font(.neuralJackBody)
                            .foregroundStyleNeuralJackSecondary()
                    }
                }
            }
        }
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: 20) {
            WizardCard {
                WizardCardRow(divider: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Analyzing your conversations…")
                                .font(.neuralJackBody)
                        }

                        ProgressView(value: vm.memoryCoreProgress)
                            .tint(Color.accentColor)

                        Text(progressLabel)
                            .font(.neuralJackCaption)
                            .foregroundStyleNeuralJackSecondary()
                    }
                }
            }

            Text("This may take a moment for large exports. Claude is reading your conversations.")
                .font(.neuralJackCaption)
                .foregroundStyleNeuralJackSecondary()
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 16) {
            WizardCard {
                WizardCardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.neuralJackBody)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Memory Core generated")
                                .font(.system(size: 16, weight: .medium))
                            if let core = vm.memoryCore {
                                Text("\(core.sourceConversationCount) conversations synthesized")
                                    .font(.neuralJackCaption)
                                    .foregroundStyleNeuralJackSecondary()
                            }
                        }
                        Spacer()
                        Button {
                            vm.memoryCore?.copyToClipboard()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .focusable(false)
                    }
                }

                WizardCardRow(divider: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("To give Claude your context: open the memory core file in your export folder and paste its contents into your Claude project's instructions (Project settings → Project instructions).")
                            .font(.neuralJackCaption)
                            .foregroundStyleNeuralJackSecondary()

                        Button {
                            let url = vm.memoryCoreFileURL()
                            let dir = url.deletingLastPathComponent()
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: dir.path)
                        } label: {
                            Label("View in Finder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .focusable(false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let core = vm.memoryCore {
                    WizardCardRow(divider: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Preview")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyleNeuralJackSecondary()
                                Spacer()
                                Button(showFullPreview ? "Less" : "More") {
                                    showFullPreview.toggle()
                                }
                                .buttonStyle(.plain)
                                .font(.neuralJackCaption)
                                .foregroundStyle(Color.accentColor)
                                .focusable(false)
                            }

                            Text(core.markdown)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyleNeuralJackSecondary()
                                .lineLimit(showFullPreview ? nil : 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

        }
    }

    // MARK: - Skipped

    private var skippedView: some View {
        VStack(spacing: 16) {
            WizardCard {
                WizardCardRow(divider: false) {
                    HStack(spacing: 10) {
                        if vm.coworkMemoryPromptFileWritten {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.neuralJackBody)
                            Text("Memory Core prompt file was created in your output folder.")
                                .font(.neuralJackBody)
                                .foregroundStyle(.primary)
                        } else {
                            Image(systemName: "forward.circle")
                                .foregroundStyleNeuralJackSecondary()
                                .font(.neuralJackBody)
                            Text("Memory Core skipped")
                                .font(.neuralJackBody)
                                .foregroundStyleNeuralJackSecondary()
                        }
                        Spacer()
                        Button(vm.coworkMemoryPromptFileWritten ? "Use API key instead" : "Generate anyway") {
                            vm.memoryCorePhase = .ready
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .focusable(false)
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
                        Text("Generation failed")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                if let error = vm.memoryCoreError {
                    WizardCardRow(divider: false) {
                        Text(error)
                            .font(.neuralJackCaption)
                            .foregroundStyleNeuralJackSecondary()
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    vm.memoryCorePhase = .ready
                } label: {
                    Text("Try again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            }
        }
    }

    // MARK: - Helpers

    private var progressLabel: String {
        let pct = Int(vm.memoryCoreProgress * 100)
        if vm.memoryCoreProgress < 0.7 {
            return "\(pct)% — Extracting facts from conversations…"
        } else if vm.memoryCoreProgress < 0.9 {
            return "\(pct)% — Synthesizing Memory Core…"
        } else {
            return "\(pct)% — Formatting output…"
        }
    }
}
