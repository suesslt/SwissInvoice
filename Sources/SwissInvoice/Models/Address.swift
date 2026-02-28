import Foundation

/// Structured address for creditor or debtor on a Swiss QR Bill.
/// Uses the "S" (structured) address type per SIX specification.
public struct Address: Codable, Hashable, Sendable {
    public let name: String
    public let street: String
    public let houseNumber: String
    public let postalCode: String
    public let city: String
    /// ISO 3166-1 alpha-2 country code (e.g. "CH").
    public let countryCode: String

    public init(
        name: String,
        street: String,
        houseNumber: String,
        postalCode: String,
        city: String,
        countryCode: String
    ) {
        self.name = name
        self.street = street
        self.houseNumber = houseNumber
        self.postalCode = postalCode
        self.city = city
        self.countryCode = countryCode
    }

    /// Empty address as a safe default.
    public static let empty = Address(
        name: "",
        street: "",
        houseNumber: "",
        postalCode: "",
        city: "",
        countryCode: "CH"
    )
}
