//
//  WizardSetupStepView.swift
//  NeuralJack
//

import SwiftUI

struct WizardSetupStepView: View {
    @Bindable var vm: WizardViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        WizardStepShell(
            icon: "key.fill",
            title: "Connect Claude",
            subtitle: "Connecting your Claude API key enables Memory Core synthesis and smarter project setup."
        ) {
            VStack(spacing: 16) {
                apiKeyCard
            }
        }
    }

    // MARK: - API Key Card

    private var apiKeyCard: some View {
        WizardCard {
            WizardCardRow {
                Text("Anthropic API Key")
                    .font(.neuralJackTitle2Semibold)
            }

            if vm.hasAPIKey {
                WizardCardRow(divider: false) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(vm.maskedAPIKey() ?? "API key saved")
                            .font(.system(size: 18, design: .monospaced))
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
                        Text("Paste your API key to enable Memory Core generation and richer project instructions.")
                            .font(.neuralJackBody)
                            .foregroundStyle(.secondary)

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
                            .buttonStyle(.borderedProminent)
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
                                Text("Key saved. Memory Core is now enabled.")
                                    .font(.neuralJackCaption)
                                    .foregroundStyle(.green)
                            }
                        }

                        Link("Get a key at console.anthropic.com →",
                             destination: URL(string: "https://console.anthropic.com")!)
                            .font(.neuralJackCaption)
                    }
                }
            }
        }
    }

}
