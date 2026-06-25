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
