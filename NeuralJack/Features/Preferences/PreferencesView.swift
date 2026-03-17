//
//  PreferencesView.swift
//  NeuralJack
//

import SwiftUI
import AppKit

struct PreferencesView: View {
    @Environment(\.keychainService) private var keychainService
    @Environment(\.anthropicService) private var anthropicService

    var body: some View {
        PreferencesFormView(
            viewModel: PreferencesViewModel(keychain: keychainService, anthropicService: anthropicService)
        )
    }
}

private struct PreferencesFormView: View {
    @Bindable var viewModel: PreferencesViewModel

    var body: some View {
        Form {
            Section {
                if !viewModel.savedKeyMasked.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(viewModel.savedKeyMasked)
                            .font(.system(size: 18, design: .monospaced))
                        Spacer()
                        Button {
                            viewModel.removeKey()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.neuralJackTitle2)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                } else {
                    HStack(alignment: .center, spacing: 8) {
                        SecureField("API Key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onSubmit {
                                Task {
                                    await viewModel.saveAndValidate()
                                    if case .valid = viewModel.validationState {
                                        NSApp.keyWindow?.close()
                                    }
                                }
                            }

                        Button("Verify") {
                            Task {
                                await viewModel.saveAndValidate()
                                if case .valid = viewModel.validationState {
                                    NSApp.keyWindow?.close()
                                }
                            }
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .focusable(false)
                        .disabled(viewModel.apiKey.isEmpty)
                    }

                    switch viewModel.validationState {
                    case .validating:
                        Text("Validating…")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    case .invalid(let msg):
                        Text(msg)
                            .font(.neuralJackCaption)
                            .foregroundStyle(.red)
                    default:
                        EmptyView()
                    }
                }

                Text("Your key is stored securely in the macOS Keychain and never leaves your Mac except when calling api.anthropic.com.")
                    .font(.neuralJackCaption)
                    .foregroundStyle(.secondary)

                Link("Get a key at console.anthropic.com →", destination: URL(string: "https://console.anthropic.com")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSApp.keyWindow?.title = "Claude API Key"
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }
}
