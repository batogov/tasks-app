//
//  SettingsView.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("exportOnClear") private var exportOnClear = false
    @AppStorage("exportDirectoryPath") private var exportDirectoryPath = ""

    var body: some View {
        Form {
            Section(header: Text("Export settings")) {
                Toggle("Export on clear", isOn: $exportOnClear)

                HStack {
                    Text("Directory")
                    Spacer()
                    TextField("", text: $exportDirectoryPath)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 260)
                    Button("Browse") {
                        chooseDirectory()
                    }
                }
                .disabled(!exportOnClear)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(width: 460)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            exportDirectoryPath = url.path
            // Save security-scoped bookmark for sandbox access across launches
            if let bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmarkData, forKey: "exportDirectoryBookmark")
            }
        }
    }
}

#Preview {
    SettingsView()
}
