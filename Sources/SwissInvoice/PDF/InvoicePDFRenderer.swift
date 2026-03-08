import CoreGraphics
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MARK: - PDF Measurements (points at 72 dpi)
// 1 mm = 72/25.4 pt ≈ 2.8346 pt

private enum PDFMasse {
    static let ptPerMm: CGFloat = 72.0 / 25.4

    // A4
    static let pageWidth: CGFloat = 210 * ptPerMm
    static let pageHeight: CGFloat = 297 * ptPerMm

    // Margins
    static let marginLeft: CGFloat = 26 * ptPerMm  // SN 10130: 26 mm
    static let marginRight: CGFloat = 12 * ptPerMm  // SN 10130: 12 mm
    static let marginTop: CGFloat = 12 * ptPerMm
    static let usablePageWidth: CGFloat = pageWidth - marginLeft - marginRight
    static let rightUsableBorder: CGFloat = pageWidth - marginRight

    // SN 10130:2026 - Adressfeld
    static let adressfeldLeft: CGFloat = 117 * ptPerMm  // SN 10130: 117 mm
    static let adressfeldTop: CGFloat = 52 * ptPerMm  // SN 10130: 52 mm
    static let adressfeldWidth: CGFloat = 81 * ptPerMm  // SN 10130: 81 mm
    static let adressfeldHeight: CGFloat = 32 * ptPerMm  // SN 10130: 32 mm

    // Leitwörterbereich (below address zone, §5)
    static let topInfoblock: CGFloat = 38 * ptPerMm
    static let topContent: CGFloat = 97 * ptPerMm
    static let leitwoerterMinY: CGFloat = 111 * ptPerMm  // 314.65 pt (97 + 14 mm)
    static let leitwoerterY = PDFMasse.topInfoblock + 28 * PDFMasse.ptPerMm

    // Falzmarke (fold/punch marks)
    static let lochmarke: CGFloat = 148.5 * ptPerMm  // 420.94 pt

    // Tabulatoren
    static let quantityColumn: CGFloat = 120 * ptPerMm
    static let unitColumn: CGFloat = 135 * ptPerMm
    static let unitPriceColumn: CGFloat = 164 * ptPerMm
    static let leitwoerterColumn: CGFloat = PDFMasse.marginLeft + 28 * PDFMasse.ptPerMm

    // Payment part (SIX Swiss QR Bill specification)
    static let zahlteilHeight: CGFloat = 105 * ptPerMm
    static let qrCodeSize: CGFloat = 46 * ptPerMm  // 130.39 pt — exactly 46 mm
    static let qrLeft: CGFloat = 68 * ptPerMm
    static let qrTop: CGFloat = 210 * ptPerMm

    // Receipt (Empfangsschein) — 60mm wide, left side
    static let receiptWidth: CGFloat = 62 * ptPerMm
    // Payment part (Zahlteil) — 150mm wide, right side
    static let paymentPartWidth: CGFloat = 148 * ptPerMm
    static let annahmestelle: CGFloat = 59 * ptPerMm

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

/// Renders a complete A4 invoice PDF with Swiss QR Bill payment part and receipt.
public class InvoicePDFRenderer: PDFRenderer {

