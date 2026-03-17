//
//  ConversationsExportView.swift
//  NeuralJack
//

import SwiftUI

struct ConversationsExportView: View {
    let exportResult: ExportResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Exported \(exportResult.exportedConversations) conversations")
                    .font(.neuralJackTitle2Semibold)
            }

            Text(exportResult.outputDirectory.path)
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            Text("Duration: \(Int(exportResult.durationSeconds)) seconds")
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
