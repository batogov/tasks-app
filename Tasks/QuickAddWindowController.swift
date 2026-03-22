//
//  QuickAddWindowController.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import Cocoa

@MainActor
class QuickAddWindowController: NSWindowController, NSWindowDelegate {
    private var textField: NSTextField!
    private var addButton: NSButton!
    private var flagButton: NSButton!
    private var isImportant = false
    private weak var statusBarController: StatusBarController?

    init(statusBarController: StatusBarController) {
        self.statusBarController = statusBarController

        let panelWidth: CGFloat = 520
        let panelHeight: CGFloat = 48

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.identifier = NSUserInterfaceItemIdentifier("quick-add")
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = true

        super.init(window: panel)

        panel.delegate = self
        setupContent(in: panel, width: panelWidth, height: panelHeight)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupContent(in panel: NSPanel, width: CGFloat, height: CGFloat) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true

        let padding: CGFloat = 16

        textField = makeTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)

        flagButton = makeFlagButton()
        flagButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(flagButton)

        addButton = makeAddButton()
        addButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addButton)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            textField.trailingAnchor.constraint(equalTo: flagButton.leadingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            flagButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -4),
            flagButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            flagButton.widthAnchor.constraint(equalToConstant: 20),
            flagButton.heightAnchor.constraint(equalToConstant: 20),

            addButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            addButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 24),
            addButton.heightAnchor.constraint(equalToConstant: 24),
        ])

        panel.contentView = container
        panel.hasShadow = true
    }

    private func makeTextField() -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = .systemFont(ofSize: 16)
        tf.textColor = .labelColor
        tf.placeholderString = "New task..."
        tf.usesSingleLineMode = true
        tf.lineBreakMode = .byClipping
        tf.cell?.isScrollable = true
        tf.cell?.wraps = false
        tf.delegate = self

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont.systemFont(ofSize: 16)
        ]
        tf.placeholderAttributedString = NSAttributedString(string: "New task...", attributes: attrs)

        return tf
    }

    private func makeFlagButton() -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "flag", accessibilityDescription: "Important")
        button.contentTintColor = .secondaryLabelColor
        button.imageScaling = .scaleProportionallyUpOrDown
        button.target = self
        button.action = #selector(flagButtonClicked)
        return button
    }

    private func makeAddButton() -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add")
        button.contentTintColor = .controlAccentColor
        button.imageScaling = .scaleProportionallyUpOrDown
        button.target = self
        button.action = #selector(addButtonClicked)
        return button
    }

    @objc private func addButtonClicked() {
        submit()
    }

    @objc private func flagButtonClicked() {
        toggleImportant()
    }

    private func updateFlagButton() {
        if isImportant {
            flagButton.image = NSImage(systemSymbolName: "flag.fill", accessibilityDescription: "Important")
            flagButton.contentTintColor = .systemRed
        } else {
            flagButton.image = NSImage(systemSymbolName: "flag", accessibilityDescription: "Important")
            flagButton.contentTintColor = .secondaryLabelColor
        }
    }

    private func toggleImportant() {
        isImportant.toggle()
        updateFlagButton()
    }

    func show() {
        guard let screen = NSScreen.main, let panel = window else { return }

        let x = (screen.frame.width - panel.frame.width) / 2 + screen.frame.origin.x
        let y = screen.frame.origin.y + screen.frame.height * 0.58
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textField)
    }

    func dismiss() {
        window?.orderOut(nil)
        // Text is preserved until successful submit
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    private func submit() {
        let text = textField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        TaskStore.shared.addTask(title: text, priority: isImportant ? .important : .normal)
        statusBarController?.refresh()
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
        textField.stringValue = ""
        isImportant = false
        updateFlagButton()
        dismiss()
    }
}

extension QuickAddWindowController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            submit()
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            dismiss()
            return true
        }
        return false
    }
}
