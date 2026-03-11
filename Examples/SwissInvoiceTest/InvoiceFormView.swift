import QuickLook
import Score
import SwiftUI
import SwissInvoice

struct InvoiceFormView: View {
    // Creditor
    @State private var creditorCompanyName = "Thomas Suessli - Mandate und Beratung"
    @State private var creditorAttentionTo = ""
    @State private var creditorFirstName = ""
    @State private var creditorLastName = ""
    @State private var creditorAddressAddition1 = ""
    @State private var creditorAddressAddition2 = ""
    @State private var creditorStreet = "Haselwart"
    @State private var creditorHouseNumber = "29"
    @State private var creditorMailbox = "Postfach 2663"
    @State private var creditorPostalCode = "6210"
    @State private var creditorCity = "Sursee"
    @State private var creditorCountryCode = "CH"

    // Debtor
    @State private var showDebtor = true
    @State private var debtorCompanyName = ""
    @State private var debtorAttentionTo = ""
    @State private var debtorFirstName = "Simon"
    @State private var debtorLastName = "Muster"
    @State private var debtorAddressAddition1 = ""
    @State private var debtorAddressAddition2 = "c/o Firma Muster"
    @State private var debtorStreet = "Musterstrasse"
    @State private var debtorHouseNumber = "1a"
    @State private var debtorMailbox = ""
    @State private var debtorPostalCode = "8000"
    @State private var debtorCity = "Seldwyla"
    @State private var debtorCountryCode = "CH"

    // Payment
    @State private var iban = "CH64 3196 1000 0044 2155 7"
    @State private var selectedCurrency: Currency = .chf
    @State private var amountText = "50.00"
    @State private var vatNr = "CHE-123.456.789 MWST"

    // Reference
    @State private var referenceType: ReferenceType = .qrReference
    @State private var referenceNumber = "00 00082 07791 22585 74212 86694"

    // Invoice
    @State private var invoiceTitle = "Rechnung"
    @State private var subject = "Rechnung für Erbrachte Leistungen"
    @State private var invoiceDate = Date()
    @State private var additionalInfo = "Payment of Travel"
    @State private var fontName = ""
    @State private var fontSizeText = ""
    @State private var leadingText =
        "Sehr geehrter Herr Müller\n\nGemäss unserer Vereinbarung vom xxxx stelle ich Ihnen wie folgt Rechnung:"
    @State private var trailingText =
        "Besten Dank für Ihr Vertrauen und den Auftrag.\n\nMit freundlichen Grüssen,\nThomas Süssli"

    // Line Items
    @State private var lineItems: [LineItemViewRow] = [
        LineItemViewRow(type: .unitPrice , description: "Vorbereitungszeit", quantity: "10", unit: "h", unitPrice: "1000.00"),
        LineItemViewRow(type: .fixedPrice, description: "Cyber Awareness Training, 2 Sessions, am 2. März 2026", amount: "6000.00"),
        LineItemViewRow(type: .unitPrice , description: "Anwaltsstunden", quantity: "18.5", unit: "h", unitPrice: "2400.00"),
        LineItemViewRow(type: .fixedPrice, description: "Ärgerpauschale", amount: "999999999.00"),
        LineItemViewRow(type: .vat, description: "", quantity: "", unit: "", vatRate: "5.6", amount: "674.38"),
        LineItemViewRow(type: .vat, description: "", quantity: "", unit: "", vatRate: "8.1", amount: "74.87"),
    ]

    // PDF preview
    @State private var pdfURL: URL?

    // Font loading
    @State private var isLoadingFont = false
    @State private var fontError: String?
    @State private var resolvedFontName: String?

