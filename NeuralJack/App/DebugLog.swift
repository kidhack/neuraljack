//
//  DebugLog.swift
//  NeuralJack
//
//  Session instrumentation; remove after debug verification.
//

import Foundation

enum DebugLog {
    private static let path = "/Users/kidhack/Documents/Dev/NeuralJack/.cursor/debug-248090.log"

    static func log(location: String, message: String, data: [String: String], hypothesisId: String) {
        // #region agent log
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let payload: [String: Any] = [
            "sessionId": "248090",
            "location": location,
            "message": message,
            "data": data,
            "timestamp": ts,
            "hypothesisId": hypothesisId
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: json, encoding: .utf8) else { return }
        let lineWithNewline = line + "\n"
        guard let dataToAppend = lineWithNewline.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: path) {
            let handle = FileHandle(forWritingAtPath: path)
            handle?.seekToEndOfFile()
            handle?.write(dataToAppend)
            try? handle?.close()
        } else {
            try? dataToAppend.write(to: URL(fileURLWithPath: path))
        }
        // #endregion
    }
}
