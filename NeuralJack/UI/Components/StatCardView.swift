//
//  StatCardView.swift
//  NeuralJack
//

import SwiftUI

struct StatCardView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.neuralJackLargeTitle)
            Text(label)
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }
}
