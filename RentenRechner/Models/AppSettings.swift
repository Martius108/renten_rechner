//
//  AppSettings.swift
//  RentenRechner
//
//  Persistente Rentendaten in Abhängigkeit vom Gesetzgeber
//

import Foundation
import SwiftData

@Model
class AppSettings {
    var gueltigkeitsjahr: Int = Calendar.current.component(.year, from: Date())
    var durchschnittsentgelt: Double = 50493.0
    var rentenwert: Double = 40.79
    var beitragsbemessungsgrenze: Double = 96600.0

    var steuerfreibetrag: Double = 12084.0
    var steuerpflichtQuote: Double = 0.85
    var durchschnittlicherSteuersatz: Double = 0.15

    var krankenkassenBeitragssatz: Double = 0.146
    var krankenkassenZusatzbeitrag: Double = 0.013
    var pflegeversicherungsBeitrag: Double = 0.034

    var nettoFaktorSchaetzung: Double {
        steuerpflichtQuote * (1.0 - durchschnittlicherSteuersatz)
    }

    // Neue Properties für Regelaltersgrenze und frühesten abschlagsfreien Beginn
    var regelaltersgrenze: Date = Date()
    var fruehesterAbschlagsfreierBeginn: Date = Date()

    init() {
        // Optional: Initialisierung mit Beispiel-Geburtsdatum (60 Jahre vor heute)
        let beispielGeburtsdatum = Calendar.current.date(byAdding: .year, value: -60, to: Date()) ?? Date()
        self.regelaltersgrenze = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: beispielGeburtsdatum)
        self.fruehesterAbschlagsfreierBeginn = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: beispielGeburtsdatum)
    }

    // Methode zum Aktualisieren der Werte basierend auf Geburtsdatum
    func updateRentenParameter(geburtsdatum: Date) {
        let normGeburt = DateHelper.mitternachtStabil(fuer: geburtsdatum)
        self.regelaltersgrenze = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: normGeburt)
        self.fruehesterAbschlagsfreierBeginn = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: normGeburt)
    }
}
