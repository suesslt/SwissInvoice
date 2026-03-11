import Score
import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Swiss Cross Shape

/// Draws a Swiss Cross (white cross on carrier square)
/// per Swiss QR Bill specification (SIX, Version 2.x):
///   QR code:              46 × 46 mm
///   Carrier square:        7 ×  7 mm  → ratio: 7/46
///   Cross bars (W × L):  1.5 × 4.5 mm relative to carrier square
private struct SwissCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let barWidth  = s * (1.5 / 7.0)
        let barLength = s * (4.5 / 7.0)
        let cx = rect.midX
        let cy = rect.midY

        var path = Path()
        // Horizontal bar
        path.addRect(CGRect(
            x: cx - barLength / 2,
            y: cy - barWidth / 2,
            width: barLength,
            height: barWidth
        ))
        // Vertical bar
        path.addRect(CGRect(
            x: cx - barWidth / 2,
            y: cy - barLength / 2,
            width: barWidth,
            height: barLength
        ))
        return path
    }
}

// MARK: - Swiss Cross Overlay

/// QR code overlay with Swiss Cross per SIX specification.
private struct SwissCrossOverlay: View {
    private let relativeSize: CGFloat = 7.0 / 46.0
    private let whiteBorderRatio: CGFloat = 0.6 / 7.0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * relativeSize
            let borderWidth = side * whiteBorderRatio
            ZStack {
                // White background square (rounded corners)
                RoundedRectangle(cornerRadius: side * 0.1)
                    .fill(Color.white)
                    .frame(width: side + borderWidth * 2, height: side + borderWidth * 2)

                // Red carrier square (7 × 7 mm) in Swiss Red (Pantone 485 C)
                RoundedRectangle(cornerRadius: side * 0.1)
                    .fill(Color(red: 0xDA / 255.0, green: 0x29 / 255.0, blue: 0x1C / 255.0))
                    .frame(width: side, height: side)

                // White Swiss Cross
                SwissCrossShape()
                    .fill(Color.white)
                    .frame(width: side, height: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - SwissQRCodeView

/// Renders a Swiss QR Bill QR code with Swiss Cross overlay.
/// Can be initialized with a `SwissInvoice` or a raw payload string.
public struct SwissQRCodeView: View {
    private let payload: String
    private let size: CGFloat

    /// Creates a QR code view from a `SwissInvoice`.
    public init(invoice: SwissInvoice, size: CGFloat = 200) {
        self.payload = QRPayloadGenerator.generatePayload(for: invoice)
        self.size = size
    }

    /// Creates a QR code view from a raw payload string.
    public init(payload: String, size: CGFloat = 200) {
        self.payload = payload
        self.size = size
    }

    private var qrCGImage: CGImage? {
        QRCodeGenerator.generateModulesCGImage(payload: payload, pixelSize: Int(size * 3))
    }

    public var body: some View {
        if let cgImage = qrCGImage {
            #if canImport(UIKit)
            Image(uiImage: UIImage(cgImage: cgImage))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .overlay(SwissCrossOverlay())
            #elseif canImport(AppKit)
            Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: size, height: size)))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .overlay(SwissCrossOverlay())
            #endif
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }
}

struct SwissQRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        SwissQRCodeView(
            invoice: SwissInvoice(
                creditor: Address(
                    companyName: "Robert Schneider AG",
                    street: "Rue du Lac",
                    houseNumber: "1268",
                    postalCode: "2501",
                    city: "Biel",
                    countryCode: "CH"
                ),
                iban: "CH4431999123000889012",
                currency: .chf,
                debtor: Address(
                    firstName: "Pia-Maria",
                    lastName: "Rutschmann-Schnyder",
                    addressAddition2: "c/o Mark Heinz",
                    street: "Grosse Marktgasse",
                    houseNumber: "28",
                    postalCode: "9400",
                    city: "Rorschach",
                    countryCode: "CH"
                ),
                reference: "210000000003139471430009017",
                lineItems: [
                    InvoiceLineItem(
                        description: "Beratung",
                        amount: Money(amount: Decimal(string: "199.95")!, currency: .chf)
                    )
                ]
            ),
            size: 300
        )
    }
}
