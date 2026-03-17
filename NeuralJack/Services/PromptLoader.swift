//
//  PromptLoader.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation

enum PromptLoader {
    /// Loads a prompt from Bundle.main by name (without extension). Expects .txt in Resources/Prompts/.
    static func load(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Resources/Prompts")
            ?? Bundle.main.url(forResource: name, withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let string = String(data: data, encoding: .utf8)
        else {
            fatalError("Prompt '\(name).txt' not found in Resources/Prompts/")
        }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
