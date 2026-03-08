import Testing
import Foundation
@testable import SwissInvoice

@Suite("LineItem Tests")
struct LineItemTests {

    // MARK: - LineItemType

    @Test func lineItemTypeRawValues() {
        #expect(LineItemType.fixedPrice.rawValue == "fixedPrice")
        #expect(LineItemType.unitPrice.rawValue == "unitPrice")
        #expect(LineItemType.vat.rawValue == "vat")
    }

    @Test func lineItemTypeLabels() {
        #expect(LineItemType.fixedPrice.label == "Netto-Betrag")
        #expect(LineItemType.unitPrice.label == "Stückpreis")
        #expect(LineItemType.vat.label == "Mehrwertsteuer")
    }

    @Test func lineItemTypeIdentifiable() {
        #expect(LineItemType.fixedPrice.id == "fixedPrice")
        #expect(LineItemType.unitPrice.id == "unitPrice")
        #expect(LineItemType.vat.id == "vat")
    }

    @Test func lineItemTypeCaseIterable() {
        #expect(LineItemType.allCases.count == 3)
        #expect(LineItemType.allCases.contains(.fixedPrice))
        #expect(LineItemType.allCases.contains(.unitPrice))
        #expect(LineItemType.allCases.contains(.vat))
    }

    // MARK: - InvoiceLineItem Creation

    @Test func fixedPriceItem() {
        let item = InvoiceLineItem(
            lineItemType: .fixedPrice,
            description: "Service",
            amount: Money(amount: 500, currency: .chf)
        )
        #expect(item.lineItemType == .fixedPrice)
        #expect(item.description == "Service")
        #expect(item.amount.amount == 500)
        #expect(item.quantity == nil)
        #expect(item.unit == nil)
        #expect(item.unitPrice == nil)
        #expect(item.vatRate == nil)
    }

    @Test func unitPriceItem() {
        let item = InvoiceLineItem(
            lineItemType: .unitPrice,
            description: "Consulting",
            quantity: 10,
            unit: "h",
            unitPrice: Money(amount: 150, currency: .chf),
            amount: Money(amount: 1500, currency: .chf)
        )
        #expect(item.lineItemType == .unitPrice)
        #expect(item.quantity == 10)
        #expect(item.unit == "h")
        #expect(item.unitPrice?.amount == 150)
        #expect(item.amount.amount == 1500)
    }

    @Test func vatItem() {
        let item = InvoiceLineItem(
            lineItemType: .vat,
            description: "MWST 8.1%",
            vatRate: Decimal(string: "8.1"),
            amount: Money(amount: 81, currency: .chf)
        )
        #expect(item.lineItemType == .vat)
        #expect(item.vatRate == Decimal(string: "8.1"))
        #expect(item.amount.amount == 81)
    }

    // MARK: - Convenience Initializer

    @Test func convenienceInitInfersFixedPrice() {
        let item = InvoiceLineItem(
            description: "Flat fee",
            amount: Money(amount: 500, currency: .chf)
        )
        #expect(item.lineItemType == .fixedPrice)
    }

    @Test func convenienceInitInfersUnitPrice() {
        let item = InvoiceLineItem(
            description: "Consulting",
            quantity: 10,
            unit: "h",
            unitPrice: Money(amount: 150, currency: .chf),
            amount: Money(amount: 1500, currency: .chf)
        )
        #expect(item.lineItemType == .unitPrice)
    }
}
