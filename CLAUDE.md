# QuickNotes

A macOS menu bar app for quick note-taking.

## What This Is
- Lives entirely in the menu bar — no dock icon, no main window
- Click the menu bar icon to open a popover with a text editor
- Built with SwiftUI for macOS

## Tech
- Swift + SwiftUI
- `MenuBarExtra` for the menu bar presence (requires macOS 13+)
- `NSApp.setActivationPolicy(.accessory)` to hide the dock icon
- `.menuBarExtraStyle(.window)` for the popover style

## Project Structure
- `QuickNotesApp.swift` — app entry point, menu bar setup
- `ContentView.swift` — popover UI

## Design Goals
- Minimal and fast — should feel instant to open and use
- Stays out of the way when not in use
- No unnecessary chrome or settings
