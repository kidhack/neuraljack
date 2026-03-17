//
//  WelcomeView.swift
//  NeuralJack
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Environment(ImportViewModel.self) private var importViewModel
    @Binding var isTargeted: Bool
    @State private var shakeTrigger = 0

    var body: some View {
        VStack(spacing: 36) {
            Text("ChatGPT → Claude")
                .font(.system(size: 36, weight: .medium))

            Text("NeuralJack is a migration assistant that prepares ChatGPT data so it can easily be imported into Claude. It can break conversations into project folders, create a memory core based off conversations, and generate Claude prompts to help with the migration process.")
                .font(.neuralJackBody)
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            getStartedCallout

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
                    .font(.neuralJackTitle2Semibold)
                Text("Export your ChatGPT data from OpenAI")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
        )
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
