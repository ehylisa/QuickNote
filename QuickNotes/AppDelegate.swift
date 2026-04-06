//
//  AppDelegate.swift
//  QuickNotes
//
//  Created by Lisa Yi on 2026-04-05.
//

import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem:        NSStatusItem!
    private var popover:           NSPopover!
    private var eventMonitor:      Any?
    private var localEventMonitor: Any?

    // Single shared store — owned here so AppDelegate can flush it on close/quit
    let store = NotesStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ── Status bar item ──
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text",
                                   accessibilityDescription: "QuickNotes")
            button.image?.isTemplate = true
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // ── Popover — inject store as environment object ──
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 430)
        popover.behavior    = .applicationDefined
        popover.animates    = true
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(store)
        )
    }

    // ── Save on quit ──
    func applicationWillTerminate(_ notification: Notification) {
        store.saveImmediately()
    }

    // MARK: Popover

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            popover.isShown ? closePopover() : openPopover()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit QuickNotes",
                                action: #selector(quitApp),
                                keyEquivalent: "q"))
        // Temporarily assign menu so the system can show it, then clear it
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func quitApp() {
        store.saveImmediately()
        NSApp.terminate(nil)
    }

    private func deleteCurrentNote() {
        guard store.notes.count > 1, let id = store.selectedId else { return }

        let alert = NSAlert()
        alert.messageText     = "Delete Note?"
        alert.informativeText = "This note will be permanently deleted."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        if alert.runModal() == .alertFirstButtonReturn {
            store.delete(id: id)
        }
    }

    func openPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Close on outside click
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.closePopover() }

        // Keyboard shortcuts while popover is open
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let cmd = event.modifierFlags.contains(.command)

            if event.keyCode == 53 { closePopover(); return nil }                 // Esc     → close
            if cmd && event.keyCode == 13 { closePopover(); return nil }          // Cmd+W   → close
            if cmd && event.keyCode == 45 { store.addNote(); return nil }         // Cmd+N   → new note
            if cmd && event.keyCode == 51 { deleteCurrentNote(); return nil }     // Cmd+⌫   → delete note
            if cmd && event.keyCode == 12 { quitApp(); return nil }               // Cmd+Q   → quit

            return event
        }
    }

    func closePopover() {
        // ── Save on close ──
        store.saveImmediately()

        popover.performClose(nil)

        if let m = eventMonitor      { NSEvent.removeMonitor(m); eventMonitor      = nil }
        if let m = localEventMonitor { NSEvent.removeMonitor(m); localEventMonitor = nil }
    }
}
