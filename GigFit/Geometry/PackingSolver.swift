import Foundation

/// Axis-aligned size in the packing coordinate system:
/// x = vehicle width (left to right), y = height (floor up),
/// z = vehicle length (rear cargo door toward the front seats).
struct PackingSize3D: Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
    let z: Double

    var volume: Double {
        guard isValid else { return 0 }
        return x * y * z
    }

    var isValid: Bool {
        x.isFinite && y.isFinite && z.isFinite && x > 0 && y > 0 && z > 0
    }

    var longestEdge: Double { max(x, max(y, z)) }
    var footprint: Double { x * z }
}

struct PackingPosition3D: Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
    let z: Double
}

struct PackingItemInstance: Identifiable, Equatable, Hashable, Sendable {
    let packageID: UUID
    let packageName: String
    /// Zero-based index within the package entry's quantity.
    let copyIndex: Int
    let copyCount: Int
    /// Natural package orientation: width × height × length.
    let originalSize: PackingSize3D

    var id: String { "\(packageID.uuidString)-\(copyIndex)" }

    var displayName: String {
        copyCount > 1 ? "\(packageName) \(copyIndex + 1)" : packageName
    }
}

struct PackingPlacement: Identifiable, Equatable, Hashable, Sendable {
    let item: PackingItemInstance
    let position: PackingPosition3D
    let size: PackingSize3D

    var id: String { item.id }
    var maxX: Double { position.x + size.x }
    var maxY: Double { position.y + size.y }
    var maxZ: Double { position.z + size.z }
}

struct PackingPlan: Equatable, Sendable {
    let container: PackingSize3D
    let placements: [PackingPlacement]
    let unplacedItems: [PackingItemInstance]
    let invalidItemCount: Int
    let truncatedItemCount: Int
    let hasValidContainer: Bool
    let variant: Int

    var totalItemCount: Int {
        placements.count + unplacedItems.count + invalidItemCount + truncatedItemCount
    }
    var placedCount: Int { placements.count }
    var unplacedCount: Int { unplacedItems.count + invalidItemCount + truncatedItemCount }
    var allItemsFit: Bool {
        hasValidContainer && unplacedItems.isEmpty && invalidItemCount == 0 && truncatedItemCount == 0
    }
    var isEmpty: Bool { totalItemCount == 0 }
    var placedVolumeCubicMeters: Double { placements.reduce(0) { $0 + $1.size.volume } }
    var spatialUtilizationPercent: Double {
        guard container.volume > 0 else { return 0 }
        return min(100, max(0, placedVolumeCubicMeters / container.volume * 100))
    }
}

/// A bounded extreme-point bin-packing heuristic intended for fast, local iPhone use.
/// It tries several deterministic item orderings and all unique 90-degree rotations,
/// then keeps the best plan found. It does not claim exhaustive mathematical optimality.
enum PackingSolver {
    static let maximumPackedInstances = 72
    static let layoutVariantCount = 12
    private static let maximumCandidatePoints = 256
    private static let epsilon = 0.000_001
    private static let minimumSupportRatio = 0.8

    static func solve(session: LoadSession, variant: Int = 0) -> PackingPlan {
        let expansion = expandItems(from: session)
        guard let container = conservativeContainer(for: session.vehicle) else {
            return PackingPlan(
                container: PackingSize3D(x: 0, y: 0, z: 0),
                placements: [],
                unplacedItems: expansion.items,
                invalidItemCount: expansion.invalidCount,
                truncatedItemCount: expansion.truncatedCount,
                hasValidContainer: false,
                variant: variant
            )
        }

        guard !expansion.items.isEmpty else {
            return PackingPlan(
                container: container,
                placements: [],
                unplacedItems: [],
                invalidItemCount: expansion.invalidCount,
                truncatedItemCount: expansion.truncatedCount,
                hasValidContainer: true,
                variant: variant
            )
        }

        let normalizedVariant = positiveModulo(variant, layoutVariantCount)
        var candidates: [WorkingPlan] = []
        for offset in 0..<4 {
            let heuristic = positiveModulo(normalizedVariant + offset, 4)
            candidates.append(
                pack(
                    expansion.items,
                    in: container,
                    heuristic: heuristic,
                    variant: normalizedVariant
                )
            )
        }

        let bestScore = candidates.map(score).max() ?? SolutionScore.zero
        let equallyBest = candidates.filter { score($0) == bestScore }
        let chosen = equallyBest[positiveModulo(normalizedVariant, max(1, equallyBest.count))]

        return PackingPlan(
            container: container,
            placements: chosen.placements,
            unplacedItems: chosen.unplaced,
            invalidItemCount: expansion.invalidCount,
            truncatedItemCount: expansion.truncatedCount,
            hasValidContainer: true,
            variant: variant
        )
    }

