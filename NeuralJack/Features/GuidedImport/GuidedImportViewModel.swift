//
//  GuidedImportViewModel.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import AppKit
import Foundation

/// Manages the Guided Import HUD state and step progression.
@MainActor
@Observable
final class GuidedImportViewModel {
    private let guidedImportService: GuidedImportService

    var packages: [ClaudeProjectPackage] = []
    var currentPackageIndex: Int = 0
    var currentStepIndex: Int = 0
    var stepStates: [Int: StepState] = [:]
    var completedPackageIDs: Set<String> = []
    weak var panel: NSPanel?

    init(guidedImportService: GuidedImportService) {
        self.guidedImportService = guidedImportService
    }

    var currentPackage: ClaudeProjectPackage? {
        guard packages.indices.contains(currentPackageIndex) else { return nil }
        return packages[currentPackageIndex]
    }

    var currentStep: ImportStep? {
        guard let pkg = currentPackage else { return nil }
        let steps = guidedImportService.makeSteps(for: pkg)
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var isLastStep: Bool {
        guard let pkg = currentPackage else { return true }
        let steps = guidedImportService.makeSteps(for: pkg)
        return currentStepIndex >= steps.count - 1
    }

    var isLastProject: Bool {
        currentPackageIndex >= packages.count - 1
    }

    var isComplete: Bool {
        !packages.isEmpty && completedPackageIDs.count == packages.count
    }

    /// Loads saved progress, positions and shows the HUD panel.
    func start(packages: [ClaudeProjectPackage]) {
        self.packages = packages
        currentPackageIndex = 0
        currentStepIndex = 0
        stepStates = [:]

        if let saved = guidedImportService.loadProgress(),
           !saved.packageIDs.isEmpty,
           let idx = packages.firstIndex(where: { $0.id == saved.currentPackageID }) {
            currentPackageIndex = idx
            currentStepIndex = min(saved.currentStepIndex, guidedImportService.makeSteps(for: packages[idx]).count - 1)
            completedPackageIDs = saved.completedPackageIDs
        } else {
            guidedImportService.openClaudeProjects()
        }

        for i in 0 ..< currentStepIndex {
            stepStates[i] = .done
        }

        positionAndShowPanel()
    }

    func advanceStep() {
        guard let pkg = currentPackage else { return }
        let steps = guidedImportService.makeSteps(for: pkg)

        stepStates[currentStepIndex] = .done
        let nextIndex = currentStepIndex + 1
        if nextIndex < steps.count {
            executeAutoAction(for: steps[nextIndex])
        }

        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        } else if currentPackageIndex < packages.count - 1 {
            completedPackageIDs.insert(pkg.id)
            currentPackageIndex += 1
            currentStepIndex = 0
            stepStates = [:]
        } else {
            completedPackageIDs.insert(pkg.id)
        }

        saveProgress()
    }

    func skipProject() {
        guard let pkg = currentPackage else { return }
        completedPackageIDs.insert(pkg.id)
        if currentPackageIndex < packages.count - 1 {
            currentPackageIndex += 1
            currentStepIndex = 0
            stepStates = [:]
        } else {
            skipAll()
            return
        }
        saveProgress()
    }

    func skipAll() {
        guidedImportService.clearProgress()
        panel?.orderOut(nil)
    }

    private func executeAutoAction(for step: ImportStep) {
        switch step.autoAction {
        case .none:
            break
        case .copyToClipboard(let string):
            guidedImportService.copyToClipboard(string)
        case .revealInFinder(let url):
            guidedImportService.revealInFinder(url)
        }
    }

    private func saveProgress() {
        guard let pkg = currentPackage else { return }
        let progress = GuidedImportProgress(
            packageIDs: packages.map(\.id),
            completedPackageIDs: completedPackageIDs,
            currentPackageID: pkg.id,
            currentStepIndex: currentStepIndex,
            outputDirectory: pkg.packageDirectory.deletingLastPathComponent()
        )
        guidedImportService.saveProgress(progress)
    }

    private func positionAndShowPanel() {
        guard let panel else { return }
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 16
        let hudWidth: CGFloat = 340
        let hudHeight = panel.frame.height
        let x = screen.visibleFrame.maxX - hudWidth - padding
        let y = screen.visibleFrame.midY - hudHeight / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFront(nil)
    }
}
