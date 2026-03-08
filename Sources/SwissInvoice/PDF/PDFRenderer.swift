import CoreGraphics
import UIKit

// MARK: - Font Configuration

public enum FontType: String, CaseIterable {
    case title = "Title"
    case standard = "Standard"
    case standardFixed = "Standard fixed"
    case standardSmall = "Standard small"
    case subject = "Subject"
    case titleInvoiceLines = "Title Invoice Lines"
    case standardBold = "Standard bold"
    case titleReceiver = "Title Receiver"
    case headerReceiver = "Header Receiver"
    case textReceiver = "Text Receiver"
    case titlePayment = "Title Payment"
    case headerPayment = "Header Payment"
    case textPayment = "Text Payment"
    case amountPayment = "Amount Payment"
    case amountReceiver = "Amount Receiver"

    // Schriftgröße
    var fontSize: CGFloat? {
        switch self {
        case .title: return 14
        case .standardFixed, .titleReceiver, .titlePayment: return 11
        case .textPayment, .amountPayment: return 10
        case .standardSmall, .titleInvoiceLines, .textReceiver, .headerPayment, .amountReceiver: return 8
        case .headerReceiver: return 6
        default: return nil  // Für "Standard", "Subject", "Standard bold" keine Angabe im Bild
        }
    }

    // Schriftschnitt (Bold oder Normal)
    var isBold: Bool {
        switch self {
        case .standard, .standardFixed, .standardSmall, .textReceiver, .textPayment, .amountPayment, .amountReceiver:
            return false
        default:
            return true
        }
    }

    // Monospace-Eigenschaft
    var isMonospaced: Bool {
        switch self {
        case .amountPayment, .amountReceiver:
            return true
        default:
            return false
        }
    }

    // Schriftart (Name)
    var fontName: String? {
        switch self {
        case .titleReceiver, .headerReceiver, .textReceiver, .titlePayment, .headerPayment, .textPayment,
            .amountPayment, .amountReceiver:
            return "Helvetica"
        default:
            return nil  // Systemspezifisch oder Standard
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .textReceiver, .headerReceiver, .textPayment, .headerPayment:
            return 1.1
        default:
            return 1.2
        }
    }
}

// MARK: - PDF Renderer Base Class

/// Base class providing reusable PDF drawing primitives for text, lines, and separators.
/// Subclass this to build domain-specific PDF renderers.
open class PDFRenderer {
    let fontName: String
    let fontSize: CGFloat

    public init(fontName: String?, fontSize: CGFloat?) {
        self.fontName = fontName ?? "Helvetica"
        self.fontSize = fontSize ?? 10
    }

    // MARK: - Text Drawing

    func draw(_ text: String, at point: CGPoint, fontType: FontType) -> CGFloat {
        let fontSize = fontType.fontSize ?? self.fontSize
        let attributes: [NSAttributedString.Key: Any] = createAttributes(fontType: fontType)
        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: point)
        return fontSize * fontType.lineSpacing
    }

    func drawRightAligned(_ text: String, at point: CGPoint, fontType: FontType) -> CGFloat {
        let fontSize = fontType.fontSize ?? self.fontSize
        var font: UIFont
        if let customFontName = fontType.fontName {
            font = UIFont(name: customFontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        } else {
            font = UIFont(name: self.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        }
        // Falls der Font laut Enum fett sein soll, den Descriptor anpassen
        if fontType.isBold {
            if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
                font = UIFont(descriptor: descriptor, size: 0)
            }
        }

        // Monospace berücksichtigen (wichtig für die Breitenberechnung von Beträgen)
        if fontType.isMonospaced {
            font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: fontType.isBold ? .bold : .regular)
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        // 2. Die Breite des Textes berechnen
        let textSize = (text as NSString).size(withAttributes: attributes)

        // 3. Den neuen Startpunkt berechnen (X-Koordinate nach links verschieben)
        let adjustedPoint = CGPoint(x: point.x - textSize.width, y: point.y)

        // 4. Die bestehende draw-Funktion zur eigentlichen Ausgabe nutzen
        return self.draw(text, at: adjustedPoint, fontType: fontType)
    }

    func drawMultiline(_ text: String, at point: CGPoint, width: CGFloat, fontType: FontType) -> CGFloat {
        // 1. Font & Style vorbereiten (wie zuvor)
        let thisFontSize = fontType.fontSize ?? fontSize
        var font: UIFont
        if let customFontName = fontType.fontName {
            font = UIFont(name: customFontName, size: thisFontSize) ?? .systemFont(ofSize: fontSize)
        } else {
            font = UIFont(name: self.fontName, size: thisFontSize) ?? .systemFont(ofSize: fontSize)
        }

        // 2. Bold-Styling anwenden, falls in der Enum definiert
        if fontType.isBold {
            if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
                font = UIFont(descriptor: descriptor, size: 0)  // size 0 behält die aktuelle Größe
            }
        }

        // 2. Absatz-Stil für den Zeilenumbruch definieren
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping  // Bricht bei Wortenden um

        // 3. Attribute zusammenstellen
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle,
        ]

        let estimatedSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let actualRect = text.boundingRect(
            with: estimatedSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        // 4. In ein Rechteck zeichnen statt an einen Punkt
        // Swift berechnet den Umbruch innerhalb von 'rect' automatisch
        text.draw(
            in: CGRect(x: point.x, y: point.y, width: width, height: actualRect.height),
            withAttributes: attributes
        )
        return actualRect.height
    }

    func drawEmptyLine(fontType: FontType) -> CGFloat {
        return fontType.fontSize ?? self.fontSize * fontType.lineSpacing
    }

    // MARK: - Line Drawing

    func drawHRule(
        ctx: CGContext,
        y: CGFloat,
        from startX: CGFloat,
        to endX: CGFloat,
        lineWidth: CGFloat = 0.5
    ) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.move(to: CGPoint(x: startX, y: y))
        ctx.addLine(to: CGPoint(x: endX, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    func drawVerticalSeparator(in ctx: CGContext, x: CGFloat, fromY: CGFloat, toY: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        ctx.move(to: CGPoint(x: x, y: fromY))
        ctx.addLine(to: CGPoint(x: x, y: toY))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Font Attributes

    func createAttributes(fontType: FontType) -> [NSAttributedString.Key: Any] {
        let fontSize = fontType.fontSize ?? self.fontSize
        var font: UIFont
        if let customFontName = fontType.fontName {
            font = UIFont(name: customFontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        } else {
            font = UIFont(name: self.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        }

        // 2. Bold-Styling anwenden, falls in der Enum definiert
        if fontType.isBold {
            if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
                font = UIFont(descriptor: descriptor, size: 0)  // size 0 behält die aktuelle Größe
            }
        }

        // Absatzstil für Wortumbruch definieren
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle,
        ]
        return attributes
    }
}
