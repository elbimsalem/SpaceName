import Foundation

/// Persists user-assigned Space names keyed by the Space's stable `uuid`.
final class SpaceStore {
    private let fileURL: URL
    private var names: [String: String]

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("spaces.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.names = decoded
        } else {
            self.names = [:]
        }
    }

    func name(for uuid: String) -> String? {
        names[uuid]
    }

    func setName(_ name: String?, for uuid: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            names[uuid] = trimmed
        } else {
            names.removeValue(forKey: uuid)
        }
        save()
    }

    func allNames() -> [String: String] { names }

    private func save() {
        guard let data = try? JSONEncoder().encode(names) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Default on-disk location used by the app (not used in tests).
    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SpaceName", isDirectory: true)
    }
}
