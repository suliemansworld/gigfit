import SwiftUI
import UIKit

/// A persistent Roadie/gig load tied to one measured cargo-space profile.
struct LiveLoadView: View {
    let sessionID: UUID
    @ObservedObject var scanStore: ScanStore

    @EnvironmentObject private var cargoStore: CargoStore
    @State private var showingAddPackage = false
    @State private var selectedScreenshot: PackageEntry?
    @State private var errorMessage: String?
    @State private var packingPlan: PackingPlan?
    @State private var selectedFitPackageID: UUID?
    @State private var packingFitCount: Int?
    @State private var isSolvingPacking = true
    @State private var showingPackingPlan = false
    @State private var packingVariant = 0
    @State private var packingCalculationGeneration = 0
    @State private var packingPlanSessionUpdatedAt: Date?

    var body: some View {
        Group {
            if let session = cargoStore.loadSession(id: sessionID) {
                loadList(session)
            } else {
                ContentUnavailableView(
                    "Load Not Found",
                    systemImage: "truck.box.badge.clock",
                    description: Text("This live load may have been deleted.")
                )
            }
        }
        .navigationTitle(cargoStore.loadSession(id: sessionID)?.name ?? "Live Load")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddPackage = true }) {
                    Label("Add Package", systemImage: "plus")
                }
                .disabled(cargoStore.loadSession(id: sessionID) == nil)
            }
        }
        .sheet(isPresented: $showingAddPackage) {
            PackageEditorView(scans: scanStore.scans, onSave: addPackage)
        }
        .sheet(item: $selectedScreenshot) { package in
            PackageScreenshotView(package: package)
                .environmentObject(cargoStore)
        }
        .alert("Could Not Update Load", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .navigationDestination(isPresented: $showingPackingPlan) {
            if let session = cargoStore.loadSession(id: sessionID), let packingPlan {
                PackingPlanView(
                    session: session,
                    plan: packingPlan,
                    variant: packingVariant
                ) { updatedPlan, updatedVariant in
                    self.packingPlan = updatedPlan
                    packingVariant = updatedVariant
                    packingPlanSessionUpdatedAt = session.updatedAt
                    Task {
                        await calculatePackingFit(for: session, plan: updatedPlan)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Packing Plan Unavailable",
                    systemImage: "shippingbox",
                    description: Text("Return to the load and try again.")
                )
            }
        }
    }

    private func loadList(_ session: LoadSession) -> some View {
        let snapshot = CapacityCalculator.calculate(for: session)

        return List {
            Section {
                CapacityCard(
                    snapshot: snapshot,
                    vehicleName: session.vehicle.name,
                    loadedPackageCount: loadedPackageCount(in: session)
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                PackingSummaryCard(
                    plan: packingPlan,
                    isSolving: isSolvingPacking,
                    packageChoices: packingPackageChoices(in: session),
                    selectedPackage: selectedFitPackage(in: session),
                    fitCount: packingFitCount,
                    onSelectPackage: { packageID in
                        selectedFitPackageID = packageID
                        packingFitCount = nil
                        Task {
                            guard let plan = packingPlan else { return }
                            await calculatePackingFit(
                                for: session,
                                plan: plan,
                                packageID: packageID
                            )
                        }
                    },
                    onViewPlan: {
                        showingPackingPlan = true
                    },
                    onReorganize: {
                        isSolvingPacking = true
                        packingFitCount = nil
                        packingCalculationGeneration += 1
                        packingVariant = (packingVariant + 1) % PackingSolver.layoutVariantCount
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                if session.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No packages in this load")
                            .font(.headline)
                        Text("Attach a Roadie screenshot and enter its dimensions to start the live capacity tally.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Add First Package") {
                            showingAddPackage = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(session.items) { package in
                        PackageLoadRow(
                            package: package,
                            onShowScreenshot: {
                                if package.screenshotFilename != nil {
                                    selectedScreenshot = package
                                }
                            },
                            onToggleDelivered: {
                                toggleDelivered(package)
                            },
                            onIncreaseQuantity: {
                                changeQuantity(package, by: 1)
                            },
                            onDecreaseQuantity: {
                                changeQuantity(package, by: -1)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deletePackage(package)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                toggleDelivered(package)
                            } label: {
                                Label(
                                    package.status == .loaded ? "Delivered" : "Reload",
                                    systemImage: package.status == .loaded ? "checkmark.circle" : "arrow.uturn.backward.circle"
                                )
                            }
                            .tint(package.status == .loaded ? .green : .orange)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Packages")
                    Spacer()
                    Text("\(session.items.reduce(0) { $0 + $1.quantity }) total")
                }
            }

            Section {
                Button {
                    toggleSessionStatus(session)
                } label: {
                    Label(
                        session.status == .active ? "Finish Load" : "Reopen Load",
                        systemImage: session.status == .active ? "flag.checkered" : "arrow.counterclockwise"
                    )
                }

                Text("Capacity and packing use a conservative rectangular estimate. Confirm doors, wheel wells, tie-downs, weight, fragility, and safe visibility before driving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .task(id: packingTaskID(for: session)) {
            await rebuildPackingPlan(for: session)
        }
    }

    private func loadedPackageCount(in session: LoadSession) -> Int {
        session.items
            .filter { $0.status == .loaded }
            .reduce(0) { $0 + $1.quantity }
    }

    private func packingPackageChoices(in session: LoadSession) -> [PackageEntry] {
        session.items.filter { package in
            package.status == .loaded && package.dimensions?.isValid == true
        }
    }

    private func selectedFitPackage(in session: LoadSession) -> PackageEntry? {
        let choices = packingPackageChoices(in: session)
        if let selectedFitPackageID,
           let selected = choices.first(where: { $0.id == selectedFitPackageID }) {
            return selected
        }
        return choices.last
    }

    private func packingTaskID(for session: LoadSession) -> String {
        "\(session.id.uuidString)-\(session.updatedAt.timeIntervalSinceReferenceDate)-\(packingVariant)"
    }

    private func rebuildPackingPlan(for session: LoadSession) async {
        if packingPlan?.variant == packingVariant,
           packingPlanSessionUpdatedAt == session.updatedAt {
            isSolvingPacking = false
            return
        }

        isSolvingPacking = true
        packingFitCount = nil
        packingCalculationGeneration += 1
        let requestedVariant = packingVariant
        let sessionSnapshot = session
        let updatedPlan = await Task.detached(priority: .userInitiated) {
            PackingSolver.solve(session: sessionSnapshot, variant: requestedVariant)
        }.value
        guard !Task.isCancelled,
              requestedVariant == packingVariant,
              cargoStore.loadSession(id: sessionID)?.updatedAt == session.updatedAt else {
            return
        }

        packingPlan = updatedPlan
        packingPlanSessionUpdatedAt = session.updatedAt
        let choices = packingPackageChoices(in: session)
        if selectedFitPackageID == nil
            || !choices.contains(where: { $0.id == selectedFitPackageID }) {
            selectedFitPackageID = choices.last?.id
        }
        isSolvingPacking = false
        await calculatePackingFit(for: session, plan: updatedPlan)
    }

    private func calculatePackingFit(
        for session: LoadSession,
        plan: PackingPlan,
        packageID requestedPackageID: UUID? = nil
    ) async {
        packingCalculationGeneration += 1
        let generation = packingCalculationGeneration
        let packageID = requestedPackageID ?? selectedFitPackageID
        guard plan.allItemsFit,
              plan.placements.count < PackingSolver.maximumPackedInstances,
              let packageID,
              let dimensions = packingPackageChoices(in: session)
                .first(where: { $0.id == packageID })?.dimensions else {
            packingFitCount = 0
            return
        }

        packingFitCount = nil
        let currentPlan = plan
        let count = await Task.detached(priority: .utility) {
            PackingSolver.additionalFitCount(of: dimensions, in: currentPlan, limit: 100)
        }.value
        guard !Task.isCancelled,
              generation == packingCalculationGeneration,
              selectedFitPackageID == packageID,
              packingPlan == plan,
              cargoStore.loadSession(id: sessionID)?.updatedAt == session.updatedAt else {
            return
        }
        packingFitCount = count
    }

    private func addPackage(_ draft: PackageDraft) -> Result<Void, CargoStoreError> {
        let dimensions = PackageDimensions(
            lengthMeters: draft.lengthMeters,
            widthMeters: draft.widthMeters,
            heightMeters: draft.heightMeters
        )
        return cargoStore.addPackage(
                to: sessionID,
                name: draft.name,
                notes: draft.notes,
                dimensions: dimensions,
                quantity: draft.quantity,
                screenshotData: draft.screenshotData,
                sourceScanID: draft.sourceScanID
            )
            .map { _ in () }
    }

    private func toggleDelivered(_ package: PackageEntry) {
        let nextStatus: PackageStatus = package.status == .loaded ? .delivered : .loaded
        showFailureIfNeeded(
            cargoStore.setPackageStatus(nextStatus, packageID: package.id, in: sessionID)
        )
    }

    private func changeQuantity(_ package: PackageEntry, by delta: Int) {
        guard delta > 0 || package.quantity > 1 else { return }
        var updated = package
        updated.quantity = max(1, package.quantity + delta)
        showFailureIfNeeded(cargoStore.updatePackage(updated, in: sessionID))
    }

    private func deletePackage(_ package: PackageEntry) {
        showFailureIfNeeded(cargoStore.deletePackage(id: package.id, from: sessionID))
    }

    private func toggleSessionStatus(_ session: LoadSession) {
        var updated = session
        updated.status = session.status == .active ? .completed : .active
        showFailureIfNeeded(cargoStore.updateLoadSession(updated))
    }

    private func showFailureIfNeeded<T>(_ result: Result<T, CargoStoreError>) {
        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

struct StartLoadView: View {
    let scans: [ScanSession]
    let onStarted: (LoadSession) -> Void

    @EnvironmentObject private var cargoStore: CargoStore
    @Environment(\.dismiss) private var dismiss
    @State private var loadName = "Roadie Load"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Load Name") {
                    TextField("Roadie Load", text: $loadName)
                }

                if !cargoStore.vehicleProfiles.isEmpty {
                    Section("Saved Vehicles") {
                        ForEach(cargoStore.vehicleProfiles) { profile in
                            Button {
                                start(using: profile)
                            } label: {
                                vehicleRow(
                                    name: profile.name,
                                    dimensions: profile.dimensions,
                                    capacity: profile.conservativeCapacityCubicMeters
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Use a Cargo-Space Scan") {
                    if eligibleScans.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No completed cargo-space scan is ready yet.")
                                .font(.headline)
                            Text("Save a completed GigFit scan first, then use it as the vehicle capacity for a live load.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(eligibleScans) { scan in
                            Button {
                                start(using: scan)
                            } label: {
                                if let dimensions = scan.dimensions {
                                    vehicleRow(
                                        name: scan.name,
                                        dimensions: dimensions,
                                        capacity: conservativeCapacity(for: scan)
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Start Live Load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Could Not Start Load", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try another scan.")
            }
        }
    }

    private var eligibleScans: [ScanSession] {
        scans.filter { scan in
            guard scan.isComplete, let dimensions = scan.dimensions else { return false }
            return dimensions.lengthMeters > 0
                && dimensions.widthMeters > 0
                && dimensions.heightMeters > 0
                && conservativeCapacity(for: scan) > 0
        }
    }

    private func conservativeCapacity(for scan: ScanSession) -> Double {
        let resultValue = scan.volumeResult?.conservativeCubicMeters ?? 0
        if resultValue.isFinite, resultValue > 0 { return resultValue }
        return scan.dimensions?.conservativeVolumeCubicMeters ?? 0
    }

    private func vehicleRow(name: String, dimensions: ScanDimensions, capacity: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "car.side.fill")
                .font(.title2)
                .foregroundStyle(Color.blue)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body.weight(.semibold))
                Text("\(UnitFormatter.formatFeetAndInches(dimensions.lengthMeters)) × \(UnitFormatter.formatFeetAndInches(dimensions.widthMeters)) × \(UnitFormatter.formatFeetAndInches(dimensions.heightMeters))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(UnitFormatter.formatCubicFeet(capacity))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func start(using scan: ScanSession) {
        switch cargoStore.startLoad(
            from: scan,
            vehicleName: scan.name,
            loadName: normalizedLoadName
        ) {
        case .success(let session):
            onStarted(session)
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func start(using profile: VehicleProfile) {
        switch cargoStore.startLoad(vehicleProfileID: profile.id, name: normalizedLoadName) {
        case .success(let session):
            onStarted(session)
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private var normalizedLoadName: String {
        let trimmed = loadName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Roadie Load" : trimmed
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

private struct CapacityCard: View {
    let snapshot: CapacitySnapshot
    let vehicleName: String
    let loadedPackageCount: Int

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicleName)
                        .font(.headline)
                    Text("\(loadedPackageCount) package\(loadedPackageCount == 1 ? "" : "s") currently loaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "car.side.fill")
                    .font(.title2)
                    .foregroundStyle(gaugeColor)
            }

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, snapshot.remainingPercent / 100)))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(snapshot.hasValidCapacity ? "\(Int(snapshot.remainingPercent.rounded()))%" : "--")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text(snapshot.isOverCapacity ? "OVER CAPACITY" : "SPACE LEFT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(gaugeColor)
                }
            }
            .frame(width: 190, height: 190)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(capacityAccessibilityLabel)

            HStack(spacing: 0) {
                capacityStat("Loaded", snapshot.occupiedCubicMeters)
                Divider().frame(height: 38)
                capacityStat("Remaining", snapshot.remainingCubicMeters)
                Divider().frame(height: 38)
                capacityStat("Capacity", snapshot.capacityCubicMeters)
            }

            if snapshot.isOverCapacity {
                Label(
                    "Over by \(UnitFormatter.formatCubicFeet(snapshot.overCapacityCubicMeters))",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.vertical, 8)
    }

    private func capacityStat(_ label: String, _ cubicMeters: Double) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(UnitFormatter.formatCubicFeet(cubicMeters))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var gaugeColor: Color {
        if snapshot.isOverCapacity || snapshot.remainingPercent < 10 { return .red }
        if snapshot.remainingPercent < 30 { return .orange }
        return .green
    }

    private var capacityAccessibilityLabel: String {
        if !snapshot.hasValidCapacity { return "Capacity unavailable" }
        if snapshot.isOverCapacity {
            return "Over capacity by \(UnitFormatter.formatCubicFeet(snapshot.overCapacityCubicMeters))"
        }
        return "\(Int(snapshot.remainingPercent.rounded())) percent space left"
    }
}

private struct PackageLoadRow: View {
    let package: PackageEntry
    let onShowScreenshot: () -> Void
    let onToggleDelivered: () -> Void
    let onIncreaseQuantity: () -> Void
    let onDecreaseQuantity: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onShowScreenshot) {
                PackageThumbnail(filename: package.screenshotFilename)
            }
            .buttonStyle(.plain)
            .disabled(package.screenshotFilename == nil)

            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .layoutPriority(1)

                HStack(spacing: 6) {
                    Text(package.status == .loaded ? "LOADED" : "DELIVERED")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background((package.status == .loaded ? Color.blue : Color.green).opacity(0.18))
                        .foregroundStyle(package.status == .loaded ? Color.blue : Color.green)
                        .clipShape(Capsule())

                    if let dimensions = package.dimensions {
                        Text("\(UnitFormatter.formatFeetAndInches(dimensions.lengthMeters)) × \(UnitFormatter.formatFeetAndInches(dimensions.widthMeters)) × \(UnitFormatter.formatFeetAndInches(dimensions.heightMeters))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Needs dimensions")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text("\(UnitFormatter.formatCubicFeet(package.rawVolumeForQuantityCubicMeters)) total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !package.notes.isEmpty {
                    Text(package.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Menu {
                Button(action: onIncreaseQuantity) {
                    Label("Add One", systemImage: "plus")
                }
                Button(action: onDecreaseQuantity) {
                    Label("Remove One", systemImage: "minus")
                }
                .disabled(package.quantity <= 1)
                Divider()
                Button(action: onToggleDelivered) {
                    Label(
                        package.status == .loaded ? "Mark Delivered" : "Mark Loaded",
                        systemImage: package.status == .loaded ? "checkmark.circle" : "arrow.uturn.backward.circle"
                    )
                }
            } label: {
                VStack(spacing: 2) {
                    Text("×\(package.quantity)")
                        .font(.headline.monospacedDigit())
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 6)
            }
        }
        .opacity(package.status == .delivered ? 0.58 : 1)
        .padding(.vertical, 4)
    }
}

private struct PackageThumbnail: View {
    let filename: String?

    @EnvironmentObject private var cargoStore: CargoStore
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 58, height: 58)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: filename) {
            guard let filename else {
                image = nil
                return
            }
            image = await cargoStore.assetStore.loadImage(named: filename)
        }
    }
}

private struct PackageScreenshotView: View {
    let package: PackageEntry
    @EnvironmentObject private var cargoStore: CargoStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let filename = package.screenshotFilename,
                   let image = try? cargoStore.assetStore.image(for: filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableView("Screenshot Unavailable", systemImage: "photo.badge.exclamationmark")
                }
            }
            .navigationTitle(package.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
