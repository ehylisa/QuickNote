//
//  ContentView.swift
//  QuickNotes
//
//  Created by Lisa Yi on 2026-04-05.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NotesStore
    @StateObject private var editorState = EditorState()
    @StateObject private var walker      = CharacterWalker()
    @State private var attributedText    = NSAttributedString(
        string: "", attributes: RichTextEditor.defaultAttrs)
    @State private var isLoadingNote = false

    // MARK: Counts

    private var wordCount: Int {
        attributedText.string
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private var charCount: Int { attributedText.string.count }

    // MARK: Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                noteTabsBar
                Divider()
                formattingToolbar
                Divider()
                editor
                Divider()
                footer
            }

            // Chat bubble
            GrabMeBubble()
                .position(x: walker.pos.x, y: walker.pos.y - 62)
                .allowsHitTesting(false)
                .opacity(walker.isDragging ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: walker.isDragging)

            // Walking character — draggable
            WalkingCharacter(stepIdx: walker.stepIdx, faceLeft: walker.faceLeft)
                .scaleEffect(walker.isDragging ? 1.25 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: walker.isDragging)
                .background(ChefCursorView(isGrabbing: walker.isDragging))
                .position(x: walker.pos.x, y: walker.pos.y - 22)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !walker.isDragging { walker.startDrag() }
                            walker.updateDrag(delta: CGSize(
                                width:  value.location.x - value.startLocation.x,
                                height: value.location.y - value.startLocation.y
                            ))
                        }
                        .onEnded { _ in walker.endDrag() }
                )
        }
        .frame(width: 300, height: 430)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear  { loadSelectedNote(); walker.start() }
        .onDisappear { walker.stop() }
        .onChange(of: attributedText)   { _, new in saveCurrentNote(new) }
        .onChange(of: store.selectedId) { _, _   in loadSelectedNote() }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "note.text")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("QuickNotes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var noteTabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(store.notes) { note in
                    NoteTabCard(
                        note:      note,
                        isActive:  note.id == store.selectedId,
                        canDelete: store.notes.count > 1,
                        onTap:     { store.selectedId = note.id },
                        onDelete:  { confirmDelete(note.id) }
                    )
                }
                addButton
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(height: 52)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var addButton: some View {
        Button { store.addNote() } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 26, height: 36)
                .background(Color(NSColor.quaternaryLabelColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("New note  ⌘N")
    }

    private var formattingToolbar: some View {
        HStack(spacing: 2) {
            FormatButton(symbol: "bold",   label: "Bold  ⌘B",    isActive: editorState.isBold)    { editorState.toggleBold() }
            FormatButton(symbol: "italic", label: "Italic  ⌘I",  isActive: editorState.isItalic)  { editorState.toggleItalic() }
            FormatButton(symbol: "textformat.size.larger", label: "Heading", isActive: editorState.isHeading) { editorState.toggleHeading() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if attributedText.length == 0 {
                Text("Start typing…")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(NSColor.placeholderTextColor))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
            RichTextEditor(attributedText: $attributedText, editorState: editorState)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }

    private var footer: some View {
        HStack {
            Text(wordCount == 1 ? "1 word" : "\(wordCount) words")
            Spacer()
            Text("\(charCount) characters")
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Helpers

    private func saveCurrentNote(_ text: NSAttributedString) {
        guard !isLoadingNote, let id = store.selectedId else { return }
        store.update(id: id, attributedString: text)
    }

    private func loadSelectedNote() {
        guard let id = store.selectedId else { return }
        isLoadingNote = true
        attributedText = store.attributedString(for: id)
        isLoadingNote = false
    }

    private func confirmDelete(_ id: UUID) {
        let alert = NSAlert()
        alert.messageText     = "Delete Note?"
        alert.informativeText = "This note will be permanently deleted."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { store.delete(id: id) }
    }
}

// MARK: - Note tab card

private struct NoteTabCard: View {
    let note:      Note
    let isActive:  Bool
    let canDelete: Bool
    let onTap:     () -> Void
    let onDelete:  () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.system(size: 11.5, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(isActive ? Color.accentColor : Color.primary)

                    Text(note.previewLine.isEmpty ? "Empty note" : note.previewLine)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(width: 86, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isActive
                              ? Color.accentColor.opacity(0.1)
                              : Color(NSColor.quaternaryLabelColor).opacity(isHovered ? 0.4 : 0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(isActive ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
                )

                // Delete ×
                if isHovered && canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(3)
                            .background(Circle().fill(Color(NSColor.windowBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Note", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Format button

private struct FormatButton: View {
    let symbol:   String
    let label:    String
    let isActive: Bool
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 24)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - Grab me bubble

private struct GrabMeBubble: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Grab me!")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Color(NSColor.windowBackgroundColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.primary.opacity(0.82))
                )
            BubbleTail()
                .fill(Color.primary.opacity(0.82))
                .frame(width: 8, height: 5)
        }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))   // tip pointing down
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cursor view
//
// Uses AppKit's addCursorRect system, which is more reliable than
// NSCursor push/pop when a DragGesture is also attached to the view.

private struct ChefCursorView: NSViewRepresentable {
    let isGrabbing: Bool

    func makeNSView(context: Context) -> CursorNSView { CursorNSView() }

    func updateNSView(_ nsView: CursorNSView, context: Context) {
        nsView.activeCursor = isGrabbing ? .closedHand : .openHand
        nsView.window?.invalidateCursorRects(for: nsView)
    }

    class CursorNSView: NSView {
        var activeCursor: NSCursor = .openHand
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: activeCursor)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NotesStore())
}