    /// Counts copies that the selected best-found plan can additionally place.
    /// Copies are fitted incrementally so the result stays bounded and responsive;
    /// a zero means this heuristic found no placement, not that none can exist.
    static func additionalFitCount(
        of dimensions: PackageDimensions,
        in plan: PackingPlan,
        limit: Int = 100
    ) -> Int {
        guard dimensions.isValid, limit > 0 else { return 0 }
        guard plan.allItemsFit else { return 0 }

        let roomUnderMobileCap = max(0, maximumPackedInstances - plan.placements.count)
        let boundedLimit = min(limit, roomUnderMobileCap)
        guard boundedLimit > 0 else { return 0 }

        var placements = plan.placements
        var points = candidatePoints(from: placements, in: plan.container)
        let baseSize = packingSize(from: dimensions)
        let syntheticID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        var count = 0

        for copyIndex in 0..<boundedLimit {
            let item = PackingItemInstance(
                packageID: syntheticID,
                packageName: "Additional package",
                copyIndex: copyIndex,
                copyCount: boundedLimit,
                originalSize: baseSize
            )
            guard let placement = bestPlacement(
                for: item,
                points: points,
                existing: placements,
                container: plan.container,
                variant: plan.variant + copyIndex
            ) else {
                break
            }
            placements.append(placement)
            points = updatedCandidatePoints(points, after: placement, placements: placements, container: plan.container)
            count += 1
        }
        return count
    }

    /// Converts a measured vehicle into a conservative rectangular packing envelope.
    /// The three axes are uniformly inset so their product never exceeds the saved
    /// conservative capacity. Irregular trim and wheel wells remain outside this model.
    static func conservativeContainer(for vehicle: VehicleProfile) -> PackingSize3D? {
        let dimensions = vehicle.dimensions
        let measured = PackingSize3D(
            x: dimensions.widthMeters,
            y: dimensions.heightMeters,
            z: dimensions.lengthMeters
        )
        guard measured.isValid,
              vehicle.conservativeCapacityCubicMeters.isFinite,
              vehicle.conservativeCapacityCubicMeters > 0 else {
            return nil
        }

        let targetVolume = min(measured.volume, vehicle.conservativeCapacityCubicMeters)
        guard targetVolume > 0 else { return nil }
        let scale = pow(targetVolume / measured.volume, 1.0 / 3.0)
        return PackingSize3D(
            x: measured.x * scale,
            y: measured.y * scale,
            z: measured.z * scale
        )
    }

    private struct Expansion {
        var items: [PackingItemInstance]
        var invalidCount: Int
        var truncatedCount: Int
    }

    private struct WorkingPlan {
        var placements: [PackingPlacement]
        var unplaced: [PackingItemInstance]
    }

    private struct SolutionScore: Equatable, Comparable {
        let placedCount: Int
        let placedVolume: Double
        let negativeUsedHeight: Double
        let negativeUsedDepth: Double

        static let zero = SolutionScore(
            placedCount: 0,
            placedVolume: 0,
            negativeUsedHeight: 0,
            negativeUsedDepth: 0
        )

        static func < (lhs: SolutionScore, rhs: SolutionScore) -> Bool {
            if lhs.placedCount != rhs.placedCount { return lhs.placedCount < rhs.placedCount }
            if lhs.placedVolume != rhs.placedVolume {
                return lhs.placedVolume < rhs.placedVolume
            }
            if lhs.negativeUsedHeight != rhs.negativeUsedHeight {
                return lhs.negativeUsedHeight < rhs.negativeUsedHeight
            }
            return lhs.negativeUsedDepth < rhs.negativeUsedDepth
        }
    }

