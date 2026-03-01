import UIKit
import CoreImage.CIFilterBuiltins
import CoreGraphics
import SwiftUI

// MARK: - PDF Measurements (points at 72 dpi)
// 1 mm = 72/25.4 pt ≈ 2.8346 pt

private enum PDFMass {
    static let ptPerMm: CGFloat       = 72.0 / 25.4

    // A4
    static let pageWidth: CGFloat     = 210 * ptPerMm   // 595.28 pt
    static let pageHeight: CGFloat    = 297 * ptPerMm   // 841.89 pt

    // Margins
    static let marginLeft: CGFloat    = 20  * ptPerMm
    static let marginRight: CGFloat   = 10  * ptPerMm   // SN 10130: min 10 mm

    // SN 10130:2026 – Vertical zones
    static let briefkopfBottom: CGFloat  = 38 * ptPerMm  // 107.72 pt
    static let adressfeldTop: CGFloat    = 38 * ptPerMm  // 107.72 pt
    static let adressfeldWidth: CGFloat  = 100 * ptPerMm // 283.46 pt (Normfenster)
    static let adressfeldHeight: CGFloat = 45 * ptPerMm  // 127.56 pt (Normfenster)
    static let adressfeldZoneBottom: CGFloat = 97 * ptPerMm // 274.96 pt
    static let ruhezone: CGFloat         = 3 * ptPerMm   // 8.50 pt min gap

    // Rechtsadressierung: right address field X position
    static let rechtsAdresseX: CGFloat   = 125 * ptPerMm // 354.33 pt

    // Leitwörterbereich (below address zone, §5)
    static let leitwoerterMinY: CGFloat  = 111 * ptPerMm // 314.65 pt (97 + 14 mm)

    // Falzmarken (fold/punch marks)
    static let falzmarkeOben: CGFloat    = 99 * ptPerMm    // 280.63 pt
    static let lochmarke: CGFloat        = 148.5 * ptPerMm // 420.94 pt
    static let falzmarkeUnten: CGFloat   = 210 * ptPerMm   // 595.28 pt

    // Payment part (SIX Swiss QR Bill specification)
    static let zahlteilHeight: CGFloat = 103 * ptPerMm
    static let qrCodeSize: CGFloat     =  46 * ptPerMm  // 130.39 pt — exactly 46 mm
    static let qrLeft: CGFloat         =   5 * ptPerMm
    static let qrTop: CGFloat          =  17 * ptPerMm

    // Receipt (Empfangsschein) — 60mm wide, left side
    static let receiptWidth: CGFloat   =  60 * ptPerMm
    // Payment part (Zahlteil) — 150mm wide, right side
    static let paymentPartWidth: CGFloat = 150 * ptPerMm

    // Vertical separator between receipt and payment part
    static let verticalSepX: CGFloat   =  60 * ptPerMm

    // Fonts
    static let fontTitle: CGFloat      = 14
    static let fontHeading: CGFloat    = 8
    static let fontBody: CGFloat       = 10
    static let fontSmall: CGFloat      = 8

    // Receipt-specific fonts (smaller per SIX spec)
    static let fontReceiptTitle: CGFloat = 11
    static let fontReceiptHeading: CGFloat = 6
    static let fontReceiptBody: CGFloat = 8
}

// MARK: - Font Provider

private struct FontProvider {
    let name: String

    init(requestedName: String?) {
        if let requested = requestedName,
           UIFont(name: requested, size: 10) != nil {
            self.name = requested
        } else {
            self.name = "Helvetica"
        }
    }

    func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont(name: name, size: size)
                   ?? UIFont(name: "Helvetica", size: size)!
        let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: weight]
        let descriptor = base.fontDescriptor.addingAttributes(
            [.traits: traits]
        )
        return UIFont(descriptor: descriptor, size: size)
    }

    func font(size: CGFloat) -> UIFont {
        font(size: size, weight: .regular)
    }

    func monospacedDigitFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = font(size: size, weight: weight)
        let features: [[UIFontDescriptor.FeatureKey: Any]] = [[
            .type: kNumberSpacingType,
            .selector: kMonospacedNumbersSelector
        ]]
        let descriptor = base.fontDescriptor.addingAttributes(
            [.featureSettings: features]
        )
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Invoice Font Sizes (upper part only)

/// Derives heading, body, and small font sizes from a single base body size.
private struct InvoiceFontSizes {
    let heading: CGFloat
    let body: CGFloat
    let small: CGFloat

