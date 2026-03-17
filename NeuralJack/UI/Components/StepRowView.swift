//
//  StepRowView.swift
//  NeuralJack
//

import SwiftUI

struct StepRowView: View {
    let title: String
    let state: StepState
    let progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            stepIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.neuralJackBody)
                if let p = progress, case .inProgress = state {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var stepIcon: some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.quaternary)
        case .inProgress:
            ProgressView()
                .scaleEffect(0.8)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
