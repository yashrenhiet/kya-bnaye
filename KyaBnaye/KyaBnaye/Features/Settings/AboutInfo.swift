import Foundation

/// One photo credit from `seed/IMAGE_CREDITS.md`.
struct ImageCredit: Identifiable, Equatable, Sendable {
    /// The image file, e.g. `images/poha.webp`.
    let file: String
    /// The photo's title.
    let title: String
    /// Who took it.
    let author: String
    /// The licence name, e.g. `CC0`.
    let licence: String
    /// Where it came from.
    let sourceURL: URL?

    var id: String { file }
}

/// Facts for the About section: the app version and the photo credits bundled with the
/// seed data.
enum AboutInfo {
    /// "0.1.0 (1)" from the bundle's Info.plist, or "unknown" if it's missing.
    static func version(in bundle: Bundle = .main) -> String {
        let info = bundle.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? String(localized: "unknown")
        guard let build = info["CFBundleVersion"] as? String else { return short }
        return "\(short) (\(build))"
    }

    /// The credits in `seed/IMAGE_CREDITS.md` inside `bundle`.
    ///
    /// - Throws: A file error if the credits file is missing or unreadable.
    static func imageCredits(in bundle: Bundle = .main) throws -> [ImageCredit] {
        guard
            let url = bundle.url(
                forResource: "IMAGE_CREDITS", withExtension: "md", subdirectory: "seed")
        else { throw CocoaError(.fileNoSuchFile) }
        return parseCredits(try String(contentsOf: url, encoding: .utf8))
    }

    /// Parses the credits table: the rows after the header row that starts with `| file |`,
    /// with columns file, recipe id, title, author, source URL, licence, …. Rows with too
    /// few columns are skipped.
    static func parseCredits(_ markdown: String) -> [ImageCredit] {
        let lines = markdown.split(separator: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let header = lines.firstIndex(where: { $0.hasPrefix("| file |") }) else { return [] }
        return lines.dropFirst(header + 2)
            .prefix { $0.hasPrefix("|") }
            .compactMap { line in
                let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                    .dropFirst()
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard cells.count >= 6, !cells[0].isEmpty else { return nil }
                return ImageCredit(
                    file: cells[0], title: cells[2], author: cells[3], licence: cells[5],
                    sourceURL: URL(string: cells[4]))
            }
    }
}
