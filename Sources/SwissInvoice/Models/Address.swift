import Foundation

/// Structured address for creditor or debtor on a Swiss QR Bill.
/// Uses the "S" (structured) address type per SIX specification.
public struct Address: Codable, Hashable, Sendable {
    public let companyName: String
    public let attentionTo: String
    public let title: String
    public let firstName: String
    public let lastName: String
    public let addressAddition1: String
    public let addressAddition2: String
    public let street: String
    public let houseNumber: String
    public let mailbox: String
    public let postalCode: String
    public let city: String
    public let countryCode: String /// ISO 3166-1 alpha-2 country code (e.g. "CH").

    public init(
        companyName: String = "",
        attentionTo: String = "",
        title: String = "",
        firstName: String = "",
        lastName: String = "",
        addressAddition1: String = "",
        addressAddition2: String = "",
        street: String = "",
        houseNumber: String = "",
        mailbox: String = "",
        postalCode: String = "",
        city: String = "",
        countryCode: String = "CH"
    ) {
        self.companyName = companyName
        self.attentionTo = attentionTo
        self.title = title
        self.firstName = firstName
        self.lastName = lastName
        self.addressAddition1 = addressAddition1
        self.addressAddition2 = addressAddition2
        self.street = street
        self.houseNumber = houseNumber
        self.mailbox = mailbox
        self.postalCode = postalCode
        self.city = city
        self.countryCode = countryCode
    }

    /// The display name: companyName if non-empty, otherwise firstName + lastName.
    public var displayName: String {
        if !companyName.isEmpty { return companyName }
        return [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Full address as lines, in field order. Empty fields are skipped.
    /// firstName and lastName are joined on one line, as are street + houseNumber
    /// and postalCode + city.
    public func fullAddress() -> [String] {
        var lines: [String] = []
        if !companyName.isEmpty { lines.append(companyName) }
        if !attentionTo.isEmpty { lines.append(attentionTo) }
        if !title.isEmpty { lines.append(title) }
        let nameLine = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        if !nameLine.isEmpty { lines.append(nameLine) }
        if !addressAddition1.isEmpty { lines.append(addressAddition1) }
        if !addressAddition2.isEmpty { lines.append(addressAddition2) }
        let streetLine = [street, houseNumber].filter { !$0.isEmpty }.joined(separator: " ")
        if !streetLine.isEmpty { lines.append(streetLine) }
        if !mailbox.isEmpty { lines.append(mailbox) }
        let cityLine = [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
        if !cityLine.isEmpty { lines.append(cityLine) }
        if !countryCode.isEmpty { lines.append(countryCode) }
        return lines
    }

    /// Payment address as 3 lines for QR bill payment part and receipt:
    /// 1. companyName (if non-empty) or firstName + lastName
    /// 2. street + houseNumber (if non-empty) or mailbox
    /// 3. postalCode + city
    public func paymentAddress() -> [String] {
        var lines: [String] = []
        if !companyName.isEmpty {
            lines.append(companyName)
        } else {
            let nameLine = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
            if !nameLine.isEmpty { lines.append(nameLine) }
        }
        let streetLine = [street, houseNumber].filter { !$0.isEmpty }.joined(separator: " ")
        if !streetLine.isEmpty {
            lines.append(streetLine)
        } else if !mailbox.isEmpty {
            lines.append(mailbox)
        }
        let cityLine = [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
        if !cityLine.isEmpty { lines.append(cityLine) }
        return lines
    }

    public static let empty = Address()
}
