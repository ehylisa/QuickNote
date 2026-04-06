//
//  NotesStore.swift
//  QuickNotes
//
//  Created by Lisa Yi on 2026-04-05.
//

import AppKit
import Combine
import Foundation

// MARK: - Model

struct Note: Identifiable, Codable {
    var id:          UUID   = UUID()
    var rtfData:     Data   = Data()
    var firstLine:   String = ""
    var previewLine: String = ""    // second non-empty line, cached to avoid re-decoding RTF

    var title: String {
        let t = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "New Note" : t
    }
}

// MARK: - Persisted envelope

private struct StoredData: Codable {
    var notes:      [Note]
    var selectedId: UUID?
}

// MARK: - Store

@MainActor
class NotesStore: ObservableObject {
    @Published private(set) var notes:      [Note] = []
    @Published              var selectedId: UUID?

    private var pendingSave: DispatchWorkItem?

    // MARK: Init

    init() {
        load()
        if notes.isEmpty { addNote() }
        else { selectedId = notes.first?.id }
    }

    // MARK: Accessors

    var selectedNote: Note? { notes.first { $0.id == selectedId } }

    func attributedString(for id: UUID) -> NSAttributedString {
        guard let note = notes.first(where: { $0.id == id }), !note.rtfData.isEmpty else {
            return NSAttributedString(string: "", attributes: RichTextEditor.defaultAttrs)
        }
        return (try? NSAttributedString(
            data: note.rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )) ?? NSAttributedString(string: "", attributes: RichTextEditor.defaultAttrs)
    }

    // MARK: Mutations

    func addNote() {
        let note = Note()
        notes.append(note)
        selectedId = note.id
        scheduleAutoSave()
    }

    func update(id: UUID, attributedString: NSAttributedString) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let range = NSRange(location: 0, length: attributedString.length)
        notes[idx].rtfData   = (try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )) ?? Data()
        let lines = attributedString.string
            .components(separatedBy: "\n")
            .map  { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        notes[idx].firstLine   = lines.first ?? ""
        notes[idx].previewLine = lines.dropFirst().first ?? ""
        scheduleAutoSave()
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        if notes.isEmpty { addNote(); return }
        if selectedId == id { selectedId = notes.first?.id }
        saveImmediately()
    }

    // MARK: Save / Load

    /// Debounced — waits 0.5 s after the last change before writing to disk.
    func scheduleAutoSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    /// Flush immediately — call on popover close or app quit.
    func saveImmediately() {
        pendingSave?.cancel()
        pendingSave = nil
        save()
    }

    private func save() {
        guard let url = Self.fileURL() else { return }
        do {
            let envelope = StoredData(notes: notes, selectedId: selectedId)
            let data     = try JSONEncoder().encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            print("QuickNotes: save failed — \(error)")
        }
    }

    private func load() {
        guard let url      = Self.fileURL(),
              let data     = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(StoredData.self, from: data)
        else { return }
        notes      = envelope.notes
        // Restore last selected note, fall back to first if it no longer exists
        selectedId = envelope.selectedId.flatMap { id in
            notes.contains(where: { $0.id == id }) ? id : nil
        } ?? notes.first?.id
    }

    // MARK: File URL — ~/Library/Application Support/QuickNotes/notes.json

    private static func fileURL() -> URL? {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("QuickNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }
}
