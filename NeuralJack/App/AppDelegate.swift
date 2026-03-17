//
//  AppDelegate.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import AppKit

extension Notification.Name {
    static let zipFileDropped = Notification.Name("zipFileDropped")
}

/// Handles Dock icon file drops and other app-level lifecycle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }
        NotificationCenter.default.post(name: .zipFileDropped, object: url)
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Future deep link support (e.g., neuraljack://open?path=...)
        for url in urls where url.scheme == "neuraljack" {
            // Handle deep link
        }
    }
}
