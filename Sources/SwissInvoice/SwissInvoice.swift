import UIKit

/// A Swiss QR Bill invoice per SIX specification v2.x.
///
/// This is the central type of the SwissInvoice package. It holds all data
/// needed to generate a QR payment part, a PDF invoice, or a standalone QR code image.
///
/// The QR standard only allows CHF and EUR currencies. This is validated
/// at generation time.
///
/// ## Usage
/// ```swift
/// let invoice = SwissInvoice(
///     creditor: creditorAddress,
///     iban: "CH12 3000 0000 0000 1234 5",
///     amount: Money(amount: 150.75, currency: .chf),
///     debtor: debtorAddress
/// )
/// let pdfData = invoice.pdfData()
/// let qrImage = invoice.qrCodeImage()
/// ```
public struct SwissInvoice: Sendable {

    // MARK: - Required Fields

    /// Creditor (payee) address.
    public let creditor: Address

    /// IBAN or QR-IBAN of the creditor.
    public let iban: String

    /// Invoice amount. Currency is derived from `amount.currency`.
    /// Only CHF and EUR are allowed per the Swiss QR Bill standard.
    public let amount: Money

    // MARK: - Optional Fields

    /// Debtor (payer) address.
    public let debtor: Address?

    /// Payment reference type.
    public let referenceType: ReferenceType

    /// Payment reference number.
    public let reference: String?

    /// Additional unstructured information.
    public let additionalInfo: String?

    // MARK: - PDF Layout Fields

    /// Invoice title shown in the letterhead area (defaults to "Rechnung").
    public let title: String?

    /// Subject line (Betreff) displayed bold below the address area per SN 10130:2026.
    public let subject: String?

    /// Invoice date.
    public let invoiceDate: Date?

    /// Line items for the invoice table.
    public let lineItems: [InvoiceLineItem]

    /// Custom font name for PDF rendering. Falls back to Helvetica if nil or invalid.
    public let fontName: String?

    /// Font size for the invoice body text. Defaults to 10 pt.
    public let fontSize: CGFloat?

    // MARK: - Initializer

    public init(
        creditor: Address,
        iban: String,
        amount: Money,
        debtor: Address? = nil,
        referenceType: ReferenceType = .none,
        reference: String? = nil,
        additionalInfo: String? = nil,
        title: String? = nil,
        subject: String? = nil,
        invoiceDate: Date? = nil,
        lineItems: [InvoiceLineItem] = [],
        fontName: String? = nil,
        fontSize: CGFloat? = nil
    ) {
        self.creditor = creditor
        self.iban = iban
        self.amount = amount
        self.debtor = debtor
        self.referenceType = referenceType
        self.reference = reference
        self.additionalInfo = additionalInfo
        self.title = title
        self.subject = subject
        self.invoiceDate = invoiceDate
        self.lineItems = lineItems
        self.fontName = fontName
        self.fontSize = fontSize
    }

    // MARK: - Public API

    /// Generates the A4 PDF with invoice details and Swiss QR Bill payment part.
    public func pdfData() -> Data {
        InvoicePDFRenderer.render(invoice: self)
    }

    /// Generates the SPC/0200/1 QR payload string.
    public func qrPayload() -> String {
        QRPayloadGenerator.generatePayload(for: self)
    }

    /// Generates a QR code UIImage with Swiss Cross overlay.
    /// - Parameter size: Image size in points (default 130).
    /// - Returns: UIImage or nil if generation fails.
    public func qrCodeImage(size: CGFloat = 130) -> UIImage? {
        let payload = qrPayload()
        return QRCodeGenerator.generateImage(payload: payload, size: size)
    }
}
