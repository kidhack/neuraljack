//
//  AnthropicService.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation

private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
private let model = "claude-opus-4-5"
private let apiVersion = "2023-06-01"
private let batchSize = 20
private let batchDelayMs: UInt64 = 1_500_000_000  // 1.5s between batches to avoid burst rate limits

/// Anthropic API client for Memory Core synthesis and project instructions.
final class AnthropicService {
    private let keychain: KeychainService

    init(keychain: KeychainService = .shared) {
        self.keychain = keychain
    }

    func validateAPIKey(_ key: String) async throws -> Bool {
        let _ = try await makeAPIRequest(
            apiKey: key,
            messages: [["role": "user", "content": "Say OK"]],
            systemPrompt: nil,
            maxTokens: 1
        )
        return true
    }

    func synthesizeMemoryCore(
        conversations: [OpenAIConversation],
        memoryEntries: [OpenAIMemoryEntry],
        progress: @escaping (Double) -> Void
    ) async throws -> MemoryCore {
        let apiKey: String
        do {
            apiKey = try keychain.load(for: .anthropicAPIKey)
        } catch {
            throw AppError.apiKeyMissing
        }

        let extractionPrompt = PromptLoader.load("extraction-prompt")
        let synthesisPrompt = PromptLoader.load("synthesis-prompt")

        let batches = stride(from: 0, to: conversations.count, by: batchSize).map {
            Array(conversations[$0 ..< min($0 + batchSize, conversations.count)])
        }
        let totalBatches = batches.count
        var batchExtracts: [String] = []
        var completedBatches = 0

        for batch in batches {
            let batchText = formatConversationsForExtraction(batch)
            let userContent = """
            Extract memory-relevant information from these conversations. Output only valid JSON.

            \(batchText)
            """
            let extractJson = try await makeAPIRequest(
                apiKey: apiKey,
                messages: [["role": "user", "content": userContent]],
                systemPrompt: extractionPrompt,
                maxTokens: 4000
            )
            batchExtracts.append(extractJson)
            completedBatches += 1
            progress(Double(completedBatches) / Double(totalBatches) * 0.7)
            if completedBatches < totalBatches {
                try await Task.sleep(nanoseconds: batchDelayMs)
            }
        }

        let extractsBlob = batchExtracts.joined(separator: "\n\n---\n\n")
        let memoryBlob = memoryEntries.map { $0.text }.joined(separator: "\n")
        let synthesisInput = """
        Extracted facts from conversation batches:
        \(extractsBlob)

        Additional memory entries from user:
        \(memoryBlob)
        """
        let rawCore = try await makeAPIRequest(
            apiKey: apiKey,
            messages: [["role": "user", "content": synthesisInput]],
            systemPrompt: synthesisPrompt,
            maxTokens: 4000
        )
        progress(0.9)

        let markdown = formatMemoryCore(rawCore, conversationCount: conversations.count, memoryCount: memoryEntries.count)
        progress(1.0)

        return MemoryCore(
            markdown: markdown,
            generatedAt: Date(),
            sourceConversationCount: conversations.count,
            sourceMemoryEntryCount: memoryEntries.count,
            tokenCount: nil
        )
    }

    func synthesizeProjectInstructions(project: ProjectGroup) async throws -> String {
        let apiKey: String
        do {
            apiKey = try keychain.load(for: .anthropicAPIKey)
        } catch {
            throw AppError.apiKeyMissing
        }

        let conversationText = project.conversations.prefix(10).map { conv in
            let messages = linearize(conversation: conv)
            return messages.map { "\($0.role): \($0.text)" }.joined(separator: "\n")
        }.joined(separator: "\n\n---\n\n")

        let userContent = """
            Create a concise system prompt (project instructions) for a Claude Project based on these conversations from "\(project.name)".
            Output only the instructions text, no preamble. Max 500 words.
            Focus on: tone, context, recurring themes, and how the user prefers assistance.

            \(conversationText)
            """
        return try await makeAPIRequest(
            apiKey: apiKey,
            messages: [["role": "user", "content": userContent]],
            systemPrompt: nil,
            maxTokens: 1500
        )
    }

    private func makeAPIRequest(
        apiKey: String,
        messages: [[String: Any]],
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": messages.map { msg in
                var m: [String: Any] = ["role": msg["role"] as? String ?? "user"]
                if let content = msg["content"] as? String {
                    m["content"] = content
                }
                return m
            },
        ]
        if let system = systemPrompt {
            body["system"] = system
        }

        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.apiRequestFailed(statusCode: 0, message: "Invalid response")
        }

        if http.statusCode == 429 {
            let retryAfterSeconds = (http.value(forHTTPHeaderField: "Retry-After")).flatMap { Int($0) } ?? 60
            let maxRetries = 3
            for attempt in 1 ... maxRetries {
                try await Task.sleep(nanoseconds: UInt64(retryAfterSeconds) * 1_000_000_000)
                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw AppError.apiRequestFailed(statusCode: 0, message: "Invalid response")
                }
                if retryHttp.statusCode == 429 {
                    if attempt == maxRetries { throw AppError.apiRateLimited }
                    continue
                }
                if (200 ..< 300).contains(retryHttp.statusCode) {
                    return try parseMessageText(data: retryData, statusCode: retryHttp.statusCode)
                }
                let msg = (try? JSONSerialization.jsonObject(with: retryData) as? [String: Any])?["error"] as? [String: Any]
                let detail = msg?["message"] as? String ?? String(data: retryData, encoding: .utf8) ?? "Unknown error"
                throw AppError.apiRequestFailed(statusCode: retryHttp.statusCode, message: detail)
            }
            throw AppError.apiRateLimited
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: responseData) as? [String: Any])?["error"] as? [String: Any]
            let detail = msg?["message"] as? String ?? String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw AppError.apiRequestFailed(statusCode: http.statusCode, message: detail)
        }

        return try parseMessageText(data: responseData, statusCode: http.statusCode)
    }

    private func parseMessageText(data: Data, statusCode: Int) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String
        else {
            throw AppError.apiRequestFailed(statusCode: statusCode, message: "Invalid response format")
        }
        return text
    }

    private func formatConversationsForExtraction(_ conversations: [OpenAIConversation]) -> String {
        conversations.map { conv in
            let messages = linearize(conversation: conv)
            let lines = messages.map { "\($0.role): \($0.text)" }
            return "Conversation: \(conv.title)\n" + lines.joined(separator: "\n")
        }.joined(separator: "\n\n---\n\n")
    }

    private func formatMemoryCore(_ raw: String, conversationCount: Int, memoryCount: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: Date())
        let header = """
        # Memory Core
        > Generated by NeuralJack from \(conversationCount) conversations and \(memoryCount) memory entries on \(dateStr)

        """
        return header + raw.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n---\n*This Memory Core was synthesized from your ChatGPT conversation history. Review and edit before pasting into Claude Project Instructions.*"
    }
}
