//
//  AppError.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation

/// Typed errors for NeuralJack. Services throw these; ViewModels translate to user-facing messages.
enum AppError: LocalizedError {
    case invalidZIPFile
    case iCloudFileNotDownloaded
    case fileTooLargeForMemory
    case missingConversationsJSON
    case conversationParseFailure(String)
    case apiKeyMissing
    case apiRequestFailed(statusCode: Int, message: String)
    case apiRateLimited
    case fileWriteFailure(path: String)
    case exportTooLarge(tokenCount: Int)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidZIPFile:
            return "This doesn't look like a valid ZIP file."
        case .iCloudFileNotDownloaded:
            return "This file is in iCloud but isn't downloaded yet."
        case .fileTooLargeForMemory:
            return "This export is very large and couldn't be parsed."
        case .missingConversationsJSON:
            return "No conversation files found in this export."
        case .conversationParseFailure(let detail):
            return "Failed to parse conversations: \(detail)"
        case .apiKeyMissing:
            return "Anthropic API key is required. Add it in Preferences."
        case .apiRequestFailed(let statusCode, let message):
            return "API request failed (HTTP \(statusCode)): \(message)"
        case .apiRateLimited:
            return "API rate limit reached. Please wait a moment and try again."
        case .fileWriteFailure(let path):
            return "Could not write to file: \(path)"
        case .exportTooLarge(let tokenCount):
            return "Export is too large (\(tokenCount) tokens). Consider splitting your conversations."
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidZIPFile:
            return "Ensure the file is a valid .zip archive and try again."
        case .iCloudFileNotDownloaded:
            return "In Finder, right-click the file → Download Now. Wait for it to fully download, then try again. At ~500MB this may take a few minutes."
        case .fileTooLargeForMemory:
            return "Try unzipping the file in Finder first, then drag the unzipped folder onto NeuralJack instead."
        case .missingConversationsJSON:
            return "Expected files named conversations-000.json, conversations-001.json, etc. Make sure this is an OpenAI data export from ChatGPT Settings → Data Controls → Export Data."
        case .conversationParseFailure:
            return "Try re-exporting your data from ChatGPT. If the problem persists, the export may be corrupted."
        case .apiKeyMissing:
            return "Open Preferences (⌘,) and enter your Anthropic API key."
        case .apiRequestFailed:
            return "Check your internet connection and API key. If the error persists, try again later."
        case .apiRateLimited:
            return "Wait a minute before retrying. Memory Core generation will resume automatically."
        case .fileWriteFailure:
            return "Check that you have write permission for the destination and try again."
        case .exportTooLarge:
            return "Export fewer conversations at once, or split your ChatGPT export."
        case .exportFailed:
            return "Check the Xcode console for details and try again."
        }
    }
}
