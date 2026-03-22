//
//  TodoItem.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import Foundation
import SwiftData

enum TaskPriority: Int, Codable {
    case normal = 0
    case important = 1
    case later = 2
}

@Model
final class TodoItem {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var sortOrder: Int
    var priorityRaw: Int = TaskPriority.normal.rawValue

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    init(title: String, isCompleted: Bool = false, createdAt: Date = .now, sortOrder: Int = 0, priority: TaskPriority = .normal) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.priorityRaw = priority.rawValue
    }
}
