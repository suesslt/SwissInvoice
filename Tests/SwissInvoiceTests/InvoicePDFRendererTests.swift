import Testing
import Foundation
import PDFKit
import Score
@testable import SwissInvoice

@Suite("Invoice PDF Renderer Tests")
struct InvoicePDFRendererTests {

    private var creditor: Address {
        Address(
            name: "Muster AG",
            addressAddition: "",
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
            addressAddition: "",
            street: "Rebenweg",
            houseNumber: "12",
            postalCode: "3000",
            city: "Bern",
            countryCode: "CH"
        )
    }

    @Test func pdfDataNotEmpty() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
        )
        let data = invoice.pdfData()
        #expect(!data.isEmpty)
    }

    @Test func pdfHasCorrectHeader() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
        )
        let data = invoice.pdfData()
        let headerString = String(data: data.prefix(5), encoding: .ascii)
        #expect(headerString == "%PDF-")
    }

    @Test func pdfPageSizeA4() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        #expect(pdf != nil)
        #expect(pdf?.pageCount == 1)

        if let page = pdf?.page(at: 0) {
            let bounds = page.bounds(for: .mediaBox)
            // A4: 595.28 × 841.89 pt (±1pt tolerance)
            #expect(abs(bounds.width - 595.28) < 1)
            #expect(abs(bounds.height - 841.89) < 1)
        }
    }

    @Test func minimalInvoice() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "50.00")!, currency: .chf)
        )
        let data = invoice.pdfData()
        #expect(!data.isEmpty)

        let pdf = PDFDocument(data: data)
        #expect(pdf != nil)
    }

    @Test func fullInvoice() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "150.75")!, currency: .chf),
            debtor: debtor,
            referenceType: .qrReference,
            reference: "210000000003139471430009017",
            additionalInfo: "Rechnung Nr. 10234",
            title: "Stromrechnung",
            invoiceDate: Date()
        )
        let data = invoice.pdfData()
        #expect(!data.isEmpty)

        let pdf = PDFDocument(data: data)
        #expect(pdf?.pageCount == 1)
    }

    @Test func invoiceWithLineItems() {
        let items = [
            InvoiceLineItem(
                description: "Consulting",
                quantity: 10,
                unit: "h",
                unitPrice: Money(amount: Decimal(string: "150.00")!, currency: .chf),
                amount: Money(amount: Decimal(string: "1500.00")!, currency: .chf)
            ),
            InvoiceLineItem(
                description: "Travel expenses",
                amount: Money(amount: Decimal(string: "250.00")!, currency: .chf)
            ),
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "1750.00")!, currency: .chf),
            debtor: debtor,
            title: "Invoice",
            invoiceDate: Date(),
            lineItems: items
        )
        let data = invoice.pdfData()
        #expect(!data.isEmpty)

        let pdf = PDFDocument(data: data)
        #expect(pdf?.pageCount == 1)
    }

    @Test func pdfContainsReceiptText() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf),
            debtor: debtor
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("Empfangsschein"))
        #expect(pageText.contains("Zahlteil"))
    }

    @Test func pdfWithVatLineItems() {
        let items = [
            InvoiceLineItem(
                lineItemType: .fixedPrice,
                description: "Service",
                amount: Money(amount: Decimal(string: "1000.00")!, currency: .chf)
            ),
            InvoiceLineItem(
                lineItemType: .vat,
                description: "MWST 8.1%",
                vatRate: Decimal(string: "8.1"),
                amount: Money(amount: Decimal(string: "81.00")!, currency: .chf)
            )
        ]
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "1081.00")!, currency: .chf),
            debtor: debtor,
            lineItems: items
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("Total"))
        #expect(pageText.contains("MWST"))
    }

    @Test func pdfWithLeadingAndTrailingText() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf),
            debtor: debtor,
            subject: "Oktober 2024",
            leadingText: "Sehr geehrte Damen und Herren",
            lineItems: [
                InvoiceLineItem(
                    description: "Beratung",
                    amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
                )
            ],
            trailingText: "Zahlbar innert 30 Tagen"
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("Sehr geehrte"))
        #expect(pageText.contains("Zahlbar"))
    }

    @Test func pdfWithoutDebtor() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf)
        )
        let data = invoice.pdfData()
        #expect(!data.isEmpty)
        let pdf = PDFDocument(data: data)
        #expect(pdf?.pageCount == 1)
    }

    @Test func pdfWithEurCurrency() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "250.00")!, currency: .eur),
            debtor: debtor
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("EUR"))
    }

    @Test func pdfWithReference() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf),
            debtor: debtor,
            referenceType: .qrReference,
            reference: "210000000003139471430009017"
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("Referenz"))
    }

    @Test func pdfWithCustomFont() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            amount: Money(amount: Decimal(string: "100.00")!, currency: .chf),
            fontName: "Courier",
            fontSize: 12
        )
        let data = invoice.pdfData()
        #expect(!data.isEmpty)
    }
}
