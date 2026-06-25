//
//  HotkeyMonitor.swift
//  ClickTrackInserter
//

import Cocoa
import Carbon

class HotkeyMonitor {

    private var eventTap: CFMachPort?
    private var lastShiftTime: TimeInterval = 0
    private let doubleTapInterval: TimeInterval = 0.35

    var onDoubleShift: (() -> Void)?

    func start() {
        print("[HotkeyMonitor] AXIsProcessTrusted: \(AXIsProcessTrusted())")
        if AXIsProcessTrusted() {
            installEventTap()
        } else {
            requestAccessibilityPermission()
            waitForPermission()
        }
    }

    private func waitForPermission() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                print("[HotkeyMonitor] 권한 획득 — EventTap 설치")
                timer.invalidate()
                self.installEventTap()
            }
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func installEventTap() {
        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handleEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            print("[HotkeyMonitor] CGEventTap 생성 실패 — Accessibility 권한 확인 필요")
            return
        }
        print("[HotkeyMonitor] CGEventTap 생성 성공")
        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(_ event: CGEvent) {
        let flags = event.flags
        print("[HotkeyMonitor] flagsChanged: \(flags.rawValue)")
        let shiftDown = flags.contains(.maskShift) && !flags.contains(.maskAlternate)
            && !flags.contains(.maskCommand) && !flags.contains(.maskControl)

        guard shiftDown else { return }
        print("[HotkeyMonitor] Shift 감지")

        let now = Date().timeIntervalSinceReferenceDate
        if now - lastShiftTime < doubleTapInterval {
            lastShiftTime = 0
            DispatchQueue.main.async { self.onDoubleShift?() }
        } else {
            lastShiftTime = now
        }
    }

    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }
}
