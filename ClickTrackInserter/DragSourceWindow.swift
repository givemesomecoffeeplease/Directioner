//
//  DragSourceWindow.swift
//  ClickTrackInserter
//

import Cocoa

class DragSourceView: NSView, NSDraggingSource {

    var fileURL: URL?

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        CGAssociateMouseAndMouseCursorPosition(1)
        print("[DragSource] 세션 종료: op=\(operation.rawValue)")
    }

    func startDragSession(with event: NSEvent, dropCG: CGPoint) {
        guard let url = fileURL else { return }

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 32, height: 32), contents: icon)

        CGAssociateMouseAndMouseCursorPosition(0)
        CGWarpMouseCursorPosition(dropCG)

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false

        guard let winNum = self.window?.windowNumber else { return }

        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: false) { _ in
            if let nudge = NSEvent.mouseEvent(
                with: .leftMouseDragged, location: NSPoint(x: 22, y: 20),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: winNum, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                NSApp.postEvent(nudge, atStart: false)
            }
        }

        Timer.scheduledTimer(withTimeInterval: 0.06, repeats: false) { _ in
            CGAssociateMouseAndMouseCursorPosition(1)
            if let up = NSEvent.mouseEvent(
                with: .leftMouseUp, location: NSPoint(x: 22, y: 20),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: winNum, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
                NSApp.postEvent(up, atStart: false)
            }
        }
    }
}

class DragSourceWindow: NSWindow {

    let dragView = DragSourceView()

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 40, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .normal
        ignoresMouseEvents = false
        dragView.frame = NSRect(x: 0, y: 0, width: 40, height: 40)
        contentView?.addSubview(dragView)
    }

    func startDrag(url: URL, to dropAX: CGPoint) {
        dragView.fileURL = url

        let screenH = NSScreen.main?.frame.height ?? 1440
        let appkitY = screenH - dropAX.y

        setFrameOrigin(NSPoint(x: dropAX.x - 20, y: appkitY - 20))
        orderBack(nil)

        guard let event = NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 20, y: 20),
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1.0
        ) else { return }

        print("[DragSource] 즉시 드롭 → CG\(dropAX)")
        dragView.startDragSession(with: event, dropCG: dropAX)
    }
}
