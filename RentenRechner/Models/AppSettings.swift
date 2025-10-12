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

    var steuerfreibetrag: Double = 12096.0
    var steuerpflichtQuote: Double = 0.835
    var durchschnittlicherSteuersatz: Double = 0.15

    var krankenkassenBeitragssatz: Double = 0.146
    var krankenkassenZusatzbeitrag: Double = 0.0125
    var pflegeversicherungsBeitrag: Double = 0.036

    var nettoFaktorSchaetzung: Double {
        steuerpflichtQuote * (1.0 - durchschnittlicherSteuersatz)
    }

    // Neue Properties für Regelaltersgrenze und frühesten abschlagsfreien Beginn
    var regelaltersgrenze: Date = Date()
    var fruehesterAbschlagsfreierBeginn: Date = Date()
    var abweichenderRentenbeginn: Date? = nil

    init() {
        // Beispiel-Geburtsdatum (60 Jahre vor heute)
        let beispielGeburtsdatum = Calendar.current.date(byAdding: .year, value: -60, to: Date()) ?? Date()
        self.regelaltersgrenze = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: beispielGeburtsdatum)
        self.fruehesterAbschlagsfreierBeginn = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: beispielGeburtsdatum)
        self.abweichenderRentenbeginn = self.regelaltersgrenze
    }

    // Methode zum Aktualisieren der Werte basierend auf Geburtsdatum
    func updateRentenParameter(geburtsdatum: Date) {
        let normGeburt = DateHelper.mitternachtStabil(fuer: geburtsdatum)
        let neueRegelaltersgrenze = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: normGeburt)
        let neuerFruehesterAbschlagsfreierBeginn = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: normGeburt)

        self.regelaltersgrenze = neueRegelaltersgrenze
        self.fruehesterAbschlagsfreierBeginn = neuerFruehesterAbschlagsfreierBeginn

        // Nur initial abweichenderRentenbeginn setzen, wenn er noch nicht gesetzt oder gleich Regelaltersgrenze
        if self.abweichenderRentenbeginn == nil || self.abweichenderRentenbeginn == self.regelaltersgrenze {
            self.abweichenderRentenbeginn = neueRegelaltersgrenze
        }
    }
}

// MARK: - Kopierfunktion für AppSettings

extension AppSettings {
    func copy() -> AppSettings {
        let copy = AppSettings()
        copy.gueltigkeitsjahr = self.gueltigkeitsjahr
        copy.durchschnittsentgelt = self.durchschnittsentgelt
        copy.rentenwert = self.rentenwert
        copy.beitragsbemessungsgrenze = self.beitragsbemessungsgrenze
        copy.steuerfreibetrag = self.steuerfreibetrag
        copy.steuerpflichtQuote = self.steuerpflichtQuote
        copy.durchschnittlicherSteuersatz = self.durchschnittlicherSteuersatz
        copy.krankenkassenBeitragssatz = self.krankenkassenBeitragssatz
        copy.krankenkassenZusatzbeitrag = self.krankenkassenZusatzbeitrag
        copy.pflegeversicherungsBeitrag = self.pflegeversicherungsBeitrag
        copy.regelaltersgrenze = self.regelaltersgrenze
        copy.fruehesterAbschlagsfreierBeginn = self.fruehesterAbschlagsfreierBeginn
        copy.abweichenderRentenbeginn = self.abweichenderRentenbeginn
        return copy
    }
}
