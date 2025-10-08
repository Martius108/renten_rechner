//
//  RentenKonstanten.swift
//  RentenRechner
//
//  Zeitlose Konstanten und Tabellen für die Rentenberechnung (regelbasiert)
//

import Foundation

/// Zeitlose, gesetzlich definierte Konstanten (nicht jahresabhängig)
struct RentenKonstanten {
    // Abschläge
    static let abschlagProMonat: Double = 0.003
    static let maxAbschlagMonate: Int = 48
    static let maxAbschlag: Double = 0.144

    // Mindestversicherungszeiten (Wartezeiten)
    static let mindestversicherungszeit: Int = 5
    static let mindestversicherungszeitLangjaehrig: Int = 35
    static let mindestversicherungszeitBesondersLangjaehrig: Int = 45
}

/// Tabelle der Regelaltersgrenzen nach Geburtsjahr (gesetzlich fix)
struct RegelaltersgrenzenTabelle {
    static func regelaltersgrenze(fuer geburtsjahr: Int) -> (jahre: Int, monate: Int) {
        switch geburtsjahr {
        case ...1946: return (65, 0)
        case 1947: return (65, 1)
        case 1948: return (65, 2)
        case 1949: return (65, 3)
        case 1950: return (65, 4)
        case 1951: return (65, 5)
        case 1952: return (65, 6)
        case 1953: return (65, 7)
        case 1954: return (65, 8)
        case 1955: return (65, 9)
        case 1956: return (65, 10)
        case 1957: return (65, 11)
        case 1958: return (66, 0)
        case 1959: return (66, 2)
        case 1960: return (66, 4)
        case 1961: return (66, 6)
        case 1962: return (66, 8)
        case 1963: return (66, 10)
        case 1964...: return (67, 0)
        default: return (67, 0)
        }
    }

    /// DRV-konforme Sonderfälle für besonders langjährig Versicherte (45 Jahre)
    static func fruehesterAbschlagsfreierBeginn(fuer geburtsjahr: Int) -> (jahre: Int, monate: Int, fixJahr: Int?, fixMonat: Int?, fixTag: Int?) {
        switch geburtsjahr {
        case ...1952: return (63, 0, nil, nil, nil)
        case 1953: return (63, 2, nil, nil, nil)
        case 1954: return (63, 4, nil, nil, nil)
        case 1955: return (63, 6, nil, nil, nil)
        case 1956: return (63, 8, nil, nil, nil)
        case 1957: return (63, 10, nil, nil, nil)
        case 1958: return (64, 0, nil, nil, nil)
        case 1959:
            return (0, 0, 2023, 12, 31)
        case 1960:
            return (0, 0, 2025, 12, 31)
        case 1961:
            return (0, 0, 2027, 12, 31)
        case 1962:
            return (0, 0, 2029, 12, 31)
        case 1963:
            return (0, 0, 2028, 12, 31)
        case 1964...: return (65, 0, nil, nil, nil)
        default: return (65, 0, nil, nil, nil)
        }
    }

    static func schwerbehindertenrente(fuer geburtsjahr: Int) -> (jahre: Int, monate: Int) {
        switch geburtsjahr {
        case ...1951: return (63, 0)
        case 1952: return (63, 1)
        case 1953: return (63, 2)
        case 1954: return (63, 3)
        case 1955: return (63, 4)
        case 1956: return (63, 5)
        case 1957: return (63, 6)
        case 1958: return (63, 7)
        case 1959: return (63, 8)
        case 1960: return (63, 9)
        case 1961: return (63, 10)
        case 1962: return (63, 11)
        case 1963: return (64, 0)
        case 1964: return (64, 2)
        case 1965: return (64, 4)
        case 1966: return (64, 6)
        case 1967: return (64, 8)
        case 1968: return (64, 10)
        case 1969...: return (65, 0)
        default: return (65, 0)
        }
    }

    static func frauenrente(fuer geburtsjahr: Int) -> (jahre: Int, monate: Int)? {
        if geburtsjahr <= 1951 { return (60, 0) }
        return nil
    }
}

/// Datums-Helfer für Altersgrenzen
extension RegelaltersgrenzenTabelle {
    static func regelaltersdatum(fuer geburtsdatum: Date) -> Date {
        let (jahre, monate) = regelaltersgrenze(fuer: Calendar.current.component(.year, from: geburtsdatum))
        let basis = DateHelper.addiere(jahre: jahre, monate: monate, zu: geburtsdatum) ?? geburtsdatum
        return DateHelper.naechsterMonatserster(ab: basis)
    }

    static func fruehesterAbschlagsfreierBeginnDatum(fuer geburtsdatum: Date) -> Date {
        let geburtsjahr = Calendar.current.component(.year, from: geburtsdatum)
        let (jahre, monate, fixJahr, fixMonat, fixTag) = fruehesterAbschlagsfreierBeginn(fuer: geburtsjahr)
        if let fj = fixJahr, let fm = fixMonat, let ft = fixTag {
            let fix = DateHelper.erstelleDatum(jahr: fj, monat: fm, tag: ft) ?? geburtsdatum
            return DateHelper.naechsterMonatserster(ab: fix)
        }
        let basis = DateHelper.addiere(jahre: jahre, monate: monate, zu: geburtsdatum) ?? geburtsdatum
        return DateHelper.naechsterMonatserster(ab: basis)
    }

    static func schwerbehindertenrenteDatum(fuer geburtsdatum: Date) -> Date {
        let (jahre, monate) = schwerbehindertenrente(fuer: Calendar.current.component(.year, from: geburtsdatum))
        let basis = DateHelper.addiere(jahre: jahre, monate: monate, zu: geburtsdatum) ?? geburtsdatum
        return DateHelper.naechsterMonatserster(ab: basis)
    }

    static func frauenrenteDatum(fuer geburtsdatum: Date, geschlecht: String) -> Date? {
        guard geschlecht.lowercased() == "w" else { return nil }
        if let (jahre, monate) = frauenrente(fuer: Calendar.current.component(.year, from: geburtsdatum)) {
            let basis = DateHelper.addiere(jahre: jahre, monate: monate, zu: geburtsdatum) ?? geburtsdatum
            return DateHelper.naechsterMonatserster(ab: basis)
        }
        return nil
    }
}
