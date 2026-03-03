import Foundation

/// A single line item on an invoice.
public struct InvoiceLineItem: Sendable {
    public let description: String
    public let quantity: Decimal?
    public let unit: String?
    public let unitPrice: Money?
    public let amount: Money
    public let lineItemType: LineItemType

    public init(
        description: String,
        quantity: Decimal? = nil,
        unit: String? = nil,
        unitPrice: Money? = nil,
        amount: Money,
        lineItemType: LineItemType
    ) {
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.amount = amount
        self.lineItemType = lineItemType
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
