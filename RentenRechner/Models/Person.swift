//
//  Person.swift
//  RentenRechner
//
//  Datenmodell für Personendaten zur Rentenberechnung
//

import Foundation
import SwiftData

@Model
class Person {
    var id: UUID
    var geschlecht: Geschlecht
    
    // Private Backing-Property für Datumsnormalisierung
    private var _geburtsdatum: Date
    
    var monatlichesEinkommen: Double
    var aktuelleRentenpunkte: Double
    var aktuelleRente: Double?
    
    // Zusatzrenten
    var zusatzrente1: Double
    var zusatzrente2: Double
    
    // Witwenrente
    var witwenrente: Double
    
    // Computed Properties mit automatischer Normalisierung (Mitternacht Europe/Berlin)
    var geburtsdatum: Date {
        get {
            return DateHelper.mitternachtStabil(fuer: _geburtsdatum)
        }
        set {
            _geburtsdatum = DateHelper.mitternachtStabil(fuer: newValue)
        }
    }
    
    // Init ohne gewuenschterRentenbeginn
    init() {
        self.id = UUID()
        self.geschlecht = .maennlich
        let defaultDate = DateHelper.stableCalendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? Date()
        self._geburtsdatum = DateHelper.mitternachtStabil(fuer: defaultDate)
        self.monatlichesEinkommen = 0.0
        self.aktuelleRentenpunkte = 0.0
        self.aktuelleRente = nil
        self.zusatzrente1 = 0.0
        self.zusatzrente2 = 0.0
        self.witwenrente = 0.0
    }
    
    init(
        geschlecht: Geschlecht = .maennlich,
        geburtsdatum: Date = DateHelper.stableCalendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? Date(),
        monatlichesEinkommen: Double = 0.0,
        aktuelleRentenpunkte: Double = 0.0,
        aktuelleRente: Double? = nil,
        zusatzrente1: Double = 0.0,
        zusatzrente2: Double = 0.0,
        witwenrente: Double = 0.0
    ) {
        self.id = UUID()
        self.geschlecht = geschlecht
        self._geburtsdatum = DateHelper.mitternachtStabil(fuer: geburtsdatum)
        self.monatlichesEinkommen = monatlichesEinkommen
        self.aktuelleRentenpunkte = aktuelleRentenpunkte
        self.aktuelleRente = aktuelleRente
        self.zusatzrente1 = zusatzrente1
        self.zusatzrente2 = zusatzrente2
        self.witwenrente = witwenrente
    }
    
    // MARK: - Computed Properties
    
    var alter: Int {
        let cal = DateHelper.stableCalendar
        let heute = DateHelper.mitternachtStabil(fuer: Date())
        let comps = cal.dateComponents([.year], from: geburtsdatum, to: heute)
        return comps.year ?? 0
    }
    
    var geburtsjahr: Int {
        let cal = DateHelper.stableCalendar
        return cal.component(.year, from: geburtsdatum)
    }
    
    var jahresbruttoeinkommen: Double {
        monatlichesEinkommen * 12.0
    }
    
    // Zusatzrenten Berechnungen (ohne Witwenrente)
    var gesamtZusatzrente: Double {
        zusatzrente1 + zusatzrente2
    }
    
    var jahresZusatzrente: Double {
        gesamtZusatzrente * 12.0
    }
    
    var hatZusatzrenten: Bool {
        gesamtZusatzrente > 0
    }
    
    var jahresWitwenrente: Double {
        witwenrente * 12.0
    }
}

enum Geschlecht: String, CaseIterable, Codable {
    case maennlich = "Männlich"
    case weiblich = "Weiblich"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Validation Extensions
extension Person {
    var isValid: Bool {
        return isGeburtsdatumValid && isRentenbeginnValid
    }
    
    var isGeburtsdatumValid: Bool {
        return DateHelper.istGueltigesGeburtsdatum(geburtsdatum)
    }
    
    var isEinkommenValid: Bool {
        return true
    }
    
    var isRentenpunkteValid: Bool {
        return true
    }
    
    var isRentenbeginnValid: Bool {
        return true
    }
    
    var isZusatzrentenValid: Bool {
        return true
    }
}

// MARK: - Validation Errors
enum PersonValidationError: LocalizedError {
    case ungueltigesGeburtsdatum
    
    var errorDescription: String? {
        switch self {
        case .ungueltigesGeburtsdatum:
            return "Bitte geben Sie ein gültiges Geburtsdatum ein"
        }
    }
}
