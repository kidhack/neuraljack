//
//  GuidedImportPanel.swift
//  NeuralJack
//

import AppKit
import SwiftUI

final class GuidedImportPanel: NSPanel {
    private let hostingView: NSHostingView<AnyView>
    let viewModel: GuidedImportViewModel

    init(viewModel: GuidedImportViewModel) {
        self.viewModel = viewModel
        hostingView = NSHostingView(rootView: AnyView(GuidedImportHUDView().environment(viewModel)))

        super.init(
            contentRect: .zero,
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        title = "NeuralJack Guide"

        contentView = hostingView
        viewModel.panel = self
    }

    func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 16
        let hudWidth: CGFloat = 340
        hostingView.frame = CGRect(x: 0, y: 0, width: hudWidth, height: 400)
        contentView?.setFrameSize(NSSize(width: hudWidth, height: 400))
        setContentSize(NSSize(width: hudWidth, height: 400))
        let x = screen.visibleFrame.maxX - hudWidth - padding
        let y = screen.visibleFrame.midY - 400 / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show() {
        positionOnScreen()
        orderFront(nil)
    }

    func hide() {
        orderOut(nil)
    }
}
