//
//  TodoItem.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import Foundation
import SwiftData

@Model
final class TodoItem {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var sortOrder: Int

    init(title: String, isCompleted: Bool = false, createdAt: Date = .now, sortOrder: Int = 0) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
