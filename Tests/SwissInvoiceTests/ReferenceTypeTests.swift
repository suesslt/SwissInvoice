import Testing
import Foundation
@testable import SwissInvoice

@Suite("ReferenceType Tests")
struct ReferenceTypeTests {

    @Test func rawValues() {
        #expect(ReferenceType.qrReference.rawValue == "QRR")
        #expect(ReferenceType.creditorReference.rawValue == "SCOR")
        #expect(ReferenceType.none.rawValue == "NON")
    }

    @Test func codableRoundTrip() throws {
        for ref in [ReferenceType.qrReference, .creditorReference, .none] {
            let data = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(ReferenceType.self, from: data)
            #expect(ref == decoded)
        }
    }
}
