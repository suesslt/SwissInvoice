import Testing
import Foundation
import PDFKit
import Score
@testable import SwissInvoice

@Suite("Invoice Localization Tests")
struct InvoiceLocalizationTests {

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

    // MARK: - InvoiceLanguage

    @Test func languageLocaleIdentifiers() {
        #expect(InvoiceLanguage.de.localeIdentifier == "de_CH")
        #expect(InvoiceLanguage.en.localeIdentifier == "en_CH")
        #expect(InvoiceLanguage.fr.localeIdentifier == "fr_CH")
    }

    // MARK: - InvoiceStrings Loading

    @Test func loadGermanStrings() {
        let strings = InvoiceStrings.forLanguage(.de)
        #expect(strings.paymentPart == "Zahlteil")
        #expect(strings.receipt == "Empfangsschein")
        #expect(strings.acceptancePoint == "Annahmestelle")
        #expect(strings.accountPayableTo == "Konto / Zahlbar an")
        #expect(strings.payableBy == "Zahlbar durch")
        #expect(strings.currency == "Währung")
        #expect(strings.amountLabel == "Betrag")
        #expect(strings.total == "Total")
        #expect(strings.vatPrefix == "MWST")
    }

    @Test func loadEnglishStrings() {
        let strings = InvoiceStrings.forLanguage(.en)
        #expect(strings.paymentPart == "Payment part")
        #expect(strings.receipt == "Receipt")
        #expect(strings.acceptancePoint == "Acceptance point")
        #expect(strings.accountPayableTo == "Account / Payable to")
        #expect(strings.payableBy == "Payable by")
        #expect(strings.currency == "Currency")
        #expect(strings.amountLabel == "Amount")
        #expect(strings.total == "Total")
        #expect(strings.vatPrefix == "VAT")
    }

    @Test func loadFrenchStrings() {
        let strings = InvoiceStrings.forLanguage(.fr)
        #expect(strings.paymentPart == "Section paiement")
        #expect(strings.receipt == "Récépissé")
        #expect(strings.acceptancePoint == "Point de dépôt")
        #expect(strings.accountPayableTo == "Compte / Payable à")
        #expect(strings.payableBy == "Payable par")
        #expect(strings.currency == "Monnaie")
        #expect(strings.amountLabel == "Montant")
        #expect(strings.total == "Total")
        #expect(strings.vatPrefix == "TVA")
    }

    // MARK: - Default Language

    @Test func defaultLanguageIsGerman() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        #expect(invoice.language == .de)
    }

    // MARK: - LineItemType Labels

    @Test func lineItemTypeLabelGerman() {
        #expect(LineItemType.fixedPrice.label(language: .de) == "Netto-Betrag")
        #expect(LineItemType.unitPrice.label(language: .de) == "Stückpreis")
        #expect(LineItemType.vat.label(language: .de) == "Mehrwertsteuer")
    }

    @Test func lineItemTypeLabelEnglish() {
        #expect(LineItemType.fixedPrice.label(language: .en) == "Fixed price")
        #expect(LineItemType.unitPrice.label(language: .en) == "Unit price")
        #expect(LineItemType.vat.label(language: .en) == "VAT")
    }

    @Test func lineItemTypeLabelFrench() {
        #expect(LineItemType.fixedPrice.label(language: .fr) == "Montant net")
        #expect(LineItemType.unitPrice.label(language: .fr) == "Prix unitaire")
        #expect(LineItemType.vat.label(language: .fr) == "Taxe sur la valeur ajoutée")
    }

    @Test func lineItemTypeLabelDefaultIsGerman() {
        #expect(LineItemType.fixedPrice.label == "Netto-Betrag")
    }

    // MARK: - PDF Rendering with Languages

    @Test func pdfGermanContainsGermanLabels() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            debtor: debtor,
            language: .de,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("Empfangsschein"))
        #expect(pageText.contains("Zahlteil"))
    }

    @Test func pdfEnglishContainsEnglishLabels() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            debtor: debtor,
            language: .en,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("Receipt"))
        #expect(pageText.contains("Payment part"))
    }

    @Test func pdfFrenchContainsFrenchLabels() {
        let invoice = SwissInvoice(
            creditor: creditor,
            iban: "CH1230000000000012345",
            currency: .chf,
            debtor: debtor,
            language: .fr,
            lineItems: [InvoiceLineItem(description: "Service", amount: Money(amount: Decimal(string: "100.00")!, currency: .chf))]
        )
        let data = invoice.pdfData()
        let pdf = PDFDocument(data: data)
        let pageText = pdf?.page(at: 0)?.string ?? ""
        #expect(pageText.contains("Récépissé"))
        #expect(pageText.contains("Section paiement"))
    }
}
