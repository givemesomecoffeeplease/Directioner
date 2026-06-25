//
//  DropIndicator.swift
//  ClickTrackInserter
//

import Cocoa

class DropIndicator {

    private var indicatorWindow: NSWindow?
    private var lineWindow: NSWindow?       // 세로 재생헤드 라인
    private var positionTimer: Timer?
    private var clickTap: CFMachPort?
    private var dropKeyTap: CFMachPort?

    var onClickInLogicPro: ((CGPoint) -> Bool)?
    /// 스페이스바/Enter 시 현재 커서 CG 좌표 전달
    var onSpacebarDrop: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Show / Hide

    func show(fileName: String) {
        hide()

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 28),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .popUpMenu
        win.ignoresMouseEvents = true
        win.hasShadow = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
        container.layer?.cornerRadius = 6

        let label = NSTextField(labelWithString: "⬇ \(fileName)")
        label.frame = NSRect(x: 8, y: 4, width: 184, height: 20)
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        container.addSubview(label)
        win.contentView = container

        indicatorWindow = win
        win.orderFrontRegardless()

        // 세로 재생헤드 라인 생성
        let lineH: CGFloat = NSScreen.main?.frame.height ?? 900
        let lineWin = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 2, height: lineH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        lineWin.isOpaque = false
        lineWin.backgroundColor = .clear
        lineWin.level = .popUpMenu
        lineWin.ignoresMouseEvents = true
        lineWin.hasShadow = false

        let lineView = NSView(frame: NSRect(x: 0, y: 0, width: 2, height: lineH))
        lineView.wantsLayer = true
        lineView.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.75).cgColor
        lineWin.contentView = lineView
        lineWindow = lineWin
        lineWin.orderFrontRegardless()

        updatePosition()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }

        installClickTap()
    }

    /// 클릭 이후 — 배지를 "Space로 드롭" 텍스트로 바꾸고 스페이스바 대기
    func enterDropMode(fileName: String) {
        // 배지 텍스트 업데이트
        if let container = indicatorWindow?.contentView?.subviews.first,
           let label = container.subviews.first as? NSTextField {
            label.stringValue = "Space↵  \(fileName)"
        }
        indicatorWindow?.orderFrontRegardless()
        updatePosition()
        positionTimer = positionTimer ?? Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
        installDropKeyTap()
    }

    func hide() {
        indicatorWindow?.orderOut(nil)
        indicatorWindow = nil
        lineWindow?.orderOut(nil)
        lineWindow = nil
        positionTimer?.invalidate()
        positionTimer = nil
        removeClickTap()
        removeDropKeyTap()
    }

    // MARK: - Position

    private func updatePosition() {
        let mouse = NSEvent.mouseLocation
        indicatorWindow?.setFrameOrigin(NSPoint(x: mouse.x + 16, y: mouse.y - 28))
        // 세로 라인: 커서 X에 맞춰 화면 전체 높이로
        if let line = lineWindow {
            let lineH = line.frame.height
            line.setFrameOrigin(NSPoint(x: mouse.x - 1, y: 0))
            _ = lineH // suppress warning
        }
    }

    // MARK: - Phase 1: 클릭 감지

    private func installClickTap() {
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.keyDown.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let indicator = Unmanaged<DropIndicator>.fromOpaque(refcon!).takeUnretainedValue()

                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == 53 {
                        DispatchQueue.main.async { indicator.hide(); indicator.onCancel?() }
                        return nil
                    }
                    return Unmanaged.passRetained(event)
                }

                guard type == .leftMouseDown else { return Unmanaged.passRetained(event) }

                let pos = event.location
                if let consume = indicator.onClickInLogicPro, consume(pos) {
                    // 클릭 소비 — 이벤트가 Logic Pro에 안 가도록
                    return nil
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else { return }
        clickTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func removeClickTapOnly() {
        removeClickTap()
    }

    private func removeClickTap() {
        if let tap = clickTap { CGEvent.tapEnable(tap: tap, enable: false); clickTap = nil }
    }

    // MARK: - Phase 2: 스페이스바/Enter → 드롭

    private func installDropKeyTap() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard type == .keyDown else { return Unmanaged.passRetained(event) }
                let indicator = Unmanaged<DropIndicator>.fromOpaque(refcon!).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                if keyCode == 49 || keyCode == 36 { // space or Enter
                    // CGEvent.location은 CG 좌표 (좌상단 원점)
                    let cursorCG = event.location
                    DispatchQueue.main.async {
                        indicator.removeDropKeyTap()
                        indicator.hide()
                        indicator.onSpacebarDrop?(cursorCG)
                    }
                    return nil
                }

                if keyCode == 53 { // ESC
                    DispatchQueue.main.async { indicator.hide(); indicator.onCancel?() }
                    return nil
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else { return }
        dropKeyTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeDropKeyTap() {
        if let tap = dropKeyTap { CGEvent.tapEnable(tap: tap, enable: false); dropKeyTap = nil }
    }
}
