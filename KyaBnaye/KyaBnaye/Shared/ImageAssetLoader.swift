import Foundation
import UIKit

/// Decodes and caches recipe photos from the bundled `seed/images/` folder (`Recipe.imageAsset`),
/// off the main actor. A missing, unreadable or undecodable file always resolves to `nil`
/// rather than throwing: a bad photo must never block browsing recipes, so ``RecipeArtwork``
/// simply keeps showing its gradient fallback.
actor ImageAssetLoader {
    /// The shared loader, over the app bundle's `seed/` folder.
    static let shared = ImageAssetLoader { try? SeedLoader.bundled(in: .main).seedDirectory }

    private let resolveSeedDirectory: @Sendable () -> URL?
    private lazy var seedDirectory: URL? = resolveSeedDirectory()
    private var cache: [String: UIImage] = [:]

    /// Creates a loader.
    ///
    /// - Parameter seedDirectory: Resolves the folder `imageAsset` paths are relative to;
    ///   injected so tests can point at a temporary directory instead of the app bundle.
    init(seedDirectory: @escaping @Sendable () -> URL?) {
        self.resolveSeedDirectory = seedDirectory
    }

    /// The decoded, cached photo for `imageAsset` (e.g. `"images/dal_tadka.webp"`), or `nil`
    /// if it is absent, missing on disk, or not a decodable image.
    ///
    /// - Parameter imageAsset: ``KyaCore/Recipe/imageAsset``, or `nil` for "no photo yet".
    /// - Returns: The decoded photo, or `nil` if there is none, it is missing on disk, or
    ///   it failed to decode.
    func image(for imageAsset: String?) -> UIImage? {
        guard let imageAsset else { return nil }
        if let cached = cache[imageAsset] { return cached }
        guard let seedDirectory else { return nil }
        let path = seedDirectory.appending(path: imageAsset).path(percentEncoded: false)
        guard let decoded = UIImage(contentsOfFile: path) else { return nil }
        cache[imageAsset] = decoded
        return decoded
    }
}
