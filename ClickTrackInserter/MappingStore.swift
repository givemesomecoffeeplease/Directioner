//
//  MappingStore.swift
//  ClickTrackInserter
//

import Foundation
import Combine
import SwiftUI

struct Mapping: Identifiable, Codable {
    var id: UUID = UUID()
    var abbreviation: String  // 예: "v", "ch"
    var filePath: String      // 오디오 파일 절대경로
    var displayName: String   // 표시용 이름 (파일명 기본값)
}

class MappingStore: ObservableObject {
    static let shared = MappingStore()

    @Published var mappings: [Mapping] = []

    private let saveKey = "mappings"

    private init() {
        load()
    }

    func filePath(for abbreviation: String) -> String? {
        mappings.first { $0.abbreviation == abbreviation }?.filePath
    }

    func add(_ mapping: Mapping) {
        mappings.append(mapping)
        save()
    }

    func update(_ mapping: Mapping) {
        guard let index = mappings.firstIndex(where: { $0.id == mapping.id }) else { return }
        mappings[index] = mapping
        save()
    }

    func delete(at offsets: IndexSet) {
        mappings.remove(atOffsets: offsets)
        save()
    }

    func delete(_ mapping: Mapping) {
        mappings.removeAll { $0.id == mapping.id }
        save()
    }

    func savePublic() { save() }

    private func save() {
        if let data = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([Mapping].self, from: data)
        else { return }
        mappings = decoded
    }
}

// MARK: - 단축키 설정

enum ModifierKey: String, Codable, CaseIterable, Identifiable {
    case shift, option, command, control

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .shift:   return "⇧"
        case .option:  return "⌥"
        case .command: return "⌘"
        case .control: return "⌃"
        }
    }

    var displayName: String {
        switch self {
        case .shift:   return "Shift"
        case .option:  return "Option"
        case .command: return "Command"
        case .control: return "Control"
        }
    }
}

struct HotkeyConfig: Codable, Equatable {

    enum Kind: Codable, Equatable {
        case doubleTap(ModifierKey)
        case combo(modifiers: [ModifierKey], keyCode: UInt16, keyLabel: String)
    }

    var kind: Kind

    var displayString: String {
        switch kind {
        case .doubleTap(let mod):
            return "\(mod.symbol)\(mod.symbol)  \(mod.displayName) 두 번"
        case .combo(let mods, _, let label):
            return mods.map { $0.symbol }.joined() + label
        }
    }

    static let `default` = HotkeyConfig(kind: .doubleTap(.shift))
}

class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()

    private let udKey = "hotkeyConfig_v1"

    @Published var config: HotkeyConfig {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: udKey),
           let decoded = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            config = decoded
        } else {
            config = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }
}
