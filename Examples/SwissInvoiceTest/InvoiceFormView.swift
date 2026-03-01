import SwiftUI
import QuickLook
import SwissInvoice

struct InvoiceFormView: View {
    // Creditor
    @State private var creditorName = "Max Muster & Söhne"
    @State private var creditorStreet = "Musterstrasse"
    @State private var creditorHouseNumber = "123"
    @State private var creditorPostalCode = "8000"
    @State private var creditorCity = "Seldwyla"
    @State private var creditorCountryCode = "CH"

    // Debtor
    @State private var showDebtor = true
    @State private var debtorName = "Simon Muster"
    @State private var debtorStreet = "Musterstrasse"
    @State private var debtorHouseNumber = "1a"
    @State private var debtorPostalCode = "8000"
    @State private var debtorCity = "Seldwyla"
    @State private var debtorCountryCode = "CH"

    // Payment
    @State private var iban = "CH64 3196 1000 0044 2155 7"
    @State private var selectedCurrency: Currency = .chf
    @State private var amountText = "50.00"

    // Reference
    @State private var referenceType: ReferenceType = .qrReference
    @State private var referenceNumber = "00 00082 07791 22585 74212 86694"

    // Invoice
    @State private var invoiceTitle = "Rechnung"
    @State private var subject = "Rechnung für Auftritt am xxx"
    @State private var invoiceDate = Date()
    @State private var additionalInfo = "Payment of Travel"
    @State private var fontName = ""
    @State private var fontSizeText = ""

    // Line Items
    @State private var lineItems: [LineItemEntry] = [
        LineItemEntry(description: "Consulting", quantity: "10", unit: "h", unitPrice: "150.00"),
        LineItemEntry(description: "Travel expenses", quantity: "", unit: "", unitPrice: ""),
    ]

    // PDF preview
    @State private var pdfURL: URL?

    // Font loading
    @State private var isLoadingFont = false
    @State private var fontError: String?
    @State private var resolvedFontName: String?

