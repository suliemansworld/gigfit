import SwiftUI

struct PackingSummaryCard: View {
    let plan: PackingPlan?
    let isSolving: Bool
    let packageChoices: [PackageEntry]
    let selectedPackage: PackageEntry?
    let fitCount: Int?
    let onSelectPackage: (UUID) -> Void
    let onViewPlan: () -> Void
    let onReorganize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Packing Plan", systemImage: "shippingbox.and.arrow.backward.fill")
                    .font(.headline)
                Spacer()
                Text("RECTANGULAR ESTIMATE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("packing-summary-status")
                if isSolving {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if !packageChoices.isEmpty {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(packageChoices) { package in
                            Button(package.name) { onSelectPackage(package.id) }
                        }
                    } label: {
                        Label(selectedPackage?.name ?? "Choose package", systemImage: "shippingbox")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .accessibilityIdentifier("packing-fit-type")

                    Spacer()

                    Text(fitText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(fitColor)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("packing-fit-count")
                }
            }

            HStack(spacing: 10) {
                Button(action: onViewPlan) {
                    Label("View Plan", systemImage: "cube.transparent")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(plan == nil || plan?.placements.isEmpty == true || isSolving)
                .accessibilityIdentifier("packing-view-plan")

                Button(action: onReorganize) {
                    Label("Reorganize", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(plan == nil || plan?.placements.isEmpty == true || isSolving)
                .accessibilityIdentifier("packing-reorganize")
            }
            .controlSize(.regular)
        }
        .padding(18)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("packing-summary")
    }

    private var statusText: String {
        if isSolving { return "Building best plan found…" }
        guard let plan else { return "Packing plan unavailable." }
        if !plan.hasValidContainer { return "Vehicle dimensions are unavailable." }
        if plan.isEmpty { return "Add a measured package to create a plan." }
        if plan.allItemsFit {
            return "All \(plan.placedCount) loaded box\(plan.placedCount == 1 ? "" : "es") placed."
        }

        var details: [String] = []
        if !plan.unplacedItems.isEmpty {
            details.append("\(plan.unplacedItems.count) need another placement")
        }
        if plan.invalidItemCount > 0 {
            details.append("\(plan.invalidItemCount) need dimensions")
        }
        if plan.truncatedItemCount > 0 {
            details.append("\(plan.truncatedItemCount) not analyzed")
        }
        return "\(plan.placedCount) placed · \(details.joined(separator: " · "))."
    }

    private var statusIcon: String {
        if isSolving { return "hourglass" }
        guard let plan else { return "exclamationmark.triangle.fill" }
        if plan.allItemsFit && !plan.isEmpty { return "checkmark.circle.fill" }
        if plan.isEmpty { return "shippingbox" }
        return "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        guard let plan else { return .orange }
        if plan.allItemsFit && !plan.isEmpty { return .green }
        if plan.isEmpty { return .secondary }
        return .orange
    }

    private var fitText: String {
        guard let plan else { return "Unavailable" }
        if plan.truncatedItemCount > 0 { return "Additional check unavailable" }
        if plan.placements.count >= PackingSolver.maximumPackedInstances {
            return "Additional check unavailable at 72-item limit"
        }
        guard plan.allItemsFit else { return "Current load must fit first" }
        guard let fitCount else { return "Calculating fit…" }
        if fitCount == 0 { return "No additional placement found" }
        return "Space found for at least \(fitCount) more"
    }

    private var fitColor: Color {
        guard let plan, plan.allItemsFit, let fitCount else { return .secondary }
        return fitCount > 0 ? .green : .orange
    }
}

struct PackingPlanView: View {
    let session: LoadSession
    let onPlanChanged: (PackingPlan, Int) -> Void

    @State private var plan: PackingPlan
    @State private var variant: Int
    @State private var diagramMode: PackingDiagramMode = .isometric
    @State private var selectedStep = 0
    @State private var selectedPackageID: UUID?
    @State private var fitCount: Int?
    @State private var isReorganizing = false
    @State private var isCalculatingFit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        session: LoadSession,
        plan: PackingPlan,
        variant: Int,
        onPlanChanged: @escaping (PackingPlan, Int) -> Void
    ) {
        self.session = session
        self.onPlanChanged = onPlanChanged
        _plan = State(initialValue: plan)
        _variant = State(initialValue: variant)
        _selectedPackageID = State(initialValue: Self.packageChoices(in: session).first?.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                statusHeader

                Picker("Diagram", selection: $diagramMode) {
                    ForEach(PackingDiagramMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("packing-plan-mode")

                PackingDiagramView(
                    plan: plan,
                    mode: diagramMode,
                    selectedStep: selectedStep
                )
                .frame(height: 285)
                .padding(12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Packing diagram, \(diagramMode.rawValue), step \(min(selectedStep + 1, max(1, plan.placements.count))) of \(max(1, plan.placements.count))")
                .accessibilityIdentifier("packing-plan-diagram")

                if !plan.placements.isEmpty {
                    placementGuide
                }

                fitsMoreCard

                if plan.unplacedCount > 0 {
                    unplacedSection
                }

                disclaimer
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Packing Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: reorganize) {
                    if isReorganizing {
                        ProgressView()
                    } else {
                        Label("Reorganize", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isReorganizing || plan.placements.isEmpty)
                .accessibilityIdentifier("packing-reorganize")
            }
        }
        .task(id: fitTaskID) {
            await calculateFitCount()
        }
        .accessibilityIdentifier("packing-plan-screen")
    }

    private var statusHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: plan.allItemsFit ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(plan.allItemsFit ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(planHeaderTitle)
                    .font(.headline)
                Text("Best plan found · layout \((variant % PackingSolver.layoutVariantCount) + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(plan.spatialUtilizationPercent.rounded()))%")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.orange)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var planHeaderTitle: String {
        if plan.allItemsFit {
            return "All \(plan.placedCount) \(plan.placedCount == 1 ? "box" : "boxes") fit"
        }
        let analyzedCount = plan.placements.count + plan.unplacedItems.count
        if plan.truncatedItemCount > 0 {
            return "\(plan.placedCount) of \(analyzedCount) analyzed boxes placed"
        }
        return "\(plan.placedCount) of \(plan.totalItemCount) boxes placed"
    }

    private var placementGuide: some View {
        let safeIndex = min(max(0, selectedStep), max(0, plan.placements.count - 1))
        let placement = plan.placements[safeIndex]
        let instruction = placementInstruction(placement, container: plan.container)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STEP \(safeIndex + 1) OF \(plan.placements.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
                Spacer()
                Text(placement.item.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            Text(placement.item.displayName)
                .font(.title3.bold())

            Text(instruction)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Placed size: \(dimensionsText(placement.size))")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    changeStep(to: safeIndex - 1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(safeIndex == 0)
                .accessibilityIdentifier("packing-plan-previous")

                Spacer()

                Button {
                    changeStep(to: safeIndex + 1)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(safeIndex >= plan.placements.count - 1)
                .accessibilityIdentifier("packing-plan-next")
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("packing-plan-step")
    }

    private var fitsMoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Fits More", systemImage: "plus.forwardslash.minus")
                    .font(.headline)
                Spacer()
                Text("SPATIAL CHECK")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
            }

            if packageChoices.isEmpty {
                Text("Add a measured package to calculate additional fit.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Package type", selection: $selectedPackageID) {
                    ForEach(packageChoices) { package in
                        Text(package.name).tag(Optional(package.id))
                    }
                }
                .accessibilityIdentifier("packing-fit-type")

                if plan.truncatedItemCount > 0 {
                    Text("Additional fit is unavailable because \(plan.truncatedItemCount) loaded package copies were not analyzed.")
                        .foregroundStyle(.orange)
                } else if plan.placements.count >= PackingSolver.maximumPackedInstances {
                    Text("Additional fit is unavailable at the 72-item on-device limit.")
                        .foregroundStyle(.orange)
                } else if plan.invalidItemCount > 0 {
                    Text("Add dimensions to every loaded package before checking additional fit.")
                        .foregroundStyle(.orange)
                } else if !plan.allItemsFit {
                    Text("Additional fit is unavailable until every current package has a placement.")
                        .foregroundStyle(.orange)
                } else if isCalculatingFit {
                    HStack {
                        ProgressView()
                        Text("Checking remaining positions…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(fitCount == 0 ? "No additional placement was found for this package size." : "This plan found space for at least \(fitCount ?? 0) more.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle((fitCount ?? 0) > 0 ? Color.green : Color.orange)
                        .accessibilityIdentifier("packing-fit-count")
                }
            }
        }
        .padding(18)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var unplacedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Packages Needing Attention", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(plan.unplacedItems) { item in
                HStack {
                    Text(item.displayName)
                    Spacer()
                    Text(dimensionsText(item.originalSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if plan.invalidItemCount > 0 {
                Label(
                    "\(plan.invalidItemCount) loaded package copies need dimensions before they can be analyzed.",
                    systemImage: "ruler"
                )
                .font(.subheadline)
            }
            if plan.truncatedItemCount > 0 {
                Label(
                    "\(plan.truncatedItemCount) loaded package copies were not analyzed by the 72-item on-device limit.",
                    systemImage: "speedometer"
                )
                .font(.subheadline)
            }
        }
        .padding(18)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("packing-plan-unplaced")
    }

    private var disclaimer: some View {
        Text("This plan treats the cargo space and every item as rigid rectangular boxes and allows 90° rotations. It is a conservative estimate, not a guarantee. Check wheel wells, doors, tie-downs, weight, fragility, and safe visibility before loading.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("packing-plan-disclaimer")
    }

    private var packageChoices: [PackageEntry] {
        Self.packageChoices(in: session)
    }

    private static func packageChoices(in session: LoadSession) -> [PackageEntry] {
        session.items.filter { package in
            package.status == .loaded && package.dimensions?.isValid == true
        }
    }

    private var selectedPackage: PackageEntry? {
        guard let selectedPackageID else { return packageChoices.first }
        return packageChoices.first { $0.id == selectedPackageID }
    }

    private var fitTaskID: String {
        "\(variant)-\(selectedPackageID?.uuidString ?? "none")-\(plan.placements.count)-\(plan.unplacedCount)"
    }

    private func calculateFitCount() async {
        guard plan.allItemsFit,
              plan.placements.count < PackingSolver.maximumPackedInstances,
              let dimensions = selectedPackage?.dimensions else {
            fitCount = 0
            isCalculatingFit = false
            return
        }
        isCalculatingFit = true
        fitCount = nil
        let currentPlan = plan
        let result = await Task.detached(priority: .utility) {
            PackingSolver.additionalFitCount(
                of: dimensions,
                in: currentPlan,
                limit: 100
            )
        }.value
        guard !Task.isCancelled else { return }
        fitCount = result
        isCalculatingFit = false
    }

    private func reorganize() {
        guard !isReorganizing else { return }
        isReorganizing = true
        let nextVariant = (variant + 1) % PackingSolver.layoutVariantCount
        let sessionSnapshot = session
        Task {
            let newPlan = await Task.detached(priority: .userInitiated) {
                PackingSolver.solve(session: sessionSnapshot, variant: nextVariant)
            }.value
            guard !Task.isCancelled else { return }
            variant = nextVariant
            plan = newPlan
            selectedStep = 0
            isReorganizing = false
            onPlanChanged(newPlan, nextVariant)
        }
    }

    private func changeStep(to newValue: Int) {
        let update = { selectedStep = min(max(0, newValue), max(0, plan.placements.count - 1)) }
        if reduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                update()
            }
        }
    }

    private func placementInstruction(
        _ placement: PackingPlacement,
        container: PackingSize3D
    ) -> String {
        let vertical: String
        if placement.position.y <= 0.01 {
            vertical = "Place it on the cargo floor"
        } else {
            vertical = "Stack it \(UnitFormatter.formatFeetAndInches(placement.position.y)) above the cargo floor"
        }

        let horizontal: String
        if placement.position.x <= 0.03 {
            horizontal = "against the left wall"
        } else if container.x - placement.maxX <= 0.03 {
            horizontal = "against the right wall"
        } else {
            horizontal = "\(UnitFormatter.formatFeetAndInches(placement.position.x)) from the left wall"
        }

        let forward = placement.position.z <= 0.03
            ? "at the rear cargo door"
            : "\(UnitFormatter.formatFeetAndInches(placement.position.z)) forward from the rear cargo door"

        return "\(vertical), \(horizontal), \(forward). Turn the \(UnitFormatter.formatFeetAndInches(placement.size.z)) side front-to-back and the \(UnitFormatter.formatFeetAndInches(placement.size.x)) side left-to-right. Directions are viewed while standing at the open rear cargo door."
    }

    private func dimensionsText(_ size: PackingSize3D) -> String {
        "\(UnitFormatter.formatFeetAndInches(size.z)) × \(UnitFormatter.formatFeetAndInches(size.x)) × \(UnitFormatter.formatFeetAndInches(size.y))"
    }
}

private enum PackingDiagramMode: String, CaseIterable, Identifiable {
    case isometric = "Isometric"
    case topDown = "Top-down"

    var id: String { rawValue }
}

private struct PackingDiagramView: View {
    let plan: PackingPlan
    let mode: PackingDiagramMode
    let selectedStep: Int

    var body: some View {
        ZStack {
            Canvas { context, size in
                guard plan.container.isValid else { return }
                switch mode {
                case .isometric:
                    drawIsometric(context: &context, canvas: size)
                case .topDown:
                    drawTopDown(context: &context, canvas: size)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func drawTopDown(context: inout GraphicsContext, canvas: CGSize) {
        let frame = CGRect(x: 20, y: 18, width: canvas.width - 40, height: canvas.height - 36)
        context.stroke(Path(frame), with: .color(.white.opacity(0.38)), lineWidth: 2)

        for (index, placement) in plan.placements.enumerated() {
            let rect = CGRect(
                x: frame.minX + placement.position.x / plan.container.x * frame.width,
                y: frame.maxY - placement.maxZ / plan.container.z * frame.height,
                width: placement.size.x / plan.container.x * frame.width,
                height: placement.size.z / plan.container.z * frame.height
            )
            var boxContext = context
            boxContext.opacity = opacity(for: index)
            boxContext.fill(Path(rect), with: .color(color(for: placement.item.packageID).opacity(0.72)))
            boxContext.stroke(
                Path(rect),
                with: .color(index == selectedStep ? .white : color(for: placement.item.packageID)),
                lineWidth: index == selectedStep ? 3 : 1
            )
            boxContext.draw(
                Text("\(index + 1)").font(.caption2.bold()).foregroundColor(.white),
                at: CGPoint(x: rect.midX, y: rect.midY)
            )
        }

        context.draw(
            Text("REAR DOOR").font(.caption2.bold()).foregroundColor(.secondary),
            at: CGPoint(x: frame.midX, y: frame.maxY + 10)
        )
        context.draw(
            Text("FRONT SEATS").font(.caption2.bold()).foregroundColor(.secondary),
            at: CGPoint(x: frame.midX, y: frame.minY - 8)
        )
    }

    private func drawIsometric(context: inout GraphicsContext, canvas: CGSize) {
        let container = plan.container
        let project: (PackingPosition3D) -> CGPoint = { point in
            let widthScale = canvas.width * 0.56
            let depthX = canvas.width * 0.23
            let depthY = canvas.height * 0.18
            let heightScale = canvas.height * 0.56
            return CGPoint(
                x: canvas.width * 0.10
                    + point.x / container.x * widthScale
                    + point.z / container.z * depthX,
                y: canvas.height * 0.86
                    - point.y / container.y * heightScale
                    - point.z / container.z * depthY
            )
        }

        drawContainerWireframe(context: &context, container: container, project: project)

        let orderedIndices = plan.placements.indices.sorted { left, right in
            let lhs = plan.placements[left]
            let rhs = plan.placements[right]
            if lhs.position.z != rhs.position.z { return lhs.position.z > rhs.position.z }
            return lhs.position.y < rhs.position.y
        }

        for index in orderedIndices {
            drawCuboid(
                plan.placements[index],
                step: index,
                context: &context,
                project: project
            )
        }
    }

    private func drawContainerWireframe(
        context: inout GraphicsContext,
        container: PackingSize3D,
        project: (PackingPosition3D) -> CGPoint
    ) {
        let corners = cuboidCorners(
            position: PackingPosition3D(x: 0, y: 0, z: 0),
            size: container,
            project: project
        )
        let edges = [
            (0, 1), (1, 5), (5, 4), (4, 0),
            (2, 3), (3, 7), (7, 6), (6, 2),
            (0, 2), (1, 3), (4, 6), (5, 7),
        ]
        var path = Path()
        for edge in edges {
            path.move(to: corners[edge.0])
            path.addLine(to: corners[edge.1])
        }
        context.stroke(path, with: .color(.white.opacity(0.28)), lineWidth: 1.5)
    }

    private func drawCuboid(
        _ placement: PackingPlacement,
        step: Int,
        context: inout GraphicsContext,
        project: (PackingPosition3D) -> CGPoint
    ) {
        let points = cuboidCorners(position: placement.position, size: placement.size, project: project)
        let baseColor = color(for: placement.item.packageID)
        var boxContext = context
        boxContext.opacity = opacity(for: step)

        let top = polygon([points[2], points[3], points[7], points[6]])
        let side = polygon([points[1], points[5], points[7], points[3]])
        let front = polygon([points[0], points[1], points[3], points[2]])
        boxContext.fill(side, with: .color(baseColor.opacity(0.42)))
        boxContext.fill(front, with: .color(baseColor.opacity(0.62)))
        boxContext.fill(top, with: .color(baseColor.opacity(0.82)))

        let outlineColor: Color = step == selectedStep ? .white : baseColor
        boxContext.stroke(side, with: .color(outlineColor), lineWidth: step == selectedStep ? 2.5 : 1)
        boxContext.stroke(front, with: .color(outlineColor), lineWidth: step == selectedStep ? 2.5 : 1)
        boxContext.stroke(top, with: .color(outlineColor), lineWidth: step == selectedStep ? 2.5 : 1)

        let labelCenter = CGPoint(
            x: (points[2].x + points[3].x + points[7].x + points[6].x) / 4,
            y: (points[2].y + points[3].y + points[7].y + points[6].y) / 4
        )
        boxContext.draw(
            Text("\(step + 1)").font(.caption2.bold()).foregroundColor(.white),
            at: labelCenter
        )
    }

    private func cuboidCorners(
        position: PackingPosition3D,
        size: PackingSize3D,
        project: (PackingPosition3D) -> CGPoint
    ) -> [CGPoint] {
        let x0 = position.x
        let x1 = position.x + size.x
        let y0 = position.y
        let y1 = position.y + size.y
        let z0 = position.z
        let z1 = position.z + size.z
        return [
            project(PackingPosition3D(x: x0, y: y0, z: z0)),
            project(PackingPosition3D(x: x1, y: y0, z: z0)),
            project(PackingPosition3D(x: x0, y: y1, z: z0)),
            project(PackingPosition3D(x: x1, y: y1, z: z0)),
            project(PackingPosition3D(x: x0, y: y0, z: z1)),
            project(PackingPosition3D(x: x1, y: y0, z: z1)),
            project(PackingPosition3D(x: x0, y: y1, z: z1)),
            project(PackingPosition3D(x: x1, y: y1, z: z1)),
        ]
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private func opacity(for step: Int) -> Double {
        if step == selectedStep { return 1 }
        return step < selectedStep ? 0.72 : 0.32
    }

    private func color(for packageID: UUID) -> Color {
        let palette: [Color] = [.cyan, .blue, .purple, .pink, .orange, .green, .indigo, .mint]
        let scalarSum = packageID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[scalarSum % palette.count]
    }
}
