//
//  RichTextEditor.swift
//  QuickNotes
//
//  Created by Lisa Yi on 2026-04-05.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Editor State

@MainActor
class EditorState: ObservableObject {
    weak var textView: NSTextView?

    @Published var isBold    = false
    @Published var isItalic  = false
    @Published var isHeading = false

    // Called whenever the selection or content changes
    func updateFormattingState() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        guard storage.length > 0 else { reset(); return }

        let loc = tv.selectedRange().length > 0
            ? tv.selectedRange().location
            : max(0, tv.selectedRange().location - 1)
        guard loc < storage.length else { reset(); return }

        let font    = storage.attribute(.font, at: loc, effectiveRange: nil) as? NSFont
                      ?? NSFont.systemFont(ofSize: 14)
        let traits  = font.fontDescriptor.symbolicTraits

        isBold    = traits.contains(.bold)
        isItalic  = traits.contains(.italic)
        isHeading = font.pointSize >= 17
    }

    private func reset() { isBold = false; isItalic = false; isHeading = false }

    // MARK: Actions

    func toggleBold() {
        applyTrait(.bold, adding: !isBold)
    }

    func toggleItalic() {
        applyTrait(.italic, adding: !isItalic)
    }

    func toggleHeading() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = lineOrSelection(in: tv)

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, sub, _ in
            let base = value as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let target: NSFont
            if isHeading {
                // Back to body — strip bold only if it came from the heading style
                let desc = base.fontDescriptor.withSymbolicTraits(
                    base.fontDescriptor.symbolicTraits.subtracting(.bold))
                target = NSFont(descriptor: desc, size: 14) ?? NSFont.systemFont(ofSize: 14)
            } else {
                let desc = base.fontDescriptor.withSymbolicTraits(
                    base.fontDescriptor.symbolicTraits.union(.bold))
                target = NSFont(descriptor: desc, size: 18) ?? NSFont.boldSystemFont(ofSize: 18)
            }
            storage.addAttribute(.font, value: target, range: sub)
        }
        storage.endEditing()
        tv.didChangeText()
        updateFormattingState()
    }

    // MARK: Helpers

    private func applyTrait(_ trait: NSFontDescriptor.SymbolicTraits, adding: Bool) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        guard range.length > 0 else { return }

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, sub, _ in
            let font   = value as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let traits = font.fontDescriptor.symbolicTraits
            let next   = adding ? traits.union(trait) : traits.subtracting(trait)
            let desc   = font.fontDescriptor.withSymbolicTraits(next)
            let new    = NSFont(descriptor: desc, size: font.pointSize) ?? font
            storage.addAttribute(.font, value: new, range: sub)
        }
        storage.endEditing()
        tv.didChangeText()
        updateFormattingState()
    }

    private func lineOrSelection(in tv: NSTextView) -> NSRange {
        let sel = tv.selectedRange()
        if sel.length > 0 { return sel }
        return (tv.string as NSString).lineRange(for: NSRange(location: sel.location, length: 0))
    }
}

// MARK: - NSViewRepresentable

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    let editorState: EditorState

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }

        tv.delegate                              = context.coordinator
        tv.isRichText                            = true
        tv.isEditable                            = true
        tv.isSelectable                          = true
        tv.allowsUndo                            = true
        tv.drawsBackground                       = false
        tv.backgroundColor                       = .clear
        tv.textContainerInset                    = NSSize(width: 4, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled   = false
        tv.isAutomaticDashSubstitutionEnabled    = false
        tv.typingAttributes                      = Self.defaultAttrs

        tv.textStorage?.setAttributedString(attributedText)
        editorState.textView = tv

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            tv.window?.makeFirstResponder(tv)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        editorState.textView = tv
        guard !context.coordinator.isEditing else { return }

        let sel = tv.selectedRange()
        tv.textStorage?.setAttributedString(attributedText)
        tv.setSelectedRange(sel)
    }

    func makeCoordinator() -> Coordinator { Coordinator(attributedText: $attributedText, editorState: editorState) }

    static let defaultAttrs: [NSAttributedString.Key: Any] = [
        .font:            NSFont.systemFont(ofSize: 14),
        .foregroundColor: NSColor.labelColor
    ]
}

// MARK: - Coordinator

class Coordinator: NSObject, NSTextViewDelegate {
    var attributedText: Binding<NSAttributedString>
    let editorState: EditorState
    var isEditing = false

    init(attributedText: Binding<NSAttributedString>, editorState: EditorState) {
        self.attributedText = attributedText
        self.editorState    = editorState
    }

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView,
              let storage = tv.textStorage else { return }
        isEditing = true
        attributedText.wrappedValue = NSAttributedString(attributedString: storage)
        isEditing = false
        Task { @MainActor in editorState.updateFormattingState() }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        Task { @MainActor in editorState.updateFormattingState() }
    }
}
