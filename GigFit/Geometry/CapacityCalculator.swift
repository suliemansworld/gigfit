import Foundation

struct CapacitySnapshot: Equatable {
    let capacityCubicMeters: Double
    let occupiedCubicMeters: Double
    /// Remaining capacity for display. Never negative.
    let remainingCubicMeters: Double
    /// Utilization can exceed 100, preserving the severity of an overloaded session.
    let utilizationPercent: Double
    /// Remaining percentage for display. Clamped to the closed range 0...100.
    let remainingPercent: Double
    let overCapacityCubicMeters: Double
    let hasValidCapacity: Bool

    var isOverCapacity: Bool { overCapacityCubicMeters > 0 }
}

enum CapacityCalculator {
    static func calculate(for session: LoadSession) -> CapacitySnapshot {
        calculate(vehicle: session.vehicle, items: session.items)
    }

    static func calculate(
        vehicle: VehicleProfile,
        items: [PackageEntry]
    ) -> CapacitySnapshot {
        calculate(
            conservativeCapacityCubicMeters: vehicle.conservativeCapacityCubicMeters,
            items: items
        )
    }

    static func calculate(
        conservativeCapacityCubicMeters capacity: Double,
        items: [PackageEntry]
    ) -> CapacitySnapshot {
        let validCapacity = capacity.isFinite && capacity > 0
        let normalizedCapacity = validCapacity ? capacity : 0

        let occupied = items.reduce(0.0) { partial, item in
            guard item.status.countsTowardCapacity else { return partial }
            let volume = item.rawVolumeForQuantityCubicMeters
            guard volume.isFinite && volume > 0 else { return partial }
            return partial + volume
        }
        let normalizedOccupied = occupied.isFinite ? max(0, occupied) : 0
        let rawRemaining = normalizedCapacity - normalizedOccupied
        let remaining = max(0, rawRemaining)
        let overCapacity = max(0, -rawRemaining)

        let utilizationPercent: Double
        let remainingPercent: Double
        if validCapacity {
            utilizationPercent = max(0, normalizedOccupied / normalizedCapacity * 100)
            remainingPercent = min(100, max(0, remaining / normalizedCapacity * 100))
        } else {
            utilizationPercent = 0
            remainingPercent = 0
        }

        return CapacitySnapshot(
            capacityCubicMeters: normalizedCapacity,
            occupiedCubicMeters: normalizedOccupied,
            remainingCubicMeters: remaining,
            utilizationPercent: utilizationPercent,
            remainingPercent: remainingPercent,
            overCapacityCubicMeters: overCapacity,
            hasValidCapacity: validCapacity
        )
    }
}
