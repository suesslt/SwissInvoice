# Spezifikation: Oberer Teil der Rechnung (Briefkopf bis Betreff)

**Basierend auf:** SN 10130:2026 de – Geschäftsbrief
**Geltungsbereich:** Oberer Teil der A4-Rechnung (oberhalb des Rechnungsinhalts)
**Ausgenommen:** Empfangsschein und Zahlteil (unterer Teil) – bleiben unverändert

---

## 1. Seitenformat und Grundmasse

| Parameter          | Wert       | In Punkten (72 dpi) |
|--------------------|------------|---------------------|
| Blattbreite        | 210 mm     | 595.28 pt           |
| Blatthöhe          | 297 mm     | 841.89 pt           |
| Linker Seitenrand  | 20 mm      | 56.69 pt            |
| Rechter Seitenrand | 10 mm (min) | 28.35 pt           |
| Umrechnungsfaktor  | 1 mm = 72/25.4 pt | ≈ 2.8346 pt/mm |

> **Norm-Referenz:** Abschnitt 4, Bild 2 (Linksadressierung)

---

## 2. Vertikale Feldaufteilung

Die Norm teilt den oberen Bereich des A4-Blattes in klar definierte vertikale Zonen ein:

```
 0 mm ┌─────────────────────────────────────────┐
      │              Feld für Briefkopf          │
      │     (Logo, Firmenname, Gestaltung frei)  │
38 mm ├─────────────────────────────────────────┤
      │   Adressfeldbereich    │   Infoblock     │
      │   (Empfängeradresse)   │   oder           │
      │                        │   Eingangs-/     │
      │                        │   Bearbeitungs-  │
      │                        │   vermerke       │
97 mm ├─────────────────────────────────────────┤
      │           Leitwörterbereich              │
      │  (mind. 14 mm unter Adressfeldbereich)   │
      ├─────────────────────────────────────────┤
      │   2 Leerzeilen Abstand                   │
      ├─────────────────────────────────────────┤
      │           Betreff (fett)                 │
      ├─────────────────────────────────────────┤
      │   1 Leerzeile Abstand                    │
      ├─────────────────────────────────────────┤
      │           Brieftext / Rechnungsinhalt    │
      │           ...                            │
```

| Feld                     | Y-Start (von oben) | Höhe    | Y-Ende  |
|--------------------------|---------------------|---------|---------|
| Briefkopf                | 0 mm                | 38 mm   | 38 mm   |
| Adressfeldbereich        | 38 mm               | 59 mm   | 97 mm   |
| Leitwörter/Bezugszeichen | ≥ 111 mm *          | variabel| variabel|
| Betreff                  | nach Leitwörtern + 2 Leerzeilen | — | — |

> \* Leitwörter stehen mindestens 14 mm unter dem sichtbaren Adressfeld (Norm Abschnitt 5.5). Das sichtbare Adressfeld endet bei maximal 97 mm; die Leitwörter beginnen somit frühestens bei ~111 mm.

---

## 3. Briefkopf-Feld (0 – 38 mm)

| Parameter              | Wert           |
|------------------------|----------------|
| Y-Position Oberkante   | 0 mm (0 pt)    |
| Y-Position Unterkante  | 38 mm (107.72 pt) |
| Breite                 | volle Blattbreite (210 mm) |
| Gestaltung             | frei (Logo, Firmenname, etc.) |

> **Norm-Referenz:** Abschnitt 5.2 – Unter Berücksichtigung der Normvorgaben gibt es vielfältige Möglichkeiten zur individuellen Gestaltung.

---

## 4. Adressfeldbereich (38 – 97 mm) – Linksadressierung

### 4.1 Empfängeradresse (linke Seite)

| Parameter                    | Wert             | In Punkten        |
|------------------------------|------------------|--------------------|
| X-Position (linker Rand)     | 20 mm            | 56.69 pt           |
| Y-Position Oberkante         | 38 mm            | 107.72 pt          |
| Feldbreite (max)             | 100 mm           | 283.46 pt          |
| Feldhöhe (max)               | 45 mm            | 127.56 pt          |
| Y-Position Unterkante        | 83 mm            | 235.28 pt          |