    init(body: CGFloat) {
        self.body = body
        self.heading = max(body - 2, 8)
        self.small = max(body - 4, 7)
    }
}

// MARK: - Renderer

/// Renders a complete A4 invoice PDF with Swiss QR Bill payment part and receipt.
public enum InvoicePDFRenderer {

    /// Renders the invoice as PDF data.
    /// - Parameter invoice: The `SwissInvoice` to render.
    /// - Returns: PDF data for the A4 page.
    public static func render(invoice: SwissInvoice) -> Data {
        let pageRect = CGRect(
            x: 0, y: 0,
            width: PDFMass.pageWidth,
            height: PDFMass.pageHeight
        )
        let fonts = FontProvider(requestedName: invoice.fontName)
        let sizes = InvoiceFontSizes(body: invoice.fontSize ?? 10)
        let slipFonts = FontProvider(requestedName: nil) // Always Helvetica per SIX spec
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext

            // Upper part (SN 10130:2026)
            drawBriefkopf(invoice: invoice, fonts: fonts, sizes: sizes, in: cgCtx, pageRect: pageRect)
            drawAdressfeldbereich(invoice: invoice, fonts: fonts, sizes: sizes, in: cgCtx, pageRect: pageRect)
            drawFalzmarken(in: cgCtx)

            // Leitwörter (Datum, Referenz) at ≥111 mm per §5
            let hasLeitwoerter = invoice.invoiceDate != nil || (invoice.reference?.isEmpty == false)
            let afterLeitwoerterY: CGFloat
            if hasLeitwoerter {
                afterLeitwoerterY = drawLeitwoerter(invoice: invoice, fonts: fonts, sizes: sizes, in: cgCtx)
            } else {
                afterLeitwoerterY = PDFMass.adressfeldZoneBottom
            }

            // Betreff (subject line) — 2 empty lines below Leitwörter (or address zone)
            let lineHeight = sizes.body + sizes.body * 0.2
            var contentStartY = afterLeitwoerterY + 2 * lineHeight
            if let subject = invoice.subject, !subject.isEmpty {
                let betreffAttr: [NSAttributedString.Key: Any] = [
                    .font: fonts.font(size: sizes.body, weight: .bold)
                ]
                (subject as NSString).draw(
                    at: CGPoint(x: PDFMass.marginLeft, y: contentStartY),
                    withAttributes: betreffAttr
                )
                // 1 empty line after Betreff before content
                contentStartY += sizes.body + lineHeight
            }

            // Content (line items table)
            drawLineItems(invoice: invoice, fonts: fonts, sizes: sizes, in: cgCtx, pageRect: pageRect, startY: contentStartY)

            // Lower part (unchanged — SIX Swiss QR Bill)
            drawPaymentPart(invoice: invoice, fonts: slipFonts, in: cgCtx, pageRect: pageRect)
            drawReceipt(invoice: invoice, fonts: slipFonts, in: cgCtx, pageRect: pageRect)
        }
    }

    // MARK: - Briefkopf (0 – 38 mm)

    /// Draws the letterhead zone: creditor name/address on the left, document title right-aligned.
    private static func drawBriefkopf(invoice: SwissInvoice, fonts: FontProvider, sizes: InvoiceFontSizes, in ctx: CGContext, pageRect: CGRect) {
        let x = PDFMass.marginLeft
        let rightEdge = pageRect.width - PDFMass.marginRight
        var y: CGFloat = 12 * PDFMass.ptPerMm  // Start at 12 mm from top

        // Creditor name (bold, 14pt)
        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: 14, weight: .bold)
        ]
        invoice.creditor.name.draw(at: CGPoint(x: x, y: y), withAttributes: nameAttr)
        y += 14 + 4

        // Creditor address lines (9pt)
        let addrAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: 9),
            .foregroundColor: UIColor.darkGray
        ]
        let creditorLines = buildAddressLines(invoice.creditor, includeName: false)
        for line in creditorLines {
            line.draw(at: CGPoint(x: x, y: y), withAttributes: addrAttr)
            y += 9 + 2
        }

        // Document title (right-aligned, bold)
        let title = invoice.title ?? "Rechnung"
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.body + 4, weight: .bold)
        ]
        let titleWidth = (title as NSString).size(withAttributes: titleAttr).width
        (title as NSString).draw(
            at: CGPoint(x: rightEdge - titleWidth, y: 12 * PDFMass.ptPerMm),
            withAttributes: titleAttr
        )
    }

    // MARK: - Adressfeldbereich (38 – 97 mm) – Rechtsadressierung per SN 10130:2026 §4.3

    /// Draws the address field zone: creditor (left), Absenderzeile + debtor as recipient (right).
    private static func drawAdressfeldbereich(invoice: SwissInvoice, fonts: FontProvider, sizes: InvoiceFontSizes, in ctx: CGContext, pageRect: CGRect) {
        let addressAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: 10)
        ]

        // Left: Creditor address — 10pt, sans-serif, no bold per SN 10130
        let leftX = PDFMass.marginLeft
        var leftY = PDFMass.adressfeldTop + 2 * PDFMass.ptPerMm

        let creditorLines = buildAddressLines(invoice.creditor, includeName: true)
        for line in creditorLines {
            (line as NSString).draw(at: CGPoint(x: leftX, y: leftY), withAttributes: addressAttr)
            leftY += 10 + 2
        }

        // Right: Absenderzeile (sender line) — 7pt, underlined, secondary color
        let rightX = PDFMass.rechtsAdresseX
        var rightY = PDFMass.adressfeldTop + 2 * PDFMass.ptPerMm

        let senderLine = buildSenderLine(invoice.creditor)
        let senderAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: 7),
            .foregroundColor: UIColor.secondaryLabel,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        (senderLine as NSString).draw(at: CGPoint(x: rightX, y: rightY), withAttributes: senderAttr)
        rightY += 7 + PDFMass.ruhezone  // Ruhezone: min 3 mm gap

        // Right: Debtor as recipient — 10pt, sans-serif, no bold per SN 10130
        if let debtor = invoice.debtor {
            let debtorLines = buildAddressLines(debtor, includeName: true)
            for line in debtorLines {
                (line as NSString).draw(at: CGPoint(x: rightX, y: rightY), withAttributes: addressAttr)
                rightY += 10 + 2
            }
        }
    }

    // MARK: - Leitwörterbereich (≥ 111 mm) per SN 10130:2026 §5

    /// Draws Datum and Referenz in the Leitwörterbereich below the address zone.
    /// Returns the Y position after the last entry.
    @discardableResult
    private static func drawLeitwoerter(invoice: SwissInvoice, fonts: FontProvider, sizes: InvoiceFontSizes, in ctx: CGContext) -> CGFloat {
        let x = PDFMass.marginLeft
        var y = PDFMass.leitwoerterMinY
        let valueX = x + 22 * PDFMass.ptPerMm  // Tab stop for values

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.body),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.body)
        ]

        // Date
        if let date = invoice.invoiceDate {
            "Datum:".draw(at: CGPoint(x: x, y: y), withAttributes: labelAttr)
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.locale = Locale(identifier: "de_CH")
            let dateStr = formatter.string(from: date)
            dateStr.draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttr)
            y += sizes.body + 2
        }

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            "Referenz:".draw(at: CGPoint(x: x, y: y), withAttributes: labelAttr)
            reference.draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttr)
            y += sizes.body + 2
        }

        return y
    }

    // MARK: - Falzmarken (fold/punch marks)

    /// Draws fold and punch marks at the left edge per SN 10130:2026.
    private static func drawFalzmarken(in ctx: CGContext) {
        let markLength: CGFloat = 4 * PDFMass.ptPerMm  // 4 mm mark
        let marks = [PDFMass.falzmarkeOben, PDFMass.lochmarke, PDFMass.falzmarkeUnten]

        ctx.saveGState()
        ctx.setStrokeColor(UIColor.separator.cgColor)
        ctx.setLineWidth(0.3)
        for markY in marks {
            ctx.move(to: CGPoint(x: 0, y: markY))
            ctx.addLine(to: CGPoint(x: markLength, y: markY))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Line Items Table

    private static func drawLineItems(invoice: SwissInvoice, fonts: FontProvider, sizes: InvoiceFontSizes, in ctx: CGContext, pageRect: CGRect, startY: CGFloat) {
        var y = startY
        let x = PDFMass.marginLeft
        let rightEdge = pageRect.width - PDFMass.marginRight
        let contentWidth = rightEdge - x

        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.small, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.body)
        ]
        let monoAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: sizes.body, weight: .regular)
        ]
        let boldMonoAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: sizes.body, weight: .bold)
        ]

        if !invoice.lineItems.isEmpty {
            // Column positions
            let colDescription = x
            let colQuantity = x + contentWidth * 0.50
            let colUnit = x + contentWidth * 0.60
            let colUnitPrice = x + contentWidth * 0.70
            let colAmount = rightEdge

            // Table header
            "Description".draw(at: CGPoint(x: colDescription, y: y), withAttributes: headerAttr)
            "Qty".draw(at: CGPoint(x: colQuantity, y: y), withAttributes: headerAttr)
            "Unit".draw(at: CGPoint(x: colUnit, y: y), withAttributes: headerAttr)
            drawRightAligned("Unit Price", at: CGPoint(x: colAmount - 60, y: y), attributes: headerAttr)
            drawRightAligned("Amount", at: CGPoint(x: colAmount, y: y), attributes: headerAttr)
            y += sizes.small + 4

            drawHRule(in: ctx, y: y, from: x, to: rightEdge, lineWidth: 0.3)
            y += 4

            // Line items
            for item in invoice.lineItems {
                (item.description as NSString).draw(
                    in: CGRect(x: colDescription, y: y, width: colQuantity - colDescription - 4, height: sizes.body + 4),
                    withAttributes: bodyAttr
                )

                if let qty = item.quantity {
                    let qtyStr = "\(qty)"
                    qtyStr.draw(at: CGPoint(x: colQuantity, y: y), withAttributes: monoAttr)
                }

                if let unit = item.unit {
                    unit.draw(at: CGPoint(x: colUnit, y: y), withAttributes: bodyAttr)
                }

                if let unitPrice = item.unitPrice {
                    drawRightAligned(unitPrice.formattedShort, at: CGPoint(x: colAmount - 60, y: y), attributes: monoAttr)
                }

                drawRightAligned(item.amount.formattedShort, at: CGPoint(x: colAmount, y: y), attributes: monoAttr)
                y += sizes.body + 4
            }

            // Separator before total
            drawHRule(in: ctx, y: y, from: x, to: rightEdge, lineWidth: 0.3)
            y += 6
        }

        // Total
        let totalLabel = "Total"
        let totalLabelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.body, weight: .bold)
        ]
        (totalLabel as NSString).draw(at: CGPoint(x: x + contentWidth * 0.50, y: y), withAttributes: totalLabelAttr)
        drawRightAligned(invoice.amount.formatted, at: CGPoint(x: rightEdge, y: y), attributes: boldMonoAttr)
    }

    // MARK: - Payment Part (Zahlteil) — right 148mm

    private static func drawPaymentPart(invoice: SwissInvoice, fonts: FontProvider, in ctx: CGContext, pageRect: CGRect) {
        let zahlteilY = pageRect.height - PDFMass.zahlteilHeight

        // Horizontal dashed separator with scissors
        drawZahlteilSeparator(in: ctx, y: zahlteilY, pageRect: pageRect)

        // Vertical dashed separator between receipt and payment part
        drawVerticalSeparator(in: ctx, x: PDFMass.verticalSepX, fromY: zahlteilY, toY: pageRect.height)

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: 11, weight: .bold)
        ]

        // Left column: QR code + Currency/Amount
        let leftColX = PDFMass.verticalSepX + 5 * PDFMass.ptPerMm
        var y = zahlteilY + 10

        "Zahlteil".draw(at: CGPoint(x: leftColX, y: y), withAttributes: titleAttr)
        y += 20 * PDFMass.ptPerMm  // exactly 2 cm below title

        // QR Code (exactly 46mm per SIX spec, modules only + vector Swiss Cross)
        // The PDF context renders the image ~4.5% smaller than the specified rect.
        // We compensate by drawing into a rect scaled by 46/44 ≈ 1.04545.
        let payload = QRPayloadGenerator.generatePayload(for: invoice)
        if let modulesCGImage = QRCodeGenerator.generateModulesCGImage(
            payload: payload,
            pixelSize: Int(QRCodeGenerator.printPixelSize)
        ) {
            let qrScale: CGFloat = 46.0 / 44.0
            let qrDrawSize = PDFMass.qrCodeSize * qrScale
            let qrInset = (PDFMass.qrCodeSize - qrDrawSize) / 2  // negative → expands
            let qrRect = CGRect(
                x: leftColX + 2 * PDFMass.ptPerMm,
                y: y,
                width: PDFMass.qrCodeSize,
                height: PDFMass.qrCodeSize
            )
            let qrDrawRect = qrRect.insetBy(dx: qrInset, dy: qrInset)
            UIImage(cgImage: modulesCGImage).draw(in: qrDrawRect)
            QRCodeGenerator.drawSwissCrossOverlay(in: qrDrawRect)
            y += PDFMass.qrCodeSize + 8
        }

        // Currency & Amount below QR code
        let headingAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontHeading, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let monoAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: PDFMass.fontBody, weight: .bold)
        ]
        let monoSmallAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: PDFMass.fontBody, weight: .regular)
        ]

        "Währung".draw(at: CGPoint(x: leftColX, y: y), withAttributes: headingAttr)
        "Betrag".draw(at: CGPoint(x: leftColX + 30 * PDFMass.ptPerMm, y: y), withAttributes: headingAttr)
        y += PDFMass.fontHeading + 3
        invoice.amount.currency.rawValue.draw(at: CGPoint(x: leftColX, y: y), withAttributes: monoSmallAttr)
        if !invoice.amount.isZero {
            invoice.amount.formattedShort.draw(at: CGPoint(x: leftColX + 30 * PDFMass.ptPerMm, y: y), withAttributes: monoAttr)
        }

        // Right column: Payment info
        let rightColX = leftColX + PDFMass.qrCodeSize + 8 * PDFMass.ptPerMm
        var ry = zahlteilY + 10 + 20 * PDFMass.ptPerMm  // align with QR code

        let smallLabelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontSmall + 1, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let smallLabelBoldAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontSmall + 1, weight: .bold)
        ]
        let smallBoldAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontSmall + 1, weight: .semibold)
        ]
        let smallBodyAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontSmall + 1)
        ]

        // Account / Payable to
        "Konto / Zahlbar an".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallLabelBoldAttr)
        ry += PDFMass.fontSmall + 3
        invoice.iban.draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBodyAttr)
        ry += PDFMass.fontSmall + 4
        invoice.creditor.name.draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBoldAttr)
        ry += PDFMass.fontSmall + 4
        "\(invoice.creditor.street) \(invoice.creditor.houseNumber)".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBodyAttr)
        ry += PDFMass.fontSmall + 4
        "\(invoice.creditor.postalCode) \(invoice.creditor.city)".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBodyAttr)
        ry += PDFMass.fontSmall + 10

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            "Referenz".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallLabelAttr)
            ry += PDFMass.fontSmall + 3
            reference.draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBodyAttr)
            ry += PDFMass.fontSmall + 10
        }

        // Additional info
        if let info = invoice.additionalInfo, !info.isEmpty {
            "Zusätzliche Informationen".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallLabelAttr)
            ry += PDFMass.fontSmall + 3
            info.draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBodyAttr)
            ry += PDFMass.fontSmall + 10
        }

        // Payable by
        if let debtor = invoice.debtor {
            "Zahlbar durch (Name/Adresse)".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallLabelBoldAttr)
            ry += PDFMass.fontSmall + 3
            debtor.name.draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBoldAttr)
            ry += PDFMass.fontSmall + 4
            "\(debtor.street) \(debtor.houseNumber)".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBodyAttr)
            ry += PDFMass.fontSmall + 4
            "\(debtor.postalCode) \(debtor.city)".draw(at: CGPoint(x: rightColX, y: ry), withAttributes: smallBodyAttr)
        }
    }

    // MARK: - Receipt (Empfangsschein) — left 62mm

    private static func drawReceipt(invoice: SwissInvoice, fonts: FontProvider, in ctx: CGContext, pageRect: CGRect) {
        let zahlteilY = pageRect.height - PDFMass.zahlteilHeight
        let leftX: CGFloat = 5 * PDFMass.ptPerMm
        let maxWidth = PDFMass.receiptWidth - 10 * PDFMass.ptPerMm

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptTitle, weight: .bold)
        ]
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptHeading, weight: .bold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let boldAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptBody, weight: .bold)
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptBody)
        ]

        var y = zahlteilY + 10

        "Empfangsschein".draw(at: CGPoint(x: leftX, y: y), withAttributes: titleAttr)
        y += PDFMass.fontReceiptTitle + 8

        // Account / Payable to
        drawWrapped("Konto / Zahlbar an", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(invoice.iban, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(invoice.creditor.name, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped("\(invoice.creditor.street) \(invoice.creditor.houseNumber)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped("\(invoice.creditor.postalCode) \(invoice.creditor.city)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 8

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            drawWrapped("Referenz", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
            y += PDFMass.fontReceiptHeading + 2
            drawWrapped(reference, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 8
        }

        // Payable by
        if let debtor = invoice.debtor {
            drawWrapped("Zahlbar durch", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
            y += PDFMass.fontReceiptHeading + 2
            drawWrapped(debtor.name, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 2
            drawWrapped("\(debtor.street) \(debtor.houseNumber)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 2
            drawWrapped("\(debtor.postalCode) \(debtor.city)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 8
        }

        // Currency & Amount
        let currAmtY = pageRect.height - 30 * PDFMass.ptPerMm
        "Währung".draw(at: CGPoint(x: leftX, y: currAmtY), withAttributes: labelAttr)
        "Betrag".draw(at: CGPoint(x: leftX + 18 * PDFMass.ptPerMm, y: currAmtY), withAttributes: labelAttr)
        let valueY = currAmtY + PDFMass.fontReceiptHeading + 2
        invoice.amount.currency.rawValue.draw(at: CGPoint(x: leftX, y: valueY), withAttributes: bodyAttr)
        if !invoice.amount.isZero {
            invoice.amount.formattedShort.draw(at: CGPoint(x: leftX + 18 * PDFMass.ptPerMm, y: valueY), withAttributes: boldAttr)
        }

        // "Annahmestelle" (acceptance point) — bottom right of receipt
        let acceptAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptHeading, weight: .bold)
        ]
        let acceptText = "Annahmestelle"
        let acceptSize = (acceptText as NSString).size(withAttributes: acceptAttr)
        let acceptX = PDFMass.receiptWidth - 5 * PDFMass.ptPerMm - acceptSize.width
        let acceptY = pageRect.height - 15 * PDFMass.ptPerMm
        acceptText.draw(at: CGPoint(x: acceptX, y: acceptY), withAttributes: acceptAttr)
    }

    // MARK: - Drawing Helpers

    private static func drawHRule(in ctx: CGContext, y: CGFloat, from startX: CGFloat, to endX: CGFloat, lineWidth: CGFloat = 0.5) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.separator.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.move(to: CGPoint(x: startX, y: y))
        ctx.addLine(to: CGPoint(x: endX, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawZahlteilSeparator(in ctx: CGContext, y: CGFloat, pageRect: CGRect) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: pageRect.width, y: y))
        ctx.strokePath()
        ctx.restoreGState()

        // Scissors symbol
        let scissorsAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10)
        ]
        let scissorsStr = "✂"
        let size = (scissorsStr as NSString).size(withAttributes: scissorsAttr)
        (scissorsStr as NSString).draw(
            at: CGPoint(x: pageRect.width / 2 - size.width / 2, y: y - size.height / 2),
            withAttributes: scissorsAttr
        )
    }

    private static func drawVerticalSeparator(in ctx: CGContext, x: CGFloat, fromY: CGFloat, toY: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        ctx.move(to: CGPoint(x: x, y: fromY))
        ctx.addLine(to: CGPoint(x: x, y: toY))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawRightAligned(_ text: String, at point: CGPoint, attributes: [NSAttributedString.Key: Any]) {
        let w = (text as NSString).size(withAttributes: attributes).width
        (text as NSString).draw(at: CGPoint(x: point.x - w, y: point.y), withAttributes: attributes)
    }

    private static func drawWrapped(_ text: String, at point: CGPoint, maxWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: 100)
        (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
    }

    // MARK: - Address Helpers

    /// Builds address lines from an Address, optionally including the name.
    /// Omits countryCode for CH addresses (domestic).
    private static func buildAddressLines(_ address: Address, includeName: Bool) -> [String] {
        var lines: [String] = []
        if includeName {
            lines.append(address.name)
        }
        let street = "\(address.street) \(address.houseNumber)".trimmingCharacters(in: .whitespaces)
        if !street.isEmpty {
            lines.append(street)
        }
        let cityLine = "\(address.postalCode) \(address.city)".trimmingCharacters(in: .whitespaces)
        if !cityLine.isEmpty {
            lines.append(cityLine)
        }
        if address.countryCode.uppercased() != "CH" && !address.countryCode.isEmpty {
            lines.append(address.countryCode)
        }
        return lines
    }

    /// Builds a compact sender line for the Absenderzeile (e.g. "Muster AG, Musterstrasse 1, 3000 Bern").
    private static func buildSenderLine(_ address: Address) -> String {
        var parts: [String] = [address.name]
        let street = "\(address.street) \(address.houseNumber)".trimmingCharacters(in: .whitespaces)
        if !street.isEmpty { parts.append(street) }
        let city = "\(address.postalCode) \(address.city)".trimmingCharacters(in: .whitespaces)
        if !city.isEmpty { parts.append(city) }
        return parts.joined(separator: ", ")
    }
}
