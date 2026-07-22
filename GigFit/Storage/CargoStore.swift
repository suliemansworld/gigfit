import Combine
import Foundation

enum CargoStoreError: Error, Equatable, LocalizedError {
    case invalidVehicleScan(String)
    case invalidVehicleProfile(String)
    case invalidPackage(String)
    case vehicleProfileNotFound(UUID)
    case loadSessionNotFound(UUID)
    case packageNotFound(UUID)
    case unsupportedSchemaVersion(Int)
    case readFailed(String)
    case decodeFailed(String)
    case encodeFailed(String)
    case writeFailed(String)
    case assetFailed(PackageAssetStoreError)

    var errorDescription: String? {
        switch self {
        case .invalidVehicleScan(let reason): return "This scan cannot be used as a vehicle: \(reason)"
        case .invalidVehicleProfile(let reason): return "The vehicle profile is invalid: \(reason)"
        case .invalidPackage(let reason): return "The package is invalid: \(reason)"
        case .vehicleProfileNotFound: return "The selected vehicle profile no longer exists."
        case .loadSessionNotFound: return "The selected load session no longer exists."
        case .packageNotFound: return "The selected package no longer exists."
        case .unsupportedSchemaVersion(let version):
            return "Cargo data version \(version) is not supported by this app version."
        case .readFailed(let message): return "Cargo data could not be read: \(message)"
        case .decodeFailed(let message): return "Cargo data could not be decoded: \(message)"
        case .encodeFailed(let message): return "Cargo data could not be encoded: \(message)"
        case .writeFailed(let message): return "Cargo data could not be saved: \(message)"
        case .assetFailed(let error): return error.localizedDescription
        }
    }
}

/// Persists vehicle profiles and live load sessions separately from ScanStore.
/// Mutations are written from local copies and only published after an atomic write.
final class CargoStore: ObservableObject {
    @Published private(set) var vehicleProfiles: [VehicleProfile] = []
    @Published private(set) var loadSessions: [LoadSession] = []
    @Published private(set) var lastError: CargoStoreError?

    let fileURL: URL
    let assetStore: PackageAssetStore

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// A failed read/decode must make this store read-only until a later load
    /// succeeds. Otherwise the next mutation could overwrite recoverable data.
    private var persistenceBlocker: CargoStoreError?

    init(
        fileURL: URL? = nil,
        assetStore: PackageAssetStore? = nil,
        fileManager: FileManager = .default,
        loadImmediately: Bool = true
    ) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.fileURL = fileURL ?? documents.appendingPathComponent("gigfit_cargo_v1.json")
        self.assetStore = assetStore ?? PackageAssetStore(fileManager: fileManager)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()

