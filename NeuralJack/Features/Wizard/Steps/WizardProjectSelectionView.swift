//
//  WizardProjectSelectionView.swift
//  NeuralJack
//

import AppKit
import SwiftUI

struct WizardProjectSelectionView: View {
    @Bindable var vm: WizardViewModel

    var body: some View {
        WizardStepShell(
            icon: "folder.badge.plus",
            title: "Select Projects",
            subtitle: vm.includeMemoryCore
                ? "Memory Core will be generated from your selected projects. Project names are not included in ChatGPT data export; we will generate prompts to help migrate project names using Claude."
                : "Project names are not included in ChatGPT data export. We will generate prompts to help migrate project names using Claude."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                projectList
                if vm.isCurrentStepBusy {
                    exportingProgressView
                } else if vm.selectedProjectsCount == 0 && !vm.allSelectedProjectsDone {
                    Text("Select at least one project to continue.")
                        .font(.neuralJackCaption)
                        .foregroundStyleNeuralJackSecondary()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: vm.selectedProjectIndices) {
            vm.checkProjectSelectionChangedAndResetMemoryCoreIfNeeded()
        }
    }

    // MARK: - Select All

    private var selectAllRow: some View {
        HStack(alignment: .center, spacing: 6) {
            TriStateCheckbox(
                isOn: vm.allProjectsSelected,
                isIndeterminate: vm.someProjectsSelected,
                action: { vm.setAllProjectsSelected(!vm.allProjectsSelected) }
            )
            .frame(width: 22, height: 22)
            Text("Projects")
                .font(.neuralJackCardHeaderSemibold)
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Project List

    private var projectList: some View {
        WizardCard {
            WizardCardRow(divider: true) {
                selectAllRow
            }
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(vm.projectGroups.enumerated()), id: \.element.id) { index, group in
                        ProjectRowView(
                            group: group,
                            isSelected: vm.selectedProjectIndices.contains(index),
                            phase: vm.projectPhases[group.id] ?? .ready,
                            onToggleSelection: { vm.toggleProjectSelection(index) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Exporting progress (shown in content when footer triggers export)

    private var exportingProgressView: some View {
        WizardCard {
            WizardCardRow(divider: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        if vm.exportingProjectTotal > 0 {
                            Text("Exporting project \(vm.exportingProjectCurrent) of \(vm.exportingProjectTotal)…")
                                .font(.neuralJackBody)
                        } else {
                            Text("Exporting…")
                                .font(.neuralJackBody)
                        }
                    }
                    if let exportingId = vm.projectGroups.indices.first(where: { vm.projectPhases[vm.projectGroups[$0].id] == .exporting }),
                       vm.projectGroups.indices.contains(exportingId) {
                        let group = vm.projectGroups[exportingId]
                        ProgressView(value: vm.projectProgress[group.id] ?? 0)
                            .tint(Color.accentColor)
                    }
                }
            }
        }
    }
}

// MARK: - Tri-State Checkbox (all / some / none)

private struct TriStateCheckbox: NSViewRepresentable {
    let isOn: Bool
    let isIndeterminate: Bool
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(checkboxWithTitle: "", target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        button.allowsMixedState = true
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        if isIndeterminate {
            button.state = .mixed
        } else {
            button.state = isOn ? .on : .off
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator {
        var action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func tapped(_ sender: NSButton) {
            action()
        }
    }
}

// MARK: - Project Row (checkbox on left, accordion chevron on right)

private struct ProjectRowView: View {
    let group: ProjectGroup
    let isSelected: Bool
    let phase: WizardViewModel.ProjectPhase
    let onToggleSelection: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggleSelection() }
                )) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 14, weight: .medium))
                    Text("\(group.conversations.count) conversation\(group.conversations.count == 1 ? "" : "s")")
                        .font(.neuralJackCaption)
                        .foregroundStyleNeuralJackSecondary()
                }

                Spacer(minLength: 8)

                phaseBadge

                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyleNeuralJackSecondary()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.conversations) { conv in
                        Text(conv.title)
                            .font(.neuralJackCaption)
                            .foregroundStyleNeuralJackSecondary()
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.leading, 28)
                .padding(.vertical, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? (colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.5)) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
    }

    @ViewBuilder
    private var phaseBadge: some View {
        switch phase {
        case .ready:
            EmptyView()
        case .exporting:
            ProgressView().controlSize(.mini)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
