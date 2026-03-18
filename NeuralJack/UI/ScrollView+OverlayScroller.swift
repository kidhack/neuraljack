//
//  ScrollView+OverlayScroller.swift
//  NeuralJack
//
//  Forces macOS ScrollView to use overlay scrollbars so the scrollbar doesn’t
//  reserve space and cause content to jump when it appears.
//

import AppKit
import SwiftUI

extension View {
    /// Use overlay scrollbars on macOS so content doesn’t shift when the scrollbar appears.
    func overlayScrollerStyle() -> some View {
        background(OverlayScrollerAnchor())
    }
}

private struct OverlayScrollerAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = false
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        func runFix() {
            if let window = nsView.window, let contentView = window.contentView {
                Self.applyOverlayToAllScrollViews(in: contentView)
            } else {
                Self.findAndApplyOverlay(from: nsView)
            }
        }
        DispatchQueue.main.async { runFix() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { runFix() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { runFix() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { runFix() }
    }

    /// Recursively find every NSScrollView in the window and apply overlay style so the scrollbar never reserves space.
    private static func applyOverlayToAllScrollViews(in view: NSView) {
        if let sv = view as? NSScrollView {
            applySubtleOverlay(to: sv)
        }
        for sub in view.subviews {
            applyOverlayToAllScrollViews(in: sub)
        }
    }

    /// Walk up from the anchor and apply overlay to any NSScrollView we find (fallback when window not yet available).
    private static func findAndApplyOverlay(from view: NSView) {
        var current: NSView? = view
        while let v = current {
            if let sv = v as? NSScrollView {
                applySubtleOverlay(to: sv)
            }
            for sub in v.subviews {
                if let sv = sub as? NSScrollView {
                    applySubtleOverlay(to: sv)
                }
            }
            current = v.superview
        }
    }

    private static func applySubtleOverlay(to scrollView: NSScrollView) {
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.alphaValue = 0.5
        scrollView.horizontalScroller?.alphaValue = 0.5
    }
}