    private static func expandItems(from session: LoadSession) -> Expansion {
        var result: [PackingItemInstance] = []
        var invalidCount = 0
        var truncatedCount = 0

        for package in session.items where package.status.countsTowardCapacity {
            let quantity = max(1, package.quantity)
            guard let dimensions = package.dimensions, dimensions.isValid else {
                invalidCount += quantity
                continue
            }
            let size = packingSize(from: dimensions)
            for copyIndex in 0..<quantity {
                guard result.count < maximumPackedInstances else {
                    truncatedCount += quantity - copyIndex
                    break
                }
                result.append(
                    PackingItemInstance(
                        packageID: package.id,
                        packageName: package.name,
                        copyIndex: copyIndex,
                        copyCount: quantity,
                        originalSize: size
                    )
                )
            }
        }
        return Expansion(items: result, invalidCount: invalidCount, truncatedCount: truncatedCount)
    }

    private static func packingSize(from dimensions: PackageDimensions) -> PackingSize3D {
        PackingSize3D(
            x: dimensions.widthMeters,
            y: dimensions.heightMeters,
            z: dimensions.lengthMeters
        )
    }

    private static func pack(
        _ items: [PackingItemInstance],
        in container: PackingSize3D,
        heuristic: Int,
        variant: Int
    ) -> WorkingPlan {
        let ordered = order(items, heuristic: heuristic, variant: variant)
        var placements: [PackingPlacement] = []
        var unplaced: [PackingItemInstance] = []
        var points = [PackingPosition3D(x: 0, y: 0, z: 0)]

        for (index, item) in ordered.enumerated() {
            if let placement = bestPlacement(
                for: item,
                points: points,
                existing: placements,
                container: container,
                variant: variant + index + heuristic
            ) {
                placements.append(placement)
                points = updatedCandidatePoints(
                    points,
                    after: placement,
                    placements: placements,
                    container: container
                )
            } else {
                unplaced.append(item)
            }
        }
        return WorkingPlan(placements: placements, unplaced: unplaced)
    }

    private static func order(
        _ items: [PackingItemInstance],
        heuristic: Int,
        variant: Int
    ) -> [PackingItemInstance] {
        items.sorted { left, right in
            let leftMetric: (Double, Double)
            let rightMetric: (Double, Double)
            switch heuristic {
            case 1:
                leftMetric = (left.originalSize.longestEdge, left.originalSize.volume)
                rightMetric = (right.originalSize.longestEdge, right.originalSize.volume)
            case 2:
                leftMetric = (left.originalSize.footprint, left.originalSize.volume)
                rightMetric = (right.originalSize.footprint, right.originalSize.volume)
            case 3:
                let leftShortest = min(left.originalSize.x, min(left.originalSize.y, left.originalSize.z))
                let rightShortest = min(right.originalSize.x, min(right.originalSize.y, right.originalSize.z))
                leftMetric = (leftShortest, left.originalSize.volume)
                rightMetric = (rightShortest, right.originalSize.volume)
            default:
                leftMetric = (left.originalSize.volume, left.originalSize.longestEdge)
                rightMetric = (right.originalSize.volume, right.originalSize.longestEdge)
            }

            if leftMetric.0 != rightMetric.0 { return leftMetric.0 > rightMetric.0 }
            if leftMetric.1 != rightMetric.1 { return leftMetric.1 > rightMetric.1 }
            if left.packageName != right.packageName {
                return positiveModulo(variant, 2) == 0
                    ? left.packageName < right.packageName
                    : left.packageName > right.packageName
            }
            if left.packageID != right.packageID {
                return left.packageID.uuidString < right.packageID.uuidString
            }
            return left.copyIndex < right.copyIndex
        }
    }

    private static func bestPlacement(
        for item: PackingItemInstance,
        points: [PackingPosition3D],
        existing: [PackingPlacement],
        container: PackingSize3D,
        variant: Int
    ) -> PackingPlacement? {
        let orientations = rotated(uniqueOrientations(of: item.originalSize), by: variant)
        let sortedPoints = points.sorted { candidatePointComesFirst($0, $1, variant: variant) }
        var best: (placement: PackingPlacement, orientationRank: Int)?

        for (orientationIndex, orientation) in orientations.enumerated() {
            for point in sortedPoints {
                var positions = [point]
                if positiveModulo(variant, 2) == 1 {
                    positions.append(
                        PackingPosition3D(
                            x: max(0, container.x - orientation.x),
                            y: point.y,
                            z: point.z
                        )
                    )
                }

                for position in positions {
                    let proposed = PackingPlacement(item: item, position: position, size: orientation)
                    guard isWithinBounds(proposed, container: container),
                          !existing.contains(where: { overlaps(proposed, $0) }),
                          supportRatio(for: proposed, on: existing) >= minimumSupportRatio else {
                        continue
                    }

                    guard let current = best else {
                        best = (proposed, orientationIndex)
                        continue
                    }
                    if placementComesFirst(
                        proposed,
                        orientationIndex: orientationIndex,
                        before: current.placement,
                        currentOrientationIndex: current.orientationRank,
                        variant: variant
                    ) {
                        best = (proposed, orientationIndex)
                    }
                }
            }
        }
        return best?.placement
    }

