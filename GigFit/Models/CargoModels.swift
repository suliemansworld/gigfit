import Foundation

/// Box dimensions captured independently from a scan so a package remains usable
/// even if its source scan is later deleted.
struct PackageDimensions: Codable, Equatable, Sendable {
    var lengthMeters: Double
    var widthMeters: Double
    var heightMeters: Double

    init(lengthMeters: Double, widthMeters: Double, heightMeters: Double) {
        self.lengthMeters = lengthMeters
        self.widthMeters = widthMeters
        self.heightMeters = heightMeters
    }

    init(scanDimensions: ScanDimensions) {
        self.init(
            lengthMeters: scanDimensions.lengthMeters,
            widthMeters: scanDimensions.widthMeters,
            heightMeters: scanDimensions.heightMeters
        )
    }

    var rawVolumeCubicMeters: Double {
        guard isValid else { return 0 }
        return lengthMeters * widthMeters * heightMeters
    }

    var isValid: Bool {
        lengthMeters.isFinite && widthMeters.isFinite && heightMeters.isFinite
            && lengthMeters > 0 && widthMeters > 0 && heightMeters > 0
    }
}

/// A reusable vehicle/cargo-space profile. Capacity and dimensions are snapshots,
/// rather than live lookups, so old loads survive deletion of the original scan.
struct VehicleProfile: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var sourceScanID: UUID
    var dimensions: ScanDimensions
    var conservativeCapacityCubicMeters: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sourceScanID: UUID,
        dimensions: ScanDimensions,
        conservativeCapacityCubicMeters: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sourceScanID = sourceScanID
        self.dimensions = dimensions
        self.conservativeCapacityCubicMeters = conservativeCapacityCubicMeters
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isValid: Bool {
        dimensions.lengthMeters.isFinite && dimensions.lengthMeters > 0
            && dimensions.widthMeters.isFinite && dimensions.widthMeters > 0
            && dimensions.heightMeters.isFinite && dimensions.heightMeters > 0
            && conservativeCapacityCubicMeters.isFinite
            && conservativeCapacityCubicMeters > 0
    }
}

enum PackageStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case loaded
    case delivered

    var id: String { rawValue }
    var countsTowardCapacity: Bool { self == .loaded }
}

/// One package line in a live load. Quantity is always normalized to at least one.
/// A screenshot may be attached before dimensions are known; undimensioned entries
/// remain visible in the tally but contribute zero to occupied capacity.
struct PackageEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var notes: String
    var dimensions: PackageDimensions?
    var quantity: Int {
        didSet { quantity = max(1, quantity) }
    }
    var status: PackageStatus
    var screenshotFilename: String?
    var sourceScanID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        dimensions: PackageDimensions? = nil,
        quantity: Int = 1,
        status: PackageStatus = .loaded,
        screenshotFilename: String? = nil,
        sourceScanID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.dimensions = dimensions
        self.quantity = max(1, quantity)
        self.status = status
        self.screenshotFilename = screenshotFilename
        self.sourceScanID = sourceScanID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var rawVolumePerItemCubicMeters: Double {
        dimensions?.rawVolumeCubicMeters ?? 0
    }

    var rawVolumeForQuantityCubicMeters: Double {
        rawVolumePerItemCubicMeters * Double(max(1, quantity))
    }

    var needsDimensions: Bool {
        guard let dimensions else { return true }
        return !dimensions.isValid
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, dimensions, quantity, status, screenshotFilename
        case sourceScanID, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Package"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        dimensions = try container.decodeIfPresent(PackageDimensions.self, forKey: .dimensions)
        quantity = max(1, try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1)
        status = try container.decodeIfPresent(PackageStatus.self, forKey: .status) ?? .loaded
        screenshotFilename = try container.decodeIfPresent(String.self, forKey: .screenshotFilename)
        sourceScanID = try container.decodeIfPresent(UUID.self, forKey: .sourceScanID)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

enum LoadSessionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case completed

    var id: String { rawValue }
}

/// A live Roadie/gig load. It embeds the vehicle snapshot used for its capacity
/// calculation while retaining that profile's persistent identity.
struct LoadSession: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var vehicle: VehicleProfile
    var items: [PackageEntry]
    var status: LoadSessionStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        vehicle: VehicleProfile,
        items: [PackageEntry] = [],
        status: LoadSessionStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.vehicle = vehicle
        self.items = items
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var vehicleProfileID: UUID { vehicle.id }
}

/// Versioned persistence envelope kept separate from `gigfit_scans.json`.
struct CargoStoreData: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var vehicleProfiles: [VehicleProfile]
    var loadSessions: [LoadSession]

    init(
        schemaVersion: Int = CargoStoreData.currentSchemaVersion,
        vehicleProfiles: [VehicleProfile] = [],
        loadSessions: [LoadSession] = []
    ) {
        self.schemaVersion = schemaVersion
        self.vehicleProfiles = vehicleProfiles
        self.loadSessions = loadSessions
    }
}
