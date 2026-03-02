import CoreGraphics
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MARK: - PDF Measurements (points at 72 dpi)
// 1 mm = 72/25.4 pt ≈ 2.8346 pt

private enum PDFMass {
    static let ptPerMm: CGFloat = 72.0 / 25.4

    // A4
    static let pageWidth: CGFloat = 210 * ptPerMm
    static let pageHeight: CGFloat = 297 * ptPerMm

    // Margins
    static let marginLeft: CGFloat = 26 * ptPerMm  // SN 10130: 26 mm
    static let marginRight: CGFloat = 12 * ptPerMm  // SN 10130: 12 mm
    static let marginTop: CGFloat = 12 * ptPerMm
    static let usablePageWidth: CGFloat = pageWidth - marginLeft - marginRight

    // SN 10130:2026 - Adressfeld
    static let adressfeldLeft: CGFloat = 117 * ptPerMm  // SN 10130: 117 mm
    static let adressfeldTop: CGFloat = 52 * ptPerMm  // SN 10130: 52 mm
    static let adressfeldWidth: CGFloat = 81 * ptPerMm  // SN 10130: 81 mm
    static let adressfeldHeight: CGFloat = 32 * ptPerMm  // SN 10130: 32 mm

    // Leitwörterbereich (below address zone, §5)
    static let topInfoblock: CGFloat = 38 * ptPerMm
    static let topContent: CGFloat = 97 * ptPerMm
    static let leitwoerterMinY: CGFloat = 111 * ptPerMm  // 314.65 pt (97 + 14 mm)

    // Falzmarke (fold/punch marks)
    static let lochmarke: CGFloat = 148.5 * ptPerMm  // 420.94 pt

    // Payment part (SIX Swiss QR Bill specification)
    static let zahlteilHeight: CGFloat = 105 * ptPerMm
    static let qrCodeSize: CGFloat = 46 * ptPerMm  // 130.39 pt — exactly 46 mm
    static let qrLeft: CGFloat = 5 * ptPerMm
    static let qrTop: CGFloat = 17 * ptPerMm

    // Receipt (Empfangsschein) — 60mm wide, left side
    static let receiptWidth: CGFloat = 62 * ptPerMm
    // Payment part (Zahlteil) — 150mm wide, right side
    static let paymentPartWidth: CGFloat = 148 * ptPerMm

    // Vertical separator between receipt and payment part
    static let verticalSepX: CGFloat = 62 * ptPerMm

    // Fonts
    static let fontTitle: CGFloat = 14
    static let fontTitleAddress: CGFloat = 9
    static let fontHeading: CGFloat = 8
    static let fontBody: CGFloat = 10
    static let fontSmall: CGFloat = 8

    // Receipt-specific fonts (smaller per SIX spec)
    static let fontReceiptTitle: CGFloat = 11
    static let fontReceiptHeading: CGFloat = 6
    static let fontReceiptBody: CGFloat = 8

    static let lineSpacing: CGFloat = 2
}

// MARK: - Font Provider

private struct FontProvider {
    let name: String

    init(requestedName: String?) {
        if let requested = requestedName,
            UIFont(name: requested, size: PDFMass.fontBody) != nil
        {
            self.name = requested
        } else {
            self.name = "Helvetica"
        }
    }

