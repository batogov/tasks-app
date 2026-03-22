//
//  TasksApp.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import SwiftUI
import SwiftData

@main
struct TasksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(TaskStore.shared.container)
        .commands {
            TaskPriorityCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

struct TaskPriorityCommands: Commands {
    @FocusedValue(\.toggleImportantAction) var toggleImportant
    @FocusedValue(\.toggleLaterAction) var toggleLater

    var body: some Commands {
        CommandMenu("Tasks") {
            Button("Mark as Important") {
                toggleImportant?()
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(toggleImportant == nil)

            Button("Mark as Later") {
                toggleLater?()
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(toggleLater == nil)
        }
    }
}
