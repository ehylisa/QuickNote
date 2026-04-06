//
//  main.swift
//  QuickNotes
//
//  Created by Lisa Yi on 2026-04-05.
//

import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
