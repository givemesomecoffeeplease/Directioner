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

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        print("[DragSource] 세션 시작: \(screenPoint)")
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        CGAssociateMouseAndMouseCursorPosition(1)
        print("[DragSource] 세션 종료: \(screenPoint), operation: \(operation.rawValue)")
        if operation == [] {
            print("[DragSource] ❌ Logic Pro가 드롭 거부")
        } else {
            print("[DragSource] ✅ 드롭 수락")
        }
    }

    /// dropCG: AX API = CG 좌표계 (좌상단 원점, Y 아래 증가) — 변환 없이 그대로 사용
    func startDragSession(with event: NSEvent, dropCG: CGPoint) {
        guard let url = fileURL else { return }

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 32, height: 32), contents: icon)

        // 물리 마우스 디커플 후 커서를 드롭 위치로 워프 (CG 좌표 직접 사용)
        CGAssociateMouseAndMouseCursorPosition(0)
        CGWarpMouseCursorPosition(dropCG)

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false

        // 드래그 세션 런루프에 nudge + mouseUp 주입
        guard let winNum = self.window?.windowNumber else { return }
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            guard self != nil else { return }
            if let nudge = NSEvent.mouseEvent(
                with: .leftMouseDragged, location: NSPoint(x: 21, y: 20),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: winNum, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                NSApp.postEvent(nudge, atStart: false)
            }
            Timer.scheduledTimer(withTimeInterval: 0.03, repeats: false) { _ in
                if let up = NSEvent.mouseEvent(
                    with: .leftMouseUp, location: NSPoint(x: 20, y: 20),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: winNum, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
                    NSApp.postEvent(up, atStart: false)
                    print("[DragSource] 드롭 완료 → CG\(dropCG)")
                }
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
        level = .normal           // Logic Pro와 동일 레벨 — orderBack으로 뒤에 배치
        ignoresMouseEvents = false
        dragView.frame = NSRect(x: 0, y: 0, width: 40, height: 40)
        contentView?.addSubview(dragView)
    }

    /// dropAX: AX kAXPositionAttribute 좌표 = CG 좌표 (좌상단 원점, Y 아래 증가)
    func startDrag(url: URL, to dropAX: CGPoint) {
        dragView.fileURL = url

        // AX/CG → AppKit 변환 (NSWindow.setFrameOrigin은 AppKit 좌표 사용)
        // AppKit: 좌하단 원점, Y 위 증가 → appkitY = screenH - cgY
        let screenH = NSScreen.main?.frame.height ?? 1440
        let appkitY = screenH - dropAX.y

        // 소스 윈도우를 드롭 타겟 위치에 배치 후 Logic Pro 뒤로 보냄
        // Logic Pro가 앞에 있으므로 드롭이 Logic Pro에 정상 전달됨
        setFrameOrigin(NSPoint(x: dropAX.x - 20, y: appkitY - 20))
        orderBack(nil)

        guard let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 20, y: 20),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        ) else {
            print("[DragSource] NSEvent 생성 실패")
            return
        }

        print("[DragSource] 드래그 시작 → 드롭 CG\(dropAX) / AppKit(\(dropAX.x), \(appkitY))")
        dragView.startDragSession(with: event, dropCG: dropAX)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.orderOut(nil)
        }
    }
}
