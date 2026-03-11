import Foundation
import Score
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// A Swiss QR Bill invoice per SIX specification v2.x.
///
/// This is the central type of the SwissInvoice package. It holds all data
/// needed to generate a QR payment part, a PDF invoice, or a standalone QR code image.
///
/// The QR standard only allows CHF and EUR currencies. This is validated
/// at generation time.
///
/// The total `amount` is computed automatically from line items.
///
/// ## Usage
/// ```swift
/// let invoice = SwissInvoice(
///     creditor: creditorAddress,
///     iban: "CH12 3000 0000 0000 1234 5",
///     currency: .chf,
///     debtor: debtorAddress,
///     lineItems: [
///         InvoiceLineItem(description: "Beratung", amount: Money(amount: 150.75, currency: .chf))
///     ]
/// )
/// let pdfData = invoice.pdfData()
/// ```
///
public struct SwissInvoice: Sendable {
    public let title: String?
    public let creditor: Address
    public let debtor: Address?
    public let invoiceDate: Date?
    public let iban: String
    public let referenceType: ReferenceType
    public let reference: String?
    public let additionalInfo: String?
    public let vatNr: String?
    public let subject: String?
    public let leadingText: String?
    public let currency: Currency
    public let lineItems: [InvoiceLineItem]
    public let trailingText: String?
    public let language: InvoiceLanguage
    public let fontName: String?
    public let fontSize: CGFloat?

    /// Total amount computed from all line items (including VAT).
    public var amount: Money {
        lineItems.reduce(Money.zero(currency)) { $0 + $1.amount }
    }

    public init(
        creditor: Address,
        iban: String,
        currency: Currency,
        debtor: Address? = nil,
        referenceType: ReferenceType = .none,
        reference: String? = nil,
        additionalInfo: String? = nil,
        vatNr: String? = nil,
        title: String? = nil,
        subject: String? = nil,
        leadingText: String? = nil,
        invoiceDate: Date? = nil,
        lineItems: [InvoiceLineItem] = [],
        trailingText: String? = nil,
        language: InvoiceLanguage = .de,
        fontName: String? = nil,
        fontSize: CGFloat? = nil
    ) {
        self.creditor = creditor
        self.debtor = debtor
        self.iban = iban
        self.currency = currency
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
        self.language = language
        self.fontName = fontName
        self.fontSize = fontSize
    }

    public var totalVatAmount: Money? {
        let vatItems = lineItems.filter { $0.lineItemType == .vat }
        guard !vatItems.isEmpty else { return nil }
        return vatItems.reduce(Money.zero(currency)) { $0 + $1.amount }
    }

    public var totalWithoutVatAmount: Money? {
        let nonVatItems = lineItems.filter { $0.lineItemType != .vat }
        guard !nonVatItems.isEmpty else { return nil }
        return nonVatItems.reduce(Money.zero(currency)) { $0 + $1.amount }
    }

    public var invoiceItems: [InvoiceLineItem] {
        lineItems.filter { $0.lineItemType != .vat }
    }

    public var vatItems: [InvoiceLineItem] {
        lineItems.filter { $0.lineItemType == .vat }
    }

    public func pdfData() -> Data {
        InvoicePDFRenderer(fontName: fontName, fontSize: fontSize).render(invoice: self)
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

    #if canImport(UIKit)
    /// Generates a QR code UIImage with Swiss Cross overlay.
    /// - Parameter size: Image size in points (default 130).
    /// - Returns: UIImage or nil if generation fails.
    public func qrCodeImage(size: CGFloat = 130) -> UIImage? {
        let payload = qrPayload()
        return QRCodeGenerator.generateImage(payload: payload, size: size)
    }
    #endif
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

    /// Convenience initializer that infers `lineItemType` from the presence of `unitPrice`.
    public init(
        description: String,
        quantity: Decimal? = nil,
        unit: String? = nil,
        unitPrice: Money? = nil,
        amount: Money
    ) {
        self.init(
            lineItemType: unitPrice != nil ? .unitPrice : .fixedPrice,
            description: description,
            quantity: quantity,
            unit: unit,
            unitPrice: unitPrice,
            amount: amount
        )
    }
}

public enum LineItemType: String, CaseIterable, Identifiable, Sendable {
    case fixedPrice
    case unitPrice
    case vat

    public var id: String { self.rawValue }

    /// Localized label for the given language.
    public func label(language: InvoiceLanguage = .de) -> String {
        let strings = InvoiceStrings.forLanguage(language)
        switch self {
        case .fixedPrice:
            return strings.fixedPriceLabel
        case .unitPrice:
            return strings.unitPriceLabel
        case .vat:
            return strings.vatLabel
        }
    }

    /// German label (backward compatibility).
    public var label: String { label() }
}
