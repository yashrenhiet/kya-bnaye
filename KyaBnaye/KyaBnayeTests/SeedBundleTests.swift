import Foundation
import Testing

/// The repo-root `seed/` folder must ship inside the app bundle unchanged, because first-run
/// seeding reads it from `Bundle.main`.
struct SeedBundleTests {
    @Test("manifest.json is bundled under seed/ and lists existing fragments")
    func manifestAndFragmentsAreBundled() throws {
        let manifestURL = try #require(
            Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "seed"))
        let data = try Data(contentsOf: manifestURL)
        let manifest = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let seedVersion = try #require(manifest["seedVersion"] as? Int)
        #expect(seedVersion >= 1)

        let ingredients = try #require(manifest["ingredients"] as? [String])
        let recipes = try #require(manifest["recipes"] as? [String])
        #expect(!ingredients.isEmpty)
        #expect(!recipes.isEmpty)

        let seedDirectory = manifestURL.deletingLastPathComponent()
        for fragment in ingredients + recipes {
            let path = seedDirectory.appending(path: fragment).path(percentEncoded: false)
            #expect(FileManager.default.fileExists(atPath: path), "missing seed/\(fragment)")
        }
    }
}
