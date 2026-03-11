import Testing
import Foundation
import Score
@testable import SwissInvoice

@Suite("SwissInvoice Integration Tests")
struct SwissInvoiceTests {

    private var creditor: Address {
        Address(
            companyName: "Muster AG",
            street: "Bahnhofstrasse",
            houseNumber: "1",
            postalCode: "8001",
            city: "Zürich",
            countryCode: "CH"
        )
    }

    private var debtor: Address {
        Address(
            firstName: "Hans",
            lastName: "Mustermann",
            street: "Rebenweg",
            houseNumber: "12",
            postalCode: "3000",
            city: "Bern",
            countryCode: "CH"
        )
    }

    @Test func minimalCreation() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        #expect(invoice.creditor.companyName == "Muster AG")
        #expect(invoice.iban == "CH1230000000000012345")
        #expect(invoice.amount.amount == Decimal(string: "100.00")!)
        #expect(invoice.amount.currency == .chf)
        #expect(invoice.debtor == nil)
        #expect(invoice.referenceType == .none)
        #expect(invoice.reference == nil)
        #expect(invoice.additionalInfo == nil)
        #expect(invoice.title == nil)
        #expect(invoice.invoiceDate == nil)
    }

    @Test func fullCreation() {
        let date = Date()
        let items = [
            InvoiceLineItem(
                description: "Service",
                quantity: 1,
                unit: "pcs",
                unitPrice: Money(amount: Decimal(string: "150.75")!, currency: .chf),
                amount: Money(amount: Decimal(string: "150.75")!, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            debtor: debtor,
            referenceType: .qrReference,
            reference: "210000000003139471430009017",
            additionalInfo: "Test invoice",
            title: "Invoice 001",
            invoiceDate: date,
            lineItems: items
        )
        #expect(invoice.debtor?.displayName == "Hans Mustermann")
        #expect(invoice.referenceType == .qrReference)
        #expect(invoice.reference == "210000000003139471430009017")
        #expect(invoice.additionalInfo == "Test invoice")
        #expect(invoice.title == "Invoice 001")
        #expect(invoice.invoiceDate == date)
        #expect(invoice.lineItems.count == 1)
    }

    @Test func pdfDataReturnsValidPDF() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let data = invoice.pdfData()
        #expect(!data.isEmpty)
        let header = String(data: data.prefix(5), encoding: .ascii)
        #expect(header == "%PDF-")
    }

    @Test func qrPayloadReturnsValidString() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        #expect(payload.hasPrefix("SPC\n0200\n1"))
        let lines = payload.components(separatedBy: "\n")
        #expect(lines.count == 33)
    }

    #if canImport(UIKit)
    @Test func qrCodeImageReturnsImage() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let image = invoice.qrCodeImage()
        #expect(image != nil)
    }
    #endif

    @Test func moneyIntegrationInPayload() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .eur,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "1234.50")!, currency: .eur))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[18] == "1234.50")
        #expect(lines[19] == "EUR")
    }

    // MARK: - Business Logic

    @Test func hasUnitItemsTrue() {
        let items = [
            InvoiceLineItem(
                description: "Consulting",
                quantity: 10,
                unit: "h",
                unitPrice: Money(amount: 150, currency: .chf),
                amount: Money(amount: 1500, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: items
        )
        #expect(invoice.hasUnitItems())
    }

    @Test func hasUnitItemsFalse() {
        let items = [
            InvoiceLineItem(
                description: "Flat fee",
                amount: Money(amount: 500, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: items
        )
        #expect(!invoice.hasUnitItems())
    }

    @Test func hasUnitItemsEmpty() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf
        )
        #expect(!invoice.hasUnitItems())
    }

    @Test func hasVatTrue() {
        let items = [
            InvoiceLineItem(
                lineItemType: .fixedPrice,
                description: "Service",
                amount: Money(amount: 1000, currency: .chf)
            ),
            InvoiceLineItem(
                lineItemType: .vat,
                description: "MWST 8.1%",
                vatRate: Decimal(string: "8.1"),
                amount: Money(amount: 81, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: items
        )
        #expect(invoice.hasVat())
    }

    @Test func hasVatFalse() {
        let items = [
            InvoiceLineItem(
                description: "Service",
                amount: Money(amount: 1000, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: items
        )
        #expect(!invoice.hasVat())
    }

    @Test func invoiceItemsFiltering() {
        let items = [
            InvoiceLineItem(
                lineItemType: .fixedPrice,
                description: "Service",
                amount: Money(amount: 1000, currency: .chf)
            ),
            InvoiceLineItem(
                lineItemType: .unitPrice,
                description: "Consulting",
                quantity: 5,
                unit: "h",
                unitPrice: Money(amount: 200, currency: .chf),
                amount: Money(amount: 1000, currency: .chf)
            ),
            InvoiceLineItem(
                lineItemType: .vat,
                description: "MWST",
                vatRate: Decimal(string: "8.1"),
                amount: Money(amount: 162, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: items
        )
        #expect(invoice.invoiceItems.count == 2)
        #expect(invoice.vatItems.count == 1)
        #expect(invoice.invoiceItems.allSatisfy { $0.lineItemType != .vat })
        #expect(invoice.vatItems.allSatisfy { $0.lineItemType == .vat })
    }

    @Test func totalVatAmount() {
        let items = [
            InvoiceLineItem(
                lineItemType: .fixedPrice,
                description: "Service",
                amount: Money(amount: 1000, currency: .chf)
            ),
            InvoiceLineItem(
                lineItemType: .vat,
                description: "MWST 8.1%",
                vatRate: Decimal(string: "8.1"),
                amount: Money(amount: 81, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: items
        )
        #expect(invoice.totalVatAmount?.amount == 81)
    }

    @Test func totalWithoutVatAmount() {
        let items = [
            InvoiceLineItem(
                lineItemType: .fixedPrice,
                description: "Service",
                amount: Money(amount: 1000, currency: .chf)
            ),
            InvoiceLineItem(
                lineItemType: .vat,
                description: "MWST 8.1%",
                vatRate: Decimal(string: "8.1"),
                amount: Money(amount: 81, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: items
        )
        #expect(invoice.totalWithoutVatAmount?.amount == 1000)
    }

    @Test func totalVatAmountNilWhenNoVat() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf
        )
        #expect(invoice.totalVatAmount == nil)
    }

    @Test func totalWithoutVatAmountNilWhenNoItems() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf
        )
        #expect(invoice.totalWithoutVatAmount == nil)
    }

    @Test func optionalFields() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            vatNr: "CHE-123.456.789 MWST",
            subject: "Rechnung Oktober",
            leadingText: "Sehr geehrte Damen und Herren",
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: 100, currency: .chf))],
            trailingText: "Zahlbar innert 30 Tagen"
        )
        #expect(invoice.vatNr == "CHE-123.456.789 MWST")
        #expect(invoice.subject == "Rechnung Oktober")
        #expect(invoice.leadingText == "Sehr geehrte Damen und Herren")
        #expect(invoice.trailingText == "Zahlbar innert 30 Tagen")
    }

    @Test func fontSettings() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: 100, currency: .chf))],
            fontName: "Roboto",
            fontSize: 12
        )
        #expect(invoice.fontName == "Roboto")
        #expect(invoice.fontSize == 12)
    }
}
