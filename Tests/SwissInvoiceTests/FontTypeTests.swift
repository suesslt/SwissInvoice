import Testing
import Foundation
import ScoreUI
@testable import SwissInvoice

@Suite("FontType Tests")
struct FontTypeTests {

    // MARK: - Font Size

    @Test func fontSizes() {
        #expect(FontType.title.fontSize == 14)
        #expect(FontType.standardFixed.fontSize == 11)
        #expect(FontType.titleReceiver.fontSize == 11)
        #expect(FontType.titlePayment.fontSize == 11)
        #expect(FontType.textPayment.fontSize == 10)
        #expect(FontType.amountPayment.fontSize == 10)
        #expect(FontType.standardSmall.fontSize == 8)
        #expect(FontType.titleInvoiceLines.fontSize == 8)
        #expect(FontType.textReceiver.fontSize == 8)
        #expect(FontType.headerPayment.fontSize == 8)
        #expect(FontType.amountReceiver.fontSize == 8)
        #expect(FontType.headerReceiver.fontSize == 6)
    }

    @Test func fontSizeNilForDefaults() {
        #expect(FontType.subject.fontSize == nil)
        #expect(FontType.standardBold.fontSize == nil)
    }

    // MARK: - Bold

    @Test func boldFonts() {
        #expect(FontType.title.isBold)
        #expect(FontType.subject.isBold)
        #expect(FontType.titleInvoiceLines.isBold)
        #expect(FontType.standardBold.isBold)
        #expect(FontType.titleReceiver.isBold)
        #expect(FontType.headerReceiver.isBold)
        #expect(FontType.titlePayment.isBold)
        #expect(FontType.headerPayment.isBold)
    }

    @Test func nonBoldFonts() {
        #expect(!FontType.standard.isBold)
        #expect(!FontType.standardFixed.isBold)
        #expect(!FontType.standardSmall.isBold)
        #expect(!FontType.textReceiver.isBold)
        #expect(!FontType.textPayment.isBold)
        #expect(!FontType.amountPayment.isBold)
        #expect(!FontType.amountReceiver.isBold)
    }

    // MARK: - Monospaced

    @Test func monospacedFonts() {
        #expect(FontType.amountPayment.isMonospaced)
        #expect(FontType.amountReceiver.isMonospaced)
    }

    @Test func nonMonospacedFonts() {
        #expect(!FontType.standard.isMonospaced)
        #expect(!FontType.title.isMonospaced)
        #expect(!FontType.textPayment.isMonospaced)
    }

    // MARK: - Font Name

    @Test func helveticaFonts() {
        #expect(FontType.titleReceiver.fontName == "Helvetica")
        #expect(FontType.headerReceiver.fontName == "Helvetica")
        #expect(FontType.textReceiver.fontName == "Helvetica")
        #expect(FontType.titlePayment.fontName == "Helvetica")
        #expect(FontType.headerPayment.fontName == "Helvetica")
        #expect(FontType.textPayment.fontName == "Helvetica")
        #expect(FontType.amountPayment.fontName == "Helvetica")
        #expect(FontType.amountReceiver.fontName == "Helvetica")
    }

    @Test func defaultFontNames() {
        #expect(FontType.standard.fontName == nil)
        #expect(FontType.title.fontName == nil)
        #expect(FontType.standardBold.fontName == nil)
    }

    // MARK: - Line Spacing

    @Test func tightLineSpacing() {
        #expect(FontType.textReceiver.lineSpacing == 1.1)
        #expect(FontType.headerReceiver.lineSpacing == 1.1)
        #expect(FontType.textPayment.lineSpacing == 1.1)
        #expect(FontType.headerPayment.lineSpacing == 1.1)
    }

    @Test func standardLineSpacing() {
        #expect(FontType.standard.lineSpacing == 1.2)
        #expect(FontType.title.lineSpacing == 1.2)
        #expect(FontType.standardBold.lineSpacing == 1.2)
    }

    // MARK: - CaseIterable

    @Test func allCases() {
        #expect(FontType.allCases.count == 19)
    }

    // MARK: - Raw Values

    @Test func rawValues() {
        #expect(FontType.title.rawValue == "Title")
        #expect(FontType.standard.rawValue == "Standard")
        #expect(FontType.amountPayment.rawValue == "Amount Payment")
    }
}
