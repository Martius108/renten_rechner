//
//  RentenCalculator.swift
//  RentenRechner
//
//

import Foundation

class RentenCalculator {
    

    

    var appSettings: AppSettings
    

    
    init(appSettings: AppSettings? = nil) {
        self.appSettings = appSettings ?? AppSettings()
    }
    

    





    func berechneRente(
        fuer person: Person,
        appSettings: AppSettings? = nil
    ) -> RentenErgebnis {
        
        guard person.isValid else {
            return RentenErgebnis.empty(for: person, appSettings: appSettings ?? self.appSettings)
        }
        
        let s = appSettings ?? self.appSettings
        let regelaltersgrenze = s.regelaltersgrenze
        let fruehesterAbschlagsfreierBeginn = s.fruehesterAbschlagsfreierBeginn
        
        guard let gewuenschterRentenbeginn = s.abweichenderRentenbeginn else {
            return RentenErgebnis.empty(for: person, appSettings: s)
        }

        let tatsaechlicherRentenbeginn = DateHelper.naechsterMonatserster(
            ab: DateHelper.mitternachtStabil(fuer: gewuenschterRentenbeginn)
        )
        
        let standMonat = DateHelper.ersterTagDesMonats(fuer: person.rentenpunkteStand)
        let beitragsbeginn = DateHelper.stableCalendar.date(byAdding: .month, value: 1, to: standMonat) ?? standMonat
        let monateBisRente = max(0, DateHelper.monateZwischen(
            startDatum: beitragsbeginn,
            endDatum: tatsaechlicherRentenbeginn
        ))
        let jahreBisRente = Double(monateBisRente) / 12.0
        
        let zusRes = berechneZusaetzlicheRentenpunkteMitFestenZeitwerten(
            fuer: person,
            monate: monateBisRente,
            jahre: jahreBisRente,
            settings: s
        )
        
        let abschlagProzent = berechneAbschlag(
            gewuenschterBeginn: tatsaechlicherRentenbeginn,
            regelaltersgrenze: regelaltersgrenze,
            fruehesterAbschlagsfreierBeginn: fruehesterAbschlagsfreierBeginn,
            erfuelltWartezeit45Jahre: person.erfuelltWartezeit45Jahre
        )
        
        var result = RentenErgebnis(
            person: person,
            regelaltersgrenze: regelaltersgrenze,
            fruehesterAbschlagsfreierBeginn: fruehesterAbschlagsfreierBeginn,
            tatsaechlicherRentenbeginn: tatsaechlicherRentenbeginn,
            aktuelleRentenpunkte: person.aktuelleRentenpunkte,
            zusaetzlicheRentenpunkte: zusRes.zusaetzlicheRP,
            abschlagProzent: abschlagProzent,
            verwendeterRentenwert: s.rentenwert,
            appSettings: s
        )
        
        result.debugMonateBisRente = zusRes.monateBisRente
        result.debugJahreBisRente = zusRes.jahreBisRente
        result.debugJahresbrutto = zusRes.jahresbrutto
        result.debugBBGjaehrlich = zusRes.bbgJahr
        result.debugDurchschnittsentgelt = zusRes.durchschnittsentgelt
        result.debugCappedBrutto = zusRes.cappedBrutto
        result.debugEntgeltpunkteProJahr = zusRes.epProJahr
        result.debugZusRP = zusRes.zusaetzlicheRP
        
        return result
    }
    

    






    func berechneRentenpunkteProJahr(jahreseinkommen: Double, settings: AppSettings? = nil) -> Double {
        let s = settings ?? self.appSettings
        guard s.durchschnittsentgelt > 0 else { return 0 }
        
        let bbgJahr = s.beitragsbemessungsgrenze
        let cappedEinkommen = min(jahreseinkommen, bbgJahr)
        
        return cappedEinkommen / s.durchschnittsentgelt
    }
    
    private struct ZusatzRPResult {
        let zusaetzlicheRP: Double
        let monateBisRente: Int
        let jahreBisRente: Double
        let jahresbrutto: Double
        let bbgJahr: Double
        let durchschnittsentgelt: Double
        let cappedBrutto: Double
        let epProJahr: Double
    }
    
