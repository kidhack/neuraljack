//
//  GuidedImportService.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import AppKit
import Foundation

/// Handles Claude Projects onboarding: opens browser, clipboard, Finder, and persists HUD progress.
final class GuidedImportService {
    func openClaudeProjects() {
        guard let url = URL(string: "https://claude.ai/projects") else { return }
        NSWorkspace.shared.open(url)
    }

    func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    private let progressKey = "com.neuraljack.guided-import-progress"

    func saveProgress(_ progress: GuidedImportProgress) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    func loadProgress() -> GuidedImportProgress? {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(GuidedImportProgress.self, from: data)
    }

    func clearProgress() {
        UserDefaults.standard.removeObject(forKey: progressKey)
    }

    /// Builds the 8-step import flow for a package.
    func makeSteps(for package: ClaudeProjectPackage) -> [ImportStep] {
        let instructionsContent = (try? String(contentsOf: package.projectInstructionsFile, encoding: .utf8)) ?? ""
        let exportRoot = package.packageDirectory.deletingLastPathComponent().deletingLastPathComponent()
        let fileList = [package.projectInstructionsFile.lastPathComponent, package.memoryCoreFile.lastPathComponent] + package.conversationFiles.map(\.lastPathComponent)
        let filesLine = fileList.joined(separator: "\n• ")
        return [
            ImportStep(id: 1, instruction: "Click **New Project** in the sidebar", autoAction: .none, actionStatusLabel: nil),
            ImportStep(id: 2, instruction: "Name this project: \(package.name)", autoAction: .copyToClipboard(package.name), actionStatusLabel: "Project name copied"),
            ImportStep(id: 3, instruction: "Paste the name, then click **Create project**", autoAction: .none, actionStatusLabel: nil),
            ImportStep(id: 4, instruction: "Click **Add content** in the project knowledge panel", autoAction: .none, actionStatusLabel: nil),
            ImportStep(id: 5, instruction: "Drag these files into the upload area (from your project folder and NeuralJack-Export root):\n• \(filesLine)", autoAction: .revealInFinder(exportRoot), actionStatusLabel: "Folder revealed in Finder"),
            ImportStep(id: 6, instruction: "Click **Project Instructions** (the pencil icon)", autoAction: .none, actionStatusLabel: nil),
            ImportStep(id: 7, instruction: "Paste the instructions below:\n\(String(instructionsContent.prefix(500)))...", autoAction: .copyToClipboard(instructionsContent), actionStatusLabel: "Instructions copied"),
            ImportStep(id: 8, instruction: "Click **Save**", autoAction: .none, actionStatusLabel: nil),
        ]
    }
}
