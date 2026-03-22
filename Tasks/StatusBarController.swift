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
        // Later items are excluded from the counter
        let countedTasks = tasks.filter { $0.priority != .later }
        statusItem.button?.title = countedTasks.isEmpty ? "" : " \(countedTasks.count)"
        statusItem.button?.image = checkmarkIcon

        let menu = NSMenu()

        let importantTasks = tasks.filter { $0.priority == .important }
        let otherTasks = tasks.filter { $0.priority != .important }

        if tasks.isEmpty {
            let emptyItem = NSMenuItem(title: "No pending tasks", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for task in importantTasks {
                let item = NSMenuItem(title: "", action: #selector(toggleTask(_:)), keyEquivalent: "")
                item.attributedTitle = attributedTitle(task.title, showFlag: true)
                item.target = self
                item.representedObject = task.id
                menu.addItem(item)
            }

            for task in otherTasks {
                let item = NSMenuItem(title: truncated(task.title), action: #selector(toggleTask(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = task.id
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let showWindowItem = NSMenuItem(title: "Open…", action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        showWindowItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Open")
        menu.addItem(showWindowItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(AppDelegate.quitApp), keyEquivalent: "")
        quitItem.target = NSApp.delegate
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private static let maxTitleLength = 55

    private func truncated(_ title: String) -> String {
        title.count > Self.maxTitleLength
            ? String(title.prefix(Self.maxTitleLength)) + "…"
            : title
    }

    private func attributedTitle(_ title: String, showFlag: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: truncated(title), attributes: [
            .font: NSFont.menuFont(ofSize: 0)
        ])
        if showFlag {
            let flagAttachment = NSTextAttachment()
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            if let flagImage = NSImage(systemSymbolName: "flag.fill", accessibilityDescription: "Important") {
                let configured = flagImage.withSymbolConfiguration(config)
                configured?.isTemplate = false
                let tinted = configured ?? flagImage
                tinted.lockFocus()
                NSColor.systemRed.set()
                NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
                tinted.unlockFocus()
                flagAttachment.image = tinted
            }
            result.append(NSAttributedString(string: "  "))
            result.append(NSAttributedString(attachment: flagAttachment))
        }
        return result
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
