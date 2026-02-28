import Testing
import Foundation
@testable import SwissInvoice

@Suite("QR Code Generator Tests")
struct QRCodeGeneratorTests {

    @Test func generatesImage() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345\nS\nTest\nStrasse\n1\n8000\nZürich\nCH\n\n\n\n\n\n\n\n100.00\nCHF\n\n\n\n\n\n\n\nNON\n\n\nEPD\n\n"
        let image = QRCodeGenerator.generateImage(payload: payload, size: 200)
        #expect(image != nil)
    }

    @Test func correctImageSize() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345"
        let size: CGFloat = 300
        let image = QRCodeGenerator.generateImage(payload: payload, size: size)
        #expect(image != nil)
        if let image = image {
            #expect(image.size.width >= size - 1)
            #expect(image.size.height >= size - 1)
        }
    }

    @Test func emptyPayloadReturnsNil() {
        let image = QRCodeGenerator.generateImage(payload: "", size: 200)
        #expect(image == nil)
    }

    @Test func highResForPrint() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345"
        let image = QRCodeGenerator.generateImage(payload: payload, size: 130, pixelSize: 1087)
        #expect(image != nil)
        if let image = image {
            // Pixel dimensions should be 1087 (size * scale)
            let pixelWidth = image.size.width * image.scale
            #expect(abs(pixelWidth - 1087) < 2)
        }
    }

    @Test func defaultPixelSizeIsPrintQuality() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345"
        // Default pixelSize should produce 1087px (600 DPI at 46mm)
        let image = QRCodeGenerator.generateImage(payload: payload, size: 130)
        #expect(image != nil)
        if let image = image {
            let pixelWidth = image.size.width * image.scale
            #expect(pixelWidth >= 1000) // At least 1000px for print quality
        }
    }
}