        if loadImmediately {
            _ = load()
        }
    }

    @discardableResult
    func load() -> Result<Void, CargoStoreError> {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            vehicleProfiles = []
            loadSessions = []
            persistenceBlocker = nil
            lastError = nil
            return .success(())
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            return blockPersistence(.readFailed(error.localizedDescription))
        }

        let stored: CargoStoreData
        do {
            stored = try decoder.decode(CargoStoreData.self, from: data)
        } catch {
            return blockPersistence(.decodeFailed(error.localizedDescription))
        }

        guard stored.schemaVersion == CargoStoreData.currentSchemaVersion else {
            return blockPersistence(.unsupportedSchemaVersion(stored.schemaVersion))
        }

        vehicleProfiles = stored.vehicleProfiles.sorted { $0.updatedAt > $1.updatedAt }
        loadSessions = stored.loadSessions.sorted { $0.updatedAt > $1.updatedAt }
        persistenceBlocker = nil
        lastError = nil
        return .success(())
    }

    func vehicleProfile(id: UUID) -> VehicleProfile? {
        vehicleProfiles.first { $0.id == id }
    }

    func loadSession(id: UUID) -> LoadSession? {
        loadSessions.first { $0.id == id }
    }

    func capacity(for sessionID: UUID) -> CapacitySnapshot? {
        loadSession(id: sessionID).map(CapacityCalculator.calculate(for:))
    }

    /// Creates or refreshes a persistent vehicle profile from a completed scan.
    @discardableResult
    func saveVehicleProfile(
        from scan: ScanSession,
        name: String? = nil
    ) -> Result<VehicleProfile, CargoStoreError> {
        let snapshot: VehicleProfile
        do {
            snapshot = try makeVehicleProfile(from: scan, name: name)
        } catch let error as CargoStoreError {
            return fail(error)
        } catch {
            return fail(.invalidVehicleScan(error.localizedDescription))
        }

        return commit { profiles, _ in
            if let index = profiles.firstIndex(where: { $0.sourceScanID == scan.id }) {
                var updated = snapshot
                updated.id = profiles[index].id
                updated.createdAt = profiles[index].createdAt
                profiles[index] = updated
                return updated
            }
            profiles.append(snapshot)
            return snapshot
        }
    }

    @discardableResult
    func saveVehicleProfile(_ profile: VehicleProfile) -> Result<VehicleProfile, CargoStoreError> {
        guard profile.isValid else {
            return fail(.invalidVehicleProfile("Dimensions and conservative capacity must be positive."))
        }
        let cleanedName = normalizedName(profile.name, fallback: "Vehicle")
        var updated = profile
        updated.name = cleanedName
        updated.updatedAt = Date()

        return commit { profiles, _ in
            if let index = profiles.firstIndex(where: { $0.id == updated.id }) {
                profiles[index] = updated
            } else {
                profiles.append(updated)
            }
            return updated
        }
    }

    @discardableResult
    func deleteVehicleProfile(id: UUID) -> Result<Void, CargoStoreError> {
        commit { profiles, _ in
            guard profiles.contains(where: { $0.id == id }) else {
                throw CargoStoreError.vehicleProfileNotFound(id)
            }
            profiles.removeAll { $0.id == id }
        }
    }

    /// Starts a load directly from a valid scan, creating or refreshing its profile
    /// and embedding that same capacity snapshot in the new session.
    @discardableResult
    func startLoad(
        from scan: ScanSession,
        vehicleName: String? = nil,
        loadName: String? = nil
    ) -> Result<LoadSession, CargoStoreError> {
        let proposedProfile: VehicleProfile
        do {
            proposedProfile = try makeVehicleProfile(from: scan, name: vehicleName)
        } catch let error as CargoStoreError {
            return fail(error)
        } catch {
            return fail(.invalidVehicleScan(error.localizedDescription))
        }

        return commit { profiles, sessions in
            let profile: VehicleProfile
            if let index = profiles.firstIndex(where: { $0.sourceScanID == scan.id }) {
                var refreshed = proposedProfile
                refreshed.id = profiles[index].id
                refreshed.createdAt = profiles[index].createdAt
                profiles[index] = refreshed
                profile = refreshed
            } else {
                profiles.append(proposedProfile)
                profile = proposedProfile
            }

            let session = LoadSession(
                name: normalizedName(loadName, fallback: "Roadie Load"),
                vehicle: profile
            )
            sessions.append(session)
            return session
        }
    }

    @discardableResult
    func startLoad(
        vehicleProfileID: UUID,
        name: String? = nil
    ) -> Result<LoadSession, CargoStoreError> {
        commit { profiles, sessions in
            guard let profile = profiles.first(where: { $0.id == vehicleProfileID }) else {
                throw CargoStoreError.vehicleProfileNotFound(vehicleProfileID)
            }
            let session = LoadSession(
                name: normalizedName(name, fallback: "Roadie Load"),
                vehicle: profile
            )
            sessions.append(session)
            return session
        }
    }

    @discardableResult
    func updateLoadSession(_ session: LoadSession) -> Result<LoadSession, CargoStoreError> {
        guard session.vehicle.isValid else {
            return fail(.invalidVehicleProfile("The embedded capacity snapshot is invalid."))
        }
        guard session.items.allSatisfy(isValidPackage) else {
            return fail(.invalidPackage("A package has invalid dimensions or an empty name."))
        }

        var updated = session
        updated.name = normalizedName(session.name, fallback: "Roadie Load")
        updated.updatedAt = Date()
        return commit { _, sessions in
            guard let index = sessions.firstIndex(where: { $0.id == updated.id }) else {
                throw CargoStoreError.loadSessionNotFound(updated.id)
            }
            sessions[index] = updated
            return updated
        }
    }

    @discardableResult
    func deleteLoadSession(id: UUID) -> Result<Void, CargoStoreError> {
        guard let existing = loadSession(id: id) else {
            return fail(.loadSessionNotFound(id))
        }
        let filenames = existing.items.compactMap(\.screenshotFilename)
        let result: Result<Void, CargoStoreError> = commit { _, sessions in
            sessions.removeAll { $0.id == id }
        }
        guard case .success = result else { return result }
        return cleanupAssets(filenames)
    }

    /// Adds a package and optionally stores selected screenshot bytes in the same flow.
    @discardableResult
    func addPackage(
        to sessionID: UUID,
        name: String,
        notes: String = "",
        dimensions: PackageDimensions? = nil,
        quantity: Int = 1,
        status: PackageStatus = .loaded,
        screenshotData: Data? = nil,
        sourceScanID: UUID? = nil
    ) -> Result<PackageEntry, CargoStoreError> {
        let cleanedName = normalizedName(name, fallback: "Package")
        if let dimensions, !dimensions.isValid {
            return fail(.invalidPackage("Dimensions must be finite positive values."))
        }

        var storedFilename: String?
        if let screenshotData {
            do {
                storedFilename = try assetStore.saveImageData(screenshotData)
            } catch let error as PackageAssetStoreError {
                return fail(.assetFailed(error))
            } catch {
                return fail(.assetFailed(.fileSystem(error.localizedDescription)))
            }
        }

        let package = PackageEntry(
            name: cleanedName,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dimensions: dimensions,
            quantity: quantity,
            status: status,
            screenshotFilename: storedFilename,
            sourceScanID: sourceScanID
        )

        let result: Result<PackageEntry, CargoStoreError> = commit { _, sessions in
            guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) else {
                throw CargoStoreError.loadSessionNotFound(sessionID)
            }
            sessions[sessionIndex].items.append(package)
            sessions[sessionIndex].updatedAt = Date()
            return package
        }

        if case .failure = result, let storedFilename {
            try? assetStore.deleteAsset(named: storedFilename)
        }
        return result
    }

    @discardableResult
    func updatePackage(
        _ package: PackageEntry,
        in sessionID: UUID
    ) -> Result<PackageEntry, CargoStoreError> {
        guard isValidPackage(package) else {
            return fail(.invalidPackage("Name and any supplied dimensions must be valid."))
        }

        var updated = package
        updated.name = normalizedName(package.name, fallback: "Package")
        updated.quantity = max(1, package.quantity)
        updated.updatedAt = Date()

        var oldFilename: String?
        let result: Result<PackageEntry, CargoStoreError> = commit { _, sessions in
            guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) else {
                throw CargoStoreError.loadSessionNotFound(sessionID)
            }
            guard let packageIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == updated.id }) else {
                throw CargoStoreError.packageNotFound(updated.id)
            }
            oldFilename = sessions[sessionIndex].items[packageIndex].screenshotFilename
            sessions[sessionIndex].items[packageIndex] = updated
            sessions[sessionIndex].updatedAt = Date()
            return updated
        }

        if case .success = result,
           let oldFilename,
           oldFilename != updated.screenshotFilename,
           !isAssetReferenced(oldFilename) {
            return cleanupAsset(oldFilename).map { updated }
        }
        return result
    }

    @discardableResult
    func setPackageStatus(
        _ status: PackageStatus,
        packageID: UUID,
        in sessionID: UUID
    ) -> Result<PackageEntry, CargoStoreError> {
        guard var package = loadSession(id: sessionID)?.items.first(where: { $0.id == packageID }) else {
            if loadSession(id: sessionID) == nil { return fail(.loadSessionNotFound(sessionID)) }
            return fail(.packageNotFound(packageID))
        }
        package.status = status
        return updatePackage(package, in: sessionID)
    }

    /// Replaces or removes a package screenshot. New bytes are stored before the JSON
    /// mutation; failed persistence removes the newly-created orphan automatically.
    @discardableResult
    func replacePackageScreenshot(
        packageID: UUID,
        in sessionID: UUID,
        with imageData: Data?
    ) -> Result<PackageEntry, CargoStoreError> {
        guard var package = loadSession(id: sessionID)?.items.first(where: { $0.id == packageID }) else {
            if loadSession(id: sessionID) == nil { return fail(.loadSessionNotFound(sessionID)) }
            return fail(.packageNotFound(packageID))
        }

        let oldFilename = package.screenshotFilename
        var newFilename: String?
        if let imageData {
            do {
                newFilename = try assetStore.saveImageData(imageData)
            } catch let error as PackageAssetStoreError {
                return fail(.assetFailed(error))
            } catch {
                return fail(.assetFailed(.fileSystem(error.localizedDescription)))
            }
        }
        package.screenshotFilename = newFilename

        let result = updatePackage(package, in: sessionID)
        if case .failure = result, let newFilename {
            try? assetStore.deleteAsset(named: newFilename)
            return result
        }
        if case .success = result,
           let oldFilename,
           oldFilename != newFilename,
           !isAssetReferenced(oldFilename) {
            return cleanupAsset(oldFilename).map { package }
        }
        return result
    }

    @discardableResult
    func deletePackage(
        id packageID: UUID,
        from sessionID: UUID
    ) -> Result<Void, CargoStoreError> {
        var filename: String?
        let result: Result<Void, CargoStoreError> = commit { _, sessions in
            guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) else {
                throw CargoStoreError.loadSessionNotFound(sessionID)
            }
            guard let packageIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == packageID }) else {
                throw CargoStoreError.packageNotFound(packageID)
            }
            filename = sessions[sessionIndex].items[packageIndex].screenshotFilename
            sessions[sessionIndex].items.remove(at: packageIndex)
            sessions[sessionIndex].updatedAt = Date()
        }
        guard case .success = result else { return result }
        guard let filename, !isAssetReferenced(filename) else { return .success(()) }
        return cleanupAsset(filename)
    }

    func clearLastError() {
        lastError = nil
    }

    private func makeVehicleProfile(from scan: ScanSession, name: String?) throws -> VehicleProfile {
        guard scan.isComplete else {
            throw CargoStoreError.invalidVehicleScan("The scan must contain all eight boundary points.")
        }
        guard let dimensions = scan.dimensions,
              dimensions.lengthMeters.isFinite, dimensions.lengthMeters > 0,
              dimensions.widthMeters.isFinite, dimensions.widthMeters > 0,
              dimensions.heightMeters.isFinite, dimensions.heightMeters > 0 else {
            throw CargoStoreError.invalidVehicleScan("Positive length, width, and height are required.")
        }

        let resultCapacity = scan.volumeResult?.conservativeCubicMeters ?? 0
        let dimensionCapacity = dimensions.conservativeVolumeCubicMeters
        let capacity = resultCapacity.isFinite && resultCapacity > 0
            ? resultCapacity
            : dimensionCapacity
        guard capacity.isFinite && capacity > 0 else {
            throw CargoStoreError.invalidVehicleScan("A positive conservative volume is required.")
        }

        return VehicleProfile(
            name: normalizedName(name, fallback: normalizedName(scan.name, fallback: "Vehicle")),
            sourceScanID: scan.id,
            dimensions: dimensions,
            conservativeCapacityCubicMeters: capacity
        )
    }

    private func isValidPackage(_ package: PackageEntry) -> Bool {
        let hasName = !package.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let dimensionsAreValid = package.dimensions.map(\.isValid) ?? true
        return hasName && package.quantity >= 1 && dimensionsAreValid
    }

    private func normalizedName(_ proposed: String?, fallback: String) -> String {
        let trimmed = proposed?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func commit<T>(
        _ mutation: (inout [VehicleProfile], inout [LoadSession]) throws -> T
    ) -> Result<T, CargoStoreError> {
        if let persistenceBlocker {
            return fail(persistenceBlocker)
        }

        var nextProfiles = vehicleProfiles
        var nextSessions = loadSessions

        do {
            let value = try mutation(&nextProfiles, &nextSessions)
            try persist(profiles: nextProfiles, sessions: nextSessions)
            vehicleProfiles = nextProfiles.sorted { $0.updatedAt > $1.updatedAt }
            loadSessions = nextSessions.sorted { $0.updatedAt > $1.updatedAt }
            lastError = nil
            return .success(value)
        } catch let error as CargoStoreError {
            return fail(error)
        } catch {
            return fail(.writeFailed(error.localizedDescription))
        }
    }

    private func persist(profiles: [VehicleProfile], sessions: [LoadSession]) throws {
        let stored = CargoStoreData(vehicleProfiles: profiles, loadSessions: sessions)
        let data: Data
        do {
            data = try encoder.encode(stored)
        } catch {
            throw CargoStoreError.encodeFailed(error.localizedDescription)
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw CargoStoreError.writeFailed(error.localizedDescription)
        }
    }

    private func cleanupAssets(_ filenames: [String]) -> Result<Void, CargoStoreError> {
        for filename in Set(filenames) where !isAssetReferenced(filename) {
            let result = cleanupAsset(filename)
            if case .failure = result { return result }
        }
        return .success(())
    }

    private func cleanupAsset(_ filename: String) -> Result<Void, CargoStoreError> {
        do {
            try assetStore.deleteAsset(named: filename)
            return .success(())
        } catch let error as PackageAssetStoreError {
            return fail(.assetFailed(error))
        } catch {
            return fail(.assetFailed(.fileSystem(error.localizedDescription)))
        }
    }

    private func isAssetReferenced(_ filename: String) -> Bool {
        loadSessions.contains { session in
            session.items.contains { $0.screenshotFilename == filename }
        }
    }

    private func fail<T>(_ error: CargoStoreError) -> Result<T, CargoStoreError> {
        lastError = error
        return .failure(error)
    }

    private func blockPersistence<T>(_ error: CargoStoreError) -> Result<T, CargoStoreError> {
        persistenceBlocker = error
        return fail(error)
    }
}
