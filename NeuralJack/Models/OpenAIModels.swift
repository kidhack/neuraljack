//
//  OpenAIModels.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation

// MARK: - Top-level

typealias OpenAIConversationsFile = [OpenAIConversation]

struct OpenAIConversation: Codable, Identifiable {
    let id: String
    let title: String
    let createTime: Double
    let updateTime: Double
    let mapping: [String: OpenAINode]
    let currentNode: String?
    let conversationId: String?
    let gizmoId: String?
    let isArchived: Bool?
    let conversationTemplateId: String?
    let workspaceId: String?
    let projectTitle: String?
    let customInstructions: OpenAICustomInstructions?

    var createdAt: Date { Date(timeIntervalSince1970: createTime) }
    var updatedAt: Date { Date(timeIntervalSince1970: updateTime) }

    enum CodingKeys: String, CodingKey {
        case id, title, mapping
        case createTime = "create_time"
        case updateTime = "update_time"
        case currentNode = "current_node"
        case conversationId = "conversation_id"
        case gizmoId = "gizmo_id"
        case isArchived = "is_archived"
        case conversationTemplateId = "conversation_template_id"
        case workspaceId = "workspace_id"
        case projectTitle = "project_title"
        case customInstructions = "custom_instructions"
    }
}

struct OpenAICustomInstructions: Codable {
    let aboutUserMessage: String?
    let aboutModelMessage: String?

    enum CodingKeys: String, CodingKey {
        case aboutUserMessage = "about_user_message"
        case aboutModelMessage = "about_model_message"
    }
}

// MARK: - Node (message tree node)

struct OpenAINode: Codable {
    let id: String
    let parent: String?
    let children: [String]
    let message: OpenAIMessage?
}

struct OpenAIMessage: Codable {
    let id: String
    let author: OpenAIAuthor
    let createTime: Double?
    let content: OpenAIContent
    let status: String?
    let weight: Double?

    enum CodingKeys: String, CodingKey {
        case id, author, content, status, weight
        case createTime = "create_time"
    }
}

struct OpenAIAuthor: Codable {
    let role: String
    let name: String?
}

struct OpenAIContent: Codable {
    let contentType: String
    let parts: [OpenAIContentPart]?

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case parts
    }
}

// Parts can be String OR objects — use a custom decoder
enum OpenAIContentPart: Codable {
    case text(String)
    case unsupported

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .unsupported
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .unsupported: try container.encodeNil()
        }
    }

    var textValue: String? {
        if case .text(let t) = self { return t }
        return nil
    }
}

// MARK: - Memory

struct OpenAIMemoryFile: Codable {
    let memories: [OpenAIMemoryEntry]
}

struct OpenAIMemoryEntry: Codable, Identifiable {
    let id: String
    let text: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, text
        case createdAt = "created_at"
    }
}

// MARK: - User

struct OpenAIUser: Codable {
    let id: String?
    let email: String?
    let chatgptPlusUser: Bool?
    let phoneNumber: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case chatgptPlusUser = "chatgpt_plus_user"
        case phoneNumber = "phone_number"
    }
}
