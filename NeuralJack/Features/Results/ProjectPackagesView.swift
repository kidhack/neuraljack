//
//  ProjectPackagesView.swift
//  NeuralJack
//

import SwiftUI

struct ProjectPackagesView: View {
    let packages: [ClaudeProjectPackage]

    var body: some View {
        List(packages) { pkg in
            VStack(alignment: .leading, spacing: 4) {
                Text(pkg.name)
                    .font(.neuralJackTitle2Semibold)
                Text("\(pkg.conversationCount) conversations")
                    .font(.neuralJackCaption)
                    .foregroundStyle(.secondary)
                Text(pkg.packageDirectory.path)
                    .font(.neuralJackCaption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 4)
        }
    }
}