    private static func uniqueOrientations(of size: PackingSize3D) -> [PackingSize3D] {
        let candidates = [
            PackingSize3D(x: size.x, y: size.y, z: size.z),
            PackingSize3D(x: size.x, y: size.z, z: size.y),
            PackingSize3D(x: size.y, y: size.x, z: size.z),
            PackingSize3D(x: size.y, y: size.z, z: size.x),
            PackingSize3D(x: size.z, y: size.x, z: size.y),
            PackingSize3D(x: size.z, y: size.y, z: size.x),
        ]
        var unique: [PackingSize3D] = []
        for candidate in candidates where !unique.contains(where: { approximatelyEqual($0, candidate) }) {
            unique.append(candidate)
        }
        return unique
    }

    private static func rotated<T>(_ values: [T], by amount: Int) -> [T] {
        guard !values.isEmpty else { return values }
        let offset = positiveModulo(amount, values.count)
        return Array(values[offset...] + values[..<offset])
    }

    private static func candidatePointComesFirst(
        _ left: PackingPosition3D,
        _ right: PackingPosition3D,
        variant: Int
    ) -> Bool {
        if left.y != right.y { return left.y < right.y }
        if positiveModulo(variant, 3) == 1 {
            if left.x != right.x { return left.x < right.x }
            if left.z != right.z { return left.z < right.z }
        } else {
            if left.z != right.z { return left.z < right.z }
            if left.x != right.x { return left.x < right.x }
        }
        return false
    }

    private static func placementComesFirst(
        _ proposed: PackingPlacement,
        orientationIndex: Int,
        before current: PackingPlacement,
        currentOrientationIndex: Int,
        variant: Int
    ) -> Bool {
        if abs(proposed.position.y - current.position.y) > epsilon {
            return proposed.position.y < current.position.y
        }
        let proposedSupport = proposed.position.y <= epsilon ? 1 : proposed.size.footprint
        let currentSupport = current.position.y <= epsilon ? 1 : current.size.footprint
        if abs(proposedSupport - currentSupport) > epsilon { return proposedSupport > currentSupport }

        if positiveModulo(variant, 3) == 1 {
            if abs(proposed.position.x - current.position.x) > epsilon {
                return proposed.position.x < current.position.x
            }
            if abs(proposed.position.z - current.position.z) > epsilon {
                return proposed.position.z < current.position.z
            }
        } else {
            if abs(proposed.position.z - current.position.z) > epsilon {
                return proposed.position.z < current.position.z
            }
            if abs(proposed.position.x - current.position.x) > epsilon {
                return proposed.position.x < current.position.x
            }
        }
        if abs(proposed.size.y - current.size.y) > epsilon { return proposed.size.y < current.size.y }
        return orientationIndex < currentOrientationIndex
    }

    private static func updatedCandidatePoints(
        _ existingPoints: [PackingPosition3D],
        after placement: PackingPlacement,
        placements: [PackingPlacement],
        container: PackingSize3D
    ) -> [PackingPosition3D] {
        var points = existingPoints
        points.append(PackingPosition3D(x: placement.maxX, y: placement.position.y, z: placement.position.z))
        points.append(PackingPosition3D(x: placement.position.x, y: placement.maxY, z: placement.position.z))
        points.append(PackingPosition3D(x: placement.position.x, y: placement.position.y, z: placement.maxZ))
        // Project the new faces through the existing frontier. These intersections
        // find substantially more gap-filling layouts than three face origins alone,
        // while the bounded frontier keeps mobile work predictable.
        for point in existingPoints {
            points.append(PackingPosition3D(x: placement.maxX, y: point.y, z: point.z))
            points.append(PackingPosition3D(x: point.x, y: placement.maxY, z: point.z))
            points.append(PackingPosition3D(x: point.x, y: point.y, z: placement.maxZ))
        }
        return prune(points, placements: placements, container: container)
    }

