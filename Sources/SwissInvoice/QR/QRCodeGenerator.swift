#if canImport(UIKit)
import UIKit
#endif
import CoreGraphics
import CoreImage.CIFilterBuiltins
import CoreText

/// Generates a QR code bitmap with Swiss Cross overlay per SIX specification.
///
/// Key specs (SIX v2.3):
/// - QR code: exactly 46 x 46 mm **without** quiet zone
/// - Quiet zone: 5mm (external, not part of the 46mm)
/// - Swiss cross: 7 x 7 mm carrier, centered
/// - Error correction: Level M (15%)
/// - Minimum module size for print: 0.4mm
/// - Recommended: 300 DPI → 543px, 600 DPI → 1087px
public enum QRCodeGenerator {

    /// Default pixel resolution for print-quality QR codes (600 DPI at 46mm).
    public static let printPixelSize: CGFloat = 1087

    #if canImport(UIKit)
    /// Generates a QR code UIImage from a payload string, with Swiss Cross overlay.
    /// - Parameters:
    ///   - payload: The SPC payload string.
    ///   - size: The desired image size in points (for screen display).
    ///   - pixelSize: Pixel resolution of the generated bitmap.
    ///     Defaults to 1087 (600 DPI at 46mm) for print-sharp output.
    /// - Returns: A UIImage with the QR code and Swiss Cross, or nil on failure.
    public static func generateImage(
        payload: String,
        size: CGFloat,
        pixelSize: Int = 1087
    ) -> UIImage? {
        guard !payload.isEmpty else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.correctionLevel = "M"
        guard let data = payload.data(using: .utf8) else { return nil }
        filter.message = data
        guard let ciImage = filter.outputImage else { return nil }

        let cropped = cropQuietZone(from: ciImage)

        let moduleExtent = cropped.extent
        let scaleX = CGFloat(pixelSize) / moduleExtent.width
        let scaleY = CGFloat(pixelSize) / moduleExtent.height
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let logicalSize = CGSize(width: size, height: size)
        let drawRect = CGRect(origin: .zero, size: logicalSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = CGFloat(pixelSize) / size
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: logicalSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(drawRect)

            ctx.cgContext.interpolationQuality = .none
            UIImage(cgImage: cgImage).draw(in: drawRect)

            drawSwissCrossUIKit(in: drawRect)
        }
    }
    #endif

    /// Returns a CGImage of the QR modules only (no Swiss Cross, no quiet zone),
    /// scaled to `pixelSize` pixels. Used by the PDF renderer for exact sizing.
    public static func generateModulesCGImage(payload: String, pixelSize: Int = 1087) -> CGImage? {
        guard !payload.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.correctionLevel = "M"
        guard let data = payload.data(using: .utf8) else { return nil }
        filter.message = data
        guard let ciImage = filter.outputImage else { return nil }

        let cropped = cropQuietZone(from: ciImage)
        let extent = cropped.extent
        let scaleX = CGFloat(pixelSize) / extent.width
        let scaleY = CGFloat(pixelSize) / extent.height
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }

    /// Draws the Swiss Cross overlay into a CGContext (CoreGraphics).
    /// `rect` is the QR code's bounding rectangle in CoreGraphics coordinates.
    public static func drawSwissCrossOverlay(in rect: CGRect, context: CGContext) {
        drawSwissCrossCG(in: rect, context: context)
    }

    #if canImport(UIKit)
    /// Draws the Swiss Cross overlay into the current UIKit graphics context.
    /// `rect` is the QR code's bounding rectangle.
    public static func drawSwissCrossOverlay(in rect: CGRect) {
        drawSwissCrossUIKit(in: rect)
    }
    #endif

    // MARK: - Quiet Zone Cropping

