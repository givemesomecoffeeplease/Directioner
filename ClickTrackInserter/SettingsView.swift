//
//  SettingsView.swift
//  ClickTrackInserter
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var store = MappingStore.shared
    @State private var pendingFiles: [PendingMapping] = []
    @State private var showingPending = false
    @State private var editingMapping: Mapping? = nil

    var body: some View {
        VStack(spacing: 0) {
            HotkeySettingsRow()
            Divider()
            // 기존 매핑 목록
            if store.mappings.isEmpty && !showingPending {
                Spacer()
                Text("매핑이 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(store.mappings) { mapping in
                        HStack(spacing: 8) {
                            Text(mapping.abbreviation)
                                .font(.system(.body, design: .monospaced))
                                .bold()
                                .frame(width: 40, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mapping.displayName)
                                Text(mapping.filePath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button { editingMapping = mapping } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            Button { store.delete(mapping) } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // 파일 추가 대기 목록
            if showingPending {
                Divider()
                PendingMappingEditor(pending: $pendingFiles) {
                    // 저장
                    for p in pendingFiles {
                        let abbr = p.abbreviation.trimmingCharacters(in: .whitespaces).lowercased()
                        let name = p.displayName.isEmpty
                            ? URL(fileURLWithPath: p.filePath).deletingPathExtension().lastPathComponent
                            : p.displayName
                        store.add(Mapping(abbreviation: abbr, filePath: p.filePath, displayName: name))
                    }
                    pendingFiles = []
                    showingPending = false
                } onCancel: {
                    pendingFiles = []
                    showingPending = false
                }
            }

            Divider()
            HStack {
                Button(action: pickFiles) {
                    Label("파일 추가", systemImage: "plus")
                }
                Spacer()
                Text("\(store.mappings.count)개")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Button(role: .destructive, action: confirmReset) {
                    Label("초기화", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .disabled(store.mappings.isEmpty)
            }
            .padding(10)
        }
        .frame(width: 540, height: 380)
        .sheet(item: $editingMapping) { mapping in
            MappingEditView(mode: .edit(mapping))
        }
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "모든 매핑 초기화"
        alert.informativeText = "등록된 매핑 \(store.mappings.count)개를 모두 삭제합니다. 되돌릴 수 없습니다."
        alert.addButton(withTitle: "모두 삭제")
        alert.addButton(withTitle: "취소")
        alert.buttons[0].hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.mappings.removeAll()
        store.savePublic()
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            let newEntries = panel.urls.map { url in
                PendingMapping(
                    filePath: url.path,
                    abbreviation: "",
                    displayName: url.deletingPathExtension().lastPathComponent
                )
            }
            pendingFiles.append(contentsOf: newEntries)
            showingPending = true
        }
    }
}

// MARK: - MappingEditView

struct MappingEditView: View {
    let mode: MappingEditMode
    @Environment(\.dismiss) private var dismiss
    @State private var abbreviation = ""
    @State private var filePath = ""
    @State private var displayName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("매핑 편집").font(.headline)

            HStack {
                Text("약어").frame(width: 70, alignment: .trailing)
                TextField("예: v, ch", text: $abbreviation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onChange(of: abbreviation) { val in
                        let f = val.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }.lowercased()
                        if f != val { abbreviation = f }
                    }
            }
            HStack {
                Text("표시 이름").frame(width: 70, alignment: .trailing)
                TextField("예: Verse Click", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("파일 경로").frame(width: 70, alignment: .trailing)
                TextField("/Users/.../file.wav", text: $filePath)
                    .textFieldStyle(.roundedBorder)
                Button("선택...") { pickFile() }
            }
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.escape)
                Button("저장") { save() }
                    .keyboardShortcut(.return)
                    .disabled(abbreviation.isEmpty || filePath.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if case .edit(let m) = mode {
                abbreviation = m.abbreviation
                filePath = m.filePath
                displayName = m.displayName
            }
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        if panel.runModal() == .OK, let url = panel.url {
            filePath = url.path
            if displayName.isEmpty { displayName = url.deletingPathExtension().lastPathComponent }
        }
    }

    private func save() {
        let name = displayName.isEmpty
            ? URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
            : displayName
        guard case .edit(let existing) = mode else { return }
        let abbr = abbreviation.lowercased()

        if let conflict = MappingStore.shared.mappings.first(where: { $0.abbreviation == abbr && $0.id != existing.id }) {
            let alert = NSAlert()
            alert.messageText = "중복된 약어"
            alert.informativeText = "'\(abbr)'은 이미 '\(conflict.displayName)'에 사용 중입니다.\n덮어쓰려면 확인을 누르세요."
            alert.addButton(withTitle: "덮어쓰기")
            alert.addButton(withTitle: "취소")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            MappingStore.shared.delete(conflict)
        }

        MappingStore.shared.update(Mapping(id: existing.id, abbreviation: abbr, filePath: filePath, displayName: name))
        dismiss()
    }
}

enum MappingEditMode { case edit(Mapping) }

// MARK: - 단축키 설정 행

struct HotkeySettingsRow: View {
    @ObservedObject private var hotkeyStore = HotkeyStore.shared
    @State private var isRecording = false
    @State private var recordingTap: CFMachPort? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text("단축키")
                .frame(width: 50, alignment: .trailing)
                .foregroundColor(.secondary)
                .font(.callout)

            Text(isRecording ? "⌨ 키를 누르세요 (ESC 취소)" : hotkeyStore.config.displayString)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 180, alignment: .leading)
                .background(Color(isRecording ? .systemYellow : .controlBackgroundColor).opacity(isRecording ? 0.3 : 1))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(isRecording ? .systemOrange : .separatorColor), lineWidth: 1))
                .animation(.easeInOut(duration: 0.15), value: isRecording)

            Button(isRecording ? "취소" : "변경") {
                if isRecording { stopRecording() } else { startRecording() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func startRecording() {
        isRecording = true
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
                              | (1 << CGEventType.keyDown.rawValue)

        final class Box { var tap: CFMachPort?; var row: HotkeySettingsRow? }
        let box = Box(); box.row = self

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let b = Unmanaged<Box>.fromOpaque(refcon!).takeUnretainedValue()
                DispatchQueue.main.async { b.row?.handleRecordedEvent(type: type, event: event) }
                return nil // 모든 키 소비 (recording 중 오작동 방지)
            },
            userInfo: Unmanaged.passRetained(box).toOpaque()
        )
        guard let tap else { isRecording = false; return }
        recordingTap = tap
        box.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopRecording() {
        if let tap = recordingTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            recordingTap = nil
        }
        isRecording = false
    }

    private func handleRecordedEvent(type: CGEventType, event: CGEvent) {
        let flags = event.flags

        if type == .keyDown {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

            // ESC → 취소
            if keyCode == 53 { stopRecording(); return }

            // 모디파이어 조합 수집
            var mods: [ModifierKey] = []
            if flags.contains(.maskCommand) { mods.append(.command) }
            if flags.contains(.maskControl) { mods.append(.control) }
            if flags.contains(.maskAlternate) { mods.append(.option) }
            if flags.contains(.maskShift) { mods.append(.shift) }

            // 키 레이블
            let label = keyLabel(for: keyCode)
            let config = HotkeyConfig(kind: .combo(modifiers: mods, keyCode: keyCode, keyLabel: label))
            hotkeyStore.config = config
            stopRecording()
            AppDelegate.shared?.hotkeyMonitor.restart()
            return
        }

        if type == .flagsChanged {
            // 모디파이어만 단독으로 눌린 경우 → doubleTap 설정
            let onlyShift   = flags.contains(.maskShift) && !flags.contains(.maskAlternate) && !flags.contains(.maskCommand) && !flags.contains(.maskControl)
            let onlyOption  = flags.contains(.maskAlternate) && !flags.contains(.maskShift) && !flags.contains(.maskCommand) && !flags.contains(.maskControl)
            let onlyCommand = flags.contains(.maskCommand) && !flags.contains(.maskShift) && !flags.contains(.maskAlternate) && !flags.contains(.maskControl)
            let onlyControl = flags.contains(.maskControl) && !flags.contains(.maskShift) && !flags.contains(.maskAlternate) && !flags.contains(.maskCommand)

            let mod: ModifierKey?
            if onlyShift { mod = .shift }
            else if onlyOption { mod = .option }
            else if onlyCommand { mod = .command }
            else if onlyControl { mod = .control }
            else { mod = nil }

            if let mod {
                let config = HotkeyConfig(kind: .doubleTap(mod))
                hotkeyStore.config = config
                stopRecording()
                AppDelegate.shared?.hotkeyMonitor.restart()
            }
        }
    }

    private func keyLabel(for keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            49: "Space", 36: "Return", 48: "Tab", 51: "⌫",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            53: "ESC", 116: "PgUp", 121: "PgDn", 115: "Home", 119: "End",
        ]
        if let label = map[keyCode] { return label }
        // 일반 문자키
        if let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
           let nsEvent = NSEvent(cgEvent: event) {
            let chars = nsEvent.charactersIgnoringModifiers?.uppercased() ?? ""
            if !chars.isEmpty { return chars }
        }
        return "(\(keyCode))"
    }
}

