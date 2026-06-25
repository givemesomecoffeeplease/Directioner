//
//  InputPopupController.swift
//  ClickTrackInserter
//

import Cocoa

class PopupWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class PopupTableView: NSTableView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        if row >= 0 { selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }
}

class InputPopupController: NSWindowController {

    private let textField = NSTextField()
    private let tableView = PopupTableView()
    private let scrollView = NSScrollView()
    private var filteredMappings: [Mapping] = []
    private var selectedIndex: Int = -1
    private var isListVisible = false

    var onSubmit: ((String) -> Void)?
    private var clickMonitor: Any?

    private let rowHeight: CGFloat = 28
    private let maxVisibleRows: Int = 6
    private let popupWidth: CGFloat = 280

    convenience init() {
        let window = PopupWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        self.init(window: window)
        setupViews()
    }

    private func setupViews() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // 텍스트필드 컨테이너 (둥근 배경)
        let inputContainer = NSView(frame: NSRect(x: 0, y: 0, width: popupWidth, height: 44))
        inputContainer.wantsLayer = true
        inputContainer.layer?.cornerRadius = 10
        inputContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        inputContainer.autoresizingMask = [.width]

        textField.frame = NSRect(x: 12, y: 8, width: popupWidth - 24, height: 28)
        textField.autoresizingMask = [.width]
        textField.placeholderString = "약어 입력 (Tab으로 목록)"
        textField.font = NSFont.systemFont(ofSize: 16)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.delegate = self
        textField.target = self
        textField.action = #selector(submitFromField)
        inputContainer.addSubview(textField)
        contentView.addSubview(inputContainer)

        // 테이블뷰 설정
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.width = popupWidth - 2
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.target = self
        tableView.action = #selector(tableRowClicked(_:))

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.isHidden = true
        contentView.addSubview(scrollView)
    }

    func show() {
        guard let window else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var origin = NSPoint(x: mouseLocation.x - popupWidth / 2, y: mouseLocation.y + 20)
        origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - popupWidth))
        origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - 44))
        window.setFrame(NSRect(origin: origin, size: NSSize(width: popupWidth, height: 44)), display: false)

        textField.stringValue = ""
        selectedIndex = -1
        hideList()

        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKey()
        DispatchQueue.main.async {
            window.makeFirstResponder(self.textField)
            NSTextInputContext.current?.allowedInputSourceLocales = [NSAllRomanInputSourcesLocaleIdentifier]
        }
    }

    func hide() {
        hideList()
        close()
    }

    // MARK: - List

    private func showList(filter: String) {
        let all = MappingStore.shared.mappings
        filteredMappings = filter.isEmpty ? all : all.filter {
            $0.abbreviation.hasPrefix(filter) || $0.displayName.lowercased().contains(filter)
        }
        guard !filteredMappings.isEmpty else { hideList(); return }

        isListVisible = true
        tableView.reloadData()
        selectedIndex = -1

        let visibleRows = min(filteredMappings.count, maxVisibleRows)
        let listHeight = CGFloat(visibleRows) * rowHeight
        let totalHeight = 44 + listHeight

        guard let window else { return }
        var frame = window.frame
        // 리스트는 텍스트필드 아래로 확장 (y를 내려서 높이 확보)
        frame.origin.y = frame.origin.y + frame.height - totalHeight
        frame.size.height = totalHeight

        // 리스트 컨테이너 배경
        if scrollView.superview != nil {
            scrollView.frame = NSRect(x: 0, y: 0, width: popupWidth, height: listHeight)
        }

        // contentView 레이어 배경
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // 텍스트필드 컨테이너를 위로 재배치
        if let inputContainer = window.contentView?.subviews.first {
            inputContainer.frame = NSRect(x: 0, y: listHeight, width: popupWidth, height: 44)
        }
        scrollView.frame = NSRect(x: 0, y: 0, width: popupWidth, height: listHeight)
        scrollView.isHidden = false

        window.setFrame(frame, display: true, animate: false)
        window.contentView?.layer?.masksToBounds = true
        installClickMonitor()
    }

    // MARK: - Click monitor for list

    private func installClickMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, !self.scrollView.isHidden else { return event }
            // scrollView 영역 안인지 확인
            let winPt = event.locationInWindow
            let sv = self.scrollView.frame
            guard winPt.x >= sv.minX && winPt.x <= sv.maxX &&
                  winPt.y >= sv.minY && winPt.y <= sv.maxY else { return event }
            // tableView 좌표계로 변환 후 row 계산
            let tablePoint = self.tableView.convert(winPt, from: nil)
            let row = self.tableView.row(at: tablePoint)
            guard row >= 0 && row < self.filteredMappings.count else { return nil }
            self.selectedIndex = row
            DispatchQueue.main.async { self.submitSelected() }
            return nil
        }
    }

    private func removeClickMonitor() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private func hideList() {
        guard isListVisible || !scrollView.isHidden else { return }
        isListVisible = false
        filteredMappings = []
        scrollView.isHidden = true

        guard let window else { return }
        var frame = window.frame
        frame.origin.y = frame.origin.y + frame.height - 44
        frame.size.height = 44
        if let inputContainer = window.contentView?.subviews.first {
            inputContainer.frame = NSRect(x: 0, y: 0, width: popupWidth, height: 44)
        }
        window.setFrame(frame, display: true, animate: false)
        window.contentView?.layer?.backgroundColor = .clear
        removeClickMonitor()
    }

    private func selectRow(_ index: Int) {
        guard index >= 0, index < filteredMappings.count else { return }
        selectedIndex = index
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    // MARK: - Table click

    @objc private func tableRowClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0 else { return }
        selectedIndex = row
        submitSelected()
    }

    // MARK: - Submit

    @objc private func submitFromField() {
        let text = textField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { hide(); return }

        let all = MappingStore.shared.mappings
        let match = all.first { $0.abbreviation.lowercased() == text }
            ?? all.first { $0.displayName.lowercased() == text }

        guard let found = match else {
            shakeTextField()
            window?.makeFirstResponder(textField)
            return
        }
        let path = found.filePath
        hide()
        onSubmit?(path)
    }

    private func shakeTextField() {
        guard let container = window?.contentView?.subviews.first else { return }
        container.wantsLayer = true
        let x = container.frame.origin.x
        let shake = CAKeyframeAnimation(keyPath: "position.x")
        shake.values = [x, x - 8, x + 8, x - 5, x + 5, x]
        shake.duration = 0.35
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        container.layer?.add(shake, forKey: "shake")
        textField.textColor = NSColor.systemRed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.textField.textColor = NSColor.labelColor
        }
    }

    private func submitSelected() {
        guard selectedIndex >= 0, selectedIndex < filteredMappings.count else {
            submitFromField()
            return
        }
        let path = filteredMappings[selectedIndex].filePath
        hide()
        onSubmit?(path)
    }

}

