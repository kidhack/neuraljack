//
//  Color+NeuralJack.swift
//  NeuralJack
//

import AppKit
import SwiftUI

// MARK: - Accent gradient (magenta → purple)

extension LinearGradient {
    /// Subtle magenta-to-purple gradient for primary buttons and step icons (light mode).
    static var neuralJackAccent: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.769, green: 0.149, blue: 0.831),   // #C026D3
                Color(red: 0.486, green: 0.227, blue: 0.929)   // #7C3AED
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Darker gradient for primary buttons in dark mode.
    static var neuralJackAccentDark: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.54, green: 0.10, blue: 0.58),   // darker magenta
                Color(red: 0.34, green: 0.16, blue: 0.65)   // darker purple
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Prominent button style with gradient

struct NeuralJackProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        NeuralJackProminentButtonContent(configuration: configuration)
    }
}

// MARK: - Divider (darkened in dark mode)

struct NeuralJackDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    var axis: Axis = .horizontal

    private var dividerColor: Color {
        colorScheme == .dark ? Color.neuralJackDividerDark : Color.neuralJackDividerLight
    }

    var body: some View {
        Group {
            if axis == .horizontal {
                Divider()
                    .tint(dividerColor)
            } else {
                Rectangle()
                    .fill(dividerColor)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}

private struct NeuralJackProminentButtonContent: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? LinearGradient.neuralJackAccentDark : LinearGradient.neuralJackAccent)
                    .opacity(configuration.isPressed ? 0.9 : 1)
            )
            .foregroundStyle(.white)
    }
}

// MARK: - Semantic secondary text color

extension Color {
    /// Use for captions and secondary labels so they stay readable on glass and in light/dark mode.
    static var neuralJackSecondary: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    /// Accessible secondary text in light mode (≥ 4.5:1 on window and #F7F7F7). #525252.
    static var neuralJackSecondaryLight: Color {
        Color(red: 82 / 255.0, green: 82 / 255.0, blue: 82 / 255.0)
    }

    /// Accessible secondary text in dark mode (≥ 4.5:1 on #0D0D0D and #1A1A1C). #A8A8A8.
    static var neuralJackSecondaryDark: Color {
        Color(red: 168 / 255.0, green: 168 / 255.0, blue: 168 / 255.0)
    }

    /// Card background in light mode (#F7F7F7).
    static var neuralJackCardBackgroundLight: Color {
        Color(red: 247 / 255.0, green: 247 / 255.0, blue: 247 / 255.0)
    }

    /// Card background in dark mode (#161618).
    static var neuralJackCardBackgroundDark: Color {
        Color(red: 22 / 255.0, green: 22 / 255.0, blue: 24 / 255.0)
    }

    /// Window background in dark mode (#0D0D0D).
    static var neuralJackWindowBackgroundDark: Color {
        Color(red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0)
    }

    /// Divider line in light mode (system separator).
    static var neuralJackDividerLight: Color {
        Color(nsColor: .separatorColor)
    }

    /// Darker divider line in dark mode (#2C2C2E).
    static var neuralJackDividerDark: Color {
        Color(red: 44 / 255.0, green: 44 / 255.0, blue: 46 / 255.0)
    }

    /// Link/accent text on dark card background (≥ 4.5:1 on #161618). Use for prompts like "Choose where to save…".
    static var neuralJackLinkOnDark: Color {
        Color(red: 183 / 255.0, green: 148 / 255.0, blue: 246 / 255.0)  // #B794F6
    }

    /// Selected project row background in dark mode (#110D1F).
    static var neuralJackProjectSelectionBackgroundDark: Color {
        Color(red: 17 / 255.0, green: 13 / 255.0, blue: 31 / 255.0)
    }

    /// Selected project row background in light mode (#F3EDFF).
    static var neuralJackProjectSelectionBackgroundLight: Color {
        Color(red: 243 / 255.0, green: 237 / 255.0, blue: 255 / 255.0)
    }

    /// Selected project row border in dark mode (#342457).
    static var neuralJackProjectSelectionBorderDark: Color {
        Color(red: 52 / 255.0, green: 36 / 255.0, blue: 87 / 255.0)
    }

    /// Selected project row border in light mode (#E8DBFF).
    static var neuralJackProjectSelectionBorderLight: Color {
        Color(red: 232 / 255.0, green: 219 / 255.0, blue: 255 / 255.0)
    }
}

// MARK: - Accessible secondary text (WCAG AA)

private struct NeuralJackSecondaryTextStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(colorScheme == .dark ? Color.neuralJackSecondaryDark : Color.neuralJackSecondaryLight)
    }
}

extension View {
    /// Applies an accessible secondary text color (≥ 4.5:1) for the current color scheme.
    func foregroundStyleNeuralJackSecondary() -> some View {
        modifier(NeuralJackSecondaryTextStyle())
    }
}