**Adressfeldaufbau (max. 6 Zeilen im Adressblock):**

```
┌────────────────────────────────────────┐
│ Absenderzeile (optional, kleinere      │ ← Oberstes Fünftel
│ Schrift, durch Linie abgegrenzt)       │    des Adressfeldes
│ ─── Ruhezone mind. 3 mm ──────────── │
│ Anrede oder Firmenname                 │ ← Empfängeradresse
│ Abteilung / Organisatorische Einheit   │    (3–6 Zeilen)
│ Akad. Titel / Vorname / Name          │
│ Strasse / Nummer                       │
│ PLZ und Ort                            │
└────────────────────────────────────────┘
```

**Regeln:**
- Linksbündig, waagrecht zum oberen Papierrand
- Serifenlose Schrift (Calibri, Arial, Helvetica, etc.)
- Schriftgrösse: mindestens 10 Punkt (~3 mm)
- Kein Fettdruck, keine Zierschrift, nicht kursiv
- Keine Leerzeilen innerhalb des Adressblocks
- Keine Hintergrunddrucke oder -grafiken im Adressfeld
- Die schraffierte Zone um den Adressfeldbereich darf nicht beschriftet werden

> **Norm-Referenz:** Abschnitte 5.3, 6.2, 6.3; Bild 2, Bild 7

### 4.2 Infoblock (rechte Seite neben Adresse)

| Parameter                    | Wert             | In Punkten        |
|------------------------------|------------------|--------------------|
| X-Position                   | rechts neben dem Adressfeld | ab ~125 mm |
| Y-Position                   | 38 mm            | 107.72 pt          |
| Verfügbare Höhe              | 59 mm            | 167.32 pt          |
| Rechter Rand                 | 10 mm vom Blattrand | bis 200 mm     |

**Infoblock-Inhalt (Variante mit Leitwörtern im Infoblock):**

```
Ihr Zeichen:    [Wert]
Ihre Nachricht: [Wert]
Unser Zeichen:  [Wert]
Telefon:        [Wert]
Fax:            [Wert]
E-Mail:         [Wert]
Datum:          [Wert]
```

> **Norm-Referenz:** Abschnitt 4.4.2, Bild 4

---

## 5. Leitwörter und Datum (ab ~111 mm)

Die Norm definiert drei Varianten zur Darstellung der Leitwörter:

### Variante A: Leitwörter im Infoblock (empfohlen für Rechnungen)
Die Leitwörter stehen im Infoblock rechts neben der Adresse (siehe Abschnitt 4.2). In diesem Fall entfällt eine separate Leitwörterzone unterhalb des Adressfeldbereichs. Das Datum ist Teil des Infoblocks.

### Variante B: Leitwörter am Seitenrand
| Parameter              | Wert             |
|------------------------|------------------|
| X-Position             | 20 mm (linker Seitenrand) |
| Y-Position             | mind. 14 mm unter sichtbarem Adressfeld |
| Ausrichtung            | rechtsbündig zum Leitwort-Label |

Leitwörter untereinander:
```
   Ihr Zeichen  [Wert]
Ihre Nachricht  [Wert]
 Unser Zeichen  [Wert]
         Datum  [Wert]
```

> **Norm-Referenz:** Abschnitt 4.4.3, Bild 5

### Variante C: Leitwörter auf waagrechter Linie
| Parameter              | Wert             |
|------------------------|------------------|
| X-Position             | 20 mm            |
| Y-Position             | mind. 14 mm unter sichtbarem Adressfeld |
| Anordnung              | nebeneinander auf einer Zeile |

```
Ihr Zeichen    Ihre Nachricht    Unser Zeichen    Datum
[Wert]         [Wert]            [Wert]           [Wert]
```

> **Norm-Referenz:** Abschnitt 4.4.4, Bild 6

### Datum-Formatierung
- Umgangssprache: `3. Dezember 2025`
- Kurzform: `03.12.2025` (Tag.Monat.Jahr)
- ISO 8601: `2025-12-03`

