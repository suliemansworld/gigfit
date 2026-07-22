import UIKit
import XCTest
@testable import GigFit

final class CargoLoadTests: XCTestCase {
    private let accuracy = 0.000_001

    func testThirtySixPercentOccupiedLeavesExactlySixtyFourPercentRemaining() {
        let package = PackageEntry(
            name: "Roadie package",
            dimensions: PackageDimensions(lengthMeters: 3, widthMeters: 3, heightMeters: 4)
        )

        let snapshot = CapacityCalculator.calculate(
            conservativeCapacityCubicMeters: 100,
            items: [package]
        )

        XCTAssertTrue(snapshot.hasValidCapacity)
        XCTAssertEqual(snapshot.capacityCubicMeters, 100, accuracy: accuracy)
        XCTAssertEqual(snapshot.occupiedCubicMeters, 36, accuracy: accuracy)
        XCTAssertEqual(snapshot.utilizationPercent, 36, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingCubicMeters, 64, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 64, accuracy: accuracy)
        XCTAssertEqual(snapshot.overCapacityCubicMeters, 0, accuracy: accuracy)
        XCTAssertFalse(snapshot.isOverCapacity)
    }

    func testEmptyLoadLeavesAllCapacityAvailable() {
        let snapshot = CapacityCalculator.calculate(
            conservativeCapacityCubicMeters: 25,
            items: []
        )

        XCTAssertTrue(snapshot.hasValidCapacity)
        XCTAssertEqual(snapshot.occupiedCubicMeters, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.utilizationPercent, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingCubicMeters, 25, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 100, accuracy: accuracy)
        XCTAssertFalse(snapshot.isOverCapacity)
    }

    func testPackageQuantityMultipliesOccupiedVolume() {
        let package = PackageEntry(
            name: "Four boxes",
            dimensions: PackageDimensions(lengthMeters: 1, widthMeters: 2, heightMeters: 3),
            quantity: 4
        )

        let snapshot = CapacityCalculator.calculate(
            conservativeCapacityCubicMeters: 100,
            items: [package]
        )

        XCTAssertEqual(package.rawVolumePerItemCubicMeters, 6, accuracy: accuracy)
        XCTAssertEqual(package.rawVolumeForQuantityCubicMeters, 24, accuracy: accuracy)
        XCTAssertEqual(snapshot.occupiedCubicMeters, 24, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 76, accuracy: accuracy)
    }

    func testDeliveredStatusAndPackageRemovalRestoreCapacityThroughCargoStore() throws {
        let root = temporaryDirectory(named: "delivery-removal")
        defer { try? FileManager.default.removeItem(at: root) }

        let assetStore = PackageAssetStore(
            directoryURL: root.appendingPathComponent("assets", isDirectory: true)
        )
        let store = CargoStore(
            fileURL: root.appendingPathComponent("cargo.json"),
            assetStore: assetStore,
            loadImmediately: false
        )
        let profile = makeVehicleProfile(capacity: 100)
        let savedProfile = try store.saveVehicleProfile(profile).get()
        let session = try store.startLoad(vehicleProfileID: savedProfile.id, name: "Roadie route").get()
        let package = try store.addPackage(
            to: session.id,
            name: "Twenty percent package",
            dimensions: PackageDimensions(lengthMeters: 2, widthMeters: 2, heightMeters: 5)
        ).get()

        var snapshot = try XCTUnwrap(store.capacity(for: session.id))
        XCTAssertEqual(snapshot.occupiedCubicMeters, 20, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 80, accuracy: accuracy)

        _ = try store.setPackageStatus(.delivered, packageID: package.id, in: session.id).get()
        snapshot = try XCTUnwrap(store.capacity(for: session.id))
        XCTAssertEqual(snapshot.occupiedCubicMeters, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 100, accuracy: accuracy)

        _ = try store.setPackageStatus(.loaded, packageID: package.id, in: session.id).get()
        snapshot = try XCTUnwrap(store.capacity(for: session.id))
        XCTAssertEqual(snapshot.occupiedCubicMeters, 20, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 80, accuracy: accuracy)

        try store.deletePackage(id: package.id, from: session.id).get()
        snapshot = try XCTUnwrap(store.capacity(for: session.id))
        XCTAssertEqual(snapshot.occupiedCubicMeters, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingCubicMeters, 100, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 100, accuracy: accuracy)
    }

