//
//  DropZoneView.swift
//  NeuralJack
//

import SwiftUI

struct DropZoneView: View {
    @Binding var isTargeted: Bool
    var onChooseFile: (() -> Void)? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.neuralJackSecondary,
                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
            )
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
            .overlay {
                Button {
                    onChooseFile?()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 66))
                            .foregroundStyleNeuralJackSecondary()
                        Text(isTargeted ? "Release to import" : "Drop your OpenAI data export here")
                            .font(.neuralJackCardHeader)
                        Text("Choose folder or zip…")
                            .font(.neuralJackBody)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .frame(minWidth: 280, minHeight: 180)
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}