> **Norm-Referenz:** Abschnitt 6.9 i)

---

## 6. Betreff

| Parameter              | Wert             |
|------------------------|------------------|
| X-Position             | 20 mm (linker Seitenrand) |
| Y-Position             | 2 Leerzeilen unter der Leitwörtergruppe oder dem Infoblock |
| Schrift                | Grundschrift des Briefes (gleicher Font) |
| Hervorhebung           | fett oder unterstrichen (optional) |
| Schlusspunkt           | keiner           |

**Regeln:**
- Stichwortartige Angabe zum Rechnungsinhalt
- Bei längerem Text sinngemäss auf mehrere Zeilen verteilen
- Kann mit einer Linie (Breite = breiteste Textzeile) abgeschlossen werden
- Teilbetreff beginnt am linken Rand, schliesst mit Punkt ab

> **Norm-Referenz:** Abschnitt 6.5

---

## 7. Falz- und Lochmarken

| Marke             | Y-Position (von oben) | In Punkten  | Zweck                    |
|-------------------|-----------------------|-------------|--------------------------|
| Falzmarke oben    | 99 mm                 | 280.63 pt   | Falz für C5/6-Umschlag   |
| Lochmarke         | 148.5 mm              | 420.94 pt   | Ablage-Lochung           |
| Falzmarke unten   | 210 mm                | 595.28 pt   | Falz für C5-Umschlag     |

- Darstellung: kurzer Strich am linken Blattrand
- Optional, können bei maschineller Kuvertierung weggelassen werden

> **Norm-Referenz:** Abschnitt 5.7, Bild 2

---

## 8. Schrift

| Anwendung          | Schrifttyp      | Grösse         |
|--------------------|-----------------|----------------|
| Empfängeradresse   | Serifenlos (Calibri, Arial, Helvetica) | mind. 10 pt |
| Brieftext          | Frei wählbar (z.B. Cambria, Segoe UI) | max. 12 pt  |
| Betreff            | Grundschrift des Briefes, ggf. fett   | wie Brieftext |

> **Norm-Referenz:** Abschnitte 6.1, 6.2

---

## 9. Abgleich mit aktuellem Code (IST vs. SOLL)

### Abweichungen vom Standard

| Element               | IST (aktueller Code)                        | SOLL (SN 10130:2026)                       | Aktion           |
|-----------------------|---------------------------------------------|---------------------------------------------|------------------|
| Briefkopf-Bereich     | marginTop = 20 mm, freies Layout            | 0–38 mm, frei gestaltbar                   | **Anpassen**: Briefkopf nutzt volle 38 mm  |
| Adressfeld Y-Position | ~112.69 pt (~39.8 mm), dynamisch berechnet  | 38 mm (107.72 pt) fest                     | **Anpassen**: Feste Y-Position bei 38 mm   |
| Adressfeld Breite     | Keine Begrenzung (bis Seitenmitte)          | max. 100 mm                                | **Anpassen**: Breite auf 100 mm begrenzen  |
| Adressfeld Höhe       | Dynamisch (~69 pt)                          | max. 45 mm (127.56 pt)                     | **Prüfen**: Passt bei 4–6 Zeilen           |
| Absenderzeile         | Nicht vorhanden                              | Optional, oberstes Fünftel des Adressfelds | **Neu**: Absenderzeile implementieren       |
| Infoblock             | Debtor rechts (als Empfänger)               | Kommunikationsvermerke rechts neben Adresse| **Umbauen**: Adresse = Empfänger, Infoblock = Metadaten |
| Debtor-Adresse        | Rechts oben (gespiegelt zum Creditor)       | Im Adressfeldbereich als Empfänger (links) | **Umbauen**: Debtor = Empfängeradresse     |
| Creditor-Adresse      | Links oben ("From")                         | Im Briefkopf oder Infoblock oder als Absenderzeile | **Umbauen**: Creditor in Briefkopf   |
| Leitwörter/Datum      | Datum unter dem Titel (20 mm von oben)      | Im Infoblock oder mind. 14 mm unter Adresse| **Anpassen**: Position gemäss Variante     |
| Betreff               | Nicht vorhanden                              | 2 Leerzeilen unter Leitwörtern, fett       | **Neu**: Betreff-Feld implementieren        |
| Rechter Seitenrand    | 20 mm                                       | mind. 10 mm                                | **OK**, 20 mm ist konform                   |
| Falzmarken            | Nicht vorhanden                              | Optional bei 99/148.5/210 mm               | **Neu**: Optional implementieren            |
| Adress-Schrift        | Konfigurierbarer Font                       | Serifenlos, mind. 10 pt, kein Fettdruck    | **Prüfen/Anpassen**                        |