    var body: some View {
        Form {
            Section("Creditor") {
                TextField("Name", text: $creditorName)
                TextField("Street", text: $creditorStreet)
                TextField("House Number", text: $creditorHouseNumber)
                TextField("Postal Code", text: $creditorPostalCode)
                TextField("City", text: $creditorCity)
                TextField("Country Code", text: $creditorCountryCode)
            }

            Section("Debtor") {
                Toggle("Include Debtor", isOn: $showDebtor)
                if showDebtor {
                    TextField("Name", text: $debtorName)
                    TextField("Street", text: $debtorStreet)
                    TextField("House Number", text: $debtorHouseNumber)
                    TextField("Postal Code", text: $debtorPostalCode)
                    TextField("City", text: $debtorCity)
                    TextField("Country Code", text: $debtorCountryCode)
                }
            }

            Section("Payment") {
                TextField("IBAN", text: $iban)
                Picker("Currency", selection: $selectedCurrency) {
                    Text("CHF").tag(Currency.chf)
                    Text("EUR").tag(Currency.eur)
                }
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
            }

            Section("Reference") {
                Picker("Reference Type", selection: $referenceType) {
                    Text("None (NON)").tag(ReferenceType.none)
                    Text("QR Reference (QRR)").tag(ReferenceType.qrReference)
                    Text("Creditor Reference (SCOR)").tag(ReferenceType.creditorReference)
                }
                if referenceType != .none {
                    TextField("Reference Number", text: $referenceNumber)
                }
            }

            Section("Invoice Details") {
                TextField("Title", text: $invoiceTitle)
                TextField("Subject (Betreff)", text: $subject)
                DatePicker("Date", selection: $invoiceDate, displayedComponents: .date)
                TextField("Additional Info", text: $additionalInfo)
                TextField("Font Name (e.g. Roboto, Open Sans)", text: $fontName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Font Size (default 10 pt)", text: $fontSizeText)
                    .keyboardType(.decimalPad)
            }

            Section("Line Items") {
                ForEach($lineItems) { $item in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Description", text: $item.description)
                        HStack {
                            TextField("Qty", text: $item.quantity)
                                .frame(width: 60)
                                .keyboardType(.decimalPad)
                            TextField("Unit", text: $item.unit)
                                .frame(width: 60)
                            TextField("Unit Price", text: $item.unitPrice)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                .onDelete { lineItems.remove(atOffsets: $0) }

                Button("Add Line Item") {
                    lineItems.append(LineItemEntry())
                }
            }

            Section {
                Button("Generate Invoice") {
                    generateInvoice()
                }
                .font(.headline)
                .disabled(isLoadingFont)

                if isLoadingFont {
                    HStack {
                        ProgressView()
                        Text("Loading font…")
                            .foregroundStyle(.secondary)
                    }
                }

                if let fontError {
                    Text(fontError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Swiss Invoice Demo")
        .quickLookPreview($pdfURL)
    }

    private func generateInvoice() {
        fontError = nil

        let name = fontName.trimmingCharacters(in: .whitespaces)

        // Empty font name — use default (Helvetica).
        guard !name.isEmpty else {
            resolvedFontName = nil
            showPDF()
            return
        }

        // System font already available — use it directly.
        if UIFont(name: name, size: 12) != nil {
            resolvedFontName = name
            showPDF()
            return
        }

        // Try loading as a Google Font.
        isLoadingFont = true
        Task {
            do {
                let psName = try await GoogleFontLoader.load(name)
                resolvedFontName = psName
            } catch {
                fontError = "Font '\(name)': \(error.localizedDescription) — using Helvetica."
                resolvedFontName = nil
            }
            isLoadingFont = false
            showPDF()
        }
    }

    private func showPDF() {
        let data = buildInvoice().pdfData()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwissInvoice.pdf")
        try? data.write(to: url)
        pdfURL = url
    }

    private func buildInvoice() -> SwissInvoice {
        let creditor = Address(
            name: creditorName,
            street: creditorStreet,
            houseNumber: creditorHouseNumber,
            postalCode: creditorPostalCode,
            city: creditorCity,
            countryCode: creditorCountryCode
        )

        let debtor: Address? = showDebtor ? Address(
            name: debtorName,
            street: debtorStreet,
            houseNumber: debtorHouseNumber,
            postalCode: debtorPostalCode,
            city: debtorCity,
            countryCode: debtorCountryCode
        ) : nil

        let amount = Money(
            amount: Decimal(string: amountText) ?? 0,
            currency: selectedCurrency
        )

        let items: [InvoiceLineItem] = lineItems.compactMap { entry in
            guard !entry.description.isEmpty else { return nil }
            let qty = Decimal(string: entry.quantity)
            let up = entry.unitPrice.isEmpty ? nil : Money(
                amount: Decimal(string: entry.unitPrice) ?? 0,
                currency: selectedCurrency
            )
            let itemAmount: Money
            if let q = qty, let u = up {
                itemAmount = u * q
            } else if let u = up {
                itemAmount = u
            } else {
                itemAmount = Money.zero(selectedCurrency)
            }
            return InvoiceLineItem(
                description: entry.description,
                quantity: qty,
                unit: entry.unit.isEmpty ? nil : entry.unit,
                unitPrice: up,
                amount: itemAmount
            )
        }

        return SwissInvoice(
            creditor: creditor,
            iban: iban,
            amount: amount,
            debtor: debtor,
            referenceType: referenceType,
            reference: referenceNumber.isEmpty ? nil : referenceNumber,
            additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo,
            title: invoiceTitle.isEmpty ? nil : invoiceTitle,
            subject: subject.isEmpty ? nil : subject,
            invoiceDate: invoiceDate,
            lineItems: items,
            fontName: resolvedFontName,
            fontSize: CGFloat(Double(fontSizeText) ?? 10)
        )
    }
}

// MARK: - Line Item Entry (form state)

struct LineItemEntry: Identifiable {
    let id = UUID()
    var description: String = ""
    var quantity: String = ""
    var unit: String = ""
    var unitPrice: String = ""
}
