//
//  AppSettings.swift
//  RentenRechner
//
//

import Foundation
import SwiftData

@Model
class AppSettings {
    static let datenstandJahr2026 = 2026
    static let durchschnittsentgelt2026 = 51944.0
    static let rentenwertAbJuli2026 = 42.52
    static let beitragsbemessungsgrenze2026 = 101400.0
    static let grundfreibetrag2026 = 12348.0
    static let steuerpflichtQuote2026 = 0.84
    static let krankenkassenBeitragssatz2026 = 0.146
    static let krankenkassenZusatzbeitrag2026 = 0.029
    static let pflegeversicherungsBeitrag2026 = 0.036

    var gueltigkeitsjahr: Int = 2026
    var durchschnittsentgelt: Double = 51944.0
    var rentenwert: Double = 42.52
    var beitragsbemessungsgrenze: Double = 101400.0

    var steuerfreibetrag: Double = 12348.0
    var steuerpflichtQuote: Double = 0.84
    var durchschnittlicherSteuersatz: Double = 0.15

    var krankenkassenBeitragssatz: Double = 0.146
    var krankenkassenZusatzbeitrag: Double = 0.029
    var pflegeversicherungsBeitrag: Double = 0.036

    var nettoFaktorSchaetzung: Double {
        steuerpflichtQuote * (1.0 - durchschnittlicherSteuersatz)
    }

    var gueltigkeitsjahrText: String {
        String(gueltigkeitsjahr)
    }

    var regelaltersgrenze: Date = Date()
    var fruehesterAbschlagsfreierBeginn: Date = Date()
    var abweichenderRentenbeginn: Date? = nil
    var nutztAbweichendenRentenbeginn: Bool = false

    init() {
        let beispielGeburtsdatum = Calendar.current.date(byAdding: .year, value: -60, to: Date()) ?? Date()
        self.regelaltersgrenze = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: beispielGeburtsdatum)
        self.fruehesterAbschlagsfreierBeginn = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: beispielGeburtsdatum)
        self.abweichenderRentenbeginn = self.regelaltersgrenze
    }

    func updateRentenParameter(geburtsdatum: Date) {
        let normGeburt = DateHelper.mitternachtStabil(fuer: geburtsdatum)
        let neueRegelaltersgrenze = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: normGeburt)
        let neuerFruehesterAbschlagsfreierBeginn = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: normGeburt)

        self.regelaltersgrenze = neueRegelaltersgrenze
        self.fruehesterAbschlagsfreierBeginn = neuerFruehesterAbschlagsfreierBeginn

        if !nutztAbweichendenRentenbeginn || self.abweichenderRentenbeginn == nil {
            self.abweichenderRentenbeginn = neueRegelaltersgrenze
        }
    }

    @discardableResult
    func aktualisiereGesetzlicheStandardwerteAuf2026FallsNoetig() -> Bool {
        let enthaeltAlteStandardwerte =
            gueltigkeitsjahr < Self.datenstandJahr2026 ||
            abs(rentenwert - 40.79) < 0.001 ||
            abs(durchschnittsentgelt - 50493.0) < 0.001 ||
            abs(beitragsbemessungsgrenze - 96600.0) < 0.001 ||
            abs(steuerfreibetrag - 12096.0) < 0.001 ||
            abs(steuerfreibetrag - 12196.0) < 0.001 ||
            abs(steuerpflichtQuote - 0.835) < 0.0001 ||
            abs(krankenkassenZusatzbeitrag - 0.025) < 0.0001

        guard enthaeltAlteStandardwerte else { return false }

        gueltigkeitsjahr = Self.datenstandJahr2026
        durchschnittsentgelt = Self.durchschnittsentgelt2026
        rentenwert = Self.rentenwertAbJuli2026
        beitragsbemessungsgrenze = Self.beitragsbemessungsgrenze2026
        steuerfreibetrag = Self.grundfreibetrag2026
        steuerpflichtQuote = Self.steuerpflichtQuote2026
        krankenkassenBeitragssatz = Self.krankenkassenBeitragssatz2026
        krankenkassenZusatzbeitrag = Self.krankenkassenZusatzbeitrag2026
        pflegeversicherungsBeitrag = Self.pflegeversicherungsBeitrag2026
        return true
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
        copy.nutztAbweichendenRentenbeginn = self.nutztAbweichendenRentenbeginn
        return copy
    }
}
