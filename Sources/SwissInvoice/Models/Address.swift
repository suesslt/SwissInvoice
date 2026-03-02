import Foundation

/// Structured address for creditor or debtor on a Swiss QR Bill.
/// Uses the "S" (structured) address type per SIX specification.
public struct Address: Codable, Hashable, Sendable {
    public let name: String
    public let addressAddition: String
    public let street: String
    public let houseNumber: String
    public let postalCode: String
    public let city: String
    public let countryCode: String /// ISO 3166-1 alpha-2 country code (e.g. "CH").

    public init(
        name: String,
        addressAddition: String,
        street: String,
        houseNumber: String,
        postalCode: String,
        city: String,
        countryCode: String
    ) {
        self.name = name
        self.addressAddition = addressAddition
        self.street = street
        self.houseNumber = houseNumber
        self.postalCode = postalCode
        self.city = city
        self.countryCode = countryCode
    }

    public static let empty = Address(
        name: "",
        addressAddition: "",
        street: "",
        houseNumber: "",
        postalCode: "",
        city: "",
        countryCode: "CH"
    )
}
