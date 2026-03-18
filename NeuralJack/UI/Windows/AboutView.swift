//
//  AboutView.swift
//  NeuralJack
//

import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Image("AboutIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 256, height: 256)
                .clipShape(RoundedRectangle(cornerRadius: NeuralJack.windowCornerRadius))

            Text("NeuralJack")
                .font(.system(size: 20, weight: .semibold))

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/kidhack/neuraljack")!)
                } label: {
                    Text("Version \(version)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? Color.neuralJackLinkOnDark : Color.accentColor)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Text("© 2026 kidhack. MIT License.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .frame(minWidth: 360, minHeight: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color.neuralJackWindowBackgroundDark : Color(NSColor.windowBackgroundColor))
        .toolbarBackground(colorScheme == .dark ? Color.neuralJackWindowBackgroundDark : Color(NSColor.windowBackgroundColor), for: .automatic)
        .background(NonResizableWindowAnchor())
    }
}

// MARK: - Disable window resizing

private struct NonResizableWindowAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = false
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        func makeNonResizable() {
            guard let window = nsView.window else { return }
            window.styleMask = window.styleMask.subtracting(.resizable)
            let contentSize = window.contentRect(forFrameRect: window.frame).size
            window.minSize = contentSize
            window.maxSize = contentSize
        }
        makeNonResizable()
        DispatchQueue.main.async { makeNonResizable() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { makeNonResizable() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { makeNonResizable() }
    }
}
