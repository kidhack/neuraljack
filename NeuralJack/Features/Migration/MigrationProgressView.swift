//
//  MigrationProgressView.swift
//  NeuralJack
//

import SwiftUI

struct MigrationProgressView: View {
    @Environment(MigrationViewModel.self) private var migrationViewModel
    @State private var showCancelAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Migration in progress…")
                .font(.neuralJackTitle2)

            VStack(alignment: .leading, spacing: 16) {
                StepRowView(
                    title: "Parsed Conversations",
                    state: migrationViewModel.stepStates[.parseConversations] ?? .pending,
                    progress: nil
                )
                StepRowView(
                    title: "Generating Memory Core",
                    state: migrationViewModel.stepStates[.generateMemoryCore] ?? .pending,
                    progress: progressValue(for: .generateMemoryCore)
                )
                StepRowView(
                    title: "Exporting conversations",
                    state: migrationViewModel.stepStates[.exportConversations] ?? .pending,
                    progress: progressValue(for: .exportConversations)
                )
                StepRowView(
                    title: "Exporting Project Templates",
                    state: migrationViewModel.stepStates[.packageProjects] ?? .pending,
                    progress: progressValue(for: .packageProjects)
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))

            Text("Estimated time remaining: ~1 minute")
                .font(.neuralJackCaption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .alert("Cancel Migration?", isPresented: $showCancelAlert) {
            Button("Cancel Migration", role: .destructive) {
                migrationViewModel.cancel()
            }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Partial results will be discarded.")
        }
    }

    private func progressValue(for step: MigrationViewModel.Step) -> Double? {
        guard case .inProgress(let p) = migrationViewModel.stepStates[step] else { return nil }
        return p
    }
}
