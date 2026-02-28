import UIKit
import CoreImage.CIFilterBuiltins
import CoreGraphics

// MARK: - PDF Measurements (points at 72 dpi)
// 1 mm = 72/25.4 pt ≈ 2.8346 pt

private enum PDFMass {
    static let ptPerMm: CGFloat       = 72.0 / 25.4

    // A4
    static let pageWidth: CGFloat     = 210 * ptPerMm   // 595.28 pt
    static let pageHeight: CGFloat    = 297 * ptPerMm   // 841.89 pt

    // Margins
    static let marginLeft: CGFloat    = 20  * ptPerMm
    static let marginRight: CGFloat   = 20  * ptPerMm
    static let marginTop: CGFloat     = 20  * ptPerMm

    // Payment part (SIX Swiss QR Bill specification)
    static let zahlteilHeight: CGFloat = 105 * ptPerMm  // 297.64 pt
    static let qrCodeSize: CGFloat     =  46 * ptPerMm  // 130.39 pt — exactly 46 mm
    static let qrLeft: CGFloat         =   5 * ptPerMm
    static let qrTop: CGFloat          =  17 * ptPerMm

    // Receipt (Empfangsschein) — 62mm wide, left side
    static let receiptWidth: CGFloat   =  62 * ptPerMm
    // Payment part (Zahlteil) — 148mm wide, right side
    static let paymentPartWidth: CGFloat = 148 * ptPerMm

