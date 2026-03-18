//
//  ImportProgressView.swift
//  NeuralJack
//

import SwiftUI

struct ImportProgressView: View {
    @Environment(ImportViewModel.self) private var importViewModel

    var body: some View {
        VStack(spacing: 5) {
            Text("Parsing export…")
                .font(.neuralJackCardHeader)

            ProgressView()
                .progressViewStyle(.linear)
                .scaleEffect(1.2)

            Text(importViewModel.parseProgressMessage.isEmpty ? "Preparing…" : importViewModel.parseProgressMessage)
                .font(.neuralJackCaption)
                .foregroundStyleNeuralJackSecondary()
        }
        .padding(40)
    }
}