    private static func candidatePoints(
        from placements: [PackingPlacement],
        in container: PackingSize3D
    ) -> [PackingPosition3D] {
        var points = [PackingPosition3D(x: 0, y: 0, z: 0)]
        var placed: [PackingPlacement] = []
        for placement in placements {
            placed.append(placement)
            points = updatedCandidatePoints(
                points,
                after: placement,
                placements: placed,
                container: container
            )
        }
        return points
    }

    private static func prune(
        _ points: [PackingPosition3D],
        placements: [PackingPlacement],
        container: PackingSize3D
    ) -> [PackingPosition3D] {
        var unique: [PackingPosition3D] = []
        for point in points {
            guard point.x >= -epsilon, point.y >= -epsilon, point.z >= -epsilon,
                  point.x < container.x - epsilon,
                  point.y < container.y - epsilon,
                  point.z < container.z - epsilon,
                  !placements.contains(where: { strictlyContains($0, point: point) }),
                  !unique.contains(where: { approximatelyEqual($0, point) }) else {
                continue
            }
            unique.append(point)
        }
        return Array(
            unique
                .sorted { candidatePointComesFirst($0, $1, variant: 0) }
                .prefix(maximumCandidatePoints)
        )
    }

    private static func isWithinBounds(
        _ placement: PackingPlacement,
        container: PackingSize3D
    ) -> Bool {
        placement.position.x >= -epsilon
            && placement.position.y >= -epsilon
            && placement.position.z >= -epsilon
            && placement.maxX <= container.x + epsilon
            && placement.maxY <= container.y + epsilon
            && placement.maxZ <= container.z + epsilon
    }

    private static func overlaps(_ left: PackingPlacement, _ right: PackingPlacement) -> Bool {
        left.position.x < right.maxX - epsilon
            && left.maxX > right.position.x + epsilon
            && left.position.y < right.maxY - epsilon
            && left.maxY > right.position.y + epsilon
            && left.position.z < right.maxZ - epsilon
            && left.maxZ > right.position.z + epsilon
    }

    private static func supportRatio(
        for placement: PackingPlacement,
        on existing: [PackingPlacement]
    ) -> Double {
        if placement.position.y <= epsilon { return 1 }
        let baseArea = placement.size.x * placement.size.z
        guard baseArea > 0 else { return 0 }

        let supportedArea = existing.reduce(0.0) { area, support in
            guard abs(support.maxY - placement.position.y) <= epsilon else { return area }
            let overlapX = max(
                0,
                min(placement.maxX, support.maxX) - max(placement.position.x, support.position.x)
            )
            let overlapZ = max(
                0,
                min(placement.maxZ, support.maxZ) - max(placement.position.z, support.position.z)
            )
            return area + overlapX * overlapZ
        }
        return min(1, supportedArea / baseArea)
    }

    private static func strictlyContains(
        _ placement: PackingPlacement,
        point: PackingPosition3D
    ) -> Bool {
        point.x > placement.position.x + epsilon
            && point.x < placement.maxX - epsilon
            && point.y > placement.position.y + epsilon
            && point.y < placement.maxY - epsilon
            && point.z > placement.position.z + epsilon
            && point.z < placement.maxZ - epsilon
    }

    private static func score(_ plan: WorkingPlan) -> SolutionScore {
        SolutionScore(
            placedCount: plan.placements.count,
            placedVolume: plan.placements.reduce(0) { $0 + $1.size.volume },
            negativeUsedHeight: -(plan.placements.map(\.maxY).max() ?? 0),
            negativeUsedDepth: -(plan.placements.map(\.maxZ).max() ?? 0)
        )
    }

    private static func approximatelyEqual(_ left: PackingSize3D, _ right: PackingSize3D) -> Bool {
        abs(left.x - right.x) <= epsilon
            && abs(left.y - right.y) <= epsilon
            && abs(left.z - right.z) <= epsilon
    }

    private static func approximatelyEqual(
        _ left: PackingPosition3D,
        _ right: PackingPosition3D
    ) -> Bool {
        abs(left.x - right.x) <= epsilon
            && abs(left.y - right.y) <= epsilon
            && abs(left.z - right.z) <= epsilon
    }

    private static func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}
