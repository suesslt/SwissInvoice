import CoreGraphics
import CoreImage.CIFilterBuiltins
import CoreText
import Score
import ScoreUI
import SwiftUI

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

/// Swiss locale used for formatting monetary amounts.
private let swissLocale = Locale(identifier: "de_CH")

/// Formats a Money amount with '.' as decimal separator and ' ' (space) as thousands separator,
/// as required by the SIX QR Bill specification for the payment slip.
private func formattedAmountForSlip(_ money: Money) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.decimalSeparator = "."
    formatter.groupingSeparator = " "
    formatter.minimumFractionDigits = money.currency.decimalPlaces
    formatter.maximumFractionDigits = money.currency.decimalPlaces
    return formatter.string(from: money.amount as NSDecimalNumber) ?? "0.00"
}

/// Renders a complete A4 invoice PDF with Swiss QR Bill payment part and receipt.
public class InvoicePDFRenderer: PDFRenderer {

    public func render(invoice: SwissInvoice) -> Data {
        let strings = InvoiceStrings.forLanguage(invoice.language)
        guard let (ctx, pdfData) = beginPDF() else { return Data() }
        ctx.scaleBy(x: 1.004, y: 1.0)
        drawBriefkopf(ctx: ctx, invoice: invoice)
        drawAdressfeld(ctx: ctx, invoice: invoice)
        _ = drawLeitwoerter(ctx: ctx, invoice: invoice, strings: strings)
        var yPosition: CGFloat = PDFMasse.topContent
        yPosition += drawSubject(ctx: ctx, invoice: invoice, yPosition: yPosition)
        yPosition += drawEmptyLine(fontType: FontType.standard)
        drawContent(ctx: ctx, invoice: invoice, strings: strings, yPosition: yPosition)
        drawPaymentPart(invoice: invoice, strings: strings, in: ctx)
        drawReceipt(invoice: invoice, strings: strings, in: ctx)
        drawFalzmarken(in: ctx)
        return endPDF(context: ctx, pdfData: pdfData)
    }

    private func drawBriefkopf(ctx: CGContext, invoice: SwissInvoice) {
        var y: CGFloat = PDFMasse.marginTop
        let creditorLines = invoice.creditor.fullAddress()
        if let first = creditorLines.first {
            y += drawText(context: ctx, text: first, x: PDFMasse.marginLeft, y: y, fontType: .title)
        }
        for line in creditorLines.dropFirst() {
            y += drawText(context: ctx, text: line, x: PDFMasse.marginLeft, y: y, fontType: .standard)
        }
        if let title = invoice.title {
            _ = drawTextRightAligned(
                context: ctx,
                text: title,
                rightX: PDFMasse.pageWidth - PDFMasse.marginRight,
                y: PDFMasse.marginTop,
                fontType: .title
            )
        }
    }

    // MARK: - Adressfeldbereich (38 – 97 mm) – Rechtsadressierung per SN 10130:2026 §4.3
    private func drawAdressfeld(ctx: CGContext, invoice: SwissInvoice) {
        let leftX = PDFMasse.adressfeldLeft + 8 * PDFMasse.ptPerMm
        var leftY = PDFMasse.adressfeldTop

        // Center vertically
        let debtorLines = (invoice.debtor ?? .empty).fullAddress()
        let nrLines = debtorLines.count
        let textHeight = nrLines * Int(PDFMasse.fontBody) + (nrLines - 1) * 2
        let yOffset = (PDFMasse.adressfeldHeight - CGFloat(textHeight)) / PDFMasse.lineSpacing
        leftY += yOffset

        for line in debtorLines {
            leftY += drawText(
                context: ctx,
                text: line,
                x: leftX,
                y: leftY,
                fontType: .standard
            )
        }
    }

