//
//  PreferencesViewModel.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation

/// Manages API key entry, validation, and Keychain storage.
@MainActor
@Observable
final class PreferencesViewModel {
    enum ValidationState {
        case idle
        case validating
        case valid
        case invalid(String)
    }

    private let keychain: KeychainService
    private let anthropicService: AnthropicService

    var apiKey: String = ""
    var savedKeyMasked: String = ""
    var validationState: ValidationState = .idle

    init(keychain: KeychainService, anthropicService: AnthropicService) {
        self.keychain = keychain
        self.anthropicService = anthropicService
        refreshSavedKeyMasked()
    }

    /// Validates the current apiKey and saves to Keychain on success.
    func saveAndValidate() async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            validationState = .invalid("API key cannot be empty")
            return
        }
        validationState = .validating
        do {
            let isValid = try await anthropicService.validateAPIKey(key)
            if isValid {
                try keychain.save(key: key, for: .anthropicAPIKey)
                validationState = .valid
                apiKey = ""
                refreshSavedKeyMasked()
            } else {
                validationState = .invalid("Invalid API key")
            }
        } catch {
            validationState = .invalid((error as? AppError)?.errorDescription ?? "Validation failed")
        }
    }

    /// Removes the stored API key from Keychain.
    func removeKey() {
        try? keychain.delete(for: .anthropicAPIKey)
        savedKeyMasked = ""
        validationState = .idle
    }

    private func refreshSavedKeyMasked() {
        do {
            let key = try keychain.load(for: .anthropicAPIKey)
            savedKeyMasked = maskAPIKey(key)
        } catch {
            savedKeyMasked = ""
        }
    }

    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "sk-ant-••••••••" }
        return String(key.prefix(8)) + "••••••••"
    }
}
