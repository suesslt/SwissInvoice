import Testing
import Foundation
@testable import SwissInvoice

@Suite("Address Tests")
struct AddressTests {

    @Test func creation() {
        let address = Address(
            companyName: "Muster AG",
            attentionTo: "Abteilung Finanzen",
            street: "Bahnhofstrasse",
            houseNumber: "1",
            postalCode: "8001",
            city: "Zürich",
            countryCode: "CH"
        )
        #expect(address.companyName == "Muster AG")
        #expect(address.attentionTo == "Abteilung Finanzen")
        #expect(address.street == "Bahnhofstrasse")
        #expect(address.houseNumber == "1")
        #expect(address.postalCode == "8001")
        #expect(address.city == "Zürich")
        #expect(address.countryCode == "CH")
    }

    @Test func creationWithPerson() {
        let address = Address(
            firstName: "Thomas",
            lastName: "Suessli",
            street: "Bahnhofstrasse",
            houseNumber: "43",
            postalCode: "8143",
            city: "Zürich"
        )
        #expect(address.firstName == "Thomas")
        #expect(address.lastName == "Suessli")
        #expect(address.companyName == "")
        #expect(address.displayName == "Thomas Suessli")
    }

    @Test func emptyAddress() {
        let address = Address.empty
        #expect(address.companyName == "")
        #expect(address.firstName == "")
        #expect(address.lastName == "")
        #expect(address.countryCode == "CH")
    }

    @Test func displayNameCompany() {
        let address = Address(companyName: "UBS Switzerland AG", firstName: "Thomas", lastName: "Suessli")
        #expect(address.displayName == "UBS Switzerland AG")
    }

    @Test func displayNamePerson() {
        let address = Address(firstName: "Thomas", lastName: "Suessli")
        #expect(address.displayName == "Thomas Suessli")
    }

    @Test func displayNameFirstNameOnly() {
        let address = Address(firstName: "Thomas")
        #expect(address.displayName == "Thomas")
    }

    @Test func fullAddressAllFields() {
        let address = Address(
            companyName: "UBS Switzerland AG",
            attentionTo: "Accounts Payable CH",
            firstName: "Thomas",
            lastName: "Suessli",
            addressAddition1: "GPN 34234",
            addressAddition2: "c/o scolar AG",
            street: "Bahnhofstrasse",
            houseNumber: "43",
            mailbox: "Postfach",
            postalCode: "8143",
            city: "Zürich",
            countryCode: "CH"
        )
        let lines = address.fullAddress()
        #expect(lines == [
            "UBS Switzerland AG",
            "Accounts Payable CH",
            "Thomas Suessli",
            "GPN 34234",
            "c/o scolar AG",
            "Bahnhofstrasse 43",
            "Postfach",
            "8143 Zürich",
            "CH"
        ])
    }

    @Test func fullAddressMinimal() {
        let address = Address(firstName: "Hans", lastName: "Muster", postalCode: "3000", city: "Bern")
        let lines = address.fullAddress()
        #expect(lines == ["Hans Muster", "3000 Bern", "CH"])
    }

    @Test func paymentAddressCompany() {
        let address = Address(
            companyName: "Muster AG",
            firstName: "Hans",
            lastName: "Muster",
            street: "Bahnhofstrasse",
            houseNumber: "1",
            postalCode: "8001",
            city: "Zürich"
        )
        let lines = address.paymentAddress()
        #expect(lines == ["Muster AG", "Bahnhofstrasse 1", "8001 Zürich"])
    }

    @Test func paymentAddressPerson() {
        let address = Address(
            firstName: "Hans",
            lastName: "Muster",
            street: "Rebenweg",
            houseNumber: "12",
            postalCode: "3000",
            city: "Bern"
        )
        let lines = address.paymentAddress()
        #expect(lines == ["Hans Muster", "Rebenweg 12", "3000 Bern"])
    }

    @Test func paymentAddressWithMailbox() {
        let address = Address(
            companyName: "Muster AG",
            mailbox: "Postfach 2663",
            postalCode: "8001",
            city: "Zürich"
        )
        let lines = address.paymentAddress()
        #expect(lines == ["Muster AG", "Postfach 2663", "8001 Zürich"])
    }

    @Test func codableRoundTrip() throws {
        let original = Address(
            companyName: "Test GmbH",
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
            companyName: "Test",
            street: "Strasse",
            houseNumber: "1",
            postalCode: "1234",
            city: "Stadt",
            countryCode: "CH"
        )
        let b = Address(
            companyName: "Test",
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
