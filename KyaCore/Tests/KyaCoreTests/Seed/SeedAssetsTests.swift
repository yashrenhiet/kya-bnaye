import Foundation
import KyaCore
import Testing

/// The real bundled seed data in repo-root `seed/`, loaded from disk and run
/// through ``SeedCodec`` and ``SeedValidator`` with coverage targets, plus the
/// file-level rules a ``SeedBundle`` cannot see: I8 row order, images and
/// credits. Port of `legacy/packages/kya_core/test/seed/seed_assets_test.dart`.
@Suite("Seed assets (repo-root seed/)")
struct SeedAssetsTests {
    /// Largest allowed recipe photo (`docs/design/SEED_GUIDE.md` section 8).
    static let maxImageBytes = 60 * 1024

    /// A typical first-run pantry besides the assumed staples.
    static let firstRunPantry: Set<String> = [
        "onion", "tomato", "potato", "ginger", "garlic", "green_chilli", "curd", "milk",
        "wheat_flour", "rice", "toor_dal",
    ]

    let seedDirectory: URL
    let manifest: SeedManifest
    let dataByPath: [String: Data]
    let bundle: SeedBundle

    init() throws {
        seedDirectory = try Self.findSeedDirectory()
        let codec = SeedCodec()
        manifest = try codec.decodeManifest(
            try Self.read(SeedCodec.manifestFile, in: seedDirectory))
        var dataByPath: [String: Data] = [:]
        for path in manifest.allFiles {
            dataByPath[path] = try Self.read(path, in: seedDirectory)
        }
        self.dataByPath = dataByPath
        bundle = try codec.decode(manifest, dataByPath: dataByPath)
    }

