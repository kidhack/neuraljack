//
//  MemoryCoreView.swift
//  NeuralJack
//

import SwiftUI

struct MemoryCoreView: View {
    let memoryCore: MemoryCore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(memoryCore.markdown)
                    .font(.neuralJackBody)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button("Copy to Clipboard") {
                        memoryCore.copyToClipboard()
                    }
                    .keyboardShortcut("c", modifiers: .command)
                    .focusable(false)
                }
            }
            .padding()
        }
    }
}
