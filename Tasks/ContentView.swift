//
//  ContentView.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TodoItem> { !$0.isCompleted },
           sort: \TodoItem.sortOrder)
    private var activeItems: [TodoItem]

    private var mainItems: [TodoItem] {
        activeItems.filter { $0.priority != .later }
    }

    private var laterItems: [TodoItem] {
        activeItems.filter { $0.priority == .later }
    }

    @Query(filter: #Predicate<TodoItem> { $0.isCompleted },
           sort: \TodoItem.completedAt, order: .reverse)
    private var completedItems: [TodoItem]

    @State private var newTaskTitle = ""
    @State private var showCompleted = false
    @State private var selectedItemID: PersistentIdentifier?
    @State private var pendingCompletionIDs: Set<PersistentIdentifier> = []
    @State private var completionDebounceTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Input field
            HStack(spacing: 8) {
                TextField("New task...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isInputFocused)
                    .onSubmit { addTask() }

                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Task list
            if activeItems.isEmpty && completedItems.isEmpty && !showCompleted {
                Spacer()
                Text("No tasks yet")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                Spacer()
            } else {
                List(selection: $selectedItemID) {
                    // Main tasks (important + normal, sorted by sortOrder)
                    ForEach(mainItems) { item in
                        TaskRow(
                            item: item,
                            isPendingCompletion: pendingCompletionIDs.contains(item.id),
                            onToggle: { toggleItem(item) }
                        )
                        .tag(item.id)
                    }
                    .onDelete { offsets in deleteItems(offsets, from: mainItems) }
                    .onMove(perform: moveMainItems)

                    // Later tasks
                    if !laterItems.isEmpty {
                        Section("Later") {
                            ForEach(laterItems) { item in
                                TaskRow(
                                    item: item,
                                    isPendingCompletion: pendingCompletionIDs.contains(item.id),
                                    onToggle: { toggleItem(item) }
                                )
                                .tag(item.id)
                            }
                            .onDelete { offsets in deleteItems(offsets, from: laterItems) }
                        }
                    }

                    // Completed items
                    if showCompleted && !completedItems.isEmpty {
                        Section("Completed") {
                            ForEach(completedItems) { item in
                                TaskRow(item: item)
                                    .tag(item.id)
                            }
                            .onDelete(perform: deleteCompletedItems)
                        }
                    }
                }
                .listStyle(.plain)
                .onDeleteCommand { deleteSelected() }
                .onKeyPress(.return) {
                    completeSelected()
                    return .handled
                }
            }

            // Completed bar (sticky bottom)
            if !completedItems.isEmpty {
                Divider()
                HStack {
                    HStack(spacing: 4) {
                        Text("\(completedItems.count) Completed")
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Button("Clear") {
                            clearCompleted()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    .font(.subheadline)
                    Spacer()
                    Button(showCompleted ? "Hide" : "Show") {
                        withAnimation { showCompleted.toggle() }
                    }
                    .font(.subheadline)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 360, minHeight: 400)
        .onAppear { isInputFocused = true }
        .focusedSceneValue(\.toggleImportantAction) { togglePriority(.important) }
        .focusedSceneValue(\.toggleLaterAction) { togglePriority(.later) }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        for item in activeItems {
            item.sortOrder += 1
        }
        let item = TodoItem(title: title, sortOrder: 0)
        modelContext.insert(item)
        newTaskTitle = ""
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func toggleItem(_ item: TodoItem) {
        if pendingCompletionIDs.contains(item.id) {
            // Remove from pending set
            pendingCompletionIDs.remove(item.id)
        } else {
            // Mark as pending completion
            pendingCompletionIDs.insert(item.id)
        }

        // Reset the debounce timer
        completionDebounceTask?.cancel()
        if !pendingCompletionIDs.isEmpty {
            completionDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                flushPendingCompletions()
            }
        }
    }

    private func flushPendingCompletions() {
        let ids = pendingCompletionIDs
        pendingCompletionIDs.removeAll()
        completionDebounceTask = nil

        withAnimation {
            for item in activeItems where ids.contains(item.id) {
                item.isCompleted = true
                item.completedAt = .now
            }
        }
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func moveMainItems(from source: IndexSet, to destination: Int) {
        var reordered = Array(mainItems)
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            item.sortOrder = index
        }
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func deleteItems(_ offsets: IndexSet, from items: [TodoItem]) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func deleteActiveItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(activeItems[index])
        }
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func togglePriority(_ priority: TaskPriority) {
        guard let id = selectedItemID,
              let item = activeItems.first(where: { $0.id == id }) else { return }
        let newPriority: TaskPriority = item.priority == priority ? .normal : priority
        item.priority = newPriority

        // Move important items to the top of the main list
        if newPriority == .important {
            let minOrder = (mainItems.map(\.sortOrder).min() ?? 0) - 1
            item.sortOrder = minOrder
        }

        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func deleteCompletedItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(completedItems[index])
        }
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func clearCompleted() {
        if ExportManager.isEnabled {
            ExportManager.exportCompletedItems(completedItems)
        }
        for item in completedItems {
            modelContext.delete(item)
        }
        showCompleted = false
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    private func nextID(after id: PersistentIdentifier, in items: [TodoItem]) -> PersistentIdentifier? {
        guard let index = items.firstIndex(where: { $0.id == id }),
              index + 1 < items.count else { return nil }
        return items[index + 1].id
    }

    private func completeSelected() {
        guard let id = selectedItemID else { return }
        guard let item = activeItems.first(where: { $0.id == id }) else { return }
        selectedItemID = nextID(after: id, in: activeItems)
        toggleItem(item)
    }

    private func deleteSelected() {
        guard let id = selectedItemID else { return }
        let allItems: [TodoItem] = activeItems + completedItems
        guard let item = allItems.first(where: { $0.id == id }) else { return }
        selectedItemID = nextID(after: id, in: allItems)
        modelContext.delete(item)
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }
}

struct TaskRow: View {
    @Bindable var item: TodoItem
    var isPendingCompletion: Bool = false
    var onToggle: (() -> Void)?

    private var visuallyCompleted: Bool {
        item.isCompleted || isPendingCompletion
    }

    private var checkCircleIcon: String {
        if visuallyCompleted {
            return "checkmark.circle.fill"
        } else if item.priority == .later {
            return "circle.dashed"
        } else {
            return "circle"
        }
    }

    private static let completedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if let onToggle {
                    onToggle()
                } else {
                    item.isCompleted.toggle()
                    item.completedAt = item.isCompleted ? .now : nil
                    NotificationCenter.default.post(name: .tasksDidChange, object: nil)
                }
            } label: {
                Image(systemName: checkCircleIcon)
                    .font(.title3)
                    .foregroundStyle(visuallyCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                LinkedText(text: item.title, isCompleted: visuallyCompleted)

                if item.isCompleted, let completedAt = item.completedAt {
                    Text("Completed \(Self.completedDateFormatter.string(from: completedAt))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if !item.isCompleted && item.priority == .important {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

// Parses URLs in text and renders them as clickable links.
// Non-URL parts render as plain text. Data in the store is not modified.
struct LinkedText: View {
    let text: String
    let isCompleted: Bool

    private static let detector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    var body: some View {
        buildText()
            .strikethrough(isCompleted)
    }

    private func buildText() -> Text {
        guard let detector = Self.detector else {
            return plainText(text)
        }

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = detector.matches(in: text, range: fullRange)

        if matches.isEmpty {
            return plainText(text)
        }

        var result = Text("")
        var currentIndex = text.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: text),
                  let url = match.url else { continue }

            // Text before the link
            if currentIndex < matchRange.lowerBound {
                let before = String(text[currentIndex..<matchRange.lowerBound])
                result = result + plainText(before)
            }

            // The link itself
            let linkString = String(text[matchRange])
            result = result + Text(.init("[\(linkString)](\(url.absoluteString))"))
                .foregroundColor(isCompleted ? .secondary : .blue)
                .underline()

            currentIndex = matchRange.upperBound
        }

        // Text after the last link
        if currentIndex < text.endIndex {
            let after = String(text[currentIndex...])
            result = result + plainText(after)
        }

        return result
    }

    private func plainText(_ string: String) -> Text {
        Text(string)
            .foregroundColor(isCompleted ? .secondary : .primary)
    }
}

extension Notification.Name {
    static let tasksDidChange = Notification.Name("tasksDidChange")
}

struct ToggleImportantActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ToggleLaterActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var toggleImportantAction: (() -> Void)? {
        get { self[ToggleImportantActionKey.self] }
        set { self[ToggleImportantActionKey.self] = newValue }
    }

    var toggleLaterAction: (() -> Void)? {
        get { self[ToggleLaterActionKey.self] }
        set { self[ToggleLaterActionKey.self] = newValue }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
