//
//  AppDelegate.swift
//  Tasks
//
//  Created by Dmitriy Batogov on 09.03.2026.
//

import Cocoa
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var quickAddController: QuickAddWindowController!
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        quickAddController = QuickAddWindowController(statusBarController: statusBarController)
        registerHotKey()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        var hotKeyID = EventHotKeyID()
        hotKeyID.id = 1
        hotKeyID.signature = 0x5453_4B59 // "TSKY"

        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            quickAddHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }
}

private func quickAddHotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        delegate.quickAddController.show()
    }
    return noErr
}
