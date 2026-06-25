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
