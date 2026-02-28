import UIKit
import CoreImage.CIFilterBuiltins

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

        // CIFilter output includes a built-in quiet zone (white border).
        // Per SIX spec, the 46mm covers only the QR modules, NOT the quiet zone.
        // We must crop the quiet zone before scaling.
        let cropped = cropQuietZone(from: ciImage)

        // Scale to target pixel size using nearest-neighbor (no interpolation = sharp modules)
        let moduleExtent = cropped.extent
        let scaleX = CGFloat(pixelSize) / moduleExtent.width
        let scaleY = CGFloat(pixelSize) / moduleExtent.height
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        // UIGraphicsImageRenderer works in POINTS — format.scale creates the pixel buffer.
        // All drawing coordinates must use the logical size, not pixel size.
        let logicalSize = CGSize(width: size, height: size)
        let drawRect = CGRect(origin: .zero, size: logicalSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = CGFloat(pixelSize) / size   // pixels / points = scale factor
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: logicalSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(drawRect)

            ctx.cgContext.interpolationQuality = .none
            UIImage(cgImage: cgImage).draw(in: drawRect)

            drawSwissCross(in: drawRect)
        }
    }

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

    /// Draws the Swiss Cross overlay into the current UIKit graphics context.
    /// `rect` is the QR code's bounding rectangle.
    public static func drawSwissCrossOverlay(in rect: CGRect) {
        drawSwissCross(in: rect)
    }

    // MARK: - Quiet Zone Cropping

    /// Crops the CIFilter's built-in quiet zone from the QR code image.
    /// This ensures the 46mm measurement covers only the QR modules.
    ///
    /// CIFilter.qrCodeGenerator() outputs transparent pixels for the quiet zone.
    /// We composite onto white first so transparent → white (opaque), then detect
    /// the first opaque black pixel to find where the modules begin.
    private static func cropQuietZone(from image: CIImage) -> CIImage {
        let extent = image.extent

        // Composite onto white so transparent quiet zone becomes opaque white.
        // Without this, transparent pixels (R=0,G=0,B=0,A=0) look like black
        // to the pixel scanner and the crop detects nothing to remove.
        let white = CIImage(color: .white).cropped(to: extent)
        let opaque = image.composited(over: white)

        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(opaque, from: extent) else { return image }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 2, height > 2 else { return image }

        // Get pixel data
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return image }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        // Find first non-white row from top
        var topCrop = 0
        outer: for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if ptr[offset] == 0 { // black pixel found
                    topCrop = y
                    break outer
                }
            }
        }

        // Find first non-white column from left
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

        // Symmetric crop (quiet zone is same on all sides)
        let cropRect = CGRect(
            x: extent.origin.x + CGFloat(leftCrop),
            y: extent.origin.y + CGFloat(topCrop),
            width: extent.width - CGFloat(leftCrop * 2),
            height: extent.height - CGFloat(topCrop * 2)
        )

        // Return the opaque version (white background) so downstream
        // consumers don't have to deal with transparency.
        return opaque.cropped(to: cropRect)
    }

    // MARK: - Swiss Cross

    /// Draws the Swiss Cross (red square + white cross) per SIX specification.
    private static func drawSwissCross(in rect: CGRect) {
        let qr = min(rect.width, rect.height)

        // Carrier square: 7mm at 46mm QR code
        let squareSide = qr * (7.0 / 46.0)
        let squareX = rect.midX - squareSide / 2
        let squareY = rect.midY - squareSide / 2
        let squareRect = CGRect(x: squareX, y: squareY, width: squareSide, height: squareSide)

        // White border around carrier square
        let borderWidth = squareSide * (0.6 / 7.0)
        let borderRect = squareRect.insetBy(dx: -borderWidth, dy: -borderWidth)
        let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: squareSide * 0.1)
        UIColor.white.setFill()
        borderPath.fill()

        // Red carrier square (Pantone 485 C)
        let redPath = UIBezierPath(roundedRect: squareRect, cornerRadius: squareSide * 0.1)
        UIColor(red: 1.0, green: 0.0, blue: 0.063, alpha: 1.0).setFill()
        redPath.fill()

        // Cross bars: 1.5mm wide, 4.5mm long (relative to 7mm square)
        let barWidth  = squareSide * (1.5 / 7.0)
        let barLength = squareSide * (4.5 / 7.0)
        UIColor.white.setFill()
        // Horizontal bar
        UIRectFill(CGRect(
            x: rect.midX - barLength / 2,
            y: rect.midY - barWidth  / 2,
            width: barLength, height: barWidth
        ))
        // Vertical bar
        UIRectFill(CGRect(
            x: rect.midX - barWidth  / 2,
            y: rect.midY - barLength / 2,
            width: barWidth, height: barLength
        ))
    }
}
