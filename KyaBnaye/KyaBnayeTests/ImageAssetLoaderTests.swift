import Foundation
import Testing
import UIKit

@testable import KyaBnaye

/// ``ImageAssetLoader`` resolves ``KyaCore/Recipe/imageAsset`` paths against an injected
/// seed directory (never the real bundle here), so these run against a throwaway temporary
/// folder with a synthetic image written by the test itself.
@Suite("ImageAssetLoader")
struct ImageAssetLoaderTests {
    /// A fresh temp folder with `images/<name>` written as a small solid-colour PNG.
    private func seedDirectory(withImageNamed name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "kya-image-tests-\(UUID().uuidString)")
        let images = directory.appending(path: "images")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        let data = try #require(Self.pngData(width: 4, height: 4))
        try data.write(to: images.appending(path: name))
        return directory
    }

    private static func pngData(width: Int, height: Int) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()
    }

    @Test("no imageAsset resolves to no photo, without touching the seed directory")
    func noAsset() async throws {
        let loader = ImageAssetLoader {
            Issue.record("should not resolve a directory")
            return nil
        }
        let photo = await loader.image(for: nil)
        #expect(photo == nil)
    }

    @Test("an existing file decodes to a photo")
    func existingFile() async throws {
        let directory = try seedDirectory(withImageNamed: "dal_tadka.png")
        let loader = ImageAssetLoader { directory }

        let photo = await loader.image(for: "images/dal_tadka.png")

        #expect(photo != nil)
    }

    @Test("a path that doesn't exist on disk resolves to no photo, not a crash")
    func missingFile() async throws {
        let directory = try seedDirectory(withImageNamed: "dal_tadka.png")
        let loader = ImageAssetLoader { directory }

        let photo = await loader.image(for: "images/does_not_exist.png")

        #expect(photo == nil)
    }

    @Test("a seed directory that can't be resolved (e.g. bundle without seed/) is silent")
    func noSeedDirectory() async throws {
        let loader = ImageAssetLoader { nil }

        let photo = await loader.image(for: "images/dal_tadka.png")

        #expect(photo == nil)
    }

    @Test("the same asset returns the cached instance on a second call")
    func caches() async throws {
        let directory = try seedDirectory(withImageNamed: "dal_tadka.png")
        let loader = ImageAssetLoader { directory }

        let first = try #require(await loader.image(for: "images/dal_tadka.png"))
        let second = try #require(await loader.image(for: "images/dal_tadka.png"))

        #expect(first === second)
    }
}