// MARK: - PendingMapping

struct PendingMapping: Identifiable {
    let id = UUID()
    let filePath: String
    var abbreviation: String
    var displayName: String
}

// MARK: - PendingMappingEditor

struct PendingMappingEditor: View {
    @Binding var pending: [PendingMapping]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("약어")
                    .frame(width: 60)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("표시 이름")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("파일")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    ForEach($pending) { $item in
                        HStack(spacing: 8) {
                            TextField("v", text: $item.abbreviation)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: item.abbreviation) { val in
                                    // 영문 소문자만
                                    let filtered = val.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }.lowercased()
                                    if filtered != val { item.abbreviation = filtered }
                                }
                            TextField("표시 이름", text: $item.displayName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                            Text(URL(fileURLWithPath: item.filePath).lastPathComponent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button {
                                pending.removeAll { $0.id == item.id }
                                if pending.isEmpty { onCancel() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 6)
            }

            Divider()
            HStack {
                Button("취소", action: onCancel)
                Spacer()
                Button("저장") { saveWithDuplicateCheck() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 200)
    }

    private func saveWithDuplicateCheck() {
        let existing = Set(MappingStore.shared.mappings.map { $0.abbreviation })
        // 추가하려는 항목끼리 중복 포함
        var seen = Set<String>()
        var duplicates = Set<String>()
        for p in pending {
            let abbr = p.abbreviation.trimmingCharacters(in: .whitespaces).lowercased()
            guard !abbr.isEmpty else { continue }
            if existing.contains(abbr) || seen.contains(abbr) { duplicates.insert(abbr) }
            seen.insert(abbr)
        }
        if !duplicates.isEmpty {
            let list = duplicates.sorted().joined(separator: ", ")
            let alert = NSAlert()
            alert.messageText = "중복된 약어"
            alert.informativeText = "이미 사용 중인 약어입니다: \(list)\n덮어쓰려면 확인을 누르세요."
            alert.addButton(withTitle: "덮어쓰기")
            alert.addButton(withTitle: "취소")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            // 기존 항목 삭제 후 추가
            for abbr in duplicates { MappingStore.shared.mappings.removeAll { $0.abbreviation == abbr } }
        }
        onSave()
    }
}
