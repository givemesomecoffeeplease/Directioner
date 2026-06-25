//
//  AppDelegate.swift
//  ClickTrackInserter
//
//  Created by 한희 on 6/25/26.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    let hotkeyMonitor = HotkeyMonitor()
    private lazy var inputPopup = InputPopupController()
    private let logicPro = LogicProController()
    private let dropIndicator = DropIndicator()

    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        setupMenuBarItem()
        setupHotkey()

        if !UserDefaults.standard.bool(forKey: "onboardingDone") {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Directioner 시작하기"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView {
            UserDefaults.standard.set(true, forKey: "onboardingDone")
            window.orderOut(nil)
        })
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func setupHotkey() {
        hotkeyMonitor.onTrigger = { [weak self] in
            self?.inputPopup.show()
        }
        inputPopup.onSubmit = { [weak self] path in
            guard let self else { return }
            let url = URL(fileURLWithPath: path)
            let fileName = url.deletingPathExtension().lastPathComponent
            print("[AppDelegate] 드롭 대기: \(path)")

            self.dropIndicator.show(fileName: fileName)
            if let logicApp = NSRunningApplication.runningApplications(withBundleIdentifier: LogicProController.bundleID).first {
                logicApp.activate(options: .activateIgnoringOtherApps)
            }

            // 클릭: Logic Pro 위면 그 위치에 즉시 드롭
            self.dropIndicator.onClickInLogicPro = { [weak self] clickCG in
                guard let self else { return false }
                guard self.logicPro.isOverLogicPro(point: clickCG) else { return false }
                self.dropIndicator.hide()
                self.logicPro.insertAudio(url: url, at: clickCG) { result in
                    switch result {
                    case .success: print("[AppDelegate] 삽입 완료")
                    case .failure(let err): print("[AppDelegate] 삽입 실패: \(err.localizedDescription)")
                    }
                }
                return true
            }
        }
        hotkeyMonitor.start()
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Directioner")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "ClickTrack Inserter 설정"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
