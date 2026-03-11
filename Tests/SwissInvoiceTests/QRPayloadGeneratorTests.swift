import Testing
import Foundation
import Score
@testable import SwissInvoice

@Suite("QR Payload Generator Tests")
struct QRPayloadGeneratorTests {

    // MARK: - Test Data

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

    // MARK: - Header

    @Test func headerFormat() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "150.75")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[0] == "SPC")
        #expect(lines[1] == "0200")
        #expect(lines[2] == "1")
    }

    // MARK: - Total Line Count

    @Test func totalLineCount() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            debtor: debtor,
            referenceType: .qrReference,
            reference: "210000000003139471430009017",
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "150.75")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        // SPC format: exactly 32 separators → 33 lines
        #expect(lines.count == 33)
    }

    // MARK: - IBAN

    @Test func ibanWithoutSpaces() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH12 3000 0000 0000 1234 5",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[3] == "CH1230000000000012345")
    }

    // MARK: - Creditor Address

    @Test func creditorStructuredAddress() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[4] == "S")
        #expect(lines[5] == "Muster AG")
        #expect(lines[6] == "Bahnhofstrasse")
        #expect(lines[7] == "1")
        #expect(lines[8] == "8001")
        #expect(lines[9] == "Zürich")
        #expect(lines[10] == "CH")
    }

    // MARK: - Ultimate Creditor (reserved, empty)

    @Test func ultimateCreditorEmpty() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        for i in 11...17 {
            #expect(lines[i] == "", "Line \(i) should be empty (ultimate creditor)")
        }
    }

    // MARK: - Amount

    @Test func amountFormatting() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "150.75")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[18] == "150.75")
    }

    @Test func amountZeroIsEmpty() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[18] == "")
    }

    // MARK: - Currency

    @Test func currencyCHF() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[19] == "CHF")
    }

    @Test func currencyEUR() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .eur,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .eur))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[19] == "EUR")
    }

    // MARK: - Debtor

    @Test func debtorPresent() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            debtor: debtor,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[20] == "S")
        #expect(lines[21] == "Hans Mustermann")
        #expect(lines[22] == "Rebenweg")
        #expect(lines[23] == "12")
        #expect(lines[24] == "3000")
        #expect(lines[25] == "Bern")
        #expect(lines[26] == "CH")
    }

    @Test func debtorAbsent() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        for i in 20...26 {
            #expect(lines[i] == "", "Line \(i) should be empty (no debtor)")
        }
    }

    // MARK: - Reference

    @Test func referenceTypeQRR() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            referenceType: .qrReference,
            reference: "21 00000 00003 13947 14300 09017",
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[27] == "QRR")
        #expect(lines[28] == "210000000003139471430009017")
    }

    @Test func referenceTypeSCOR() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            referenceType: .creditorReference,
            reference: "RF18 5390 0754 7034",
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[27] == "SCOR")
        #expect(lines[28] == "RF18539007547034")
    }

    @Test func referenceTypeNON() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            referenceType: .none,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[27] == "NON")
        #expect(lines[28] == "")
    }

    // MARK: - Additional Info & Trailer

    @Test func additionalInfoAndTrailer() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            additionalInfo: "Rechnung Nr. 10234",
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[29] == "Rechnung Nr. 10234")
        #expect(lines[30] == "EPD")
    }

    @Test func alternativeProceduresEmpty() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")
        #expect(lines[31] == "")
        #expect(lines[32] == "")
    }

    // MARK: - Full Payload

    @Test func fullPayload() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH12 3000 0000 0000 1234 5",
            currency: .chf,
            debtor: debtor,
            referenceType: .qrReference,
            reference: "21 00000 00003 13947 14300 09017",
            additionalInfo: "Rechnung Nr. 10234",
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "150.75")!, currency: .chf))]
        )
        let payload = invoice.qrPayload()
        let lines = payload.components(separatedBy: "\n")

        #expect(lines.count == 33)
        #expect(lines[0] == "SPC")
        #expect(lines[3] == "CH1230000000000012345")
        #expect(lines[4] == "S")
        #expect(lines[5] == "Muster AG")
        #expect(lines[18] == "150.75")
        #expect(lines[19] == "CHF")
        #expect(lines[20] == "S")
        #expect(lines[21] == "Hans Mustermann")
        #expect(lines[27] == "QRR")
        #expect(lines[28] == "210000000003139471430009017")
        #expect(lines[29] == "Rechnung Nr. 10234")
        #expect(lines[30] == "EPD")
    }
}
