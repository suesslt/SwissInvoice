import SwiftUI
import SwissInvoice
import PDFKit
import UniformTypeIdentifiers

// MARK: - FileDocument wrapper for PDF save

struct PDFFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - UIActivityViewController wrapper (shares a file URL)

struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct InvoicePreviewView: View {
    let invoice: SwissInvoice
    @State private var pdfData: Data?
    @State private var showSaveDialog = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // QR Code Preview
                SwissQRCodeView(invoice: invoice, size: 250)
                    .padding()

                // QR Payload (for debugging)
                GroupBox("QR Payload") {
                    Text(invoice.qrPayload())
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // PDF Preview
                GroupBox("PDF Preview") {
                    if let data = pdfData {
                        PDFKitView(data: data)
                            .frame(height: 500)
                    } else {
                        ProgressView("Generating PDF...")
                    }
                }
                .padding(.horizontal)

                if pdfData != nil {
                    HStack(spacing: 12) {
                        // Share Button (AirDrop, Mail, Messages, etc.)
                        Button {
                            prepareShareFile()
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        // Save Button (native file save dialog)
                        Button {
                            showSaveDialog = true
                        } label: {
                            Label("Save", systemImage: "folder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            pdfData = invoice.pdfData()
        }
        .fileExporter(
            isPresented: $showSaveDialog,
            document: pdfData.map { PDFFile(data: $0) },
            contentType: .pdf,
            defaultFilename: "SwissInvoice"
        ) { result in
            if case .failure(let error) = result {
                print("Save failed: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ActivityView(url: shareURL)
            }
        }
    }

    /// Writes PDF to Documents directory (accessible by share service).
    private func prepareShareFile() {
        guard let pdfData else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("SwissInvoice.pdf")
        try? pdfData.write(to: url)
        shareURL = url
    }
}

// MARK: - PDFKit UIViewRepresentable

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}
