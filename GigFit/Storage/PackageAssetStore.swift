import Foundation
import ImageIO
import UIKit

enum PackageAssetStoreError: Error, Equatable, LocalizedError, Sendable {
    case emptyData
    case inputTooLarge(maxBytes: Int)
    case invalidImage
    case imageDimensionsTooLarge(maxPixels: Int)
    case encodingFailed
    case unsafeFilename
    case assetNotFound
    case fileSystem(String)

    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "The selected image is empty."
        case .inputTooLarge(let maxBytes):
            return "The selected image exceeds the \(maxBytes / 1_000_000) MB limit."
        case .invalidImage:
            return "The selected file is not a readable image."
        case .imageDimensionsTooLarge(let maxPixels):
            return "The selected image exceeds the \(maxPixels / 1_000_000)-megapixel safety limit."
        case .encodingFailed:
            return "The selected image could not be converted to JPEG."
        case .unsafeFilename:
            return "The stored image filename is invalid."
        case .assetNotFound:
            return "The stored package image could not be found."
        case .fileSystem(let message):
            return "Package image storage failed: \(message)"
        }
    }
}

/// Owns durable, app-local package screenshots. Callers persist only the returned
/// generated filename; user-provided filenames and temporary picker URLs are never used.
final class PackageAssetStore: @unchecked Sendable {
    let directoryURL: URL
    let maxInputBytes: Int
    let maxSourcePixelCount: Int
    let maxOutputPixelDimension: Int
    let jpegQuality: CGFloat

    private let fileManager: FileManager
    private let imageCache = NSCache<NSString, UIImage>()

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        maxInputBytes: Int = 30_000_000,
        maxSourcePixelCount: Int = 100_000_000,
        maxOutputPixelDimension: Int = 1_600,
        jpegQuality: CGFloat = 0.82
    ) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directoryURL = directoryURL ?? documents.appendingPathComponent("GigFitMedia", isDirectory: true)
        self.fileManager = fileManager
        self.maxInputBytes = max(1, maxInputBytes)
        self.maxSourcePixelCount = max(1, maxSourcePixelCount)
        self.maxOutputPixelDimension = max(1, maxOutputPixelDimension)
        self.jpegQuality = min(1, max(0, jpegQuality))
    }

    /// Validates, orientation-normalizes, downsizes, and stores image bytes as JPEG.
    /// - Returns: A safe generated filename suitable for JSON persistence.
    func saveImageData(_ data: Data) throws -> String {
        let jpegData = try normalizedJPEGData(data)

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let filename = "package_\(UUID().uuidString.lowercased()).jpg"
            let destination = directoryURL.appendingPathComponent(filename, isDirectory: false)
            try jpegData.write(to: destination, options: .atomic)
            if let image = UIImage(data: jpegData) {
                imageCache.setObject(image, forKey: filename as NSString)
            }
            return filename
        } catch {
            throw PackageAssetStoreError.fileSystem(error.localizedDescription)
        }
    }

    /// Prepares picker bytes away from the UI thread so previewing a screenshot
    /// never retains or decodes an unbounded original image.
    func prepareImageData(_ data: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try self.normalizedJPEGData(data)
        }.value
    }

    private func normalizedJPEGData(_ data: Data) throws -> Data {
        guard !data.isEmpty else { throw PackageAssetStoreError.emptyData }
        guard data.count <= maxInputBytes else {
            throw PackageAssetStoreError.inputTooLarge(maxBytes: maxInputBytes)
        }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else {
            throw PackageAssetStoreError.invalidImage
        }

        guard width * height <= Double(maxSourcePixelCount) else {
            throw PackageAssetStoreError.imageDimensionsTooLarge(maxPixels: maxSourcePixelCount)
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxOutputPixelDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw PackageAssetStoreError.invalidImage
        }

        let targetSize = CGSize(width: thumbnail.width, height: thumbnail.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalizedImage = renderer.image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            UIImage(cgImage: thumbnail).draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpegData = normalizedImage.jpegData(compressionQuality: jpegQuality),
              !jpegData.isEmpty else {
            throw PackageAssetStoreError.encodingFailed
        }
        return jpegData
    }

    func imageData(for filename: String) throws -> Data {
        let url = try assetURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PackageAssetStoreError.assetNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty, UIImage(data: data) != nil else {
                throw PackageAssetStoreError.invalidImage
            }
            return data
        } catch let error as PackageAssetStoreError {
            throw error
        } catch {
            throw PackageAssetStoreError.fileSystem(error.localizedDescription)
        }
    }

    func image(for filename: String) throws -> UIImage {
        if let cached = imageCache.object(forKey: filename as NSString) {
            return cached
        }
        let data = try imageData(for: filename)
        guard let image = UIImage(data: data) else {
            throw PackageAssetStoreError.invalidImage
        }
        imageCache.setObject(image, forKey: filename as NSString)
        return image
    }

    struct LoadedImage: @unchecked Sendable {
        let value: UIImage
    }

    func loadImage(named filename: String) async -> UIImage? {
        if let cached = imageCache.object(forKey: filename as NSString) {
            return cached
        }
        return await Task.detached(priority: .utility) {
            try? LoadedImage(value: self.image(for: filename))
        }.value?.value
    }

    func containsAsset(named filename: String) -> Bool {
        guard let url = try? assetURL(for: filename) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    /// Idempotent deletion keeps JSON/media cleanup safe to retry.
    func deleteAsset(named filename: String) throws {
        let url = try assetURL(for: filename)
        imageCache.removeObject(forKey: filename as NSString)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw PackageAssetStoreError.fileSystem(error.localizedDescription)
        }
    }

    func assetURL(for filename: String) throws -> URL {
        guard isSafeGeneratedFilename(filename) else {
            throw PackageAssetStoreError.unsafeFilename
        }
        return directoryURL.appendingPathComponent(filename, isDirectory: false)
    }

    private func isSafeGeneratedFilename(_ filename: String) -> Bool {
        guard filename == (filename as NSString).lastPathComponent,
              filename.hasPrefix("package_"), filename.hasSuffix(".jpg") else {
            return false
        }

        let uuidText = String(filename.dropFirst("package_".count).dropLast(".jpg".count))
        return UUID(uuidString: uuidText) != nil
    }
}
