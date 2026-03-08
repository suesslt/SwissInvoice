import Testing
import Foundation
@testable import SwissInvoice

@Suite("GoogleFontLoader Tests")
struct GoogleFontLoaderTests {

    // MARK: - Error Descriptions

    @Test func cssParsingFailedDescription() {
        let error = GoogleFontLoader.GoogleFontError.cssParsingFailed
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("ttf"))
    }

    @Test func downloadFailedDescription() {
        let error = GoogleFontLoader.GoogleFontError.downloadFailed
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("download"))
    }

    @Test func registrationFailedDescription() {
        let error = GoogleFontLoader.GoogleFontError.registrationFailed("test error")
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("test error"))
    }

    // MARK: - registerCachedFonts

    @Test func registerCachedFontsDoesNotCrash() {
        // Should not throw even if cache directory doesn't exist
        GoogleFontLoader.registerCachedFonts()
    }
}