    func testOverCapacityClampsRemainingButPreservesOverage() {
        let package = PackageEntry(
            name: "Oversized package",
            dimensions: PackageDimensions(lengthMeters: 2, widthMeters: 2, heightMeters: 3)
        )

        let snapshot = CapacityCalculator.calculate(
            conservativeCapacityCubicMeters: 10,
            items: [package]
        )

        XCTAssertEqual(snapshot.occupiedCubicMeters, 12, accuracy: accuracy)
        XCTAssertEqual(snapshot.utilizationPercent, 120, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingCubicMeters, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.overCapacityCubicMeters, 2, accuracy: accuracy)
        XCTAssertTrue(snapshot.isOverCapacity)
    }

    func testZeroCapacityIsSafeAndPreservesOccupiedOverage() {
        let package = PackageEntry(
            name: "Package",
            dimensions: PackageDimensions(lengthMeters: 1, widthMeters: 1, heightMeters: 2)
        )

        let snapshot = CapacityCalculator.calculate(
            conservativeCapacityCubicMeters: 0,
            items: [package]
        )

        XCTAssertFalse(snapshot.hasValidCapacity)
        XCTAssertEqual(snapshot.capacityCubicMeters, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.occupiedCubicMeters, 2, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingCubicMeters, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.utilizationPercent, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.remainingPercent, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.overCapacityCubicMeters, 2, accuracy: accuracy)
        XCTAssertTrue(snapshot.utilizationPercent.isFinite)
        XCTAssertTrue(snapshot.remainingPercent.isFinite)
    }

    func testCargoModelsRoundTripInsideVersionedJSONEnvelope() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let vehicle = VehicleProfile(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Cargo van",
            sourceScanID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            dimensions: ScanDimensions(
                lengthMeters: 4,
                widthMeters: 2,
                heightMeters: 2,
                rawVolumeCubicMeters: 16,
                conservativeVolumeCubicMeters: 15
            ),
            conservativeCapacityCubicMeters: 15,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let package = PackageEntry(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            name: "Roadie stop 4",
            dimensions: PackageDimensions(lengthMeters: 1, widthMeters: 0.5, heightMeters: 0.25),
            quantity: 3,
            status: .delivered,
            screenshotFilename: "package_dddddddd-dddd-dddd-dddd-dddddddddddd.jpg",
            sourceScanID: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let session = LoadSession(
            id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
            name: "Tuesday route",
            vehicle: vehicle,
            items: [package],
            status: .completed,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let original = CargoStoreData(
            vehicleProfiles: [vehicle],
            loadSessions: [session]
        )

        let data = try JSONEncoder().encode(original)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, CargoStoreData.currentSchemaVersion)

        let decoded = try JSONDecoder().decode(CargoStoreData.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, CargoStoreData.currentSchemaVersion)
        XCTAssertEqual(decoded, original)
    }

    func testUnsupportedCargoSchemaCannotBeOverwrittenByMutation() throws {
        let root = temporaryDirectory(named: "future-schema")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("cargo.json")
        let originalData = try XCTUnwrap(
            "{\"schemaVersion\":999,\"vehicleProfiles\":[],\"loadSessions\":[]}".data(using: .utf8)
        )
        try originalData.write(to: fileURL)

        let store = CargoStore(fileURL: fileURL)
        XCTAssertEqual(store.lastError, .unsupportedSchemaVersion(999))

        let result = store.saveVehicleProfile(makeVehicleProfile(capacity: 10))
        switch result {
        case .success:
            XCTFail("A store with a newer schema must stay read-only")
        case .failure(let error):
            XCTAssertEqual(error, .unsupportedSchemaVersion(999))
        }
        XCTAssertEqual(try Data(contentsOf: fileURL), originalData)
    }

    func testRenamedScanReplacesExistingRecordAndPersists() throws {
        let root = temporaryDirectory(named: "scan-rename")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("scans.json")
        let store = ScanStore(fileURL: fileURL, loadImmediately: false)
        var scan = ScanSession(name: "Cargo Scan")

        store.save(scan)
        scan.name = "Honda CR-V trunk"
        store.save(scan)

        XCTAssertEqual(store.scans.count, 1)
        XCTAssertEqual(store.scan(by: scan.id)?.name, "Honda CR-V trunk")

        let reloaded = ScanStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.scans.count, 1)
        XCTAssertEqual(reloaded.scan(by: scan.id)?.name, "Honda CR-V trunk")
    }

