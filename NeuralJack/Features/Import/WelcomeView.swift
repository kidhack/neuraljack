//
//  WelcomeView.swift
//  NeuralJack
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Environment(ImportViewModel.self) private var importViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isTargeted: Bool
    @State private var shakeTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ChatGPT → Claude")
                .font(.system(size: 36, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(height: 16)

            Text("NeuralJack is a migration assistant that prepares ChatGPT data for easy import to Claude. It will parse conversations into project folders, create a Memory Core using selected projects, and generate Claude prompts to complete migration.")
                .font(.neuralJackBody)
                .lineSpacing(4)
                .foregroundStyleNeuralJackSecondary()
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 28)

            getStartedCallout

            Spacer().frame(height: 36)

            DropZoneView(isTargeted: $isTargeted, onChooseFile: { openFilePanel() })
                .modifier(ShakeEffect(trigger: shakeTrigger))
        }
        .padding(40)
        .onReceive(NotificationCenter.default.publisher(for: .zipFileDropped)) { notification in
            guard let url = notification.object as? URL else { return }
            Task {
                await importViewModel.handleDrop(url: url)
            }
        }
        .onChange(of: importViewModel.failedDropCount) { _, _ in
            shakeTrigger += 1
        }
    }

    private var getStartedCallout: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Get Started")
                    .font(.neuralJackCardHeaderSemibold)
                Text("Export your ChatGPT data from OpenAI")
                    .font(.system(size: 14))
                    .foregroundStyleNeuralJackSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Export your OpenAI data") {
                if let url = URL(string: "https://chatgpt.com/#settings/DataControls") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .font(.neuralJackBody)
            .focusable(false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackground)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if colorScheme == .light {
            RoundedRectangle(cornerRadius: 10).fill(Color.neuralJackCardBackgroundLight)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.neuralJackCardBackgroundDark)
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await importViewModel.handleDrop(url: url)
            }
        }
    }
}

// MARK: - Shake Effect

private struct ShakeEffect: ViewModifier {
    let trigger: Int
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                Task { @MainActor in
                    let steps: [CGFloat] = [10, -10, 8, -8, 6, -6, 4, -4, 0]
                    for step in steps {
                        withAnimation(.linear(duration: 0.04)) {
                            offset = step
                        }
                        try? await Task.sleep(nanoseconds: 40_000_000)
                    }
                }
            }
    }
}
