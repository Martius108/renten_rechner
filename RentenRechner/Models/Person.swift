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
    
    // Private Backing-Properties für Datumsnormalisierung
    private var _geburtsdatum: Date
    private var _gewuenschterRentenbeginn: Date?
    
    var monatlichesEinkommen: Double
    var aktuelleRentenpunkte: Double
    var aktuelleRente: Double?
    
    // Zusatzrenten
    var zusatzrente1: Double
    var zusatzrente2: Double
    
    // Computed Properties mit automatischer Normalisierung (Mitternacht Europe/Berlin)
    var geburtsdatum: Date {
        get {
            return DateHelper.mitternachtStabil(fuer: _geburtsdatum)
        }
        set {
            _geburtsdatum = DateHelper.mitternachtStabil(fuer: newValue)
        }
    }
    
    var gewuenschterRentenbeginn: Date? {
        get {
            guard let d = _gewuenschterRentenbeginn else { return nil }
            return DateHelper.mitternachtStabil(fuer: d)
        }
        set {
            if let nv = newValue {
                _gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: nv)
            } else {
                _gewuenschterRentenbeginn = nil
            }
        }
    }
    
    init() {
        self.id = UUID()
        self.geschlecht = .maennlich
        let defaultDate = DateHelper.stableCalendar.date(from: DateComponents(year: 1980, month: 1, day: 1)) ?? Date()
        self._geburtsdatum = DateHelper.mitternachtStabil(fuer: defaultDate)
        self.monatlichesEinkommen = 0.0
        self.aktuelleRentenpunkte = 0.0
        self.aktuelleRente = nil
        self._gewuenschterRentenbeginn = nil
        self.zusatzrente1 = 0.0
        self.zusatzrente2 = 0.0
    }
    
    init(
        geschlecht: Geschlecht = .maennlich,
        geburtsdatum: Date = DateHelper.stableCalendar.date(from: DateComponents(year: 1980, month: 1, day: 1)) ?? Date(),
        monatlichesEinkommen: Double = 0.0,
        aktuelleRentenpunkte: Double = 0.0,
        aktuelleRente: Double? = nil,
        gewuenschterRentenbeginn: Date? = nil,
        zusatzrente1: Double = 0.0,
        zusatzrente2: Double = 0.0
    ) {
        self.id = UUID()
        self.geschlecht = geschlecht
        self._geburtsdatum = DateHelper.mitternachtStabil(fuer: geburtsdatum)
        self.monatlichesEinkommen = monatlichesEinkommen
        self.aktuelleRentenpunkte = aktuelleRentenpunkte
        self.aktuelleRente = aktuelleRente
        if let rb = gewuenschterRentenbeginn {
            self._gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: rb)
        } else {
            self._gewuenschterRentenbeginn = nil
        }
        self.zusatzrente1 = zusatzrente1
        self.zusatzrente2 = zusatzrente2
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
    
    // Zusatzrenten Berechnungen
    var gesamtZusatzrente: Double {
        zusatzrente1 + zusatzrente2
    }
    
    var jahresZusatzrente: Double {
        gesamtZusatzrente * 12.0
    }
    
    var hatZusatzrenten: Bool {
        gesamtZusatzrente > 0
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
        return isGeburtsdatumValid &&
               isEinkommenValid &&
               isRentenpunkteValid &&
               isRentenbeginnValid &&
               isZusatzrentenValid
    }
    
    var isGeburtsdatumValid: Bool {
        // Nutze DateHelper-Logik für gültiges Geburtsdatum (mit DE-Zeitzone)
        return DateHelper.istGueltigesGeburtsdatum(geburtsdatum)
    }
    
    var isEinkommenValid: Bool {
        // Obergrenze 96.600 / 12 = 8.050 (wird ggf. im ViewModel dynamisch geprüft)
        return monatlichesEinkommen >= 0 && monatlichesEinkommen <= 8_050
    }
    
    var isRentenpunkteValid: Bool {
        return aktuelleRentenpunkte >= 0 && aktuelleRentenpunkte <= 200 // Plausibilitätsprüfung
    }
    
    var isRentenbeginnValid: Bool {
        guard let rentenbeginn = gewuenschterRentenbeginn else { return true }
        let cal = DateHelper.stableCalendar
        let age60 = cal.date(byAdding: .year, value: 60, to: geburtsdatum) ?? Date()
        return rentenbeginn >= DateHelper.mitternachtStabil(fuer: age60)
    }
    
    var isZusatzrentenValid: Bool {
        // Zusatzrenten sollten nicht negativ sein und nicht unrealistisch hoch
        return zusatzrente1 >= 0 && zusatzrente1 <= 5000 &&
               zusatzrente2 >= 0 && zusatzrente2 <= 5000
    }
}

// MARK: - Validation Errors
enum PersonValidationError: LocalizedError {
    case ungueltigesGeburtsdatum
    case einkommenZuHoch
    case rentenpunkteUngueltig
    case rentenbeginnZuFrueh
    case zusatzrenteUngueltig
    
    var errorDescription: String? {
        switch self {
        case .ungueltigesGeburtsdatum:
            return "Bitte geben Sie ein gültiges Geburtsdatum ein (zwischen 1955 und heute, Mindestalter 18 Jahre)"
        case .einkommenZuHoch:
            return "Das monatliche Einkommen darf 8.050€ nicht überschreiten (Beitragsbemessungsgrenze)"
        case .rentenpunkteUngueltig:
            return "Die Anzahl der Rentenpunkte muss zwischen 0 und 200 liegen"
        case .rentenbeginnZuFrueh:
            return "Der gewünschte Rentenbeginn darf nicht vor dem 60. Lebensjahr liegen"
        case .zusatzrenteUngueltig:
            return "Zusatzrenten müssen zwischen 0€ und 5.000€ pro Monat liegen"
        }
    }
}
