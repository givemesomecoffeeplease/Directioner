//
//  HotkeyMonitor.swift
//  ClickTrackInserter
//

import Cocoa
import Carbon

class HotkeyMonitor {

    private var eventTap: CFMachPort?
    private var lastTapTime: TimeInterval = 0
    private let doubleTapInterval: TimeInterval = 0.35

    var onTrigger: (() -> Void)?

    func start() {
        if AXIsProcessTrusted() {
            installEventTap()
        } else {
            requestAccessibilityPermission()
            waitForPermission()
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    func restart() {
        stop()
        installEventTap()
    }

    // MARK: - CGEventFlags 변환 (HotkeyConfig 독립)

    private func cgFlag(for mod: ModifierKey) -> CGEventFlags {
        switch mod {
        case .shift:   return .maskShift
        case .option:  return .maskAlternate
        case .command: return .maskCommand
        case .control: return .maskControl
        }
    }

    private let allModifierFlags: CGEventFlags = [.maskShift, .maskAlternate, .maskCommand, .maskControl]

    // MARK: - Private

    private func waitForPermission() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.installEventTap()
            }
        }
    }

    private func installEventTap() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
                              | (1 << CGEventType.keyDown.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handleEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else { return }
        eventTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let config = HotkeyStore.shared.config
        switch config.kind {
        case .doubleTap(let mod):
            guard type == .flagsChanged else { return }
            handleDoubleTap(event: event, modifier: mod)
        case .combo(let mods, let keyCode, _):
            guard type == .keyDown else { return }
            handleCombo(event: event, mods: mods, keyCode: keyCode)
        }
    }

    private func handleDoubleTap(event: CGEvent, modifier: ModifierKey) {
        let flags = event.flags
        let target = cgFlag(for: modifier)
        let others = allModifierFlags.subtracting(target)

        // 해당 모디파이어만 눌렸을 때
        guard flags.contains(target) else { return }
        guard flags.intersection(others).isEmpty else { return }

        let now = Date().timeIntervalSinceReferenceDate
        if now - lastTapTime < doubleTapInterval {
            lastTapTime = 0
            DispatchQueue.main.async { self.onTrigger?() }
        } else {
            lastTapTime = now
        }
    }

    private func handleCombo(event: CGEvent, mods: [ModifierKey], keyCode: UInt16) {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        guard code == Int64(keyCode) else { return }

        let flags = event.flags
        for mod in mods {
            guard flags.contains(cgFlag(for: mod)) else { return }
        }

        // 지정하지 않은 모디파이어는 없어야 함
        let specified = mods.reduce(into: CGEventFlags()) { $0.formUnion(cgFlag(for: $1)) }
        let extra = allModifierFlags.subtracting(specified)
        guard flags.intersection(extra).isEmpty else { return }

        DispatchQueue.main.async { self.onTrigger?() }
    }

    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }
}
