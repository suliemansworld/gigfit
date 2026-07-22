import XCTest
@testable import GigFit

final class PackingSolverTests: XCTestCase {
    private let accuracy = 0.000_001

    func testPackageFitsOnlyAfterAxisRotation() {
        let session = makeSession(
            vehicleLength: 1,
            vehicleWidth: 2,
            vehicleHeight: 1,
            items: [package(name: "Long box", length: 2, width: 1, height: 1)]
        )

        let plan = PackingSolver.solve(session: session)

        XCTAssertTrue(plan.allItemsFit)
        XCTAssertEqual(plan.placedCount, 1)
        XCTAssertEqual(plan.placements[0].size.x, 2, accuracy: accuracy)
        XCTAssertEqual(plan.placements[0].size.z, 1, accuracy: accuracy)
    }

    func testItemCanFailSpatialFitEvenWhenVolumeWouldFit() {
        let session = makeSession(
            vehicleLength: 2,
            vehicleWidth: 2,
            vehicleHeight: 2,
            items: [package(name: "Too long", length: 3, width: 1, height: 1)]
        )

        let plan = PackingSolver.solve(session: session)

        XCTAssertEqual(plan.placements.count, 0)
        XCTAssertEqual(plan.unplacedCount, 1)
        XCTAssertFalse(plan.allItemsFit)
    }

    func testQuantityExpandsWhileDeliveredPackagesAreExcluded() {
        let loaded = package(name: "Cube", length: 1, width: 1, height: 1, quantity: 2)
        let delivered = package(
            name: "Already delivered",
            length: 20,
            width: 20,
            height: 20,
            status: .delivered
        )
        let session = makeSession(
            vehicleLength: 2,
            vehicleWidth: 1,
            vehicleHeight: 1,
            items: [loaded, delivered]
        )

        let plan = PackingSolver.solve(session: session)

        XCTAssertEqual(plan.totalItemCount, 2)
        XCTAssertEqual(plan.placedCount, 2)
        XCTAssertEqual(Set(plan.placements.map(\.item.copyIndex)), Set([0, 1]))
        XCTAssertTrue(plan.allItemsFit)
    }

    func testTwoCubesStackOnSupportedSurfaces() {
        let session = makeSession(
            vehicleLength: 1,
            vehicleWidth: 1,
            vehicleHeight: 2,
            items: [package(name: "Cube", length: 1, width: 1, height: 1, quantity: 2)]
        )

        let plan = PackingSolver.solve(session: session)
        let heights = plan.placements.map(\.position.y).sorted()

        XCTAssertTrue(plan.allItemsFit)
        XCTAssertEqual(heights.count, 2)
        XCTAssertEqual(heights[0], 0, accuracy: accuracy)
        XCTAssertEqual(heights[1], 1, accuracy: accuracy)
    }

    func testPlacementsStayWithinBoundsAndNeverOverlap() {
        let session = makeSession(
            vehicleLength: 2,
            vehicleWidth: 2,
            vehicleHeight: 2,
            items: [
                package(name: "A", length: 1, width: 1, height: 1, quantity: 3),
                package(name: "B", length: 1, width: 2, height: 1),
            ]
        )

        let plan = PackingSolver.solve(session: session)

        XCTAssertTrue(plan.allItemsFit)
        for placement in plan.placements {
            XCTAssertGreaterThanOrEqual(placement.position.x, -accuracy)
            XCTAssertGreaterThanOrEqual(placement.position.y, -accuracy)
            XCTAssertGreaterThanOrEqual(placement.position.z, -accuracy)
            XCTAssertLessThanOrEqual(placement.maxX, plan.container.x + accuracy)
            XCTAssertLessThanOrEqual(placement.maxY, plan.container.y + accuracy)
            XCTAssertLessThanOrEqual(placement.maxZ, plan.container.z + accuracy)
        }
        for leftIndex in plan.placements.indices {
            for rightIndex in plan.placements.indices where rightIndex > leftIndex {
                XCTAssertFalse(overlaps(plan.placements[leftIndex], plan.placements[rightIndex]))
            }
        }
    }

    func testConservativeCapacityUniformlyInsetsPackingEnvelope() throws {
        let vehicle = makeVehicle(length: 4, width: 2, height: 2, capacity: 2)

        let container = try XCTUnwrap(PackingSolver.conservativeContainer(for: vehicle))

        XCTAssertEqual(container.x, 1, accuracy: accuracy)
        XCTAssertEqual(container.y, 1, accuracy: accuracy)
        XCTAssertEqual(container.z, 2, accuracy: accuracy)
        XCTAssertEqual(container.volume, 2, accuracy: accuracy)
    }

