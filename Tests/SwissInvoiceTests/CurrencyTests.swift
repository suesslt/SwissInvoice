import Testing
import Foundation
@testable import SwissInvoice

@Suite("Currency Tests")
struct CurrencyTests {

    // MARK: - Decimal Places

    @Test func standardDecimalPlaces() {
        #expect(Currency.chf.decimalPlaces == 2)
        #expect(Currency.eur.decimalPlaces == 2)
        #expect(Currency.usd.decimalPlaces == 2)
        #expect(Currency.gbp.decimalPlaces == 2)
    }

    @Test func zeroDecimalPlaces() {
        #expect(Currency.jpy.decimalPlaces == 0)
        #expect(Currency.krw.decimalPlaces == 0)
        #expect(Currency.vuv.decimalPlaces == 0)
        #expect(Currency.clp.decimalPlaces == 0)
        #expect(Currency.bif.decimalPlaces == 0)
        #expect(Currency.xof.decimalPlaces == 0)
        #expect(Currency.xaf.decimalPlaces == 0)
        #expect(Currency.xpf.decimalPlaces == 0)
    }

    @Test func threeDecimalPlaces() {
        #expect(Currency.bhd.decimalPlaces == 3)
        #expect(Currency.jod.decimalPlaces == 3)
        #expect(Currency.kwd.decimalPlaces == 3)
        #expect(Currency.omr.decimalPlaces == 3)
        #expect(Currency.tnd.decimalPlaces == 3)
        #expect(Currency.lyd.decimalPlaces == 3)
        #expect(Currency.iqd.decimalPlaces == 3)
    }

    @Test func oneDecimalPlace() {
        #expect(Currency.mru.decimalPlaces == 1)
        #expect(Currency.mga.decimalPlaces == 1)
    }

    // MARK: - Symbol

    @Test func commonSymbols() {
        #expect(Currency.chf.symbol == "Fr.")
        #expect(Currency.eur.symbol == "€")
        #expect(Currency.usd.symbol == "$")
        #expect(Currency.gbp.symbol == "£")
        #expect(Currency.jpy.symbol == "¥")
    }

    @Test func sharedDollarSymbol() {
        #expect(Currency.cad.symbol == "$")
        #expect(Currency.aud.symbol == "$")
        #expect(Currency.nzd.symbol == "$")
        #expect(Currency.hkd.symbol == "$")
        #expect(Currency.sgd.symbol == "$")
    }

    @Test func specialSymbols() {
        #expect(Currency.krw.symbol == "₩")
        #expect(Currency.inr.symbol == "₹")
        #expect(Currency.thb.symbol == "฿")
        #expect(Currency.ils.symbol == "₪")
        #expect(Currency.try.symbol == "₺")
        #expect(Currency.pln.symbol == "zł")
        #expect(Currency.rub.symbol == "₽")
    }

    @Test func fallbackSymbol() {
        // Currencies without explicit symbol use rawValue
        #expect(Currency.bob.symbol == "BOB")
        #expect(Currency.pen.symbol == "PEN")
    }

    // MARK: - Name

    @Test func commonNames() {
        #expect(Currency.chf.name == "Swiss Franc")
        #expect(Currency.eur.name == "Euro")
        #expect(Currency.usd.name == "US Dollar")
        #expect(Currency.gbp.name == "British Pound")
        #expect(Currency.jpy.name == "Japanese Yen")
    }

    @Test func otherNames() {
        #expect(Currency.cad.name == "Canadian Dollar")
        #expect(Currency.brl.name == "Brazilian Real")
        #expect(Currency.cny.name == "Chinese Yuan")
        #expect(Currency.inr.name == "Indian Rupee")
        #expect(Currency.zar.name == "South African Rand")
    }

    // MARK: - Common Array

    @Test func commonArrayContents() {
        let common = Currency.common
        #expect(common.contains(.chf))
        #expect(common.contains(.eur))
        #expect(common.contains(.usd))
        #expect(common.contains(.gbp))
        #expect(common.contains(.jpy))
        #expect(common.count == 14)
    }

    // MARK: - Identifiable & CaseIterable

    @Test func identifiable() {
        #expect(Currency.chf.id == "CHF")
        #expect(Currency.eur.id == "EUR")
    }

    @Test func caseIterable() {
        let all = Currency.allCases
        #expect(all.count > 100)
        #expect(all.contains(.chf))
        #expect(all.contains(.eur))
    }

    @Test func codable() throws {
        let original = Currency.chf
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Currency.self, from: data)
        #expect(original == decoded)
    }
}
