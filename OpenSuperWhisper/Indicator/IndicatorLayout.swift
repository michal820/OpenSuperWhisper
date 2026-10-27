import AppKit
import SwiftUI

/// Where the recording indicator sits and how big it is. The user moves it by
/// dragging the card and resizes it by dragging the card's right end; both
/// are remembered across sessions and launches, separately for each display.
@MainActor
final class IndicatorLayout: ObservableObject {
    static let shared = IndicatorLayout()
    static let scaleRange: ClosedRange<CGFloat> = 0.6...3
    /// Width of the drag-to-resize zone at the card's right end, before scaling.
    static let resizeHandleWidth: CGFloat = 24

    @Published private(set) var scale: CGFloat = 1

    private init() {}

    private static func clamped(_ scale: CGFloat) -> CGFloat {
        min(max(scale, scaleRange.lowerBound), scaleRange.upperBound)
    }

    func setScale(_ newScale: CGFloat) {
        scale = Self.clamped(newScale)
    }

    /// Switches to the size the user last chose on this screen.
    func applySavedScale(for screen: NSScreen) {
        let saved = Self.key(for: screen).flatMap { AppPreferences.shared.indicatorScales[$0] }
        setScale(CGFloat(saved ?? 1))
    }

    var cardSize: CGSize {
        CGSize(width: IndicatorWindow.cardSize.width * scale, height: IndicatorWindow.cardSize.height * scale)
    }

    /// Whole points: AppKit rounds window frames, and the SwiftUI root must
    /// match the panel exactly.
    var windowSize: CGSize {
        CGSize(width: (IndicatorWindow.windowSize.width * scale).rounded(),
               height: (IndicatorWindow.windowSize.height * scale).rounded())
    }

    /// The card is centered inside the larger panel (margins for the appear
    /// animation), so the card and window frames share a center.
    func cardFrame(inWindowFrame frame: NSRect) -> NSRect {
        NSRect(x: frame.midX - cardSize.width / 2, y: frame.midY - cardSize.height / 2,
               width: cardSize.width, height: cardSize.height)
    }

    func windowFrame(cardCenter center: NSPoint) -> NSRect {
        NSRect(x: center.x - windowSize.width / 2, y: center.y - windowSize.height / 2,
               width: windowSize.width, height: windowSize.height)
    }

    /// Card center the user last chose on this screen, if it still fits on it.
    func savedCardCenter(on screen: NSScreen) -> NSPoint? {
        guard let key = Self.key(for: screen),
              let offset = AppPreferences.shared.indicatorPositions[key], offset.count == 2 else { return nil }
        let frame = screen.frame
        let center = NSPoint(x: frame.minX + offset[0], y: frame.minY + offset[1])
        return frame.contains(center) ? center : nil
    }

    /// Remembers the position and size for the screen the card ended up on.
    func save(cardCenter center: NSPoint) {
        let prefs = AppPreferences.shared
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }),
              let key = Self.key(for: screen) else { return }
        var positions = prefs.indicatorPositions
        positions[key] = [Double(center.x - screen.frame.minX), Double(center.y - screen.frame.minY)]
        prefs.indicatorPositions = positions
        var scales = prefs.indicatorScales
        scales[key] = Double(scale)
        prefs.indicatorScales = scales
    }

    /// The display's UUID, which, unlike its display ID, survives reboots and
    /// reconnecting or rearranging monitors.
    private static func key(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

/// Hosts the indicator card and turns drags on it into moving (anywhere on
/// the card) or resizing (its right end). The panel keeps AppKit's default
/// mouse handling, so clicks on its transparent margins fall through to the
/// window below, and it is non-activating, so dragging never steals focus
/// from the app the transcription will be pasted into.
final class IndicatorHostingView: NSHostingView<IndicatorWindow> {
    private enum Drag {
        case move(startMouse: NSPoint, startCenter: NSPoint)
        case resize(startMouse: NSPoint, startCard: NSRect)
    }

    private var drag: Drag?
    private var hoverArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Claim clicks on the card so SwiftUI's own views never swallow them.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window else { return nil }
        let screenPoint = window.convertPoint(toScreen: convert(convert(point, from: superview), to: nil))
        return currentCardFrame(in: window).contains(screenPoint) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let card = currentCardFrame(in: window)
        if isOverResizeHandle(mouse, card: card) {
            drag = .resize(startMouse: mouse, startCard: card)
        } else {
            drag = .move(startMouse: mouse, startCenter: NSPoint(x: card.midX, y: card.midY))
            NSCursor.closedHand.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let drag else { return }
        let layout = IndicatorLayout.shared
        let mouse = NSEvent.mouseLocation
        switch drag {
        case let .move(startMouse, startCenter):
            let center = NSPoint(x: startCenter.x + mouse.x - startMouse.x,
                                 y: startCenter.y + mouse.y - startMouse.y)
            window.setFrame(layout.windowFrame(cardCenter: center), display: true)
        case let .resize(startMouse, startCard):
            // Scale with the horizontal drag, keeping the card's left edge and
            // vertical center in place, like resizing a window from its edge.
            layout.setScale((startCard.width + mouse.x - startMouse.x) / IndicatorWindow.cardSize.width)
            let center = NSPoint(x: startCard.minX + layout.cardSize.width / 2, y: startCard.midY)
            window.setFrame(layout.windowFrame(cardCenter: center), display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let window, drag != nil else { return }
        drag = nil
        let card = currentCardFrame(in: window)
        IndicatorLayout.shared.save(cardCenter: NSPoint(x: card.midX, y: card.midY))
        updateCursor(at: NSEvent.mouseLocation)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard hoverArea == nil else { return }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
                                  owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if drag == nil { updateCursor(at: NSEvent.mouseLocation) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if drag == nil { NSCursor.arrow.set() }
    }

    private func updateCursor(at mouse: NSPoint) {
        guard let window else { return }
        let card = currentCardFrame(in: window)
        if !card.contains(mouse) {
            NSCursor.arrow.set()
        } else if isOverResizeHandle(mouse, card: card) {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.openHand.set()
        }
    }

    private func currentCardFrame(in window: NSWindow) -> NSRect {
        IndicatorLayout.shared.cardFrame(inWindowFrame: window.frame)
    }

    private func isOverResizeHandle(_ mouse: NSPoint, card: NSRect) -> Bool {
        mouse.x >= card.maxX - IndicatorLayout.resizeHandleWidth * IndicatorLayout.shared.scale
    }
}
