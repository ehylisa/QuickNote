//
//  CharacterWalker.swift
//  QuickNotes
//

import Combine
import SwiftUI

// MARK: - Walker

@MainActor
final class CharacterWalker: ObservableObject {
    @Published var pos      = CGPoint(x: 292, y: 78)
    @Published var faceLeft = true
    @Published var stepIdx  = 0

    private var timer:    Timer?
    private var section   = 0
    private var tickCount = 0

    // ── Layout constants matching ContentView 300×430 (top-origin) ────
    // header ~36px | div 1 | noteTabs 52px | div 1 | toolbar 34px | div 1 | editor ...
    private let leftEdge:  CGFloat = 6
    private let rightEdge: CGFloat = 294

    // Feet-Y placed exactly on each divider line / text baseline
    // Header(36) | Div(36) | Tabs(52→89) | Div(89) | Toolbar(34→124) | Div(124) | Editor…
    private let rowY: [CGFloat] = [
        89,   // divider between tabs bar and formatting toolbar
        124,  // divider between formatting toolbar and editor
    ]
    private let editorFirstY:   CGFloat = 151   // bottom of first text line (inset 8 + line ~18)
    private let editorLineStep: CGFloat = 20
    private let editorLineCount         = 6

    private let speed:         CGFloat = 0.55
    private let stepsPerFrame          = 12      // timer ticks per walk-cycle frame

    @Published var isDragging  = false
    private var dragStartPos   = CGPoint.zero

    // MARK: Control

    func start() {
        guard timer == nil else { return }
        reset()
        resume()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Drag

    func startDrag() {
        isDragging   = true
        dragStartPos = pos
        // Timer keeps running — tick() skips movement but still advances stepIdx
        // so legs keep swinging while the character is held
    }

    func updateDrag(delta: CGSize) {
        pos = CGPoint(x: dragStartPos.x + delta.width,
                      y: dragStartPos.y + delta.height)
        if abs(delta.width) > 1 { faceLeft = delta.width < 0 }
    }

    func endDrag() {
        isDragging = false
        // Snap Y to nearest walking row
        let allY: [CGFloat] = rowY + (0..<editorLineCount).map {
            editorFirstY + CGFloat($0) * editorLineStep
        }
        let snapY = allY.min(by: { abs($0 - pos.y) < abs($1 - pos.y) }) ?? rowY[0]
        section   = allY.firstIndex(of: snapY) ?? 0
        pos.y     = snapY
        pos.x     = max(leftEdge, min(rightEdge, pos.x))
        faceLeft  = pos.x > (leftEdge + rightEdge) / 2
    }

    // MARK: Private

    private func resume() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func reset() {
        section   = 0
        faceLeft  = true
        pos       = CGPoint(x: rightEdge, y: rowY[0])   // start on first divider, walking left
        stepIdx   = 0
        tickCount = 0
    }

    private func tick() {
        tickCount += 1
        if tickCount % stepsPerFrame == 0 { stepIdx = (stepIdx + 1) % 4 }

        guard !isDragging else { return }   // legs still swing; only movement is skipped

        let newX = pos.x + (faceLeft ? -speed : speed)
        if faceLeft ? (newX <= leftEdge) : (newX >= rightEdge) {
            nextRow()
        } else {
            pos.x = newX
        }
    }

    private func nextRow() {
        section  += 1
        faceLeft.toggle()
        let startX: CGFloat = faceLeft ? rightEdge : leftEdge

        if section < rowY.count {
            pos = CGPoint(x: startX, y: rowY[section])
            return
        }
        let line = section - rowY.count
        if line < editorLineCount {
            pos = CGPoint(x: startX, y: editorFirstY + CGFloat(line) * editorLineStep)
        } else {
            reset()
        }
    }
}

// MARK: - Sprite  (voxel Overcooked chef matching omma.build/k4nekpztrbj)
//
// Drawn at 26×44. Every block has a front face + darker right-side face for depth.
// Stepped two-tier hat, square eyes with gleam, pink blush cheeks, white coat,
// red apron with straps + pocket, blue pants, black cube shoes, tiny spatula.
// Whole upper body bobs on alternate steps. Faces right; scaleEffect flips left.

struct WalkingCharacter: View {
    let stepIdx:  Int
    let faceLeft: Bool