    func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base =
            UIFont(name: name, size: size)
            ?? UIFont(name: "Helvetica", size: size)!
        // For semibold and above, resolve the actual bold face via symbolic traits.
        // Using addingAttributes with .weight does NOT switch font faces for named fonts.
        guard weight >= .semibold else { return base }
        guard let boldDescriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return base
        }
        return UIFont(descriptor: boldDescriptor, size: size)
    }

    func font(size: CGFloat) -> UIFont {
        font(size: size, weight: .regular)
    }

    func monospacedDigitFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = font(size: size, weight: weight)
        let features: [[UIFontDescriptor.FeatureKey: Any]] = [
            [
                .type: kNumberSpacingType,
                .selector: kMonospacedNumbersSelector,
            ]
        ]
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
    public static func render(invoice: SwissInvoice) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: PDFMass.pageWidth, height: PDFMass.pageHeight)
        let fonts = FontProvider(requestedName: invoice.fontName)
        let sizes = InvoiceFontSizes(body: invoice.fontSize ?? PDFMass.fontBody)
        let slipFonts = FontProvider(requestedName: nil)  // Always Helvetica per SIX spec
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            cgContext.scaleBy(x: 1.004, y: 1.0)  // It's a detail but makes it perfect
            drawBriefkopf(invoice: invoice, fonts: fonts, in: cgContext)
            drawAdressfeld(invoice: invoice, fonts: fonts, sizes: sizes, in: cgContext)
            drawLeitwoerter(invoice: invoice, fonts: fonts, sizes: sizes, in: cgContext)
            let yPosition: CGFloat = drawSubject(invoice: invoice, fonts: fonts, sizes: sizes, in: cgContext)
            drawContent(invoice: invoice, yPosition: yPosition, fonts: fonts, sizes: sizes, in: cgContext)
            drawFalzmarken(in: cgContext)
            drawPaymentPart(invoice: invoice, fonts: slipFonts, in: cgContext, pageRect: pageRect)
            drawReceipt(invoice: invoice, fonts: slipFonts, in: cgContext, pageRect: pageRect)
        }
    }

    private static func drawBriefkopf(
        invoice: SwissInvoice,
        fonts: FontProvider,
        in ctx: CGContext
    ) {
        var y: CGFloat = PDFMass.marginTop
        let headerFontSize: CGFloat = PDFMass.fontTitle

        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: headerFontSize, weight: .bold)
        ]
