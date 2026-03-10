import Testing
import Foundation
@testable import SwissInvoice

@Suite("QR Code Generator Tests")
struct QRCodeGeneratorTests {

    // MARK: - generateImage (UIKit only)

    #if canImport(UIKit)
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
            let pixelWidth = image.size.width * image.scale
            #expect(abs(pixelWidth - 1087) < 2)
        }
    }

    @Test func defaultPixelSizeIsPrintQuality() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345"
        let image = QRCodeGenerator.generateImage(payload: payload, size: 130)
        #expect(image != nil)
        if let image = image {
            let pixelWidth = image.size.width * image.scale
            #expect(pixelWidth >= 1000)
        }
    }
    #endif

    // MARK: - generateModulesCGImage

    @Test func generateModulesCGImageReturnsImage() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345"
        let cgImage = QRCodeGenerator.generateModulesCGImage(payload: payload)
        #expect(cgImage != nil)
    }

    @Test func generateModulesCGImageCorrectSize() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345"
        let pixelSize = 1087
        let cgImage = QRCodeGenerator.generateModulesCGImage(payload: payload, pixelSize: pixelSize)
        #expect(cgImage != nil)
        if let cgImage = cgImage {
            #expect(abs(cgImage.width - pixelSize) < 2)
            #expect(abs(cgImage.height - pixelSize) < 2)
        }
    }

    @Test func generateModulesCGImageEmptyPayload() {
        let cgImage = QRCodeGenerator.generateModulesCGImage(payload: "")
        #expect(cgImage == nil)
    }

    @Test func generateModulesCGImageCustomPixelSize() {
        let payload = "SPC\n0200\n1\nCH1230000000000012345"
        let cgImage = QRCodeGenerator.generateModulesCGImage(payload: payload, pixelSize: 543)
        #expect(cgImage != nil)
        if let cgImage = cgImage {
            #expect(abs(cgImage.width - 543) < 2)
        }
    }

    // MARK: - printPixelSize constant

    @Test func printPixelSizeIs1087() {
        #expect(QRCodeGenerator.printPixelSize == 1087)
    }
}
