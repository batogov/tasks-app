//
//  StatusBarController.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import Cocoa
import SwiftUI
import SwiftData

@MainActor
class StatusBarController {
    private var statusItem: NSStatusItem!
    private var observer: Any?

    private let checkmarkIcon: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        guard let icon = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Tasks") else { return nil }
        let configured = icon.withSymbolConfiguration(config)
        configured?.isTemplate = true
        return configured
    }()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = checkmarkIcon
        statusItem.button?.imagePosition = .imageLeft

        observer = NotificationCenter.default.addObserver(
            forName: .tasksDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        refresh()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func refresh() {
        let tasks = TaskStore.shared.incompleteTasks()
        updateUI(tasks: tasks)
    }

    // MARK: - UI

    private func updateUI(tasks: [TodoItem]) {
        statusItem.button?.title = tasks.isEmpty ? "" : " \(tasks.count)"
        statusItem.button?.image = checkmarkIcon

        let menu = NSMenu()

        if tasks.isEmpty {
            let emptyItem = NSMenuItem(title: "No pending tasks", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let headerItem = NSMenuItem(title: "Pending tasks", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            for task in tasks {
                let item = NSMenuItem(title: task.title, action: #selector(toggleTask(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = task.id
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let showWindowItem = NSMenuItem(title: "Open tasks", action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        menu.addItem(showWindowItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApp.delegate
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleTask(_ sender: NSMenuItem) {
        guard let taskID = sender.representedObject as? PersistentIdentifier else { return }
        let context = TaskStore.shared.context
        let descriptor = FetchDescriptor<TodoItem>()
        guard let allTasks = try? context.fetch(descriptor),
              let task = allTasks.first(where: { $0.id == taskID }) else { return }
        TaskStore.shared.toggleTask(task)
        refresh()
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue != "quick-add" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        EnvironmentValues().openSettings()
    }
}