### Kernänderung: Semantik der Adressen

Der grösste strukturelle Unterschied betrifft die Zuordnung der Adressen:

| Rolle         | IST                            | SOLL (gemäss Norm)                         |
|---------------|--------------------------------|--------------------------------------------|
| **Creditor**  | Links oben, Label "From"       | Im Briefkopf-Feld (0–38 mm) ODER als Absenderzeile im Adressfenster |
| **Debtor**    | Rechts oben, Label "To"        | **Empfängeradresse** im Adressfeldbereich (38–97 mm, linksbündig)   |

> Die Norm sieht vor, dass im Adressfeldbereich die **Empfängeradresse** steht – bei einer Rechnung ist das der Debtor (Rechnungsempfänger). Der Creditor (Rechnungssteller) gehört in den Briefkopf oder als kleine Absenderzeile über die Empfängeradresse.

---

## 10. Empfohlene Layout-Konstanten (Zusammenfassung)

```
// SN 10130:2026 – Brieflayout-Konstanten
//
// Vertikale Zonen
briefkopfTop        =   0 mm    (  0.00 pt)
briefkopfBottom     =  38 mm    (107.72 pt)
adressfeldTop       =  38 mm    (107.72 pt)
adressfeldBottom    =  97 mm    (274.96 pt)   // = 38 + 59
adressfeldSichtbar  =  83 mm    (235.28 pt)   // = 38 + 45 (Normfenster-Höhe)

// Adressfeld (Linksadressierung)
adressfeldX         =  20 mm    ( 56.69 pt)
adressfeldBreite    = 100 mm    (283.46 pt)
adressfeldHoehe     =  45 mm    (127.56 pt)   // Normfenster

// Absenderzeile im Adressfenster (optional)
absenderZoneHoehe   =   9 mm    ( 25.51 pt)   // Oberstes Fünftel von 45 mm
ruhezoneHoehe       =   3 mm    (  8.50 pt)   // Mindestabstand zur Empfängeradresse

// Infoblock (rechts neben Adresse)
infoblockX          = 125 mm    (354.33 pt)   // Abhängig von Gestaltung
infoblockBreite     =  75 mm    (212.60 pt)   // Bis 10 mm vor rechtem Rand
infoblockTop        =  38 mm    (107.72 pt)
infoblockHoehe      =  59 mm    (167.32 pt)

// Leitwörter (falls nicht im Infoblock)
leitwoerterMinY     = 111 mm    (314.65 pt)   // mind. 14 mm unter Adressfeld-Ende (97mm)

// Betreff
betreffAbstand      = 2 Leerzeilen nach Leitwörtern/Infoblock-Unterkante

// Falzmarken
falzmarkeOben       =  99 mm    (280.63 pt)
lochmarke           = 148.5 mm  (420.94 pt)
falzmarkeUnten      = 210 mm    (595.28 pt)

// Seitenränder
seitenrandLinks     =  20 mm    ( 56.69 pt)
seitenrandRechts    =  10 mm    ( 28.35 pt)   // Minimum laut Norm
```

---

## 11. Nächste Schritte

Diese Spezifikation deckt die **Positionierung** der Elemente ab. In einem nächsten Schritt wird der **inhaltliche Teil** (Rechnungspositionen, Tabellen, Summen, Fusszeilenbereich) spezifiziert.
