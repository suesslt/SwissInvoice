import CoreGraphics
import CoreText
import Foundation

/// Downloads Google Fonts on demand, caches them on disk, and registers them with Core Text.
public enum GoogleFontLoader {

    // MARK: - Errors

    public enum GoogleFontError: LocalizedError, Sendable {
        case cssParsingFailed
        case downloadFailed
        case registrationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .cssParsingFailed:
                "Could not find a .ttf URL in the Google Fonts CSS response."
            case .downloadFailed:
                "Failed to download the font file from Google Fonts."
            case .registrationFailed(let detail):
                "Core Text font registration failed: \(detail)"
            }
        }
    }

    // MARK: - Public API

    /// Downloads a Google Font by family name, caches the `.ttf` on disk,
    /// and registers it with Core Text for the current process.
    ///
    /// - Parameter family: The Google Fonts family name, e.g. `"Roboto"` or `"Open Sans"`.
    /// - Returns: The PostScript name of the font (e.g. `"Roboto-Regular"`), suitable for `UIFont(name:size:)`.
    @discardableResult
    public static func load(_ family: String) async throws -> String {
        let sanitized = family.replacingOccurrences(of: " ", with: "+")
        let cached = cachedFileURL(for: sanitized)

        // Already cached — just register and return the PostScript name.
        if FileManager.default.fileExists(atPath: cached.path) {
            try registerFont(at: cached)
            return try postScriptName(at: cached)
        }

        // 1. Fetch CSS from Google Fonts API.
        //    No User-Agent header — Google serves .ttf (format 'truetype') by default.
        //    Adding a browser UA causes Google to serve .woff/.woff2 instead.
        let cssURL = URL(string: "https://fonts.googleapis.com/css2?family=\(sanitized)")!
        let (cssData, _) = try await URLSession.shared.data(from: cssURL)
        guard let css = String(data: cssData, encoding: .utf8) else {
            throw GoogleFontError.cssParsingFailed
        }

        // 2. Extract the first .ttf URL from the CSS.
        guard let ttfURL = extractTTFURL(from: css) else {
            throw GoogleFontError.cssParsingFailed
        }

        // 3. Download the .ttf file.
        let (fontData, _) = try await URLSession.shared.data(from: ttfURL)
        guard !fontData.isEmpty else {
            throw GoogleFontError.downloadFailed
        }

        // 4. Write to cache.
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try fontData.write(to: cached)

        // 5. Register and return PostScript name.
        try registerFont(at: cached)
        return try postScriptName(at: cached)
    }

    /// Re-registers all previously cached `.ttf` files with Core Text.
    /// Call this at app launch so fonts from prior sessions are available immediately.
    public static func registerCachedFonts() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.pathExtension == "ttf" {
            try? registerFont(at: file)
        }
    }

    // MARK: - Private Helpers

    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GoogleFonts", isDirectory: true)
    }

    private static func cachedFileURL(for sanitizedFamily: String) -> URL {
        cacheDirectory.appendingPathComponent("\(sanitizedFamily).ttf")
    }

    private static func extractTTFURL(from css: String) -> URL? {
        let pattern = #"url\((https://fonts\.gstatic\.com/[^)]+\.ttf)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: css, range: NSRange(css.startIndex..., in: css)),
              let range = Range(match.range(at: 1), in: css)
        else { return nil }
        return URL(string: String(css[range]))
    }

    private static func registerFont(at url: URL) throws {
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !success {
            let cfError = error?.takeRetainedValue()
            // "already registered" is not a real failure.
            let code = cfError.map { CFErrorGetCode($0) } ?? 0
            // kCTFontManagerErrorAlreadyRegistered == 105
            if code != 105 {
                let desc = cfError.map { CFErrorCopyDescription($0) as String } ?? "unknown"
                throw GoogleFontError.registrationFailed(desc)
            }
        }
    }

    private static func postScriptName(at url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider),
              let psName = cgFont.postScriptName as? String
        else {
            throw GoogleFontError.registrationFailed("Could not read PostScript name from font file.")
        }
        return psName
    }
}
