import SwiftUI
import SwissInvoice

@main
struct SwissInvoiceDemoApp: App {

    init() {
        GoogleFontLoader.registerCachedFonts()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                InvoiceFormView()
            }
        }
    }
}
