//
//  ImportProgressView.swift
//  NeuralJack
//

import SwiftUI

struct ImportProgressView: View {
    @Environment(ImportViewModel.self) private var importViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Parsing export…")
                .font(.neuralJackTitle2)

            ProgressView()
                .progressViewStyle(.linear)
                .scaleEffect(1.2)

            Text(importViewModel.parseProgressMessage.isEmpty ? "Preparing…" : importViewModel.parseProgressMessage)
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
