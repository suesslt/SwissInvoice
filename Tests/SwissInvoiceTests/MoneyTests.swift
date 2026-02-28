import Testing
import Foundation
@testable import SwissInvoice

@Suite("Money Tests")
struct MoneyTests {

    // MARK: - Creation

    @Test func creation() {
        let money = Money(amount: 100, currency: .chf)
        #expect(money.amount == 100)
        #expect(money.currency == .chf)
    }

    @Test func zero() {
        let money = Money.zero(.eur)
        #expect(money.amount == .zero)
        #expect(money.currency == .eur)
    }

    // MARK: - Arithmetic

    @Test func addition() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 50, currency: .chf)
        let result = a + b
        #expect(result.amount == 150)
        #expect(result.currency == .chf)
    }

    @Test func subtraction() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 30, currency: .chf)
        let result = a - b
        #expect(result.amount == 70)
        #expect(result.currency == .chf)
    }

    @Test func addAssign() {
        var a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 25, currency: .chf)
        a += b
        #expect(a.amount == 125)
    }

    @Test func subtractAssign() {
        var a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 25, currency: .chf)
        a -= b
        #expect(a.amount == 75)
    }

    @Test func multiplyByDecimal() {
        let money = Money(amount: 200, currency: .chf)
        let result = money * Decimal(string: "0.5")!
        #expect(result.amount == 100)
        #expect(result.currency == .chf)
    }

    @Test func decimalTimessMoney() {
        let money = Money(amount: 200, currency: .chf)
        let result = Decimal(3) * money
        #expect(result.amount == 600)
        #expect(result.currency == .chf)
    }

    @Test func division() {
        let money = Money(amount: 300, currency: .chf)
        let result = money / Decimal(4)
        #expect(result.amount == 75)
        #expect(result.currency == .chf)
    }

    @Test func negation() {
        let money = Money(amount: 100, currency: .chf)
        let result = -money
        #expect(result.amount == -100)
        #expect(result.currency == .chf)
    }

    @Test func negationOfNegative() {
        let money = Money(amount: -50, currency: .eur)
        let result = -money
        #expect(result.amount == 50)
    }

    // MARK: - Throwing Variants

    @Test func addingSameCurrency() throws {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 50, currency: .chf)
        let result = try a.adding(b)
        #expect(result.amount == 150)
    }

    @Test func addingDifferentCurrencies() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 50, currency: .eur)
        #expect(throws: Money.MoneyError.self) {
            try a.adding(b)
        }
    }

    @Test func subtractingSameCurrency() throws {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 30, currency: .chf)
        let result = try a.subtracting(b)
        #expect(result.amount == 70)
    }

    @Test func subtractingDifferentCurrencies() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 30, currency: .usd)
        #expect(throws: Money.MoneyError.self) {
            try a.subtracting(b)
        }
    }

    // MARK: - MoneyError

    @Test func errorDescription() {
        let error = Money.MoneyError.currencyMismatch(.chf, .eur)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("CHF"))
        #expect(error.errorDescription!.contains("EUR"))
    }

    // MARK: - Formatting

    @Test func formatted() {
        let money = Money(amount: Decimal(string: "1234.56")!, currency: .chf)
        #expect(money.formatted.contains("CHF"))
        #expect(money.formatted.contains("1"))
        #expect(money.formatted.contains("234"))
    }

    @Test func formattedShort() {
        let money = Money(amount: Decimal(string: "1234.56")!, currency: .chf)
        let short = money.formattedShort
        #expect(!short.contains("CHF"))
        #expect(short.contains("234"))
    }

    @Test func formattedZeroDecimalPlaces() {
        let money = Money(amount: Decimal(500), currency: .jpy)
        #expect(money.currency.decimalPlaces == 0)
        let short = money.formattedShort
        #expect(!short.contains("."))
    }

    @Test func formattedThreeDecimalPlaces() {
        let money = Money(amount: Decimal(string: "123.456")!, currency: .bhd)
        #expect(money.currency.decimalPlaces == 3)
        #expect(money.formatted.contains("BHD"))
    }

    // MARK: - 5-Rappen Rounding

    @Test func roundedUp5Rappen() {
        // 10.03 -> 10.05
        let money = Money(amount: Decimal(string: "10.03")!, currency: .chf)
        let rounded = money.gerundet5Rappen()
        #expect(rounded.amount == Decimal(string: "10.05")!)
    }

    @Test func roundedDown5Rappen() {
        // 10.02 -> 10.00
        let money = Money(amount: Decimal(string: "10.02")!, currency: .chf)
        let rounded = money.gerundet5Rappen()
        #expect(rounded.amount == Decimal(string: "10.00")!)
    }

    @Test func rounded5RappenZero() {
        let money = Money.zero(.chf)
        let rounded = money.gerundet5Rappen()
        #expect(rounded.amount == .zero)
    }

    @Test func rounded5RappenExact() {
        let money = Money(amount: Decimal(string: "10.15")!, currency: .chf)
        let rounded = money.gerundet5Rappen()
        #expect(rounded.amount == Decimal(string: "10.15")!)
    }

    @Test func rounded5RappenMiddle() {
        // 10.08 -> 10.10
        let money = Money(amount: Decimal(string: "10.08")!, currency: .chf)
        let rounded = money.gerundet5Rappen()
        #expect(rounded.amount == Decimal(string: "10.10")!)
    }

    // MARK: - Comparison

    @Test func lessThan() {
        let a = Money(amount: 50, currency: .chf)
        let b = Money(amount: 100, currency: .chf)
        #expect(a < b)
        #expect(!(b < a))
    }

    @Test func greaterThan() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 50, currency: .chf)
        #expect(a > b)
        #expect(!(b > a))
    }

    @Test func lessOrEqual() {
        let a = Money(amount: 50, currency: .chf)
        let b = Money(amount: 50, currency: .chf)
        let c = Money(amount: 100, currency: .chf)
        #expect(a <= b)
        #expect(a <= c)
        #expect(!(c <= a))
    }

    @Test func greaterOrEqual() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 100, currency: .chf)
        let c = Money(amount: 50, currency: .chf)
        #expect(a >= b)
        #expect(a >= c)
        #expect(!(c >= a))
    }

    // MARK: - Properties

    @Test func isZero() {
        #expect(Money.zero(.chf).isZero)
        #expect(!Money(amount: 1, currency: .chf).isZero)
        #expect(!Money(amount: -1, currency: .chf).isZero)
    }

    @Test func isPositive() {
        #expect(Money(amount: 1, currency: .chf).isPositive)
        #expect(!Money.zero(.chf).isPositive)
        #expect(!Money(amount: -1, currency: .chf).isPositive)
    }

    @Test func isNegative() {
        #expect(Money(amount: -1, currency: .chf).isNegative)
        #expect(!Money.zero(.chf).isNegative)
        #expect(!Money(amount: 1, currency: .chf).isNegative)
    }

    // MARK: - Equatable / Hashable

    @Test func equatable() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 100, currency: .chf)
        let c = Money(amount: 200, currency: .chf)
        let d = Money(amount: 100, currency: .eur)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test func hashable() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 100, currency: .chf)
        #expect(a.hashValue == b.hashValue)

        let set: Set<Money> = [a, b]
        #expect(set.count == 1)
    }
}
