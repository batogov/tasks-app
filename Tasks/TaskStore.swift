//
//  TaskStore.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import Foundation
import SwiftData

// Shared store that provides a single ModelContainer for the app.
// Used by AppKit components (StatusBar, QuickAdd) that don't have SwiftUI environment.
@MainActor
final class TaskStore {
    static let shared = TaskStore()

    let container: ModelContainer

    private init() {
        let schema = Schema([TodoItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var context: ModelContext {
        container.mainContext
    }

    func addTask(title: String) {
        // Shift existing items down, new task goes to the top
        let existing = incompleteTasks()
        for task in existing {
            task.sortOrder += 1
        }
        let item = TodoItem(title: title, sortOrder: 0)
        context.insert(item)
        try? context.save()
    }

    func toggleTask(_ item: TodoItem) {
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? .now : nil
        try? context.save()
    }

    func deleteTask(_ item: TodoItem) {
        context.delete(item)
        try? context.save()
    }

    func incompleteTasks() -> [TodoItem] {
        let predicate = #Predicate<TodoItem> { !$0.isCompleted }
        let sort = SortDescriptor(\TodoItem.sortOrder)
        let descriptor = FetchDescriptor<TodoItem>(predicate: predicate, sortBy: [sort])
        return (try? context.fetch(descriptor)) ?? []
    }

    func allTasks() -> [TodoItem] {
        let sort = SortDescriptor(\TodoItem.createdAt, order: .reverse)
        let descriptor = FetchDescriptor<TodoItem>(sortBy: [sort])
        return (try? context.fetch(descriptor)) ?? []
    }
}