    func testRenamedScanRefreshesReusableVehicleWithoutRewritingExistingLoad() throws {
        let root = temporaryDirectory(named: "vehicle-rename")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CargoStore(
            fileURL: root.appendingPathComponent("cargo.json"),
            assetStore: PackageAssetStore(directoryURL: root.appendingPathComponent("assets")),
            loadImmediately: false
        )
        var scan = makeCompleteScan(name: "Cargo Scan")
        let originalProfile = try store.saveVehicleProfile(from: scan).get()
        let existingLoad = try store.startLoad(
            vehicleProfileID: originalProfile.id,
            name: "Existing route"
        ).get()

        scan.name = "Sprinter rear cargo"
        let refreshedProfile = try store.saveVehicleProfile(from: scan, name: scan.name).get()

        XCTAssertEqual(refreshedProfile.id, originalProfile.id)
        XCTAssertEqual(store.vehicleProfile(id: originalProfile.id)?.name, "Sprinter rear cargo")
        XCTAssertEqual(store.loadSession(id: existingLoad.id)?.vehicle.name, "Cargo Scan")

        let reloaded = CargoStore(
            fileURL: store.fileURL,
            assetStore: store.assetStore
        )
        XCTAssertEqual(reloaded.vehicleProfile(id: originalProfile.id)?.name, "Sprinter rear cargo")
        XCTAssertEqual(reloaded.loadSession(id: existingLoad.id)?.vehicle.name, "Cargo Scan")
    }

    func testPackageAssetStoreSavesReadsAndDeletesValidImageInInjectedDirectory() throws {
        let root = temporaryDirectory(named: "valid-image")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = PackageAssetStore(
            directoryURL: root,
            maxOutputPixelDimension: 64,
            jpegQuality: 0.8
        )
        let inputData = try makePNGData()

        let filename = try store.saveImageData(inputData)
        XCTAssertTrue(filename.hasPrefix("package_"))
        XCTAssertTrue(filename.hasSuffix(".jpg"))
        XCTAssertTrue(store.containsAsset(named: filename))

        let storedData = try store.imageData(for: filename)
        XCTAssertFalse(storedData.isEmpty)
        let storedImage = try XCTUnwrap(UIImage(data: storedData))
        XCTAssertLessThanOrEqual(max(storedImage.size.width, storedImage.size.height), 64)

        try store.deleteAsset(named: filename)
        XCTAssertFalse(store.containsAsset(named: filename))
        XCTAssertThrowsError(try store.imageData(for: filename)) { error in
            XCTAssertEqual(error as? PackageAssetStoreError, .assetNotFound)
        }
    }

    func testPackageAssetStoreRejectsEmptyAndInvalidImageData() {
        let root = temporaryDirectory(named: "invalid-image")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PackageAssetStore(directoryURL: root)

        XCTAssertThrowsError(try store.saveImageData(Data())) { error in
            XCTAssertEqual(error as? PackageAssetStoreError, .emptyData)
        }
        XCTAssertThrowsError(try store.saveImageData(Data("not an image".utf8))) { error in
            XCTAssertEqual(error as? PackageAssetStoreError, .invalidImage)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    private func makeVehicleProfile(capacity: Double) -> VehicleProfile {
        VehicleProfile(
            name: "Test van",
            sourceScanID: UUID(),
            dimensions: ScanDimensions(
                lengthMeters: 5,
                widthMeters: 2,
                heightMeters: 2,
                rawVolumeCubicMeters: 20,
                conservativeVolumeCubicMeters: capacity
            ),
            conservativeCapacityCubicMeters: capacity
        )
    }

    private func makeCompleteScan(name: String) -> ScanSession {
        var scan = ScanSession(name: name)
        for (index, label) in ScanPointLabel.allCases.enumerated() {
            scan.upsertPoint(
                label: label,
                position: SIMD3<Float>(Float(index), 0, 0),
                source: .existingPlaneGeometry
            )
        }
        scan.dimensions = ScanDimensions(
            lengthMeters: 3,
            widthMeters: 2,
            heightMeters: 1.5,
            rawVolumeCubicMeters: 9,
            conservativeVolumeCubicMeters: 8
        )
        scan.volumeResult = ScanSession.VolumeResultData(
            rawCubicMeters: 9,
            conservativeCubicMeters: 8,
            hasNegativeTetrahedra: false
        )
        return scan
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CargoLoadTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private func makePNGData() throws -> Data {
        let size = CGSize(width: 120, height: 80)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        return try XCTUnwrap(image.pngData())
    }
}
