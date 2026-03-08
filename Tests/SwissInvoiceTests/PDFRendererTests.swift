import Testing
import UIKit
@testable import SwissInvoice

@Suite("PDFRenderer Tests")
struct PDFRendererTests {

    // MARK: - Initialization

    @Test func defaultInit() {
        let renderer = PDFRenderer(fontName: nil, fontSize: nil)
        #expect(renderer.fontName == "Helvetica")
        #expect(renderer.fontSize == 10)
    }

    @Test func customInit() {
        let renderer = PDFRenderer(fontName: "Courier", fontSize: 14)
        #expect(renderer.fontName == "Courier")
        #expect(renderer.fontSize == 14)
    }

    // MARK: - createAttributes

    @Test func createAttributesStandard() {
        let renderer = PDFRenderer(fontName: nil, fontSize: nil)
        let attrs = renderer.createAttributes(fontType: .standard)
        #expect(attrs[.font] != nil)
        #expect(attrs[.foregroundColor] != nil)
        #expect(attrs[.paragraphStyle] != nil)
    }

    @Test func createAttributesBold() {
        let renderer = PDFRenderer(fontName: nil, fontSize: nil)
        let attrs = renderer.createAttributes(fontType: .standardBold)
        let font = attrs[.font] as? UIFont
        #expect(font != nil)
        #expect(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    @Test func createAttributesCustomFont() {
        let renderer = PDFRenderer(fontName: nil, fontSize: nil)
        let attrs = renderer.createAttributes(fontType: .textPayment)
        let font = attrs[.font] as? UIFont
        #expect(font != nil)
        // textPayment uses Helvetica
        #expect(font!.fontName.contains("Helvetica"))
    }

    // MARK: - drawEmptyLine

    @Test func drawEmptyLineReturnsHeight() {
        let renderer = PDFRenderer(fontName: nil, fontSize: nil)
        let height = renderer.drawEmptyLine(fontType: .title)
        // title fontSize is 14, lineSpacing is 1.2
        #expect(height > 0)
    }
}