// MARK: - NSTextFieldDelegate

extension InputPopupController: NSTextFieldDelegate {

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.cancelOperation(_:)):
            hide()
            return true

        case #selector(NSResponder.insertTab(_:)),
             #selector(NSResponder.moveDown(_:)):
            let text = textField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
            if !isListVisible {
                showList(filter: text)
            }
            if isListVisible {
                let next = min(selectedIndex + 1, filteredMappings.count - 1)
                selectRow(max(next, 0))
            }
            return true

        case #selector(NSResponder.moveUp(_:)):
            if isListVisible {
                let prev = max(selectedIndex - 1, 0)
                selectRow(prev)
            }
            return true

        case #selector(NSResponder.insertNewline(_:)):
            submitSelected()
            return true

        default:
            return false
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let raw = field.stringValue

        if raw.contains(" ") {
            field.stringValue = raw.replacingOccurrences(of: " ", with: "")
            if isListVisible { submitSelected() } else { submitFromField() }
            return
        }

        let filtered = raw.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        if filtered != raw { field.stringValue = filtered }

        let text = field.stringValue.lowercased()
        if isListVisible { showList(filter: text) }
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension InputPopupController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { filteredMappings.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let mapping = filteredMappings[row]
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: popupWidth - 2, height: rowHeight))

        let abbrLabel = NSTextField(labelWithString: mapping.abbreviation)
        abbrLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        abbrLabel.frame = NSRect(x: 12, y: 5, width: 50, height: 18)
        abbrLabel.textColor = .controlAccentColor

        let nameLabel = NSTextField(labelWithString: mapping.displayName)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.frame = NSRect(x: 66, y: 5, width: popupWidth - 80, height: 18)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.textColor = .labelColor

        cell.addSubview(abbrLabel)
        cell.addSubview(nameLabel)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = NSTableRowView()
        return view
    }
}