    func testAdditionalFitCountUsesRemainingSpatialSlots() {
        let cube = package(name: "Cube", length: 1, width: 1, height: 1)
        let session = makeSession(
            vehicleLength: 2,
            vehicleWidth: 2,
            vehicleHeight: 1,
            items: [cube]
        )
        let dimensions = PackageDimensions(lengthMeters: 1, widthMeters: 1, heightMeters: 1)

        let plan = PackingSolver.solve(session: session)
        let additional = PackingSolver.additionalFitCount(of: dimensions, in: plan, limit: 10)

        XCTAssertEqual(additional, 3)
    }

    func testMobileInstanceCapStillReportsEveryLoadedCopy() {
        let session = makeSession(
            vehicleLength: 1,
            vehicleWidth: 1,
            vehicleHeight: 1,
            items: [package(name: "Oversized", length: 2, width: 2, height: 2, quantity: 80)]
        )

        let plan = PackingSolver.solve(session: session)

        XCTAssertEqual(plan.placements.count, 0)
        XCTAssertEqual(plan.unplacedItems.count, PackingSolver.maximumPackedInstances)
        XCTAssertEqual(plan.truncatedItemCount, 8)
        XCTAssertEqual(plan.totalItemCount, 80)
        XCTAssertEqual(plan.unplacedCount, 80)
    }

    func testInvalidLoadedDimensionsAreReportedButDeliveredInvalidEntryIsIgnored() {
        let invalidLoaded = PackageEntry(name: "Unknown loaded box", dimensions: nil, quantity: 2)
        let invalidDelivered = PackageEntry(
            name: "Unknown delivered box",
            dimensions: nil,
            quantity: 4,
            status: .delivered
        )
        let session = makeSession(
            vehicleLength: 2,
            vehicleWidth: 2,
            vehicleHeight: 2,
            items: [invalidLoaded, invalidDelivered]
        )

        let plan = PackingSolver.solve(session: session)

        XCTAssertEqual(plan.invalidItemCount, 2)
        XCTAssertEqual(plan.totalItemCount, 2)
        XCTAssertFalse(plan.allItemsFit)
    }

    func testSameVariantProducesIdenticalPlan() {
        let session = makeSession(
            vehicleLength: 3,
            vehicleWidth: 2,
            vehicleHeight: 2,
            items: [
                package(name: "Large", length: 2, width: 1, height: 1),
                package(name: "Small", length: 1, width: 1, height: 1, quantity: 3),
            ]
        )

        XCTAssertEqual(
            PackingSolver.solve(session: session, variant: 5),
            PackingSolver.solve(session: session, variant: 5)
        )
    }

    private func makeSession(
        vehicleLength: Double,
        vehicleWidth: Double,
        vehicleHeight: Double,
        items: [PackageEntry]
    ) -> LoadSession {
        let vehicle = makeVehicle(
            length: vehicleLength,
            width: vehicleWidth,
            height: vehicleHeight,
            capacity: vehicleLength * vehicleWidth * vehicleHeight
        )
        return LoadSession(name: "Packing test", vehicle: vehicle, items: items)
    }

    private func makeVehicle(
        length: Double,
        width: Double,
        height: Double,
        capacity: Double
    ) -> VehicleProfile {
        VehicleProfile(
            name: "Test vehicle",
            sourceScanID: UUID(),
            dimensions: ScanDimensions(
                lengthMeters: length,
                widthMeters: width,
                heightMeters: height,
                rawVolumeCubicMeters: length * width * height,
                conservativeVolumeCubicMeters: capacity
            ),
            conservativeCapacityCubicMeters: capacity
        )
    }

    private func package(
        name: String,
        length: Double,
        width: Double,
        height: Double,
        quantity: Int = 1,
        status: PackageStatus = .loaded
    ) -> PackageEntry {
        PackageEntry(
            name: name,
            dimensions: PackageDimensions(
                lengthMeters: length,
                widthMeters: width,
                heightMeters: height
            ),
            quantity: quantity,
            status: status
        )
    }

    private func overlaps(_ left: PackingPlacement, _ right: PackingPlacement) -> Bool {
        left.position.x < right.maxX - accuracy
            && left.maxX > right.position.x + accuracy
            && left.position.y < right.maxY - accuracy
            && left.maxY > right.position.y + accuracy
            && left.position.z < right.maxZ - accuracy
            && left.maxZ > right.position.z + accuracy
    }
}
