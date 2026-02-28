import Testing
import Foundation
@testable import SwissInvoice

@Suite("Address Tests")
struct AddressTests {

    @Test func creation() {
        let address = Address(
            name: "Muster AG",
            street: "Bahnhofstrasse",
            houseNumber: "1",
            postalCode: "8001",
            city: "Zürich",
            countryCode: "CH"
        )
        #expect(address.name == "Muster AG")
        #expect(address.street == "Bahnhofstrasse")
        #expect(address.houseNumber == "1")
        #expect(address.postalCode == "8001")
        #expect(address.city == "Zürich")
        #expect(address.countryCode == "CH")
    }

    @Test func emptyAddress() {
        let address = Address.empty
        #expect(address.name == "")
        #expect(address.countryCode == "CH")
    }

    @Test func codableRoundTrip() throws {
        let original = Address(
            name: "Test GmbH",
            street: "Hauptstrasse",
            houseNumber: "42",
            postalCode: "3000",
            city: "Bern",
            countryCode: "CH"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Address.self, from: data)
        #expect(original == decoded)
    }

    @Test func hashable() {
        let a = Address(
            name: "Test",
            street: "Strasse",
            houseNumber: "1",
            postalCode: "1234",
            city: "Stadt",
            countryCode: "CH"
        )
        let b = Address(
            name: "Test",
            street: "Strasse",
            houseNumber: "1",
            postalCode: "1234",
            city: "Stadt",
            countryCode: "CH"
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        let set: Set<Address> = [a, b]
        #expect(set.count == 1)
    }
}
