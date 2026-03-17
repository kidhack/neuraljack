//
//  ZIPParserService.swift
//  NeuralJack
//
//  Created by kidhack on 3/3/26.
//

import Foundation
import ZIPFoundation

actor ZIPParserService {
    /// Parses an OpenAI export from a ZIP file or an extracted folder.
    /// Validation is based only on content (presence of conversations.json), never filename.
    func parse(from url: URL, progress: @escaping (String) -> Void = { _ in }) async throws -> OpenAIExport {
        if url.hasDirectoryPath {
            return try await parseFromFolder(folderURL: url)
        } else {
            return try await parse(zipURL: url, progress: progress)
        }
    }

    func parse(zipURL: URL, progress: @escaping (String) -> Void = { _ in }) async throws -> OpenAIExport {
        let accessing = zipURL.startAccessingSecurityScopedResource()
        defer { if accessing { zipURL.stopAccessingSecurityScopedResource() } }

        print("[ZIPParser] Attempting to parse: \(zipURL.path)")
        progress("Verifying file...")

        let resourceValues = try? zipURL.resourceValues(forKeys: [
            .ubiquitousItemDownloadingStatusKey,
            .fileSizeKey
        ])
        print("[ZIPParser] File size: \(resourceValues?.fileSize ?? 0) bytes")
        print("[ZIPParser] Download status: \(String(describing: resourceValues?.ubiquitousItemDownloadingStatus))")

        if resourceValues?.ubiquitousItemDownloadingStatus != .current {
            try? FileManager.default.startDownloadingUbiquitousItem(at: zipURL)
            throw AppError.iCloudFileNotDownloaded
        }

        let localCopy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".zip")
        defer { try? FileManager.default.removeItem(at: localCopy) }
        progress("Copying file...")
        do {
            try FileManager.default.copyItem(at: zipURL, to: localCopy)
        } catch {
            print("[ZIPParser] ❌ Copy failed: \(error)")
            print("[ZIPParser] ❌ Localized: \(error.localizedDescription)")
            throw AppError.conversationParseFailure("Could not read ZIP file: \(error.localizedDescription)")
        }
        print("[ZIPParser] Copied to local: \(localCopy.path)")

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let archive: Archive
        do {
            archive = try Archive(url: localCopy, accessMode: .read)
        } catch {
            print("[ZIPParser] Archive open failed for local copy: \(error)")
            throw AppError.invalidZIPFile
        }

        let entries = Array(archive)
        print("[ZIPParser] Archive contains \(entries.count) entries:")
        for entry in entries {
            print("[ZIPParser]   \(entry.path) — \(entry.uncompressedSize) bytes")
        }

        let allowedExact = ["projects.json", "memory.json", "user.json"]
        progress("Extracting conversation files...")
        for entry in entries {
            let name = (entry.path as NSString).lastPathComponent
            guard (name.hasPrefix("conversations-") && name.hasSuffix(".json")) || allowedExact.contains(name) else {
                print("[ZIPParser] Skipping: \(entry.path)")
                continue
            }
            let entryURL = tempDir.appendingPathComponent(entry.path)
            let parentDir = entryURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: entryURL)
            print("[ZIPParser] Extracted: \(entry.path) — \(entry.uncompressedSize) bytes")
        }

        if let projectsURL = findFile(named: "projects.json", in: tempDir) {
            do {
                let raw = try String(contentsOf: projectsURL, encoding: .utf8)
                print("[ZIPParser] projects.json contents:")
                print(String(raw.prefix(2000)))
            } catch {
                print("[ZIPParser] Could not read projects.json: \(error)")
            }
        } else {
            print("[ZIPParser] No projects.json found in export")
        }

        let conversationFiles = findConversationChunkFiles(in: tempDir)
        guard !conversationFiles.isEmpty else {
            print("[ZIPParser] No conversation files found in archive")
            throw AppError.missingConversationsJSON
        }
        print("[ZIPParser] Found \(conversationFiles.count) conversation chunk files:")
        conversationFiles.forEach { print("[ZIPParser]   \($0.lastPathComponent)") }

        let baseDir = tempDir
        progress("Parsing conversation chunks...")

        let decoder = JSONDecoder()
        var allConversations: [OpenAIConversation] = []
        for chunkURL in conversationFiles {
            print("[ZIPParser] Parsing chunk: \(chunkURL.lastPathComponent)")
            let data: Data
            do {
                data = try Data(contentsOf: chunkURL, options: .mappedIfSafe)
            } catch {
                print("[ZIPParser] ❌ FAILED reading chunk \(chunkURL.lastPathComponent): \(error)")
                print("[ZIPParser] ❌ Localized: \(error.localizedDescription)")
                throw AppError.conversationParseFailure("Could not read file \(chunkURL.lastPathComponent): \(error.localizedDescription)")
            }
            let chunk: [OpenAIConversation]
            do {
                chunk = try decoder.decode([OpenAIConversation].self, from: data)
            } catch {
                print("[ZIPParser] ❌ FAILED decoding chunk \(chunkURL.lastPathComponent): \(error)")
                print("[ZIPParser] ❌ Localized: \(error.localizedDescription)")
                throw AppError.conversationParseFailure(error.localizedDescription)
            }
            print("[ZIPParser]   → \(chunk.count) conversations")
            allConversations.append(contentsOf: chunk)
        }
        let conversations = allConversations
        print("[ZIPParser] Total conversations merged: \(conversations.count)")

        var memoryEntries: [OpenAIMemoryEntry] = []
        let memoryURL = findFile(named: "memory.json", in: baseDir)
        if let memoryURL {
            let memoryData = (try? Data(contentsOf: memoryURL, options: .mappedIfSafe)) ?? Data()
            let memoryFile = await MainActor.run { try? decoder.decode(OpenAIMemoryFile.self, from: memoryData) }
            memoryEntries = memoryFile?.memories ?? []
        }

        var user: OpenAIUser?
        let userURL = findFile(named: "user.json", in: baseDir)
        if let userURL {
            let userData = try? Data(contentsOf: userURL, options: .mappedIfSafe)
            if let userData {
                user = await MainActor.run { try? decoder.decode(OpenAIUser.self, from: userData) }
            }
        }

        progress("Done")
        let projectsLookup = loadProjectsLookup(from: baseDir)
        let projectGroups = groupConversationsByGizmoId(conversations, projectsLookup: projectsLookup)

        return OpenAIExport(
            user: user,
            conversations: conversations,
            memoryEntries: memoryEntries,
            projectGroups: projectGroups
        )
    }

    private func groupConversationsByGizmoId(_ conversations: [OpenAIConversation], projectsLookup: [String: String] = [:]) -> [ProjectGroup] {
        var groupsByGizmo: [String: [OpenAIConversation]] = [:]
        for conv in conversations {
            let gizmoId = conv.gizmoId ?? "general"
            groupsByGizmo[gizmoId, default: []].append(conv)
        }

        for (gizmoId, convs) in groupsByGizmo {
            let first = convs[0]
            print("[ZIPParser] Project group: \(gizmoId)")
            print("  first.title: \(first.title)")
            print("  first.projectTitle: \(first.projectTitle ?? "nil")")
            print("  first.workspaceId: \(first.workspaceId ?? "nil")")
            print("  first.conversationTemplateId: \(first.conversationTemplateId ?? "nil")")
        }

        let groups = groupsByGizmo.map { gizmoId, convs in
            let name = resolveProjectName(gizmoId: gizmoId, conversations: convs, projectsLookup: projectsLookup)
            return ProjectGroup(id: gizmoId, name: name, conversations: convs)
        }
        return groups.sorted { $0.conversations.count > $1.conversations.count }
    }

    private func resolveProjectName(gizmoId: String, conversations: [OpenAIConversation], projectsLookup: [String: String]) -> String {
        if let name = projectsLookup[gizmoId], !name.isEmpty {
            return name
        }
        if let name = conversations.first?.projectTitle, !name.isEmpty {
            return name
        }
        if let name = conversations.first?.workspaceId, !name.isEmpty {
            return name
        }
        return "Project \(gizmoId.prefix(8))"
    }

    /// Parses an OpenAI export directly from an extracted folder.
    func parseFromFolder(folderURL: URL) async throws -> OpenAIExport {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw AppError.invalidZIPFile
        }

        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer { if accessing { folderURL.stopAccessingSecurityScopedResource() } }

        let resourceValues = try? folderURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if let status = resourceValues?.ubiquitousItemDownloadingStatus, status == .notDownloaded {
            throw AppError.iCloudFileNotDownloaded
        }

        if let projectsURL = findFile(named: "projects.json", in: folderURL) {
            do {
                let raw = try String(contentsOf: projectsURL, encoding: .utf8)
                print("[ZIPParser] projects.json contents (from folder):")
                print(String(raw.prefix(2000)))
            } catch {
                print("[ZIPParser] Could not read projects.json: \(error)")
            }
        } else {
            print("[ZIPParser] No projects.json found in export folder")
        }

        let conversationFiles = findConversationChunkFiles(in: folderURL)
        guard !conversationFiles.isEmpty else {
            throw AppError.missingConversationsJSON
        }
        let baseDir = folderURL

        let decoder = JSONDecoder()
        var allConversations: [OpenAIConversation] = []
        for chunkURL in conversationFiles {
            let data: Data
            do {
                data = try Data(contentsOf: chunkURL, options: .mappedIfSafe)
            } catch {
                print("[ZIPParser] ❌ FAILED reading chunk \(chunkURL.lastPathComponent): \(error)")
                print("[ZIPParser] ❌ Localized: \(error.localizedDescription)")
                throw AppError.conversationParseFailure("Could not read file \(chunkURL.lastPathComponent): \(error.localizedDescription)")
            }
            let chunk: [OpenAIConversation]
            do {
                chunk = try decoder.decode([OpenAIConversation].self, from: data)
            } catch {
                print("[ZIPParser] ❌ FAILED decoding chunk \(chunkURL.lastPathComponent): \(error)")
                print("[ZIPParser] ❌ Localized: \(error.localizedDescription)")
                throw AppError.conversationParseFailure(error.localizedDescription)
            }
            allConversations.append(contentsOf: chunk)
        }
        let conversations = allConversations

        var memoryEntries: [OpenAIMemoryEntry] = []
        let memoryURL = findFile(named: "memory.json", in: baseDir)
        if let memoryURL {
            let memoryData = (try? Data(contentsOf: memoryURL, options: .mappedIfSafe)) ?? Data()
            let memoryFile = await MainActor.run { try? decoder.decode(OpenAIMemoryFile.self, from: memoryData) }
            memoryEntries = memoryFile?.memories ?? []
        }

        var user: OpenAIUser?
        let userURL = findFile(named: "user.json", in: baseDir)
        if let userURL {
            let userData = try? Data(contentsOf: userURL, options: .mappedIfSafe)
            if let userData {
                user = await MainActor.run { try? decoder.decode(OpenAIUser.self, from: userData) }
            }
        }

        let projectsLookup = loadProjectsLookup(from: baseDir)
        let projectGroups = groupConversationsByGizmoId(conversations, projectsLookup: projectsLookup)

        return OpenAIExport(
            user: user,
            conversations: conversations,
            memoryEntries: memoryEntries,
            projectGroups: projectGroups
        )
    }

    /// Loads gizmoId → project name from projects.json if it exists.
    private func loadProjectsLookup(from directory: URL) -> [String: String] {
        guard let url = findFile(named: "projects.json", in: directory) else { return [:] }
        guard let data = try? Data(contentsOf: url) else { return [:] }
        // Try common OpenAI export schemas: { "items": [{ "id": "...", "name": "..." }] } or { "data": [...] }
        struct ProjectsResponse: Codable {
            let items: [ProjectItem]?
            let data: [ProjectItem]?
            struct ProjectItem: Codable {
                let id: String?
                let name: String?
            }
        }
        guard let response = try? JSONDecoder().decode(ProjectsResponse.self, from: data) else { return [:] }
        let items = response.items ?? response.data ?? []
        var lookup: [String: String] = [:]
        for item in items {
            guard let id = item.id, let name = item.name, !name.isEmpty else { continue }
            lookup[id] = name
        }
        return lookup
    }

    /// Finds a file by name in directory or any subdirectory (one level).
    private func findFile(named name: String, in directory: URL) -> URL? {
        let atRoot = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: atRoot.path) {
            return atRoot
        }
        if let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for item in contents where (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                let inSub = item.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: inSub.path) {
                    return inSub
                }
            }
        }
        return nil
    }

    /// Finds all conversation chunk files (conversations-*.json) in directory and subdirectories, sorted by filename.
    private func findConversationChunkFiles(in directory: URL) -> [URL] {
        var urls: [URL] = []
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        while let url = enumerator.nextObject() as? URL {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let name = url.lastPathComponent
            if name.hasPrefix("conversations-") && name.hasSuffix(".json") {
                urls.append(url)
            }
        }
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