    private func drawLeitwoerter(ctx: CGContext, invoice: SwissInvoice, strings: InvoiceStrings) -> CGFloat {
        var result = 0.0
        let yPosition = PDFMasse.leitwoerterY
        if let date = invoice.invoiceDate {
            _ = drawText(context: ctx, text: strings.invoiceDateLabel, x: PDFMasse.marginLeft, y: yPosition + result, fontType: .standardSmall)
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.locale = Locale(identifier: invoice.language.localeIdentifier)
            let dateStr = formatter.string(from: date)
            result += drawText(context: ctx, text: dateStr, x: PDFMasse.leitwoerterColumn, y: yPosition + result, fontType: .standardSmall)
        }
        if let reference = invoice.reference, !reference.isEmpty {
            _ = drawText(context: ctx, text: strings.referenceLabel, x: PDFMasse.marginLeft, y: yPosition + result, fontType: .standardSmall)
            result += drawText(context: ctx, text: reference, x: PDFMasse.leitwoerterColumn, y: yPosition + result, fontType: .standardSmall)
        }
        if let additionalInfo = invoice.additionalInfo, !additionalInfo.isEmpty {
            _ = drawText(context: ctx, text: strings.additionalInfoLabel, x: PDFMasse.marginLeft, y: yPosition + result, fontType: .standardSmall)
            result += drawText(context: ctx, text: additionalInfo, x: PDFMasse.leitwoerterColumn, y: yPosition + result, fontType: .standardSmall)
        }
        if let vatNr = invoice.vatNr, !vatNr.isEmpty {
            _ = drawText(context: ctx, text: strings.vatNumberLabel, x: PDFMasse.marginLeft, y: yPosition + result, fontType: .standardSmall)
            result += drawText(context: ctx, text: vatNr, x: PDFMasse.leitwoerterColumn, y: yPosition + result, fontType: .standardSmall)
        }
        return result
    }

    private func drawSubject(ctx: CGContext, invoice: SwissInvoice, yPosition: CGFloat) -> CGFloat {
        var result = 0.0
        if let subject = invoice.subject, !subject.isEmpty {
            result += drawText(context: ctx, text: subject, x: PDFMasse.marginLeft, y: yPosition, fontType: .subject)
        }
        return result
    }

