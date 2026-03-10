# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwissInvoice is a Swift package for generating Swiss QR Bills (SPC/0200 format per SIX specification v2.x). Supports PDF rendering, QR code generation, line items with unit pricing, and VAT calculations. Currency restricted to CHF/EUR per QR standard.

## Build & Test Commands

```bash
# Build
swift build

# Run all tests
swift test

# Run a single test
swift test --filter SwissInvoiceTests.QRPayloadGeneratorTests
```

## Architecture

- **SPM package** (Swift 6.2+, iOS 17+, macOS 14+)
- Two dependencies: `Score` and `ScoreUI` via local path (`../score`)
- All types are `Sendable`-compliant

### Key Types

| Type | Role |
|------|------|
| `SwissInvoice` | Main invoice model (creditor, debtor, IBAN, amount, line items) |
| `InvoiceLineItem` | Line item with type: fixedPrice/unitPrice/vat |
| `Address` | Creditor/debtor address |
| `ReferenceType` | QR reference / creditor reference / none |
| `QRPayloadGenerator` | Generates SPC/0200 QR payload string |
| `QRCodeGenerator` | Encodes payload to QR code image |
| `InvoicePDFRenderer` | Renders full invoice to PDF Data |
| `SwissQRCodeView` | SwiftUI component for QR code display |
| `GoogleFontLoader` | Loads custom fonts for PDF rendering |

### Test Coverage
9 test suites covering: Address, GoogleFontLoader, QRPayloadGenerator, QRCodeGenerator, InvoicePDFRenderer, FontType, LineItems, ReferenceType.

## Score Package — Shared Base Classes

This project depends on the [Score](../score) package via local SPM dependency (`../score`).

**Current usage**: `import Score` for `Money` and `Currency`; `import ScoreUI` for `PDFRenderer`.

### Available Types

| Type | Module | Description |
|------|--------|-------------|
| `Money` | Score | Currency-safe monetary amounts with `Decimal` precision. Arithmetic enforces matching currencies. |
| `Currency` | Score | ISO 4217 enum with 180+ currencies, decimal places, and localized names. |
| `Percent` | Score | Percentage as factor (e.g. `0.10` = 10%). |
| `FXRate` | Score | Bid/ask exchange rates with conversion methods. |
| `VATCalculation` | Score | VAT split (net/gross) with inclusive/exclusive handling. |
| `YearMonth` | Score | Year-month value type for monthly periods. |
| `DayCountRule` | Score | Financial day count conventions (ACT/360, ACT/365, 30/360). |
| `ServicePipeline` | Score | Async middleware chain for service operations. |
| `ServiceError` | Score | Typed errors (notFound, validation, businessRule, etc.). |
| `CSVExportable` | Score | Protocol for CSV row export. |
| `IBANValidator` | Score | ISO 13616 IBAN validation. |
| `SCORReferenceGenerator` | Score | ISO 11649 creditor reference with Mod 97. |
| `ErrorHandler` | ScoreUI | Observable error state management for SwiftUI. |
| `PDFRenderer` | ScoreUI | UIKit-based PDF generation. |
| `.errorAlert()` | ScoreUI | SwiftUI modifier for error alert presentation. |

```swift
import Score    // Money, Currency
import ScoreUI  // PDFRenderer
```
