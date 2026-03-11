import Foundation

/// Supported languages for Swiss QR Bill invoice rendering.
public enum InvoiceLanguage: String, Codable, Sendable {
    case de
    case en
    case fr

    /// The locale identifier used for date formatting.
    var localeIdentifier: String {
        switch self {
        case .de: return "de_CH"
        case .en: return "en_CH"
        case .fr: return "fr_CH"
        }
    }
}
