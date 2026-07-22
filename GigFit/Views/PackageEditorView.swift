import PhotosUI
import SwiftUI
import UIKit

/// User-entered package data. The selected screenshot is copied into durable
/// app storage by the caller only after the package is saved.
struct PackageDraft {
    var name: String
    var notes: String
    var quantity: Int
    var lengthMeters: Double
    var widthMeters: Double
    var heightMeters: Double
    var sourceScanID: UUID?
    var screenshotData: Data?
}

struct PackageEditorView: View {
    let scans: [ScanSession]
    let onSave: (PackageDraft) -> Result<Void, CargoStoreError>

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cargoStore: CargoStore
    @State private var name = "Roadie Package"
    @State private var notes = ""
    @State private var quantity = 1
    @State private var lengthInches = ""
    @State private var widthInches = ""
    @State private var heightInches = ""
    @State private var selectedScanID: UUID?
    @State private var photoSelection: PhotosPickerItem?
    @State private var screenshotData: Data?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                screenshotSection
                packageSection
                measurementSection

                Section {
                    Text("Capacity is a volume estimate. The later 3D organizer will check whether each shape and orientation physically fits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: selectedScanID) { _, newValue in
                applyMeasurement(from: newValue)
            }
            .onChange(of: photoSelection) { _, newValue in
                loadPhoto(from: newValue)
            }
        }
    }

    private var screenshotSection: some View {
        Section("Roadie Screenshot") {
            if let screenshotData, let image = UIImage(data: screenshotData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 210)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Selected Roadie screenshot")
            }

            PhotosPicker(selection: $photoSelection, matching: .images) {
                Label(screenshotData == nil ? "Attach Screenshot" : "Replace Screenshot",
                      systemImage: "photo.badge.plus")
            }
            .disabled(isLoadingPhoto)

            if isLoadingPhoto {
                HStack {
                    ProgressView()
                    Text("Loading screenshot…")
                        .foregroundStyle(.secondary)
                }
            }

            if let photoError {
                Text(photoError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var packageSection: some View {
        Section("Package") {
            TextField("Package or stop name", text: $name)

            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)

            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var measurementSection: some View {
        Section("Measurements") {
            if !measuredScans.isEmpty {
                Picker("Use saved scan", selection: $selectedScanID) {
                    Text("Enter manually")
                        .tag(Optional<UUID>.none)
                    ForEach(measuredScans) { scan in
                        Text(scan.name)
                            .tag(Optional(scan.id))
                    }
                }
            }

            dimensionField("Length", text: $lengthInches)
            dimensionField("Width", text: $widthInches)
            dimensionField("Height", text: $heightInches)

            Text("Use the dimensions shown in Roadie, or select a GigFit item scan. Measurements are in inches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dimensionField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text("in")
                .foregroundStyle(.secondary)
        }
    }

    private var measuredScans: [ScanSession] {
        scans.filter { scan in
            guard let dimensions = scan.dimensions else { return false }
            return dimensions.rawVolumeCubicMeters > 0
        }
    }

    private var parsedDimensionsInches: (Double, Double, Double)? {
        guard let length = parsePositive(lengthInches),
              let width = parsePositive(widthInches),
              let height = parsePositive(heightInches) else {
            return nil
        }
        return (length, width, height)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedDimensionsInches != nil
            && !isLoadingPhoto
    }

    private func parsePositive(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func applyMeasurement(from scanID: UUID?) {
        guard let scanID,
              let scan = measuredScans.first(where: { $0.id == scanID }),
              let dimensions = scan.dimensions else {
            return
        }

        lengthInches = formatInput(dimensions.lengthInches)
        widthInches = formatInput(dimensions.widthInches)
        heightInches = formatInput(dimensions.heightInches)
        if name == "Roadie Package" {
            name = scan.name
        }
    }

    private func formatInput(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingPhoto = true
        photoError = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw PhotoSelectionError.unreadableImage
                }
                let preparedData = try await cargoStore.assetStore.prepareImageData(data)
                await MainActor.run {
                    screenshotData = preparedData
                    isLoadingPhoto = false
                }
            } catch {
                await MainActor.run {
                    photoError = (error as? LocalizedError)?.errorDescription
                        ?? "That image could not be loaded. Try choosing the screenshot again."
                    isLoadingPhoto = false
                }
            }
        }
    }

    private func save() {
        guard let dimensions = parsedDimensionsInches else { return }
        let inchesToMeters = 0.0254
        saveError = nil
        let result = onSave(
            PackageDraft(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                lengthMeters: dimensions.0 * inchesToMeters,
                widthMeters: dimensions.1 * inchesToMeters,
                heightMeters: dimensions.2 * inchesToMeters,
                sourceScanID: selectedScanID,
                screenshotData: screenshotData
            )
        )
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            saveError = error.localizedDescription
        }
    }
}

private enum PhotoSelectionError: Error {
    case unreadableImage
}