//        invoice.creditor.name.draw(at: CGPoint(x: PDFMass.marginLeft, y: y), withAttributes: nameAttr)
//        y += headerFontSize + PDFMass.lineSpacing + PDFMass.lineSpacing
        let maximaleGroesse = CGSize(width: PDFMass.pageWidth - PDFMass.marginLeft - PDFMass.marginRight, height: CGFloat.greatestFiniteMagnitude)
        let rahmen = invoice.creditor.name.boundingRect(
            with: maximaleGroesse,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: nameAttr,
            context: nil
        )
        let benoetigteHoehe = ceil(rahmen.height)
        let drawRect = CGRect(x: PDFMass.marginLeft, y: y, width: PDFMass.pageWidth - PDFMass.marginLeft - PDFMass.marginRight, height: benoetigteHoehe)
        invoice.creditor.name.draw(
            with: drawRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: nameAttr,
            context: nil
        )
        y += benoetigteHoehe

        let addrAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontTitleAddress),
            .foregroundColor: UIColor.darkGray,
        ]
        let creditorLines = buildAddressLines(invoice.creditor, includeName: false)
        for line in creditorLines {
            line.draw(at: CGPoint(x: PDFMass.marginLeft, y: y), withAttributes: addrAttr)
            y += PDFMass.fontTitleAddress + PDFMass.lineSpacing
        }

        if let title = invoice.title {
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: fonts.font(size: headerFontSize, weight: .bold)
            ]
            let titleWidth = (title as NSString).size(withAttributes: titleAttr).width
            (title as NSString).draw(
                at: CGPoint(x: PDFMass.pageWidth - PDFMass.marginRight - titleWidth, y: PDFMass.marginTop),
                withAttributes: titleAttr
            )
        }
    }

    // MARK: - Adressfeldbereich (38 – 97 mm) – Rechtsadressierung per SN 10130:2026 §4.3
    private static func drawAdressfeld(
        invoice: SwissInvoice,
        fonts: FontProvider,
        sizes: InvoiceFontSizes,
        in ctx: CGContext
    ) {
        let addressAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontBody)
        ]
        let maxWidth = PDFMass.adressfeldWidth - 8 * PDFMass.ptPerMm
        let leftX = PDFMass.adressfeldLeft + 8 * PDFMass.ptPerMm
        var leftY = PDFMass.adressfeldTop

        // Center horizontally
        let creditorLines = buildAddressLines(invoice.debtor, includeName: true)
        let nrLines = creditorLines.count
        let textHeight = nrLines * Int(PDFMass.fontBody) + (nrLines - 1) * 2
        let yOffset = (PDFMass.adressfeldHeight - CGFloat(textHeight)) / PDFMass.lineSpacing
        leftY += yOffset

        // Draw
        for line in creditorLines {
            drawWrapped(line, at: CGPoint(x: leftX, y: leftY), maxWidth: maxWidth, attributes: addressAttr)
            leftY += PDFMass.fontBody + PDFMass.lineSpacing
        }
    }

    // MARK: - Leitwörterbereich (≥ 111 mm) per SN 10130:2026 §5

    /// Draws Datum and Referenz in the Leitwörterbereich below the address zone.
    /// Returns the Y position after the last entry.
    private static func drawLeitwoerter(
        invoice: SwissInvoice,
        fonts: FontProvider,
        sizes: InvoiceFontSizes,
        in ctx: CGContext
    ) {
        var yPosition = PDFMass.topInfoblock + 40 * PDFMass.ptPerMm
        let xTabPosition = PDFMass.marginLeft + 24 * PDFMass.ptPerMm
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.small),
            .foregroundColor: UIColor.black,
        ]
        let valueAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.small)
        ]
        if let date = invoice.invoiceDate {
            "Rechnungsdatum:".draw(at: CGPoint(x: PDFMass.marginLeft, y: yPosition), withAttributes: labelAttr)
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.locale = Locale(identifier: "de_CH")
            let dateStr = formatter.string(from: date)
            dateStr.draw(at: CGPoint(x: xTabPosition, y: yPosition), withAttributes: valueAttr)
            yPosition += (sizes.small + 2)
        }
        if let reference = invoice.reference, !reference.isEmpty {
            "Referenz:".draw(at: CGPoint(x: PDFMass.marginLeft, y: yPosition), withAttributes: labelAttr)
            reference.draw(at: CGPoint(x: xTabPosition, y: yPosition), withAttributes: valueAttr)
            yPosition += (sizes.small + 2)
        }
        if let additionalInfo = invoice.additionalInfo, !additionalInfo.isEmpty {
            "Zusatzinformation:".draw(at: CGPoint(x: PDFMass.marginLeft, y: yPosition), withAttributes: labelAttr)
            additionalInfo.draw(at: CGPoint(x: xTabPosition, y: yPosition), withAttributes: valueAttr)
            yPosition += (sizes.small + 2)
        }
        if let vatNr = invoice.vatNr, !vatNr.isEmpty {
            "UID (MWST):".draw(at: CGPoint(x: PDFMass.marginLeft, y: yPosition), withAttributes: labelAttr)
            vatNr.draw(at: CGPoint(x: xTabPosition, y: yPosition), withAttributes: valueAttr)
            yPosition += (sizes.small + 2)
        }
    }

    private static func drawSubject(
        invoice: SwissInvoice,
        fonts: FontProvider,
        sizes: InvoiceFontSizes,
        in ctx: CGContext
    ) -> CGFloat {
        var result = PDFMass.topContent
        if let subject = invoice.subject, !subject.isEmpty {
            let betreffAttr: [NSAttributedString.Key: Any] = [
                .font: fonts.font(size: sizes.body, weight: .bold)
            ]
            (subject as NSString).draw(
                at: CGPoint(x: PDFMass.marginLeft, y: result),
                withAttributes: betreffAttr
            )
            // 1 empty line after Betreff before content
            result += sizes.body + sizes.body
        }
        return result
    }

    private static func drawContent(
        invoice: SwissInvoice,
        yPosition: CGFloat,
        fonts: FontProvider,
        sizes: InvoiceFontSizes,
        in ctx: CGContext
    ) {
        
        var result = yPosition
        let betreffAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontBody)
        ]
        let width: CGFloat = PDFMass.pageWidth - PDFMass.marginLeft - PDFMass.marginRight
        let maximaleGroesse = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        if let leadingText = invoice.leadingText, !leadingText.isEmpty {
            let rahmen = leadingText.boundingRect(
                with: maximaleGroesse,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: betreffAttr,
                context: nil
            )
            let benoetigteHoehe = ceil(rahmen.height)
            let drawRect = CGRect(x: PDFMass.marginLeft, y: result, width: width, height: benoetigteHoehe)
            leadingText.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: betreffAttr,
                context: nil
            )
            result += benoetigteHoehe + 2
        }
        result = drawLineItems(
            invoice: invoice,
            fonts: fonts,
            sizes: sizes,
            in: ctx,
            yPosition: result
        )
        if let trailingText = invoice.trailingText, !trailingText.isEmpty {
            let rahmen = trailingText.boundingRect(
                with: maximaleGroesse,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: betreffAttr,
                context: nil
            )

            let benoetigteHoehe = ceil(rahmen.height)
            let drawRect = CGRect(x: PDFMass.marginLeft, y: result, width: width, height: benoetigteHoehe)
            trailingText.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: betreffAttr,
                context: nil
            )
        }
    }

    // MARK: - Falzmarken (fold/punch marks)

    /// Draws fold and punch marks at the left edge per SN 10130:2026.
    private static func drawFalzmarken(in ctx: CGContext) {
        let markLength: CGFloat = 4 * PDFMass.ptPerMm  // 4 mm mark

        ctx.saveGState()
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.3)
        ctx.move(to: CGPoint(x: 0, y: PDFMass.lochmarke))
        ctx.addLine(to: CGPoint(x: markLength, y: PDFMass.lochmarke))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Line Items Table

    private static func drawLineItems(
        invoice: SwissInvoice,
        fonts: FontProvider,
        sizes: InvoiceFontSizes,
        in ctx: CGContext,
        yPosition: CGFloat
    ) -> CGFloat {
        var result = yPosition + 10 * PDFMass.ptPerMm
        let rightEdge = PDFMass.pageWidth - PDFMass.marginRight
        let contentWidth = rightEdge - PDFMass.marginLeft

        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.small, weight: .bold),
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
            let colDescription = PDFMass.marginLeft
            let colQuantity = PDFMass.marginLeft + contentWidth * 0.50
            let colUnit = PDFMass.marginLeft + contentWidth * 0.60
            let colAmount = rightEdge

            // Table header
            "Description".draw(at: CGPoint(x: colDescription, y: result), withAttributes: headerAttr)
            "Qty".draw(at: CGPoint(x: colQuantity, y: result), withAttributes: headerAttr)
            "Unit".draw(at: CGPoint(x: colUnit, y: result), withAttributes: headerAttr)
            drawRightAligned("Unit Price", at: CGPoint(x: colAmount - 60, y: result), attributes: headerAttr)
            drawRightAligned("Amount", at: CGPoint(x: colAmount, y: result), attributes: headerAttr)
            result += sizes.small + 4

            drawHRule(in: ctx, y: result, from: PDFMass.marginLeft, to: rightEdge, lineWidth: 0.3)
            result += 4

            // Line items
            for item in invoice.lineItems {
                (item.description as NSString).draw(
                    in: CGRect(
                        x: colDescription,
                        y: result,
                        width: colQuantity - colDescription - 4,
                        height: sizes.body + 4
                    ),
                    withAttributes: bodyAttr
                )

                if let qty = item.quantity {
                    let qtyStr = "\(qty)"
                    qtyStr.draw(at: CGPoint(x: colQuantity, y: result), withAttributes: monoAttr)
                }

                if let unit = item.unit {
                    unit.draw(at: CGPoint(x: colUnit, y: result), withAttributes: bodyAttr)
                }

                if let unitPrice = item.unitPrice {
                    drawRightAligned(
                        unitPrice.formattedShort,
                        at: CGPoint(x: colAmount - 60, y: result),
                        attributes: monoAttr
                    )
                }

                drawRightAligned(item.amount.formattedShort, at: CGPoint(x: colAmount, y: result), attributes: monoAttr)
                result += sizes.body + 4
            }

            // Separator before total
            drawHRule(in: ctx, y: result, from: PDFMass.marginLeft, to: rightEdge, lineWidth: 0.3)
            result += 6
        }

        // Total
        let totalLabelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: sizes.body, weight: .bold)
        ]
        "Total".draw(at: CGPoint(x: PDFMass.marginLeft + contentWidth * 0.50, y: result), withAttributes: totalLabelAttr)
        drawRightAligned(invoice.amount.formatted, at: CGPoint(x: rightEdge, y: result), attributes: boldMonoAttr)
        result += 2 * PDFMass.ptPerMm
        drawHRule(in: ctx, y: result, from: PDFMass.marginLeft, to: rightEdge, lineWidth: 0.3)
        result += 8 * PDFMass.ptPerMm
        return result
    }

    // MARK: - Payment Part (Zahlteil) — right 148mm

    private static func drawPaymentPart(invoice: SwissInvoice, fonts: FontProvider, in ctx: CGContext, pageRect: CGRect)
    {
        let zahlteilY = pageRect.height - PDFMass.zahlteilHeight

        let maxWidth = PDFMass.paymentPartWidth - 10 * PDFMass.ptPerMm

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
        y += 12 * PDFMass.ptPerMm

        // QR Code (exactly 46mm per SIX spec, modules only + vector Swiss Cross)
        // The PDF context renders the image ~4.5% smaller than the specified rect.
        // We compensate by drawing into a rect scaled by 46/44 ≈ 1.04545.
        let payload = QRPayloadGenerator.generatePayload(for: invoice)
        if let modulesCGImage = QRCodeGenerator.generateModulesCGImage(
            payload: payload,
            pixelSize: Int(QRCodeGenerator.printPixelSize)
        ) {
            let qrDrawSize = PDFMass.qrCodeSize
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
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let monoAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: PDFMass.fontBody, weight: .bold)
        ]
        let monoSmallAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.monospacedDigitFont(size: PDFMass.fontBody, weight: .regular)
        ]

        // Right column: Payment info
        let rightColX = leftColX + PDFMass.qrCodeSize + 8 * PDFMass.ptPerMm
        var ry = zahlteilY + 10 + 20 * PDFMass.ptPerMm  // align with QR code

        let smallLabelAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontSmall + 1, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel,
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

        let sectionGap: CGFloat = 12
        ry = zahlteilY + sectionGap

        // Account / Payable to
        drawWrapped(
            "Konto / Zahlbar an",
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallLabelBoldAttr
        )
        ry += PDFMass.fontSmall + 3
        drawWrapped(invoice.iban, at: CGPoint(x: rightColX, y: ry), maxWidth: maxWidth, attributes: smallBodyAttr)
        ry += PDFMass.fontSmall + 4
        drawWrapped(
            invoice.creditor.name,
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallBodyAttr
        )
        ry += PDFMass.fontSmall + 4
        drawWrapped(
            "\(invoice.creditor.street) \(invoice.creditor.houseNumber)",
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallBodyAttr
        )
        ry += PDFMass.fontSmall + 4
        drawWrapped(
            "\(invoice.creditor.postalCode) \(invoice.creditor.city)",
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallBodyAttr
        )
        ry += PDFMass.fontSmall + sectionGap

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            drawWrapped(
                "Referenz",
                at: CGPoint(x: rightColX, y: ry),
                maxWidth: maxWidth,
                attributes: smallLabelBoldAttr
            )
            ry += PDFMass.fontSmall + 3
            drawWrapped(reference, at: CGPoint(x: rightColX, y: ry), maxWidth: maxWidth, attributes: smallBodyAttr)
            ry += PDFMass.fontSmall + sectionGap
        }

        // Additional info
        if let info = invoice.additionalInfo, !info.isEmpty {
            drawWrapped(
                "Zusätzliche Informationen",
                at: CGPoint(x: rightColX, y: ry),
                maxWidth: maxWidth,
                attributes: smallBoldAttr
            )
            ry += PDFMass.fontSmall + 3
            drawWrapped(info, at: CGPoint(x: rightColX, y: ry), maxWidth: maxWidth, attributes: smallBodyAttr)
            ry += PDFMass.fontSmall + sectionGap
        }

        // Payable by
        drawWrapped(
            "Zahlbar durch",
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallBoldAttr
        )
        ry += PDFMass.fontSmall + 3
        drawWrapped(
            invoice.debtor.name,
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallBodyAttr
        )
        ry += PDFMass.fontSmall + 4
        drawWrapped(
            "\(invoice.debtor.street) \(invoice.debtor.houseNumber)",
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallBodyAttr
        )
        ry += PDFMass.fontSmall + 4
        drawWrapped(
            "\(invoice.debtor.postalCode) \(invoice.debtor.city)",
            at: CGPoint(x: rightColX, y: ry),
            maxWidth: maxWidth,
            attributes: smallBodyAttr
        )

        let currAmtY = pageRect.height - 34 * PDFMass.ptPerMm
        drawWrapped("Währung", at: CGPoint(x: leftColX, y: currAmtY), maxWidth: maxWidth, attributes: smallBoldAttr)
        drawWrapped(
            "Betrag",
            at: CGPoint(x: leftColX + 30 * PDFMass.ptPerMm, y: currAmtY),
            maxWidth: maxWidth,
            attributes: smallBoldAttr
        )
        let valueY = currAmtY + PDFMass.fontReceiptHeading + 4
        invoice.amount.currency.rawValue.draw(at: CGPoint(x: leftColX, y: valueY), withAttributes: monoSmallAttr)
        if !invoice.amount.isZero {
            invoice.amount.formattedShort.draw(
                at: CGPoint(x: leftColX + 30 * PDFMass.ptPerMm, y: valueY),
                withAttributes: monoSmallAttr
            )
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
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let boldAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptBody, weight: .bold)
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptBody)
        ]

        var y = zahlteilY + 10

        drawWrapped("Empfangsschein", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: titleAttr)
        y += PDFMass.fontReceiptTitle + 8

        // Account / Payable to
        drawWrapped("Konto / Zahlbar an", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(invoice.iban, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(invoice.creditor.name, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(
            "\(invoice.creditor.street) \(invoice.creditor.houseNumber)",
            at: CGPoint(x: leftX, y: y),
            maxWidth: maxWidth,
            attributes: bodyAttr
        )
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(
            "\(invoice.creditor.postalCode) \(invoice.creditor.city)",
            at: CGPoint(x: leftX, y: y),
            maxWidth: maxWidth,
            attributes: bodyAttr
        )
        y += PDFMass.fontReceiptBody + 8

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            drawWrapped("Referenz", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
            y += PDFMass.fontReceiptHeading + 2
            drawWrapped(reference, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
            y += PDFMass.fontReceiptBody + 8
        }

        // Payable by
        drawWrapped("Zahlbar durch", at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: boldAttr)
        y += PDFMass.fontReceiptHeading + 2
        drawWrapped(invoice.debtor.name, at: CGPoint(x: leftX, y: y), maxWidth: maxWidth, attributes: bodyAttr)
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(
            "\(invoice.debtor.street) \(invoice.debtor.houseNumber)",
            at: CGPoint(x: leftX, y: y),
            maxWidth: maxWidth,
            attributes: bodyAttr
        )
        y += PDFMass.fontReceiptBody + 2
        drawWrapped(
            "\(invoice.debtor.postalCode) \(invoice.debtor.city)",
            at: CGPoint(x: leftX, y: y),
            maxWidth: maxWidth,
            attributes: bodyAttr
        )
        y += PDFMass.fontReceiptBody + 8

        // Currency & Amount
        let currAmtY = pageRect.height - 34 * PDFMass.ptPerMm
        drawWrapped("Währung", at: CGPoint(x: leftX, y: currAmtY), maxWidth: maxWidth, attributes: boldAttr)
        drawWrapped(
            "Betrag",
            at: CGPoint(x: leftX + 18 * PDFMass.ptPerMm, y: currAmtY),
            maxWidth: maxWidth,
            attributes: boldAttr
        )
        let valueY = currAmtY + PDFMass.fontReceiptHeading + 4
        drawWrapped(
            invoice.amount.currency.rawValue,
            at: CGPoint(x: leftX, y: valueY),
            maxWidth: maxWidth,
            attributes: bodyAttr
        )
        if !invoice.amount.isZero {
            drawWrapped(
                invoice.amount.formattedShort,
                at: CGPoint(x: leftX + 18 * PDFMass.ptPerMm, y: valueY),
                maxWidth: maxWidth,
                attributes: bodyAttr
            )
        }

        // "Annahmestelle" (acceptance point) — bottom right of receipt
        let acceptAttr: [NSAttributedString.Key: Any] = [
            .font: fonts.font(size: PDFMass.fontReceiptHeading, weight: .bold)
        ]
        let acceptText = "Annahmestelle"
        let acceptSize = (acceptText as NSString).size(withAttributes: acceptAttr)
        let acceptX = PDFMass.receiptWidth - 5 * PDFMass.ptPerMm - acceptSize.width
        let acceptY = pageRect.height - 20 * PDFMass.ptPerMm
        drawWrapped(acceptText, at: CGPoint(x: acceptX, y: acceptY), maxWidth: maxWidth, attributes: acceptAttr)
    }

    // MARK: - Drawing Helpers

    private static func drawHRule(
        in ctx: CGContext,
        y: CGFloat,
        from startX: CGFloat,
        to endX: CGFloat,
        lineWidth: CGFloat = 0.5
    ) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
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

    private static func drawWrapped(
        _ text: String,
        at point: CGPoint,
        maxWidth: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) {
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
        if !address.addressAddition.isEmpty {
            lines.append(address.addressAddition)
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
