//
//  WizardView.swift
//  NeuralJack
//

import AppKit
import SwiftUI

struct WizardView: View {
    @Bindable var vm: WizardViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                Group {
                    switch vm.currentStep {
                    case .setup:
                        WizardSetupStepView(vm: vm)
                    case .dataSummary:
                        WizardDataSummaryStepView(vm: vm)
                    case .memoryCore:
                        WizardMemoryCoreStepView(vm: vm)
                    case .projects:
                        WizardProjectSelectionView(vm: vm)
                    case .conversations:
                        WizardConversationsStepView(vm: vm)
                    case .complete:
                        WizardCompleteStepView(vm: vm)
                    }
                }
                .padding(32)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlayScrollerStyle()
            .background(colorScheme == .dark ? Color.neuralJackWindowBackgroundDark : Color(NSColor.windowBackgroundColor))

            WizardNavBar(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vm.refreshAPIKeyStatus()
        }
    }
}

// MARK: - Navigation Bar (footer with Back + primary action)

struct WizardNavBar: View {
    @Bindable var vm: WizardViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            NeuralJackDivider()
            HStack {
                if vm.canGoBack {
                    Button {
                        vm.previousStep()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                Button {
                    Task { await vm.handlePrimaryFooterAction() }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.primaryFooterButtonTitle)
                        if vm.currentStep != .complete {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .buttonStyle(NeuralJackProminentButtonStyle())
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
                .focusable(false)
                .disabled(vm.primaryFooterButtonDisabled)
                .opacity(vm.primaryFooterButtonDisabled ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(colorScheme == .dark ? Color.neuralJackWindowBackgroundDark : Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Wizard Step Shell

/// Shared card-style container for each wizard step.
struct WizardStepShell<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.neuralJackTitle2)
                        .foregroundStyle(LinearGradient.neuralJackAccent)
                        .frame(width: 28, height: 28, alignment: .center)
                    Text(title)
                        .font(.neuralJackTitle2Semibold)
                }
                Text(subtitle)
                    .font(.neuralJackBody)
                    .lineSpacing(4)
                    .foregroundStyleNeuralJackSecondary()
            }
            .padding(.bottom, 14)

            content()
        }
    }
}

// MARK: - Section Card

struct WizardCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if colorScheme == .light {
                RoundedRectangle(cornerRadius: 10).fill(Color.neuralJackCardBackgroundLight)
            } else {
                RoundedRectangle(cornerRadius: 10).fill(Color.neuralJackCardBackgroundDark)
            }
        }
    }
}

struct WizardCardRow<Content: View>: View {
    let divider: Bool
    let content: () -> Content

    init(divider: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.divider = divider
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            if divider {
                NeuralJackDivider()
                    .padding(.horizontal, 16)
            }
        }
    }
}
