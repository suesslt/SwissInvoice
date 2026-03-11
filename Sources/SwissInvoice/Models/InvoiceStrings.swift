import Foundation

/// Holds all localized strings for invoice PDF rendering.
/// Loaded from JSON resource files (de.json, en.json, fr.json).
public struct InvoiceStrings: Codable, Sendable {

    // MARK: - Leitwörter (info block)
    public let invoiceDateLabel: String
    public let referenceLabel: String
    public let additionalInfoLabel: String
    public let vatNumberLabel: String

    // MARK: - Line Items Table
    public let descriptionHeader: String
    public let qtyHeader: String
    public let unitHeader: String
    public let unitPriceHeader: String
    public let amountHeader: String

    // MARK: - Totals
    public let totalWithoutVat: String
    public let vatPrefix: String
    public let total: String

    // MARK: - Payment Part (Zahlteil)
    public let paymentPart: String
    public let accountPayableTo: String
    public let paymentReference: String
    public let additionalInformation: String
    public let payableBy: String
    public let currency: String
    public let amountLabel: String

    // MARK: - Receipt (Empfangsschein)
    public let receipt: String
    public let acceptancePoint: String

    // MARK: - LineItemType Labels
    public let fixedPriceLabel: String
    public let unitPriceLabel: String
    public let vatLabel: String

    // MARK: - Loading

    /// Cache of loaded strings per language.
    private static let cache: [InvoiceLanguage: InvoiceStrings] = {
        var dict: [InvoiceLanguage: InvoiceStrings] = [:]
        for lang in [InvoiceLanguage.de, .en, .fr] {
            if let strings = loadFromBundle(lang) {
                dict[lang] = strings
            }
        }
        return dict
    }()

    /// Returns the localized strings for the given language.
    /// Falls back to German if loading fails.
    public static func forLanguage(_ language: InvoiceLanguage) -> InvoiceStrings {
        cache[language] ?? cache[.de] ?? fallbackGerman
    }

    private static func loadFromBundle(_ language: InvoiceLanguage) -> InvoiceStrings? {
        guard let url = Bundle.module.url(forResource: language.rawValue, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(InvoiceStrings.self, from: data)
    }

    /// Hardcoded German fallback in case JSON loading fails.
    private static let fallbackGerman = InvoiceStrings(
        invoiceDateLabel: "Rechnungsdatum:",
        referenceLabel: "Referenz:",
        additionalInfoLabel: "Zusatzinformation:",
        vatNumberLabel: "UID (MWST):",
        descriptionHeader: "Beschreibung",
        qtyHeader: "Menge",
        unitHeader: "Einheit",
        unitPriceHeader: "Stückpreis",
        amountHeader: "Betrag",
        totalWithoutVat: "Total ohne MWST",
        vatPrefix: "MWST",
        total: "Total",
        paymentPart: "Zahlteil",
        accountPayableTo: "Konto / Zahlbar an",
        paymentReference: "Referenz",
        additionalInformation: "Zusätzliche Informationen",
        payableBy: "Zahlbar durch",
        currency: "Währung",
        amountLabel: "Betrag",
        receipt: "Empfangsschein",
        acceptancePoint: "Annahmestelle",
        fixedPriceLabel: "Netto-Betrag",
        unitPriceLabel: "Stückpreis",
        vatLabel: "Mehrwertsteuer"
    )
}
