import Foundation

/// A single line item on an invoice.
public struct InvoiceLineItem: Sendable {
    public let description: String
    public let quantity: Decimal?
    public let unit: String?
    public let unitPrice: Money?
    public let amount: Money

    public init(
        description: String,
        quantity: Decimal? = nil,
        unit: String? = nil,
        unitPrice: Money? = nil,
        amount: Money
    ) {
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.amount = amount
    }
}