    var body: some View {
        Form {
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
            Section("Creditor") {
                TextField("Company Name", text: $creditorCompanyName)
                TextField("Attention To", text: $creditorAttentionTo)
                TextField("First Name", text: $creditorFirstName)
                TextField("Last Name", text: $creditorLastName)
                TextField("Address Addition 1", text: $creditorAddressAddition1)
                TextField("Address Addition 2", text: $creditorAddressAddition2)
                TextField("Street", text: $creditorStreet)
                TextField("House Number", text: $creditorHouseNumber)
                TextField("Mailbox", text: $creditorMailbox)
                TextField("Postal Code", text: $creditorPostalCode)
                TextField("City", text: $creditorCity)
                TextField("Country Code", text: $creditorCountryCode)
            }

            Section("Debtor") {
                Toggle("Include Debtor", isOn: $showDebtor)
                if showDebtor {
                    TextField("Company Name", text: $debtorCompanyName)
                    TextField("Attention To", text: $debtorAttentionTo)
                    TextField("First Name", text: $debtorFirstName)
                    TextField("Last Name", text: $debtorLastName)
                    TextField("Address Addition 1", text: $debtorAddressAddition1)
                    TextField("Address Addition 2", text: $debtorAddressAddition2)
                    TextField("Street", text: $debtorStreet)
                    TextField("House Number", text: $debtorHouseNumber)
                    TextField("Mailbox", text: $debtorMailbox)
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
                TextField("MWST", text: $vatNr)
                TextField("Font Name (e.g. Roboto, Open Sans)", text: $fontName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Font Size (default 10 pt)", text: $fontSizeText)
                    .keyboardType(.decimalPad)
            }

            Section("Brieftext") {
                TextField("Anrede und Brieftxt", text: $leadingText, axis: .vertical)
                    .lineLimit(3...10)  // Startet bei 3 Zeilen, wächst bis maximal 10
                    .textFieldStyle(.roundedBorder)
                    .padding()
                TextField("Grussformel", text: $trailingText, axis: .vertical)
                    .lineLimit(3...10)  // Startet bei 3 Zeilen, wächst bis maximal 10
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }

            Section("Line Items") {
                ForEach($lineItems) { $item in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Description", text: $item.description)
                        Picker("Line Item Type", selection: $item.type) {
                            ForEach(LineItemType.allCases) { type in
                                Text(type.label)
                                    .tag(type)
                            }
                        }
                        // Der .menu Style kommt einer ComboBox am nächsten
                        .pickerStyle(.menu)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 1)
                        HStack {
                            TextField("Qty", text: $item.quantity)
                                .frame(width: 60)
                                .keyboardType(.decimalPad)
                            TextField("Unit", text: $item.unit)
                                .frame(width: 60)
                            TextField("Unit Price", text: $item.unitPrice)
                                .keyboardType(.decimalPad)
                            TextField("VAT", text: $item.vatRate)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                .onDelete { lineItems.remove(atOffsets: $0) }

                Button("Add Line Item") {
                    lineItems.append(LineItemViewRow())
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
            companyName: creditorCompanyName,
            attentionTo: creditorAttentionTo,
            firstName: creditorFirstName,
            lastName: creditorLastName,
            addressAddition1: creditorAddressAddition1,
            addressAddition2: creditorAddressAddition2,
            street: creditorStreet,
            houseNumber: creditorHouseNumber,
            mailbox: creditorMailbox,
            postalCode: creditorPostalCode,
            city: creditorCity,
            countryCode: creditorCountryCode
        )

        let debtor = Address(
            companyName: debtorCompanyName,
            attentionTo: debtorAttentionTo,
            firstName: debtorFirstName,
            lastName: debtorLastName,
            addressAddition1: debtorAddressAddition1,
            addressAddition2: debtorAddressAddition2,
            street: debtorStreet,
            houseNumber: debtorHouseNumber,
            mailbox: debtorMailbox,
            postalCode: debtorPostalCode,
            city: debtorCity,
            countryCode: debtorCountryCode
        )

        let items: [InvoiceLineItem] = lineItems.compactMap { entry in
            let qty = Decimal(string: entry.quantity)
            let unitPrice =
                entry.unitPrice.isEmpty
                ? nil
                : Money(
                    amount: Decimal(string: entry.unitPrice) ?? 0,
                    currency: selectedCurrency
                )
            let itemAmount: Money
            if entry.type == .unitPrice, let q = qty, let u = unitPrice {
                itemAmount = u * q
            } else if entry.type == .fixedPrice, entry.amount.isEmpty == false {
                itemAmount = Money(
                    amount: Decimal(string: entry.amount) ?? 0,
                    currency: selectedCurrency
                )
            } else if entry.type == .vat {
                itemAmount = Money(
                    amount: Decimal(string: entry.amount) ?? 0,
                    currency: selectedCurrency
                )
            } else {
                itemAmount = Money(
                    amount: Decimal(string: entry.unitPrice) ?? 0,
                    currency: selectedCurrency
                )
            }
            return InvoiceLineItem(
                lineItemType: entry.type,
                description: entry.description,
                quantity: qty,
                unit: entry.unit.isEmpty ? nil : entry.unit,
                unitPrice: unitPrice,
                vatRate: Decimal(string: entry.vatRate),
                amount: itemAmount
            )
        }

        return SwissInvoice(
            creditor: creditor,
            iban: iban,
            currency: selectedCurrency,
            debtor: debtor,
            referenceType: referenceType,
            reference: referenceNumber.isEmpty ? nil : referenceNumber,
            additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo,
            vatNr: vatNr,
            title: invoiceTitle.isEmpty ? nil : invoiceTitle,
            subject: subject.isEmpty ? nil : subject,
            leadingText: leadingText,
            invoiceDate: invoiceDate,
            lineItems: items,
            trailingText: trailingText,
            fontName: resolvedFontName,
            fontSize: CGFloat(Double(fontSizeText) ?? 12)
        )
    }
}

struct LineItemViewRow: Identifiable {
    let id = UUID()
    var type: LineItemType = .fixedPrice
    var description: String = ""
    var quantity: String = ""
    var unit: String = ""
    var unitPrice: String = ""
    var vatRate: String = ""
    var amount: String = ""
}
