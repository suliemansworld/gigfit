import Foundation

/// Persists scan sessions as JSON in the app's documents directory.
final class ScanStore: ObservableObject {
    @Published var scans: [ScanSession] = []

    private let fileURL: URL

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        loadImmediately: Bool = true
    ) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.fileURL = fileURL ?? documents.appendingPathComponent("gigfit_scans.json")
        if loadImmediately {
            load()
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ScanSession].self, from: data) else {
            scans = []
            return
        }
        scans = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ session: ScanSession) {
        if let idx = scans.firstIndex(where: { $0.id == session.id }) {
            scans[idx] = session
        } else {
            scans.insert(session, at: 0)
        }
        persist()
    }

    func delete(_ session: ScanSession) {
        scans.removeAll { $0.id == session.id }
        persist()
    }

    func deleteAll() {
        scans.removeAll()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(scans) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func scan(by id: UUID) -> ScanSession? {
        scans.first { $0.id == id }
    }
}
