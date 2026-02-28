import Testing
import Foundation
@testable import SwissInvoice

@Suite("SwissInvoice Integration Tests")
struct SwissInvoiceTests {

    private var creditor: Address {
        Address(
            name: "Muster AG",
            street: "Bahnhofstrasse",
            houseNumber: "1",
            postalCode: "8001",
            city: "Zürich",
            countryCode: "CH"
        )
    }

    private var debtor: Address {
        Address(
            name: "Hans Mustermann",
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
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
        )
        #expect(invoice.creditor.name == "Muster AG")
        #expect(invoice.iban == "CH1230000000000012345")
        #expect(invoice.amount.amount == Decimal(string: "100.00")!)
        #expect(invoice.amount.currency == .chf)
        #expect(invoice.debtor == nil)
        #expect(invoice.referenceType == .none)
        #expect(invoice.reference == nil)
        #expect(invoice.additionalInfo == nil)
        #expect(invoice.title == nil)
        #expect(invoice.invoiceDate == nil)
        #expect(invoice.lineItems.isEmpty)
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
            amount: Money(amount: Decimal(string: "150.75")!, currency: .chf),
            debtor: debtor,
            referenceType: .qrReference,
            reference: "210000000003139471430009017",
            additionalInfo: "Test invoice",
            title: "Invoice 001",
            invoiceDate: date,
            lineItems: items
        )
        #expect(invoice.debtor?.name == "Hans Mustermann")
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
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
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
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
        )
        let payload = invoice.qrPayload()
        #expect(payload.hasPrefix("SPC\n0200\n1"))
        let lines = payload.components(separatedBy: "\n")
        #expect(lines.count == 33)
    }

    @Test func qrCodeImageReturnsImage() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
        )
        let image = invoice.qrCodeImage()
        #expect(image != nil)
    }

    @Test func moneyIntegrationInPayload() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "1234.50")!, currency: .eur)
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[18] == "1234.50")
        #expect(lines[19] == "EUR")
    }
}