    @Test("SeedValidator reports no issues, with coverage targets on")
    func validatorClean() {
        let directory = seedDirectory
        let issues = SeedValidator().validate(
            bundle,
            assetExists: {
                FileManager.default.fileExists(atPath: directory.appending(path: $0).path)
            },
            coverage: SeedCoverageTargets())
        #expect(
            issues.isEmpty,
            "\(issues.count) issue(s); first 30:\n\(issues.prefix(30).map(\.description).joined(separator: "\n"))"
        )
    }

    @Test("the catalogue has the frozen sizes and seed ownership")
    func sizes() {
        #expect(bundle.ingredients.count == 224)
        #expect(bundle.recipes.count == 80)
        #expect(bundle.seedVersion == manifest.seedVersion)
        #expect(bundle.recipes.allSatisfy { $0.source == .seed && !$0.isFavorite && !$0.isHidden })
        #expect(bundle.ingredients.allSatisfy { !$0.isUserCreated })
    }

    @Test("the manifest lists every fragment file on disk")
    func manifestComplete() throws {
        let resolved = seedDirectory.resolvingSymlinksInPath()
        let root = resolved.path + "/"
        let enumerator = try #require(
            FileManager.default.enumerator(at: resolved, includingPropertiesForKeys: nil))
        var onDisk: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "json" {
            let path = url.resolvingSymlinksInPath().path
            let relative = path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
            if relative != SeedCodec.manifestFile { onDisk.append(relative) }
        }
        #expect(onDisk.sorted() == manifest.allFiles.sorted())
    }

    @Test("I8: ingredient rows are sorted by id within each fragment")
    func sortedIngredientRows() throws {
        var unsorted: [String] = []
        for path in manifest.ingredientFiles {
            let root = try JSONText.object(try #require(dataByPath[path]))
            let rows = try #require(root["ingredients"] as? [[String: Any]])
            let ids = try rows.map { try #require($0["id"] as? String) }
            for (previous, id) in zip(ids, ids.dropFirst())
            where id.utf16.lexicographicallyPrecedes(previous.utf16) {
                unsorted.append("\(path): \"\(id)\" comes after \"\(previous)\"")
            }
        }
        #expect(unsorted.isEmpty, "\(unsorted)")
    }

    @Test("every name and alias resolves to its own ingredient")
    func normalizerRoundTrip() throws {
        let normalizer = try IngredientNormalizer(bundle.ingredients)
        var wrong: [String] = []
        for ingredient in bundle.ingredients {
            for text in [ingredient.name] + ingredient.aliases
            where normalizer.find(text)?.id != ingredient.id {
                wrong.append("\(ingredient.id): \"\(text)\"")
            }
        }
        #expect(wrong.isEmpty, "\(wrong)")
    }

    @Test("resolves common Hindi names exactly, never by substring")
    func hindiNames() throws {
        let normalizer = try IngredientNormalizer(bundle.ingredients)
        let expected = [
            "aloo": "potato", "Tamatar": "tomato", "rice": "rice", "chawal ka atta": "rice_flour",
            "methi": "fenugreek_leaves", "methi dana": "fenugreek_seeds",
            "sitaphal": "custard_apple", "chole": "kabuli_chana", "cornstarch": "cornflour",
        ]
        for (text, id) in expected {
            #expect(normalizer.find(text)?.id == id, "\(text)")
        }
        for ambiguous in ["sarson", "corn flour", "flour"] {
            #expect(normalizer.find(ambiguous) == nil, "\(ambiguous)")
        }
    }

    @Test("every image is referenced by a recipe and within budget")
    func images() throws {
        let imagesDirectory = seedDirectory.appending(path: "images")
        let referenced = Set(bundle.recipes.compactMap(\.imageAsset).map(Self.basename))
        var problems: [String] = []
        let files =
            FileManager.default.fileExists(atPath: imagesDirectory.path)
            ? try FileManager.default.contentsOfDirectory(
                at: imagesDirectory, includingPropertiesForKeys: [.fileSizeKey]) : []
        for file in files {
            let name = file.lastPathComponent
            if file.pathExtension != "webp" {
                problems.append("\(name) is not a .webp file")
            } else if !referenced.contains(name) {
                problems.append("\(name) is not referenced by any recipe")
            }
            let bytes = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if bytes > Self.maxImageBytes {
                problems.append("\(name) is \(bytes) bytes (max \(Self.maxImageBytes))")
            }
        }
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test("IMAGE_CREDITS.md has exactly one row per recipe image")
    func credits() throws {
        let url = seedDirectory.appending(path: "IMAGE_CREDITS.md")
        let text = try String(contentsOf: url, encoding: .utf8)
        let rows = Self.creditRows(text.components(separatedBy: .newlines))
        for row in rows {
            #expect(row.count == 9, "credit row \"\(row.joined(separator: " | "))\"")
        }
        var credited: [String: String] = [:]
        for row in rows where row.count > 1 { credited[Self.basename(row[0])] = row[1] }
        #expect(credited.count == rows.count, "duplicate file rows")
        var expected: [String: String] = [:]
        for recipe in bundle.recipes {
            if let image = recipe.imageAsset { expected[Self.basename(image)] = recipe.id }
        }
        #expect(credited == expected)
    }

    @Test("a first-run pantry gives every meal type a Kitchen deck")
    func firstRunDeck() throws {
        let known = Set(bundle.ingredients.map(\.id))
        #expect(Self.firstRunPantry.subtracting(known).isEmpty, "pantry ids missing from catalogue")
        let counts = kitchenCandidateCounts(
            recipes: bundle.recipes, catalog: bundle.ingredients, atHome: Self.firstRunPantry,
            now: try TestDates.utc(2026, 9, 26, 12), calendar: TestDates.utcCalendar)
        #expect(Set(counts.keys) == Set(MealType.allCases))
        let minimum = SeedCoverageTargets().minKitchenCandidatesPerMealType
        for meal in MealType.allCases {
            #expect((counts[meal] ?? 0) >= minimum, "\(meal): \(counts[meal] ?? 0)")
        }
    }

    // MARK: Helpers

    /// Walks up from this source file to the repository's `seed/`.
    static func findSeedDirectory(from file: String = #filePath) throws -> URL {
        var directory = URL(fileURLWithPath: file).deletingLastPathComponent()
        while true {
            let seed = directory.appending(path: "seed")
            if FileManager.default.fileExists(atPath: seed.appending(path: "manifest.json").path) {
                return seed
            }
            let parent = directory.deletingLastPathComponent()
            try #require(
                parent.path != directory.path,
                "seed/manifest.json not found above \(file) (see docs/design/SEED_GUIDE.md)")
            directory = parent
        }
    }

    static func read(_ path: String, in directory: URL) throws -> Data {
        let url = directory.appending(path: path)
        try #require(
            FileManager.default.fileExists(atPath: url.path),
            "\(path) is listed but missing: \(url.path)")
        return try Data(contentsOf: url)
    }

    /// Data rows of the first Markdown table (after its header and `|---|`
    /// separator), split into trimmed cells with backticks removed.
    static func creditRows(_ lines: [String]) -> [[String]] {
        lines.filter { $0.drop { $0 == " " || $0 == "\t" }.hasPrefix("|") }.dropFirst(2).map {
            line in
            let cells = line.trimmingCharacters(in: .whitespaces).replacingOccurrences(
                of: "`", with: ""
            )
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            return Array(cells.dropFirst().dropLast())
        }
    }

    static func basename(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? path
    }
}