    // Vertical separator between receipt and payment part
    static let verticalSepX: CGFloat   =  62 * ptPerMm

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
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext
            drawInvoiceHeader(invoice: invoice, fonts: fonts, in: cgCtx, pageRect: pageRect)
            drawAddresses(invoice: invoice, fonts: fonts, in: cgCtx, pageRect: pageRect)
            drawLineItems(invoice: invoice, fonts: fonts, in: cgCtx, pageRect: pageRect)
            drawPaymentPart(invoice: invoice, fonts: fonts, in: cgCtx, pageRect: pageRect)
            drawReceipt(invoice: invoice, fonts: fonts, in: cgCtx, pageRect: pageRect)
        }
    }

    // MARK: - Invoice Header

    private static func drawInvoiceHeader(invoice: SwissInvoice, fonts: FontProvider, in ctx: CGContext, pageRect: CGRect) {
        let x = PDFMass.marginLeft
        var y = PDFMass.marginTop

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontTitle, weight: .bold)
        ]
        let title = invoice.title ?? "Invoice"
        title.draw(at: CGPoint(x: x, y: y), withAttributes: titleAttr)
        y += PDFMass.fontTitle + 4

        if let date = invoice.invoiceDate {
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: fonts.font(size: PDFMass.fontBody),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateStr = date.formatted(date: .abbreviated, time: .omitted)
            dateStr.draw(at: CGPoint(x: x, y: y), withAttributes: subAttr)
        }
        y += PDFMass.fontBody + 4

        drawHRule(in: ctx, y: y + 6, from: PDFMass.marginLeft, to: pageRect.width - PDFMass.marginRight)
    }

    // MARK: - Addresses

    private static func drawAddresses(invoice: SwissInvoice, fonts: FontProvider, in ctx: CGContext, pageRect: CGRect) {
        let topY = PDFMass.marginTop + PDFMass.fontTitle + 4 + PDFMass.fontBody + 4 + 20

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontHeading, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let boldAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontBody, weight: .semibold)
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontBody)
        ]

        // Creditor (left)
        var y = topY
        "From".draw(at: CGPoint(x: PDFMass.marginLeft, y: y), withAttributes: labelAttr)
        y += PDFMass.fontHeading + 3
        invoice.creditor.name.draw(at: CGPoint(x: PDFMass.marginLeft, y: y), withAttributes: boldAttr)
        y += PDFMass.fontBody + 2
        "\(invoice.creditor.street) \(invoice.creditor.houseNumber)".draw(at: CGPoint(x: PDFMass.marginLeft, y: y), withAttributes: bodyAttr)
        y += PDFMass.fontBody + 2
        "\(invoice.creditor.postalCode) \(invoice.creditor.city)".draw(at: CGPoint(x: PDFMass.marginLeft, y: y), withAttributes: bodyAttr)
        y += PDFMass.fontBody + 2
        invoice.creditor.countryCode.draw(at: CGPoint(x: PDFMass.marginLeft, y: y), withAttributes: bodyAttr)

        // Debtor (right, right-aligned)
        if let debtor = invoice.debtor {
            var ry = topY
            let rightEdge = pageRect.width - PDFMass.marginRight
            let lines: [(String, [NSAttributedString.Key: Any])] = [
                ("To",                                  labelAttr),
                (debtor.name,                           boldAttr),
                ("\(debtor.street) \(debtor.houseNumber)", bodyAttr),
                ("\(debtor.postalCode) \(debtor.city)", bodyAttr),
                (debtor.countryCode,                    bodyAttr)
            ]
            for (line, attr) in lines {
                let w = (line as NSString).size(withAttributes: attr).width
                (line as NSString).draw(
                    at: CGPoint(x: rightEdge - w, y: ry),
                    withAttributes: attr
                )
                let fontSize = (attr[.font] as? UIFont)?.pointSize ?? PDFMass.fontBody
                ry += fontSize + (line == "To" ? 3 : 2)
            }
        }

        let hRuleY = topY + (PDFMass.fontHeading + 3) + 4 * (PDFMass.fontBody + 2) + 10
        drawHRule(in: ctx, y: hRuleY, from: PDFMass.marginLeft, to: pageRect.width - PDFMass.marginRight)
    }

    // MARK: - Line Items Table

    private static func drawLineItems(invoice: SwissInvoice, fonts: FontProvider, in ctx: CGContext, pageRect: CGRect) {
        let topY = PDFMass.marginTop
            + PDFMass.fontTitle + 4
            + PDFMass.fontBody  + 4
            + 20
            + (PDFMass.fontHeading + 3)
            + 4 * (PDFMass.fontBody + 2)
            + 20

        var y = topY
        let x = PDFMass.marginLeft
        let rightEdge = pageRect.width - PDFMass.marginRight
        let contentWidth = rightEdge - x

        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontSmall, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontBody)
        ]
        let monoAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: PDFMass.fontBody, weight: .regular)
        ]
        let boldMonoAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: PDFMass.fontBody, weight: .bold)
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
            y += PDFMass.fontSmall + 4

            drawHRule(in: ctx, y: y, from: x, to: rightEdge, lineWidth: 0.3)
            y += 4

            // Line items
            for item in invoice.lineItems {
                (item.description as NSString).draw(
                    in: CGRect(x: colDescription, y: y, width: colQuantity - colDescription - 4, height: PDFMass.fontBody + 4),
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
                y += PDFMass.fontBody + 4
            }

            // Separator before total
            drawHRule(in: ctx, y: y, from: x, to: rightEdge, lineWidth: 0.3)
            y += 6
        }

        // Total
        if let date = invoice.invoiceDate {
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: fonts.font(size: PDFMass.fontBody),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateStr = date.formatted(date: .abbreviated, time: .omitted)
            dateStr.draw(at: CGPoint(x: x, y: y), withAttributes: dateAttr)
        }

        let totalLabel = "Total"
        let totalLabelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontBody, weight: .bold)
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
                x: leftColX,
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
            .font: fonts.font(size: PDFMass.fontReceiptHeading, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let boldAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptBody, weight: .semibold)
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptBody)
        ]

        var y = zahlteilY + 10

        "Empfangsschein".draw(at: CGPoint(x: leftX, y: y), withAttributes: titleAttr)
        y += PDFMass.fontReceiptTitle + 8

        // Account / Payable to
        "Konto / Zahlbar an".draw(at: CGPoint(x: leftX, y: y), withAttributes: labelAttr)
        y += PDFMass.fontReceiptHeading + 2
        drawWrapped(invoice.iban, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(invoice.creditor.name, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped("\(invoice.creditor.street) \(invoice.creditor.houseNumber)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped("\(invoice.creditor.postalCode) \(invoice.creditor.city)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 6

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            "Referenz".draw(at: CGPoint(x: leftX, y: y), withAttributes: labelAttr)
            y += PDFMass.fontReceiptHeading + 2
            drawWrapped(reference, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 6
        }

        // Payable by
        if let debtor = invoice.debtor {
            "Zahlbar durch".draw(at: CGPoint(x: leftX, y: y), withAttributes: labelAttr)
            y += PDFMass.fontReceiptHeading + 2
            drawWrapped(debtor.name, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
            y += PDFMass.fontReceiptBody + 2
            drawWrapped("\(debtor.street) \(debtor.houseNumber)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 2
            drawWrapped("\(debtor.postalCode) \(debtor.city)", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 6
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
}