    private func berechneZusaetzlicheRentenpunkteMitFestenZeitwerten(
        fuer person: Person,
        monate: Int,
        jahre: Double,
        settings s: AppSettings
    ) -> ZusatzRPResult {
        let safeMonate = max(0, monate)
        let safeJahre = max(0.0, jahre)
        
        let jahresbrutto = person.monatlichesEinkommen * 12.0
        let bbgJahr = s.beitragsbemessungsgrenze
        let durch = s.durchschnittsentgelt
        let capped = min(jahresbrutto, bbgJahr)
        
        let epProJahr = durch > 0 ? (capped / durch) : 0
        let zrp = epProJahr * safeJahre
        
        return ZusatzRPResult(
            zusaetzlicheRP: zrp,
            monateBisRente: safeMonate,
            jahreBisRente: safeJahre,
            jahresbrutto: jahresbrutto,
            bbgJahr: bbgJahr,
            durchschnittsentgelt: durch,
            cappedBrutto: capped,
            epProJahr: epProJahr
        )
    }
    

    
    private func berechneAbschlag(
        gewuenschterBeginn: Date,
        regelaltersgrenze: Date,
        fruehesterAbschlagsfreierBeginn: Date,
        erfuelltWartezeit45Jahre: Bool
    ) -> Double {
        
        guard gewuenschterBeginn < regelaltersgrenze else {
            return 0.0
        }
        if erfuelltWartezeit45Jahre && gewuenschterBeginn >= fruehesterAbschlagsfreierBeginn {
            return 0.0
        }
        
        let monateVorRegelalter = DateHelper.monateZwischen(
            startDatum: gewuenschterBeginn,
            endDatum: regelaltersgrenze,
            includeCurrentPartialMonth: false
        )
        let relevanteMonateVorRegelalter = min(monateVorRegelalter, RentenKonstanten.maxAbschlagMonate)
        let abschlag = Double(relevanteMonateVorRegelalter) * RentenKonstanten.abschlagProMonat
        return min(abschlag, RentenKonstanten.maxAbschlag)
    }
    

    
    func berechneSzenarien(fuer person: Person) -> [RentenSzenario] {
        var szenarien: [RentenSzenario] = []
        
        let normGeburt = DateHelper.mitternachtStabil(fuer: person.geburtsdatum)
        
        let regelaltersgrenze = appSettings.regelaltersgrenze
        let fruehesterAbschlagsfreierBeginn = appSettings.fruehesterAbschlagsfreierBeginn
        let aktuellerBeginn = appSettings.abweichenderRentenbeginn ?? regelaltersgrenze
        
        func normalisierterBeginn(_ date: Date) -> Date {
            DateHelper.naechsterMonatserster(ab: DateHelper.mitternachtStabil(fuer: date))
        }
        
        func enthaeltSzenario(fuer rentenbeginn: Date) -> Bool {
            let normalisiert = normalisierterBeginn(rentenbeginn)
            return szenarien.contains {
                normalisierterBeginn($0.ergebnis.tatsaechlicherRentenbeginn) == normalisiert
            }
        }
        
        func szenarioHinzufuegen(
            name: String,
            beschreibung: String,
            rentenbeginn: Date,
            empfehlung: SzenarioEmpfehlung
        ) {
            guard !enthaeltSzenario(fuer: rentenbeginn) else { return }
            let tempSettings = appSettings.copy()
            tempSettings.abweichenderRentenbeginn = rentenbeginn
            let ergebnis = berechneRente(fuer: person, appSettings: tempSettings)
            szenarien.append(RentenSzenario(
                name: name,
                beschreibung: beschreibung,
                ergebnis: ergebnis,
                empfehlung: empfehlung
            ))
        }
        
        szenarioHinzufuegen(
            name: "Aktuelle Auswahl",
            beschreibung: "Der aktuell gewählte Rentenbeginn",
            rentenbeginn: aktuellerBeginn,
            empfehlung: .neutral
        )
        
        szenarioHinzufuegen(
            name: "Regelaltersgrenze",
            beschreibung: "Pünktlich zur gesetzlichen Regelaltersgrenze",
            rentenbeginn: regelaltersgrenze,
            empfehlung: .neutral
        )
        
        if fruehesterAbschlagsfreierBeginn < regelaltersgrenze {
            szenarioHinzufuegen(
                name: "Früher möglich (45 Jahre)",
                beschreibung: "Rechnerisch ohne Abschlag möglich - nur bei erfüllter 45-jähriger Wartezeit",
                rentenbeginn: fruehesterAbschlagsfreierBeginn,
                empfehlung: .neutral
            )
        }
        
        if let alter63 = DateHelper.addiere(jahre: 63, zu: normGeburt) {
            if alter63 > DateHelper.mitternachtStabil(fuer: Date()) {
                szenarioHinzufuegen(
                    name: "Mit 63 Jahren",
                    beschreibung: "Rentenbeginn mit 63 Jahren (mit Abschlägen)",
                    rentenbeginn: alter63,
                    empfehlung: .negativ
                )
            }
        }
        
        if let einJahrSpaeter = DateHelper.addiere(jahre: 1, zu: regelaltersgrenze) {
            szenarioHinzufuegen(
                name: "Ein Jahr später",
                beschreibung: "Rentenbeginn ein Jahr nach Regelaltersgrenze",
                rentenbeginn: einJahrSpaeter,
                empfehlung: .positiv
            )
        }
        
        return szenarien
    }
    

    
    func validiereRentenbeginn(datum: Date, geburtsdatum: Date) -> RentenbeginnValidierung {
        let cal = DateHelper.stableCalendar
        let alter = cal.dateComponents([.year], from: DateHelper.mitternachtStabil(fuer: geburtsdatum), to: DateHelper.mitternachtStabil(fuer: datum)).year ?? 0
        
        if alter < 60 {
            return RentenbeginnValidierung(
                istGueltig: false,
                warnung: "Rentenbeginn vor dem 60. Lebensjahr ist nicht möglich"
            )
        }
        
        if alter < 63 {
            return RentenbeginnValidierung(
                istGueltig: true,
                warnung: "Sehr früher Rentenbeginn. Prüfen Sie die Voraussetzungen."
            )
        }
        
        return RentenbeginnValidierung(istGueltig: true, warnung: nil)
    }
}

// MARK: - Hilfstrukturen

struct RentenSzenario {
    let name: String
    let beschreibung: String
    let ergebnis: RentenErgebnis
    let empfehlung: SzenarioEmpfehlung
}

enum SzenarioEmpfehlung {
    case positiv
    case neutral
    case negativ
    
    var farbe: String {
        switch self {
        case .positiv: return "green"
        case .neutral: return "blue"
        case .negativ: return "orange"
        }
    }
    
    var symbol: String {
        switch self {
        case .positiv: return "👍"
        case .neutral: return "ℹ️"
        case .negativ: return "⚠️"
        }
    }
}

struct RentenbeginnValidierung {
    let istGueltig: Bool
    let warnung: String?
}
