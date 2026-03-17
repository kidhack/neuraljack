//
//  ErrorBannerView.swift
//  NeuralJack
//

import SwiftUI

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.neuralJackBody)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .accessibilityHint("Double tap to dismiss")
    }
}
