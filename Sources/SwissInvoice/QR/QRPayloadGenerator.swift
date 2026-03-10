import Foundation
import Score

/// Generates the SPC/0200/1 payload string for Swiss QR Bills
/// per SIX specification v2.x. The payload consists of exactly 33 lines.
public enum QRPayloadGenerator {

    /// Generates the QR payload string for the given invoice.
    /// - Parameter invoice: A `SwissInvoice` with all required fields.
    /// - Returns: The payload string with 33 newline-separated fields.
    public static func generatePayload(for invoice: SwissInvoice) -> String {
        var lines: [String] = []

        // 1. Header (lines 1-3)
        lines.append("SPC")      // QR Type
        lines.append("0200")     // Version 2.x
        lines.append("1")        // Coding: UTF-8

        // 2. Creditor Info: IBAN + Address Type S (lines 4-10)
        lines.append(invoice.iban.replacingOccurrences(of: " ", with: ""))
        lines.append(contentsOf: formatAddress(invoice.creditor))

        // 3. Ultimate Creditor (lines 11-17) — reserved per standard, always empty
        lines.append(contentsOf: Array(repeating: "", count: 7))

        // 4. Amount & Currency (lines 18-19)
        if !invoice.amount.isZero {
            let nsAmount = invoice.amount.amount as NSDecimalNumber
            lines.append(String(format: "%.2f", nsAmount.doubleValue))
        } else {
            lines.append("") // Optional amount
        }
        lines.append(invoice.amount.currency.rawValue)
        
        // 5. Debtor Info (lines 20-26)
        if let debtor = invoice.debtor {
            lines.append(contentsOf: formatAddress(debtor))
        } else {
            lines.append(contentsOf: Array(repeating: "", count: 7))
        }

        // 6. Payment Reference (lines 27-28)
        lines.append(invoice.referenceType.rawValue)
        lines.append(invoice.reference?.replacingOccurrences(of: " ", with: "") ?? "")

        // 7. Additional Info + Trailer (lines 29-30)
        lines.append(invoice.additionalInfo ?? "")
        lines.append("EPD")

        // 8. Alternative Procedures (lines 31-32) — empty
        lines.append("")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Formats an address into 7 fields per SIX structured address type "S".
    private static func formatAddress(_ addr: Address) -> [String] {
        [
            "S",                // Address type: Structured
            addr.name,
            addr.street,
            addr.houseNumber,
            addr.postalCode,
            addr.city,
            addr.countryCode
        ]
    }
}