    var body: some View {
        Canvas { ctx, _ in
            let s = stepIdx % 4
            let lOff: CGFloat = s == 1 ? -2.5 : (s == 3 ?  2.5 : 0)
            let rOff: CGFloat = s == 1 ?  2.5 : (s == 3 ? -2.5 : 0)
            // Whole upper body bobs slightly on each step
            let bob:  CGFloat = (s == 1 || s == 3) ? 1.0 : 0.0

            // ── Palette ───────────────────────────────────────────────
            let hatF  = Color(white: 0.88)
            let hatS  = Color(white: 0.65)
            let skin  = Color(red: 0.87, green: 0.73, blue: 0.57)
            let skinS = Color(red: 0.68, green: 0.54, blue: 0.40)
            let eyeC  = Color(red: 0.12, green: 0.10, blue: 0.14)
            let nose  = Color(red: 0.62, green: 0.42, blue: 0.28)
            let blush = Color(red: 0.93, green: 0.62, blue: 0.62)
            let coatF = Color(white: 0.92)
            let coatS = Color(white: 0.70)
            let aprF  = Color(red: 0.80, green: 0.16, blue: 0.16)
            let aprS  = Color(red: 0.55, green: 0.09, blue: 0.09)
            let pntF  = Color(red: 0.18, green: 0.30, blue: 0.63)
            let pntS  = Color(red: 0.10, green: 0.18, blue: 0.42)
            let shoF  = Color(red: 0.11, green: 0.09, blue: 0.11)
            let shoS  = Color(red: 0.05, green: 0.04, blue: 0.05)
            let spat  = Color(red: 0.52, green: 0.32, blue: 0.14)
            let drop  = Color.black.opacity(0.10)

            // ── Drop shadow ───────────────────────────────────────────
            ctx.fill(Path(ellipseIn: CGRect(x: 3, y: 41, width: 20, height: 3)), with: .color(drop))

            // ═══════════════════════════════════════════════════════════
            // Hat, head, coat, arms all shift by `bob` for walk bounce
            // ═══════════════════════════════════════════════════════════

            // ── Hat: upper crown (narrow tier) ───────────────────────
            ctx.fill(Path(CGRect(x: 6.0,  y: 0.0 + bob, width: 14.0, height: 5.5)), with: .color(hatF))
            ctx.fill(Path(CGRect(x: 19.5, y: 0.5 + bob, width: 2.5,  height: 5.0)), with: .color(hatS))

            // ── Hat: lower crown (wider toque base) ───────────────────
            ctx.fill(Path(CGRect(x: 4.0,  y: 5.0 + bob, width: 17.0, height: 3.0)), with: .color(hatF))
            ctx.fill(Path(CGRect(x: 20.5, y: 5.5 + bob, width: 2.5,  height: 2.5)), with: .color(hatS))

            // ── Hat brim ─────────────────────────────────────────────
            ctx.fill(Path(CGRect(x: 2.0,  y: 7.5 + bob, width: 19.5, height: 2.5)), with: .color(hatF))
            ctx.fill(Path(CGRect(x: 21.0, y: 8.0 + bob, width: 2.5,  height: 2.0)), with: .color(hatS))
            ctx.fill(Path(CGRect(x: 2.0,  y: 7.5 + bob, width: 19.5, height: 0.8)), with: .color(Color.white.opacity(0.45)))

            // ── Head (blocky square) ──────────────────────────────────
            ctx.fill(Path(CGRect(x: 3.0,  y: 10.0 + bob, width: 17.0, height: 12.0)), with: .color(skin))
            ctx.fill(Path(CGRect(x: 19.5, y: 10.5 + bob, width: 3.0,  height: 11.0)), with: .color(skinS))

            // Eyes — square blocks (key voxel detail)
            ctx.fill(Path(CGRect(x: 5.5,  y: 13.5 + bob, width: 4.5, height: 4.5)), with: .color(eyeC))
            ctx.fill(Path(CGRect(x: 13.0, y: 13.5 + bob, width: 4.5, height: 4.5)), with: .color(eyeC))
            // square gleam top-left of each eye
            ctx.fill(Path(CGRect(x: 5.5,  y: 13.5 + bob, width: 2.0, height: 2.0)), with: .color(Color.white.opacity(0.85)))
            ctx.fill(Path(CGRect(x: 13.0, y: 13.5 + bob, width: 2.0, height: 2.0)), with: .color(Color.white.opacity(0.85)))

            // Nose (small brown voxel)
            ctx.fill(Path(CGRect(x: 10.5, y: 17.5 + bob, width: 3.0, height: 2.0)), with: .color(nose))

            // Blush cheeks
            ctx.fill(Path(CGRect(x: 4.5,  y: 19.5 + bob, width: 3.5, height: 2.0)), with: .color(blush))
            ctx.fill(Path(CGRect(x: 15.0, y: 19.5 + bob, width: 3.5, height: 2.0)), with: .color(blush))

            // ── White coat body ───────────────────────────────────────
            ctx.fill(Path(CGRect(x: 2.5,  y: 22.0 + bob, width: 17.5, height: 9.0)), with: .color(coatF))
            ctx.fill(Path(CGRect(x: 19.5, y: 22.5 + bob, width: 3.0,  height: 8.5)), with: .color(coatS))

            // ── Red apron (over coat) ─────────────────────────────────
            // Left strap
            ctx.fill(Path(CGRect(x: 7.0,  y: 22.0 + bob, width: 2.0,  height: 5.0)), with: .color(aprS))
            // Right strap
            ctx.fill(Path(CGRect(x: 15.0, y: 22.0 + bob, width: 2.0,  height: 5.0)), with: .color(aprS))
            // Apron body
            ctx.fill(Path(CGRect(x: 6.5,  y: 26.5 + bob, width: 11.0, height: 4.5)), with: .color(aprF))
            ctx.fill(Path(CGRect(x: 17.0, y: 27.0 + bob, width: 2.0,  height: 4.0)), with: .color(aprS))
            // Pocket
            ctx.fill(Path(CGRect(x: 8.5,  y: 28.0 + bob, width: 4.5,  height: 3.0)), with: .color(aprS))

            // ── Arms ─────────────────────────────────────────────────
            ctx.fill(Path(CGRect(x: 0.0,  y: 23.0 + bob, width: 3.0,  height: 6.5)), with: .color(coatF))
            ctx.fill(Path(CGRect(x: 19.5, y: 23.0 + bob, width: 3.0,  height: 6.5)), with: .color(coatS))

            // Spatula in right hand
            ctx.fill(Path(CGRect(x: 22.0, y: 27.0 + bob, width: 1.5,  height: 8.5)), with: .color(spat))

            // ── Pants ─────────────────────────────────────────────────
            ctx.fill(Path(CGRect(x: 4.0,  y: 31.0 + lOff, width: 6.0, height: 7.5)), with: .color(pntF))
            ctx.fill(Path(CGRect(x: 9.5,  y: 31.5 + lOff, width: 1.5, height: 7.0)), with: .color(pntS))
            ctx.fill(Path(CGRect(x: 14.0, y: 31.0 + rOff, width: 6.0, height: 7.5)), with: .color(pntF))
            ctx.fill(Path(CGRect(x: 19.5, y: 31.5 + rOff, width: 1.5, height: 7.0)), with: .color(pntS))

            // ── Shoes (black cubes, wider than legs) ──────────────────
            ctx.fill(Path(CGRect(x: 2.0,  y: 38.0 + lOff, width: 9.5, height: 3.0)), with: .color(shoF))
            ctx.fill(Path(CGRect(x: 11.0, y: 38.5 + lOff, width: 2.0, height: 2.5)), with: .color(shoS))
            ctx.fill(Path(CGRect(x: 12.5, y: 38.0 + rOff, width: 9.5, height: 3.0)), with: .color(shoF))
            ctx.fill(Path(CGRect(x: 21.5, y: 38.5 + rOff, width: 2.0, height: 2.5)), with: .color(shoS))
        }
        .frame(width: 26, height: 44)
        .scaleEffect(x: faceLeft ? -1 : 1, anchor: .center)
    }
}
