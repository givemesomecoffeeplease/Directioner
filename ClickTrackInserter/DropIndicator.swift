//
//  DropIndicator.swift
//  ClickTrackInserter
//

import Cocoa

/// 커서 옆에 파일 이름 배지를 띄우고, 클릭 위치를 캡처해 콜백으로 전달
class DropIndicator {

    private var indicatorWindow: NSWindow?
    private var positionTimer: Timer?
    private var clickTap: CFMachPort?

    /// 클릭 위치(CG 좌표)를 전달 — true 반환 시 클릭 이벤트 소비(Logic Pro에 전달 안 함)
    var onClickInLogicPro: ((CGPoint) -> Bool)?
    /// ESC로 취소 시 호출
    var onCancel: (() -> Void)?

    // MARK: - Show / Hide

    func show(fileName: String) {
        hide()

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 28),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .popUpMenu
        win.ignoresMouseEvents = true
        win.hasShadow = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 28))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
        container.layer?.cornerRadius = 6

        let label = NSTextField(labelWithString: "⬇ \(fileName)")
        label.frame = NSRect(x: 8, y: 4, width: 164, height: 20)
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        container.addSubview(label)
        win.contentView = container

        indicatorWindow = win
        win.orderFrontRegardless()

        // 타이머로 마우스 위치 추적 (~60fps) — 글로벌 모니터는 자기 앱 이벤트를 못 받는 경우가 있음
        updatePosition()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }

        // 클릭 + ESC 이벤트 탭 설치
        installClickTap()
    }

    func hide() {
        indicatorWindow?.orderOut(nil)
        indicatorWindow = nil
        positionTimer?.invalidate()
        positionTimer = nil
        removeClickTap()
    }

    // MARK: - Position

    private func updatePosition() {
        guard let win = indicatorWindow else { return }
        let mouse = NSEvent.mouseLocation
        let origin = NSPoint(x: mouse.x + 16, y: mouse.y - 28)
        win.setFrameOrigin(origin)
    }

    // MARK: - Click capture (CGEventTap)

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
                    if keyCode == 53 { // ESC
                        DispatchQueue.main.async {
                            indicator.hide()
                            indicator.onCancel?()
                        }
                        return nil // ESC 소비
                    }
                    return Unmanaged.passRetained(event)
                }

                guard type == .leftMouseDown else {
                    return Unmanaged.passRetained(event)
                }
                let pos = event.location
                if let consume = indicator.onClickInLogicPro, consume(pos) {
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

    private func removeClickTap() {
        if let tap = clickTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            clickTap = nil
        }
    }
}