    public func render(invoice: SwissInvoice) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: PDFMasse.pageWidth, height: PDFMasse.pageHeight),
            format: UIGraphicsPDFRendererFormat()
        )
        return renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            cgContext.scaleBy(x: 1.004, y: 1.0)  // It's a detail but makes it perfect
            drawBriefkopf(invoice: invoice)
            drawAdressfeld(invoice: invoice)
            _ = drawLeitwoerter(invoice: invoice)
            var yPosition : CGFloat = PDFMasse.topContent
            yPosition += drawSubject(invoice: invoice, yPosition: yPosition)
            yPosition += drawEmptyLine(fontType: FontType.standard)
            drawContent(ctx: cgContext, invoice: invoice, yPosition: yPosition)
            drawPaymentPart(invoice: invoice, in: cgContext)
            drawReceipt(invoice: invoice, in: cgContext)
            drawFalzmarken(in: cgContext)
        }
    }

    private func drawBriefkopf(invoice: SwissInvoice) {
        var y: CGFloat = PDFMasse.marginTop
        y += draw(invoice.creditor.name, at: CGPoint(x: PDFMasse.marginLeft, y: y), fontType: .title)
        let creditorLines = buildAddressLines(invoice.creditor, includeName: false)
        for line in creditorLines {
            y += draw(line, at: CGPoint(x: PDFMasse.marginLeft, y: y), fontType: .standard)
        }
        if let title = invoice.title {
            _ = drawRightAligned(
                title,
                at: CGPoint(x: PDFMasse.pageWidth - PDFMasse.marginRight, y: PDFMasse.marginTop),
                fontType: .title
            )
        }
    }

    // MARK: - Adressfeldbereich (38 – 97 mm) – Rechtsadressierung per SN 10130:2026 §4.3
    private func drawAdressfeld(invoice: SwissInvoice) {
        let leftX = PDFMasse.adressfeldLeft + 8 * PDFMasse.ptPerMm
        var leftY = PDFMasse.adressfeldTop

        // Center horizontally TODO: Move to Method
        let debtorLines = buildAddressLines(invoice.debtor ?? .empty, includeName: true)
        let nrLines = debtorLines.count
        let textHeight = nrLines * Int(PDFMasse.fontBody) + (nrLines - 1) * 2
        let yOffset = (PDFMasse.adressfeldHeight - CGFloat(textHeight)) / PDFMasse.lineSpacing
        leftY += yOffset

        for line in debtorLines {
            leftY += draw(
                line,
                at: CGPoint(x: leftX, y: leftY),
                fontType: .standard
            )
        }
    }

    private func drawLeitwoerter(invoice: SwissInvoice) -> CGFloat {
        var result = 0.0
        let yPosition = PDFMasse.leitwoerterY
        if let date = invoice.invoiceDate {
            _ = draw("Rechnungsdatum:", at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result), fontType: .standardSmall)
            let formatter = DateFormatter()  // TODO: Move to Util Class
            formatter.dateStyle = .long
            formatter.locale = Locale(identifier: "de_CH")
            let dateStr = formatter.string(from: date)
            result += draw(dateStr, at: CGPoint(x: PDFMasse.leitwoerterColumn, y: yPosition + result), fontType: .standardSmall)
        }
        if let reference = invoice.reference, !reference.isEmpty {
            _ = draw("Referenz:", at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result), fontType: .standardSmall)
            result += draw(reference, at: CGPoint(x: PDFMasse.leitwoerterColumn, y: yPosition + result), fontType: .standardSmall)
        }
        if let additionalInfo = invoice.additionalInfo, !additionalInfo.isEmpty {
            _ = draw("Zusatzinformation:", at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result), fontType: .standardSmall)
            result += draw(additionalInfo, at: CGPoint(x: PDFMasse.leitwoerterColumn, y: yPosition + result), fontType: .standardSmall)
        }
        if let vatNr = invoice.vatNr, !vatNr.isEmpty {
            _ = draw("UID (MWST):", at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result), fontType: .standardSmall)
            result += draw(vatNr, at: CGPoint(x: PDFMasse.leitwoerterColumn, y: yPosition + result), fontType: .standardSmall)
        }
        return result
    }

    private func drawSubject(invoice: SwissInvoice, yPosition: CGFloat) -> CGFloat {
        var result = 0.0
        if let subject = invoice.subject, !subject.isEmpty {
            result += draw(subject, at: CGPoint(x: PDFMasse.marginLeft, y: yPosition), fontType: .subject)
        }
        return result
    }

    private func drawTrailingText(invoice: SwissInvoice, yPosition: CGFloat) -> CGFloat {
        var result = 0.0
        if let trailingText = invoice.trailingText, !trailingText.isEmpty {
            result += drawEmptyLine(fontType: FontType.standard)
            result += drawMultiline(
                trailingText,
                at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result),
                width: PDFMasse.usablePageWidth,
                fontType: .standard
            )
        }
        return result
    }

    private func drawContent(ctx: CGContext, invoice: SwissInvoice, yPosition: CGFloat) {
        var result = 0.0
        if let leadingText = invoice.leadingText, !leadingText.isEmpty {
            result += drawMultiline(
                leadingText,
                at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result),
                width: PDFMasse.usablePageWidth,
                fontType: .standard
            )
            result += drawEmptyLine(fontType: FontType.standard)
        }
        result += drawLineItems(ctx: ctx, invoice: invoice, yPosition: yPosition + result)
        _ = drawTrailingText(invoice: invoice, yPosition: yPosition + result)
    }

    private func drawFalzmarken(in ctx: CGContext) {
        let markLength: CGFloat = 8 * PDFMasse.ptPerMm  // 4 mm mark
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.3)
        ctx.move(to: CGPoint(x: 0, y: PDFMasse.lochmarke))
        ctx.addLine(to: CGPoint(x: markLength, y: PDFMasse.lochmarke))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Line Items Table

    private func drawLineItems(ctx: CGContext, invoice: SwissInvoice, yPosition: CGFloat) -> CGFloat {
        var result = 0.0
        if !invoice.lineItems.isEmpty {
            // Table header
            _ = draw("Description", at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result), fontType: .titleInvoiceLines)
            if invoice.hasUnitItems() {
                _ = draw("Qty", at: CGPoint(x: PDFMasse.quantityColumn, y: yPosition + result), fontType: .titleInvoiceLines)
                _ = draw("Unit", at: CGPoint(x: PDFMasse.unitColumn, y: yPosition + result), fontType: .titleInvoiceLines)
                _ = drawRightAligned(
                    "Unit Price",
                    at: CGPoint(x: PDFMasse.unitPriceColumn, y: yPosition + result),
                    fontType: .titleInvoiceLines
                )
            }
            result += drawRightAligned("Amount", at: CGPoint(x: PDFMasse.rightUsableBorder, y: yPosition + result), fontType: .titleInvoiceLines)

            result += 2
            drawHRule(ctx: ctx, y: yPosition + result, from: PDFMasse.marginLeft, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
            result += 2

            // Line items
            for item in invoice.invoiceItems {
                _ = draw(item.description, at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result), fontType: .standard)
                if item.lineItemType == .unitPrice {
                    if let qty = item.quantity {
                        _ = draw(qty.description, at: CGPoint(x: PDFMasse.quantityColumn, y: yPosition + result), fontType: .standard)
                    }
                    if let unit = item.unit {
                        _ = draw(unit, at: CGPoint(x: PDFMasse.unitColumn, y: yPosition + result), fontType: .standard)
                    }
                    if let unitPrice = item.unitPrice {
                        _ = drawRightAligned(
                            unitPrice.formatted,
                            at: CGPoint(x: PDFMasse.unitPriceColumn, y: yPosition + result),
                            fontType: .standard
                        )
                    }
                }
                result += drawRightAligned(
                    item.amount.formatted,
                    at: CGPoint(x: PDFMasse.rightUsableBorder, y: yPosition + result),
                    fontType: .standard
                )
            }
            result += 2
            drawHRule(ctx: ctx, y: yPosition + result, from: PDFMasse.marginLeft, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
            result += 2
        }
        if invoice.hasVat() {
            _ = draw(
                "Total ohne MWST",
                at: CGPoint(x: PDFMasse.quantityColumn, y: yPosition + result),
                fontType: .standardBold
            )
            result += drawRightAligned(
                invoice.totalWithoutVatAmount!.formatted,
                at: CGPoint(x: PDFMasse.rightUsableBorder, y: yPosition + result),
                fontType: .standardBold
            )
            for item in invoice.vatItems {
                _ = draw(
                    "MWST " + item.vatRate!.formatted() + "%",
                    at: CGPoint(x: PDFMasse.quantityColumn, y: yPosition + result),
                    fontType: .standardBold
                )
                result += drawRightAligned(
                    item.amount.formatted,
                    at: CGPoint(x: PDFMasse.rightUsableBorder, y: yPosition + result),
                    fontType: .standardBold
                )
            }
        }
        _ = draw("Total", at: CGPoint(x: PDFMasse.quantityColumn, y: yPosition + result), fontType: .standardBold)
        result += drawRightAligned(
            invoice.amount.formatted,
            at: CGPoint(x: PDFMasse.rightUsableBorder, y: yPosition + result),
            fontType: .standardBold
        )
        result += 2
        drawHRule(ctx: ctx, y: yPosition + result, from: PDFMasse.quantityColumn, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
        result += 1
        drawHRule(ctx: ctx, y: yPosition + result, from: PDFMasse.quantityColumn, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
        return result
    }

    // MARK: - Payment Part (Zahlteil) — right 148mm

    private func drawPaymentPart(invoice: SwissInvoice, in ctx: CGContext) {
        let zahlteilY = PDFMasse.pageHeight - PDFMasse.zahlteilHeight
        drawZahlteilSeparator(in: ctx, y: zahlteilY)
        drawVerticalSeparator(in: ctx, x: PDFMasse.verticalSepX, fromY: zahlteilY, toY: PDFMasse.pageHeight)
        let leftColX = PDFMasse.verticalSepX + 5 * PDFMasse.ptPerMm
        var y = zahlteilY + 10
        y += draw("Zahlteil", at: CGPoint(x: leftColX, y: y), fontType: .titlePayment)

        // QR Code (exactly 46mm per SIX spec, modules only + vector Swiss Cross)
        // The PDF context renders the image ~4.5% smaller than the specified rect.
        // We compensate by drawing into a rect scaled by 46/44 ≈ 1.04545.
        let payload = QRPayloadGenerator.generatePayload(for: invoice)
        if let modulesCGImage = QRCodeGenerator.generateModulesCGImage(
            payload: payload,
            pixelSize: Int(QRCodeGenerator.printPixelSize)
        ) {
            let qrDrawSize = PDFMasse.qrCodeSize
            let qrInset = (PDFMasse.qrCodeSize - qrDrawSize) / 2  // negative → expands
            let qrRect = CGRect(
                x: PDFMasse.qrLeft,
                y: PDFMasse.qrTop,
                width: PDFMasse.qrCodeSize,
                height: PDFMasse.qrCodeSize
            )
            let qrDrawRect = qrRect.insetBy(dx: qrInset, dy: qrInset)
            UIImage(cgImage: modulesCGImage).draw(in: qrDrawRect)
            QRCodeGenerator.drawSwissCrossOverlay(in: qrDrawRect)
            y += PDFMasse.qrCodeSize + 8
        }
        let rightColX = leftColX + PDFMasse.qrCodeSize + 8 * PDFMasse.ptPerMm
        var ry = zahlteilY + 10

        // Account / Payable to
        ry += draw(
            "Konto / Zahlbar an",
            at: CGPoint(x: rightColX, y: ry),
            fontType: .headerPayment
        )
        ry += draw(invoice.iban, at: CGPoint(x: rightColX, y: ry), fontType: .textPayment)
        ry += draw(
            invoice.creditor.name,
            at: CGPoint(x: rightColX, y: ry),
            fontType: .textPayment
        )
        ry += draw(
            "\(invoice.creditor.street) \(invoice.creditor.houseNumber)",
            at: CGPoint(x: rightColX, y: ry),
            fontType: .textPayment
        )
        ry += draw(
            "\(invoice.creditor.postalCode) \(invoice.creditor.city)",
            at: CGPoint(x: rightColX, y: ry),
            fontType: .textPayment
        )
        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            ry += drawEmptyLine(fontType: .headerPayment)
            ry += draw("Referenz", at: CGPoint(x: rightColX, y: ry), fontType: .headerPayment)
            ry += draw(reference, at: CGPoint(x: rightColX, y: ry), fontType: .textPayment)
        }

        // Additional info
        if let info = invoice.additionalInfo, !info.isEmpty {
            ry += drawEmptyLine(fontType: .headerPayment)
            ry += draw(
                "Zusätzliche Informationen",
                at: CGPoint(x: rightColX, y: ry),
                fontType: .headerPayment
            )
            ry += draw(info, at: CGPoint(x: rightColX, y: ry), fontType: .textPayment)
        }

        // Payable by
        let paymentDebtor = invoice.debtor ?? .empty
        ry += drawEmptyLine(fontType: .headerPayment)
        ry += draw(
            "Zahlbar durch",
            at: CGPoint(x: rightColX, y: ry),
            fontType: .headerPayment
        )
        ry += draw(
            paymentDebtor.name,
            at: CGPoint(x: rightColX, y: ry),
            fontType: .textPayment
        )
        ry += draw(
            "\(paymentDebtor.street) \(paymentDebtor.houseNumber)",
            at: CGPoint(x: rightColX, y: ry),
            fontType: .textPayment
        )
        ry += draw(
            "\(paymentDebtor.postalCode) \(paymentDebtor.city)",
            at: CGPoint(x: rightColX, y: ry),
            fontType: .textPayment
        )

        var currAmtY = PDFMasse.pageHeight - 34 * PDFMasse.ptPerMm
        _ = draw("Währung", at: CGPoint(x: leftColX, y: currAmtY), fontType: .headerPayment)
        currAmtY += draw(
            "Betrag",
            at: CGPoint(x: leftColX + 30 * PDFMasse.ptPerMm, y: currAmtY),
            fontType: .headerPayment
        )
        _ = draw(invoice.amount.currency.rawValue, at: CGPoint(x: leftColX, y: currAmtY), fontType: .amountPayment)
        _ = draw(
            invoice.amount.formattedShort,
            at: CGPoint(x: leftColX + 30 * PDFMasse.ptPerMm, y: currAmtY),
            fontType: .amountPayment
        )
    }

    // MARK: - Receipt (Empfangsschein) — left 62mm
    private func drawReceipt(invoice: SwissInvoice, in ctx: CGContext) {
        let zahlteilY = PDFMasse.pageHeight - PDFMasse.zahlteilHeight
        let leftX: CGFloat = 5 * PDFMasse.ptPerMm
        var y = zahlteilY + 10
        y += draw("Empfangsschein", at: CGPoint(x: leftX, y: y), fontType: .titleReceiver)
        y += drawEmptyLine(fontType: .titleReceiver)

        // Account / Payable to
        y += draw(
            "Konto / Zahlbar an",
            at: CGPoint(x: leftX, y: y),
            fontType: .headerReceiver
        )
        y += draw(invoice.iban, at: CGPoint(x: leftX, y: y), fontType: .textReceiver)
        y += draw(invoice.creditor.name, at: CGPoint(x: leftX, y: y), fontType: .textReceiver)
        y += draw(
            "\(invoice.creditor.street) \(invoice.creditor.houseNumber)",
            at: CGPoint(x: leftX, y: y),
            fontType: .textReceiver
        )
        y += draw(
            "\(invoice.creditor.postalCode) \(invoice.creditor.city)",
            at: CGPoint(x: leftX, y: y),
            fontType: .textReceiver
        )

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            y += drawEmptyLine(fontType: .headerReceiver)
            y += draw("Referenz", at: CGPoint(x: leftX, y: y), fontType: .headerReceiver)
            y += draw(reference, at: CGPoint(x: leftX, y: y), fontType: .textReceiver)
        }

        // Payable by
        let receiptDebtor = invoice.debtor ?? .empty
        y += drawEmptyLine(fontType: .headerReceiver)
        y += draw("Zahlbar durch", at: CGPoint(x: leftX, y: y), fontType: .headerReceiver)
        y += draw(receiptDebtor.name, at: CGPoint(x: leftX, y: y), fontType: .textReceiver)
        y += draw(
            "\(receiptDebtor.street) \(receiptDebtor.houseNumber)",
            at: CGPoint(x: leftX, y: y),
            fontType: .textReceiver
        )
        y += draw(
            "\(receiptDebtor.postalCode) \(receiptDebtor.city)",
            at: CGPoint(x: leftX, y: y),
            fontType: .textReceiver
        )

        // Currency & Amount
        let currAmtY = PDFMasse.pageHeight - 34 * PDFMasse.ptPerMm
        _ = draw("Währung", at: CGPoint(x: leftX, y: currAmtY), fontType: .headerReceiver)
        _ = draw(
            "Betrag",
            at: CGPoint(x: leftX + 18 * PDFMasse.ptPerMm, y: currAmtY),
            fontType: .headerReceiver
        )
        let valueY = currAmtY + PDFMasse.fontReceiptHeading + 4
        _ = draw(
            invoice.amount.currency.rawValue,
            at: CGPoint(x: leftX, y: valueY),
            fontType: .amountReceiver
        )
        _ = draw(
            invoice.amount.formattedShort,
            at: CGPoint(x: leftX + 18 * PDFMasse.ptPerMm, y: valueY),
            fontType: .amountReceiver
        )

        // "Annahmestelle" (acceptance point) — bottom right of receipt
        let acceptText = "Annahmestelle"
        let acceptY = PDFMasse.pageHeight - 20 * PDFMasse.ptPerMm
        _ = drawRightAligned(acceptText, at: CGPoint(x: PDFMasse.annahmestelle, y: acceptY), fontType: .textReceiver)
    }

    // MARK: - Invoice-specific Drawing Helpers

    private func drawZahlteilSeparator(in ctx: CGContext, y: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: PDFMasse.pageWidth, y: y))
        ctx.strokePath()
        ctx.restoreGState()

        // Scissors symbol
        let scissorsAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10)
        ]
        let scissorsStr = "✂"
        let size = (scissorsStr as NSString).size(withAttributes: scissorsAttr)
        (scissorsStr as NSString).draw(
            at: CGPoint(x: PDFMasse.pageWidth / 2 - size.width / 2, y: y - size.height / 2),
            withAttributes: scissorsAttr
        )
    }

    // MARK: - Address Helpers

    /// Builds address lines from an Address, optionally including the name.
    /// Omits countryCode for CH addresses (domestic).
    private func buildAddressLines(_ address: Address, includeName: Bool) -> [String] {
        var result: [String] = []
        if includeName {
            result.append(address.name)
        }
        if !address.addressAddition.isEmpty {
            result.append(address.addressAddition)
        }
        let street = "\(address.street) \(address.houseNumber)".trimmingCharacters(in: .whitespaces)
        if !street.isEmpty {
            result.append(street)
        }
        let cityLine = "\(address.postalCode) \(address.city)".trimmingCharacters(in: .whitespaces)
        if !cityLine.isEmpty {
            result.append(cityLine)
        }
        if address.countryCode.uppercased() != "CH" && !address.countryCode.isEmpty {
            result.append(address.countryCode)
        }
        return result
    }
}
