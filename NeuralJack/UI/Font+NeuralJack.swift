//
//  Font+NeuralJack.swift
//  NeuralJack
//
//  Type scale: Title 36pt (hero), Wizard title 22pt, Card header 16pt, Body 16pt, Caption 13pt, Hero 24/66pt.
//

import SwiftUI

/// Extra leading (line spacing) for body and caption copy. Apply with .lineSpacing(NeuralJack.bodyLineSpacing).
enum NeuralJack {
    static let bodyLineSpacing: CGFloat = 4
    /// Corner radius matching the app window (macOS standard). Use for About image and other window-aligned chrome.
    static let windowCornerRadius: CGFloat = 10
}

extension Font {
    /// Wizard step title and icon (22pt). Use only in WizardStepShell.
    static var neuralJackTitle2: Font { .system(size: 22) }
    static var neuralJackTitle2Semibold: Font { .system(size: 22, weight: .semibold) }
    /// Card headers inside wizard cards (16pt; 6pt smaller than wizard title).
    static var neuralJackCardHeader: Font { .system(size: 16) }
    static var neuralJackCardHeaderSemibold: Font { .system(size: 16, weight: .semibold) }
    /// Body copy, list rows, option labels (use weight for emphasis)
    static var neuralJackBody: Font { .system(size: 16) }
    /// Help text, metadata, secondary labels (bumped down 1 from 14pt)
    static var neuralJackCaption: Font { .system(size: 13) }
    /// Big numbers (e.g. stat cards)
    static var neuralJackLargeTitle: Font { .system(size: 24) }
}