    private func drawTrailingText(ctx: CGContext, invoice: SwissInvoice, yPosition: CGFloat) -> CGFloat {
        var result = 0.0
        if let trailingText = invoice.trailingText, !trailingText.isEmpty {
            result += drawEmptyLine(fontType: FontType.standard)
            result += drawMultiline(
                ctx: ctx,
                trailingText,
                at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result),
                width: PDFMasse.usablePageWidth,
                fontType: .standard
            )
        }
        return result
    }

    private func drawContent(ctx: CGContext, invoice: SwissInvoice, strings: InvoiceStrings, yPosition: CGFloat) {
        var result = 0.0
        if let leadingText = invoice.leadingText, !leadingText.isEmpty {
            result += drawMultiline(
                ctx: ctx,
                leadingText,
                at: CGPoint(x: PDFMasse.marginLeft, y: yPosition + result),
                width: PDFMasse.usablePageWidth,
                fontType: .standard
            )
            result += drawEmptyLine(fontType: FontType.standard)
        }
        result += drawLineItems(ctx: ctx, invoice: invoice, strings: strings, yPosition: yPosition + result)
        _ = drawTrailingText(ctx: ctx, invoice: invoice, yPosition: yPosition + result)
    }

    private func drawFalzmarken(in ctx: CGContext) {
        let markLength: CGFloat = 8 * PDFMasse.ptPerMm  // 4 mm mark
        drawHRule(
            context: ctx,
            y: PDFMasse.lochmarke,
            from: 0,
            to: markLength,
            lineWidth: 0.3,
            color: CGColor(gray: 0.75, alpha: 1.0)
        )
    }

    // MARK: - Line Items Table

    private func drawLineItems(ctx: CGContext, invoice: SwissInvoice, strings: InvoiceStrings, yPosition: CGFloat) -> CGFloat {
        var result = 0.0
        if !invoice.lineItems.isEmpty {
            // Table header
            _ = drawText(context: ctx, text: strings.descriptionHeader, x: PDFMasse.marginLeft, y: yPosition + result, fontType: .titleInvoiceLines)
            if invoice.hasUnitItems() {
                _ = drawText(context: ctx, text: strings.qtyHeader, x: PDFMasse.quantityColumn, y: yPosition + result, fontType: .titleInvoiceLines)
                _ = drawText(context: ctx, text: strings.unitHeader, x: PDFMasse.unitColumn, y: yPosition + result, fontType: .titleInvoiceLines)
                _ = drawTextRightAligned(
                    context: ctx,
                    text: strings.unitPriceHeader,
                    rightX: PDFMasse.unitPriceColumn,
                    y: yPosition + result,
                    fontType: .titleInvoiceLines
                )
            }
            result += drawTextRightAligned(context: ctx, text: strings.amountHeader, rightX: PDFMasse.rightUsableBorder, y: yPosition + result, fontType: .titleInvoiceLines)

            result += 2
            drawHRule(context: ctx, y: yPosition + result, from: PDFMasse.marginLeft, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
            result += 2

            // Line items
            for item in invoice.invoiceItems {
                _ = drawText(context: ctx, text: item.description, x: PDFMasse.marginLeft, y: yPosition + result, fontType: .standard)
                if item.lineItemType == .unitPrice {
                    if let qty = item.quantity {
                        _ = drawText(context: ctx, text: qty.description, x: PDFMasse.quantityColumn, y: yPosition + result, fontType: .standard)
                    }
                    if let unit = item.unit {
                        _ = drawText(context: ctx, text: unit, x: PDFMasse.unitColumn, y: yPosition + result, fontType: .standard)
                    }
                    if let unitPrice = item.unitPrice {
                        _ = drawTextRightAligned(
                            context: ctx,
                            text: unitPrice.formatted(locale: swissLocale),
                            rightX: PDFMasse.unitPriceColumn,
                            y: yPosition + result,
                            fontType: .standard
                        )
                    }
                }
                result += drawTextRightAligned(
                    context: ctx,
                    text: item.amount.formatted(locale: swissLocale),
                    rightX: PDFMasse.rightUsableBorder,
                    y: yPosition + result,
                    fontType: .standard
                )
            }
            result += 2
            drawHRule(context: ctx, y: yPosition + result, from: PDFMasse.marginLeft, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
            result += 2
        }
        if invoice.hasVat() {
            _ = drawText(
                context: ctx,
                text: strings.totalWithoutVat,
                x: PDFMasse.quantityColumn,
                y: yPosition + result,
                fontType: .standardBold
            )
            result += drawTextRightAligned(
                context: ctx,
                text: invoice.totalWithoutVatAmount!.formatted(locale: swissLocale),
                rightX: PDFMasse.rightUsableBorder,
                y: yPosition + result,
                fontType: .standardBold
            )
            for item in invoice.groupedVatItems {
                _ = drawText(
                    context: ctx,
                    text: strings.vatPrefix + " " + item.vatRate!.formatted() + "%",
                    x: PDFMasse.quantityColumn,
                    y: yPosition + result,
                    fontType: .standardBold
                )
                result += drawTextRightAligned(
                    context: ctx,
                    text: item.amount.formatted(locale: swissLocale),
                    rightX: PDFMasse.rightUsableBorder,
                    y: yPosition + result,
                    fontType: .standardBold
                )
            }
        }
        _ = drawText(context: ctx, text: strings.total, x: PDFMasse.quantityColumn, y: yPosition + result, fontType: .standardBold)
        result += drawTextRightAligned(
            context: ctx,
            text: invoice.amount.formatted(locale: swissLocale),
            rightX: PDFMasse.rightUsableBorder,
            y: yPosition + result,
            fontType: .standardBold
        )
        result += 2
        drawHRule(context: ctx, y: yPosition + result, from: PDFMasse.quantityColumn, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
        result += 1
        drawHRule(context: ctx, y: yPosition + result, from: PDFMasse.quantityColumn, to: PDFMasse.rightUsableBorder, lineWidth: 0.3)
        return result
    }

    // MARK: - Payment Part (Zahlteil) — right 148mm

    private func drawPaymentPart(invoice: SwissInvoice, strings: InvoiceStrings, in ctx: CGContext) {
        let zahlteilY = PDFMasse.pageHeight - PDFMasse.zahlteilHeight
        drawZahlteilSeparator(in: ctx, y: zahlteilY)
        drawVerticalLine(context: ctx, x: PDFMasse.verticalSepX, fromY: zahlteilY, toY: PDFMasse.pageHeight, dashed: true)
        let leftColX = PDFMasse.verticalSepX + 5 * PDFMasse.ptPerMm
        var y = zahlteilY + 10
        y += drawText(context: ctx, text: strings.paymentPart, x: leftColX, y: y, fontType: .titlePayment)

        // QR Code (exactly 46mm per SIX spec, modules only + vector Swiss Cross)
        let payload = QRPayloadGenerator.generatePayload(for: invoice)
        if let modulesCGImage = QRCodeGenerator.generateModulesCGImage(
            payload: payload,
            pixelSize: Int(QRCodeGenerator.printPixelSize)
        ) {
            let cgY = pageHeight - PDFMasse.qrTop - PDFMasse.qrCodeSize
            let qrDrawRect = CGRect(
                x: PDFMasse.qrLeft,
                y: cgY,
                width: PDFMasse.qrCodeSize,
                height: PDFMasse.qrCodeSize
            )
            ctx.draw(modulesCGImage, in: qrDrawRect)
            QRCodeGenerator.drawSwissCrossOverlay(in: qrDrawRect, context: ctx)
            y += PDFMasse.qrCodeSize + 8
        }
        let rightColX = leftColX + PDFMasse.qrCodeSize + 8 * PDFMasse.ptPerMm
        var ry = zahlteilY + 10

        // Account / Payable to
        ry += drawText(
            context: ctx,
            text: strings.accountPayableTo,
            x: rightColX,
            y: ry,
            fontType: .headerPayment
        )
        ry += drawText(context: ctx, text: invoice.iban, x: rightColX, y: ry, fontType: .textPayment)
        for line in invoice.creditor.paymentAddress() {
            ry += drawText(context: ctx, text: line, x: rightColX, y: ry, fontType: .textPayment)
        }
        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            ry += drawEmptyLine(fontType: .headerPayment)
            ry += drawText(context: ctx, text: strings.paymentReference, x: rightColX, y: ry, fontType: .headerPayment)
            ry += drawText(context: ctx, text: reference, x: rightColX, y: ry, fontType: .textPayment)
        }

        // Additional info
        if let info = invoice.additionalInfo, !info.isEmpty {
            ry += drawEmptyLine(fontType: .headerPayment)
            ry += drawText(
                context: ctx,
                text: strings.additionalInformation,
                x: rightColX,
                y: ry,
                fontType: .headerPayment
            )
            ry += drawText(context: ctx, text: info, x: rightColX, y: ry, fontType: .textPayment)
        }

        // Payable by
        ry += drawEmptyLine(fontType: .headerPayment)
        ry += drawText(
            context: ctx,
            text: strings.payableBy,
            x: rightColX,
            y: ry,
            fontType: .headerPayment
        )
        for line in (invoice.debtor ?? .empty).paymentAddress() {
            ry += drawText(context: ctx, text: line, x: rightColX, y: ry, fontType: .textPayment)
        }

        var currAmtY = PDFMasse.pageHeight - 34 * PDFMasse.ptPerMm
        _ = drawText(context: ctx, text: strings.currency, x: leftColX, y: currAmtY, fontType: .headerPayment)
        currAmtY += drawText(
            context: ctx,
            text: strings.amountLabel,
            x: leftColX + 30 * PDFMasse.ptPerMm,
            y: currAmtY,
            fontType: .headerPayment
        )
        _ = drawText(context: ctx, text: invoice.amount.currency.rawValue, x: leftColX, y: currAmtY, fontType: .textPayment)
        _ = drawText(
            context: ctx,
            text: formattedAmountForSlip(invoice.amount),
            x: leftColX + 30 * PDFMasse.ptPerMm,
            y: currAmtY,
            fontType: .textPayment
        )
    }

    // MARK: - Receipt (Empfangsschein) — left 62mm
    private func drawReceipt(invoice: SwissInvoice, strings: InvoiceStrings, in ctx: CGContext) {
        let zahlteilY = PDFMasse.pageHeight - PDFMasse.zahlteilHeight
        let leftX: CGFloat = 5 * PDFMasse.ptPerMm
        var y = zahlteilY + 10
        y += drawText(context: ctx, text: strings.receipt, x: leftX, y: y, fontType: .titleReceiver)
        y += drawEmptyLine(fontType: .titleReceiver)

        // Account / Payable to
        y += drawText(
            context: ctx,
            text: strings.accountPayableTo,
            x: leftX,
            y: y,
            fontType: .headerReceiver
        )
        y += drawText(context: ctx, text: invoice.iban, x: leftX, y: y, fontType: .textReceiver)
        for line in invoice.creditor.paymentAddress() {
            y += drawText(context: ctx, text: line, x: leftX, y: y, fontType: .textReceiver)
        }

        // Reference
        if let reference = invoice.reference, !reference.isEmpty {
            y += drawEmptyLine(fontType: .headerReceiver)
            y += drawText(context: ctx, text: strings.paymentReference, x: leftX, y: y, fontType: .headerReceiver)
            y += drawText(context: ctx, text: reference, x: leftX, y: y, fontType: .textReceiver)
        }

        // Payable by
        y += drawEmptyLine(fontType: .headerReceiver)
        y += drawText(context: ctx, text: strings.payableBy, x: leftX, y: y, fontType: .headerReceiver)
        for line in (invoice.debtor ?? .empty).paymentAddress() {
            y += drawText(context: ctx, text: line, x: leftX, y: y, fontType: .textReceiver)
        }

        // Currency & Amount
        let currAmtY = PDFMasse.pageHeight - 34 * PDFMasse.ptPerMm
        _ = drawText(context: ctx, text: strings.currency, x: leftX, y: currAmtY, fontType: .headerReceiver)
        _ = drawText(
            context: ctx,
            text: strings.amountLabel,
            x: leftX + 18 * PDFMasse.ptPerMm,
            y: currAmtY,
            fontType: .headerReceiver
        )
        let valueY = currAmtY + PDFMasse.fontReceiptHeading + 4
        _ = drawText(
            context: ctx,
            text: invoice.amount.currency.rawValue,
            x: leftX,
            y: valueY,
            fontType: .textReceiver
        )
        _ = drawText(
            context: ctx,
            text: formattedAmountForSlip(invoice.amount),
            x: leftX + 18 * PDFMasse.ptPerMm,
            y: valueY,
            fontType: .textReceiver
        )

        // "Annahmestelle" (acceptance point) — bottom right of receipt
        let acceptY = PDFMasse.pageHeight - 20 * PDFMasse.ptPerMm
        _ = drawTextRightAligned(context: ctx, text: strings.acceptancePoint, rightX: PDFMasse.annahmestelle, y: acceptY, fontType: .textReceiver)
    }

    // MARK: - Invoice-specific Drawing Helpers

    private func drawZahlteilSeparator(in ctx: CGContext, y: CGFloat) {
        drawHRule(
            context: ctx,
            y: y,
            from: 0,
            to: PDFMasse.pageWidth,
            lineWidth: 0.5,
            dashed: true,
            color: PDFRenderer.colorBlack
        )

        // Scissors symbol
        let ctFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: ctFont,
            .foregroundColor: PDFRenderer.colorBlack
        ]
        let attrStr = NSAttributedString(string: "\u{2702}", attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        let scissorsX = PDFMasse.pageWidth / 2 - bounds.width / 2
        ctx.textPosition = CGPoint(x: scissorsX, y: pageHeight - y + bounds.height / 2)
        CTLineDraw(line, ctx)
    }

    // MARK: - Multiline Text Drawing

    private func drawMultiline(
        ctx: CGContext,
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        fontType: FontType
    ) -> CGFloat {
        let ctFont = createCTFont(fontType: fontType)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: ctFont,
            .foregroundColor: PDFRenderer.colorBlack,
            .paragraphStyle: paragraphStyle
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)

        let constraintSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil, constraintSize, nil
        )

        let cgY = pageHeight - point.y - suggestedSize.height
        let framePath = CGPath(
            rect: CGRect(x: point.x, y: cgY, width: width, height: suggestedSize.height),
            transform: nil
        )
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), framePath, nil)
        CTFrameDraw(frame, ctx)
        return suggestedSize.height
    }

}
