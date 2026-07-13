//
//  Person.swift
//  RentenRechner
//
//

import Foundation
import SwiftData

@Model
class Person {
    var id: UUID

    private var _geburtsdatum: Date
    
    var monatlichesEinkommen: Double
    var aktuelleRentenpunkte: Double
    var rentenpunkteStand: Date = Date()
    var erfuelltWartezeit45Jahre: Bool = false
    
    var geburtsdatum: Date {
        get {
            return DateHelper.mitternachtStabil(fuer: _geburtsdatum)
        }
        set {
            _geburtsdatum = DateHelper.mitternachtStabil(fuer: newValue)
        }
    }
    
    init() {
        self.id = UUID()
        let defaultDate = DateHelper.stableCalendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? Date()
        self._geburtsdatum = DateHelper.mitternachtStabil(fuer: defaultDate)
        self.monatlichesEinkommen = 0.0
        self.aktuelleRentenpunkte = 0.0
    }
    
    init(
        geburtsdatum: Date = DateHelper.stableCalendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? Date(),
        monatlichesEinkommen: Double = 0.0,
        aktuelleRentenpunkte: Double = 0.0,
        rentenpunkteStand: Date = Date(),
        erfuelltWartezeit45Jahre: Bool = false
    ) {
        self.id = UUID()
        self._geburtsdatum = DateHelper.mitternachtStabil(fuer: geburtsdatum)
        self.monatlichesEinkommen = monatlichesEinkommen
        self.aktuelleRentenpunkte = aktuelleRentenpunkte
        self.rentenpunkteStand = DateHelper.mitternachtStabil(fuer: rentenpunkteStand)
        self.erfuelltWartezeit45Jahre = erfuelltWartezeit45Jahre
    }
    

    
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