    private static func cropQuietZone(from image: CIImage) -> CIImage {
        let extent = image.extent

        let white = CIImage(color: .white).cropped(to: extent)
        let opaque = image.composited(over: white)

        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(opaque, from: extent) else { return image }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 2, height > 2 else { return image }

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return image }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        var topCrop = 0
        outer: for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if ptr[offset] == 0 {
                    topCrop = y
                    break outer
                }
            }
        }

        var leftCrop = 0
        outer2: for x in 0..<width {
            for y in 0..<height {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if ptr[offset] == 0 {
                    leftCrop = x
                    break outer2
                }
            }
        }

        let cropRect = CGRect(
            x: extent.origin.x + CGFloat(leftCrop),
            y: extent.origin.y + CGFloat(topCrop),
            width: extent.width - CGFloat(leftCrop * 2),
            height: extent.height - CGFloat(topCrop * 2)
        )

        return opaque.cropped(to: cropRect)
    }

    // MARK: - Swiss Cross (CoreGraphics)

    /// Draws the Swiss Cross using CoreGraphics (cross-platform).
    private static func drawSwissCrossCG(in rect: CGRect, context ctx: CGContext) {
        let qr = min(rect.width, rect.height)

        // Carrier square: 7mm at 46mm QR code
        let squareSide = qr * (7.0 / 46.0)
        let squareX = rect.midX - squareSide / 2
        let squareY = rect.midY - squareSide / 2
        let squareRect = CGRect(x: squareX, y: squareY, width: squareSide, height: squareSide)

        // White border around carrier square
        let borderWidth = squareSide * (0.6 / 7.0)
        let borderRect = squareRect.insetBy(dx: -borderWidth, dy: -borderWidth)
        let cornerRadius = squareSide * 0.1

        ctx.saveGState()

        // White border rounded rect
        let borderPath = CGPath(roundedRect: borderRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        ctx.addPath(borderPath)
        ctx.fillPath()

        // Red carrier square (Pantone 485 C)
        let redPath = CGPath(roundedRect: squareRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.setFillColor(CGColor(srgbRed: 0xDA / 255.0, green: 0x29 / 255.0, blue: 0x1C / 255.0, alpha: 1.0))
        ctx.addPath(redPath)
        ctx.fillPath()

        // Cross bars: 1.5mm wide, 4.5mm long (relative to 7mm square)
        let barWidth = squareSide * (1.5 / 7.0)
        let barLength = squareSide * (4.5 / 7.0)
        ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        // Horizontal bar
        ctx.fill(CGRect(
            x: rect.midX - barLength / 2,
            y: rect.midY - barWidth / 2,
            width: barLength, height: barWidth
        ))
        // Vertical bar
        ctx.fill(CGRect(
            x: rect.midX - barWidth / 2,
            y: rect.midY - barLength / 2,
            width: barWidth, height: barLength
        ))

        ctx.restoreGState()
    }

    // MARK: - Swiss Cross (UIKit)

    #if canImport(UIKit)
    /// Draws the Swiss Cross (red square + white cross) per SIX specification using UIKit.
    private static func drawSwissCrossUIKit(in rect: CGRect) {
        let qr = min(rect.width, rect.height)

        let squareSide = qr * (7.0 / 46.0)
        let squareX = rect.midX - squareSide / 2
        let squareY = rect.midY - squareSide / 2
        let squareRect = CGRect(x: squareX, y: squareY, width: squareSide, height: squareSide)

        let borderWidth = squareSide * (0.6 / 7.0)
        let borderRect = squareRect.insetBy(dx: -borderWidth, dy: -borderWidth)
        let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: squareSide * 0.1)
        UIColor.white.setFill()
        borderPath.fill()

        let redPath = UIBezierPath(roundedRect: squareRect, cornerRadius: squareSide * 0.1)
        UIColor(red: 0xDA / 255.0, green: 0x29 / 255.0, blue: 0x1C / 255.0, alpha: 1.0).setFill()
        redPath.fill()

        let barWidth = squareSide * (1.5 / 7.0)
        let barLength = squareSide * (4.5 / 7.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(
            x: rect.midX - barLength / 2,
            y: rect.midY - barWidth / 2,
            width: barLength, height: barWidth
        ))
        UIRectFill(CGRect(
            x: rect.midX - barWidth / 2,
            y: rect.midY - barLength / 2,
            width: barWidth, height: barLength
        ))
    }
    #endif
}
