import Foundation

/// Payment reference type for Swiss QR Bills per SIX specification.
public enum ReferenceType: String, Codable, Sendable {
    /// QR Reference (for QR-IBAN).
    case qrReference = "QRR"
    /// Creditor Reference (ISO 11649).
    case creditorReference = "SCOR"
    /// No reference.
    case none = "NON"
}
