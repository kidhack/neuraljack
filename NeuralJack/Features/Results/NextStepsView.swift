//
//  NextStepsView.swift
//  NeuralJack
//

import SwiftUI

struct NextStepsView: View {
    let packageCount: Int
    let onImportIntoClaude: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import into Claude")
                .font(.neuralJackTitle2Semibold)

            Button("Import into Claude →") {
                onImportIntoClaude()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .focusable(false)

            Text("Opens guided setup for \(packageCount) project\(packageCount == 1 ? "" : "s")")
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
