//
//  Font+NeuralJack.swift
//  NeuralJack
//
//  Type scale: Title 18pt, Body 16pt, Caption 13pt, Hero 24/36/66pt.
//

import SwiftUI

/// Extra leading (line spacing) for body and caption copy. Apply with .lineSpacing(NeuralJack.bodyLineSpacing).
enum NeuralJack {
    static let bodyLineSpacing: CGFloat = 4
}

extension Font {
    /// Section/step titles, card headers (down 2pt from 20)
    static var neuralJackTitle2: Font { .system(size: 18) }
    static var neuralJackTitle2Semibold: Font { .system(size: 18, weight: .semibold) }
    /// Body copy, list rows, option labels (use weight for emphasis)
    static var neuralJackBody: Font { .system(size: 16) }
    /// Help text, metadata, secondary labels (bumped down 1 from 14pt)
    static var neuralJackCaption: Font { .system(size: 13) }
    /// Big numbers (e.g. stat cards)
    static var neuralJackLargeTitle: Font { .system(size: 24) }
}
