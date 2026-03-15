//
//  ExportManager.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import Foundation

enum ExportManager {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // Resolves the export directory URL from the saved security-scoped bookmark.
    // Falls back to the plain path if no bookmark is available.
    private static func resolveExportDirectory() -> URL? {
        if let bookmarkData = UserDefaults.standard.data(forKey: "exportDirectoryBookmark") {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    // Refresh the bookmark
                    if let newData = try? url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        UserDefaults.standard.set(newData, forKey: "exportDirectoryBookmark")
                    }
                }
                return url
            }
        }

        // Fallback to plain path (works only within same session as NSOpenPanel)
        let path = UserDefaults.standard.string(forKey: "exportDirectoryPath") ?? ""
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    // Exports completed items to markdown files grouped by completion date.
    // Each file is named YYYY-MM-DD.md and items are appended if the file already exists.
    static func exportCompletedItems(_ items: [TodoItem]) {
        guard let directoryURL = resolveExportDirectory() else { return }

        let didStartAccessing = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        // Group items by completion date (day)
        var grouped: [String: [TodoItem]] = [:]
        for item in items {
            guard let completedAt = item.completedAt else { continue }
            let key = dateFormatter.string(from: completedAt)
            grouped[key, default: []].append(item)
        }

        let fileManager = FileManager.default

        // Make sure the directory exists
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        for (dateString, tasks) in grouped {
            let fileURL = directoryURL.appendingPathComponent("\(dateString).md")

            var newLines = tasks.map { "- [x] \($0.title)" }
            newLines.append("") // Trailing newline

            let newContent = newLines.joined(separator: "\n")

            if fileManager.fileExists(atPath: fileURL.path) {
                // Append to existing file
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    if let data = newContent.data(using: .utf8) {
                        handle.write(data)
                    }
                    handle.closeFile()
                }
            } else {
                try? newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    // Returns true if export on clear is enabled and a directory is configured.
    static var isEnabled: Bool {
        let enabled = UserDefaults.standard.bool(forKey: "exportOnClear")
        let path = UserDefaults.standard.string(forKey: "exportDirectoryPath") ?? ""
        return enabled && !path.isEmpty
    }
}
