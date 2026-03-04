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
///
public struct SwissInvoice: Sendable {
    public let title: String?
    public let creditor: Address
    public let debtor: Address
    public let invoiceDate: Date?
    public let iban: String
    public let referenceType: ReferenceType
    public let reference: String?
    public let additionalInfo: String?
    public let vatNr: String?
    public let subject: String?
    public let leadingText: String?
    public let lineItems: [InvoiceLineItem]
    public let trailingText: String?
    public let fontName: String?
    public let fontSize: CGFloat?

    public init(
        title: String? = nil,
        creditor: Address,
        debtor: Address,
        invoiceDate: Date? = nil,
        iban: String,
        referenceType: ReferenceType = .none,
        reference: String? = nil,
        additionalInfo: String? = nil,
        vatNr: String? = nil,
        subject: String? = nil,
        leadingText: String? = nil,
        lineItems: [InvoiceLineItem] = [],
        trailingText: String? = nil,
        fontName: String? = nil,
        fontSize: CGFloat? = nil
    ) {
        self.creditor = creditor
        self.debtor = debtor
        self.iban = iban
        self.referenceType = referenceType
        self.reference = reference
        self.additionalInfo = additionalInfo
        self.vatNr = vatNr
        self.title = title
        self.subject = subject
        self.leadingText = leadingText
        self.invoiceDate = invoiceDate
        self.lineItems = lineItems
        self.trailingText = trailingText
        self.fontName = fontName
        self.fontSize = fontSize
    }
    
    public var amount: Money {
        lineItems.reduce(Money(amount: Decimal(0), currency: .chf)) { $0 + $1.amount }
    }
    
    public var totalVatAmount: Money? {
        lineItems.filter( { $0.lineItemType == .vat }).reduce(Money(amount: Decimal(0), currency: .chf)) { $0 + $1.amount }
    }
    
    public var totalWithoutVatAmount: Money? {
        lineItems.filter( { $0.lineItemType != .vat }).reduce(Money(amount: Decimal(0), currency: .chf)) { $0 + $1.amount }
    }
    
    public var invoiceItems: [InvoiceLineItem] {
        lineItems.filter( { $0.lineItemType != .vat })
    }
    
    public var vatItems: [InvoiceLineItem] {
        lineItems.filter( { $0.lineItemType == .vat })
    }

    public func pdfData() -> Data {
        InvoicePDFRenderer.render(invoice: self)
    }
    
    public func hasUnitItems() -> Bool {
        lineItems.contains(where: { $0.lineItemType == .unitPrice })
    }
    
    public func hasVat() -> Bool {
        lineItems.contains(where: { $0.lineItemType == .vat })
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

public struct InvoiceLineItem: Sendable {
    public let lineItemType: LineItemType
    public let description: String
    public let quantity: Decimal?
    public let unit: String?
    public let unitPrice: Money?
    public let vatRate: Decimal?
    public let amount: Money
   

    public init(
        lineItemType: LineItemType,
        description: String,
        quantity: Decimal? = nil,
        unit: String? = nil,
        unitPrice: Money? = nil,
        vatRate: Decimal? = nil,
        amount: Money
    ) {
        self.lineItemType = lineItemType
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.vatRate = vatRate
        self.amount = amount
    }
}

public enum LineItemType: String, CaseIterable, Identifiable, Sendable {
    case fixedPrice
    case unitPrice
    case vat
    
    public var id: String { self.rawValue }
    
    public var label: String {
        switch self {
        case .fixedPrice:
            return "Netto-Betrag"
        case .unitPrice:
            return "Stückpreis"
        case .vat:
            return "Mehrwertsteuer"
        }
    }
}

