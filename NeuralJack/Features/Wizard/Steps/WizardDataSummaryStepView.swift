//
//  WizardDataSummaryStepView.swift
//  NeuralJack
//

import SwiftUI
import AppKit

struct WizardDataSummaryStepView: View {
    @Bindable var vm: WizardViewModel

    var body: some View {
        WizardStepShell(
            icon: "doc.text.magnifyingglass",
            title: "ChatGPT Data",
            subtitle: "Your data was successfully parsed. Next we will prepare it for migration."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                accountAndStatsCard
                planCard
                outputCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Account & Stats (merged card)

    private var accountAndStatsCard: some View {
        WizardCard {
            if let user = vm.export.user, user.email != nil || user.id != nil {
                WizardCardRow(divider: true) {
                    Text("OpenAI Account")
                        .font(.neuralJackTitle2Semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                WizardCardRow(divider: true) {
                    HStack(alignment: .center, spacing: 12) {
                        if let email = user.email {
                            Text(email)
                                .font(.neuralJackBody)
                        }
                        Spacer(minLength: 0)
                        if let range = vm.export.dateRange {
                            Text(rangeFormatted(range))
                                .font(.neuralJackCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            WizardCardRow(divider: false) {
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("\(vm.export.conversationCount)")
                            .font(.neuralJackTitle2Semibold)
                        Text("Conversations")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider()
                        .frame(width: 1)
                    VStack(spacing: 6) {
                        Text("\(vm.export.projectCount)")
                            .font(.neuralJackTitle2Semibold)
                        Text("Projects")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Plan Card

    private var planCard: some View {
        WizardCard {
            WizardCardRow(divider: true) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include With Migration")
                        .font(.neuralJackTitle2Semibold)
                    Text("Optional data to include with projects and conversations.")
                        .font(.neuralJackCaption)
                        .lineSpacing(NeuralJack.bodyLineSpacing)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            WizardCardRow(divider: true) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory Core")
                            .font(.system(size: 16, weight: .medium))
                        Text("Generate context file for Cluade based on exported projects.")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle(isOn: $vm.includeMemoryCore) { EmptyView() }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }

            if vm.hasUncategorizedConversations {
                WizardCardRow(divider: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vm.uncategorizedConversations.count) general conversations")
                            .font(.system(size: 18, weight: .medium))
                        Text("Conversations not tied to a specific project.")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            WizardCardRow(divider: false) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Output Log")
                            .font(.system(size: 16, weight: .medium))
                        Text("Include a log of all outputs.")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle(isOn: $vm.includeExportLog) { EmptyView() }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Output Card

    private var outputCard: some View {
        WizardCard {
            WizardCardRow {
                Text("Output Location")
                    .font(.neuralJackTitle2Semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            WizardCardRow(divider: false) {
                Button {
                    vm.chooseOutputDirectory()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: vm.hasUserChosenOutputDirectory ? "folder.fill" : "folder.badge.plus")
                            .foregroundStyle(vm.hasUserChosenOutputDirectory ? Color.secondary : Color.accentColor)
                        if vm.hasUserChosenOutputDirectory {
                            Text(vm.outputFolderPath())
                                .font(.neuralJackCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Choose where to save your export…")
                                .font(.neuralJackCaption)
                                .foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                        Image(systemName: "ellipsis.circle")
                            .font(.neuralJackCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(vm.hasUserChosenOutputDirectory ? vm.outputDirectory.path : "Choose output folder (required to continue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func rangeFormatted(_ range: ClosedRange<Date>) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: range.lowerBound)) – \(formatter.string(from: range.upperBound))"
    }
}

