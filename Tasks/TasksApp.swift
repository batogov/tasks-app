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

        Settings {
            SettingsView()
        }
    }
}
