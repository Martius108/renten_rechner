//
//  RentenCalculator.swift
//  RentenRechner
//
//  Hauptberechnungslogik für deutsche Rentenberechnung
//

import Foundation

class RentenCalculator {
    
    // MARK: - Properties
    
    /// AppSettings für alle Berechnungen (Rentenwerte, Steuer- und Sozialabgaben)
    var appSettings: AppSettings
    
    // MARK: - Initializer
    
    init(appSettings: AppSettings? = nil) {
        self.appSettings = appSettings ?? AppSettings()
    }
    
    // MARK: - Hauptberechnung
    
    /// Berechnet die Rente für eine Person basierend auf den eingegebenen Daten
    /// - Parameters:
    ///   - person: Die Person mit allen Eingabedaten
    ///   - appSettings: Optionale AppSettings für Steuer- und Sozialabgaben (überschreibt Instanz-Settings)
    /// - Returns: Detailliertes Berechnungsergebnis
    func berechneRente(
        fuer person: Person,
        appSettings: AppSettings? = nil
    ) -> RentenErgebnis {
        
        // 1. Validierung
        guard person.isValid else {
            fatalError("Person-Daten sind nicht valide. Validierung sollte vor Berechnung erfolgen.")
        }
        
        // 2. Regelaltersgrenze und frühester abschlagsfreier Beginn aus AppSettings
        let s = appSettings ?? self.appSettings
        let regelaltersgrenze = s.regelaltersgrenze
        let fruehesterAbschlagsfreierBeginn = s.fruehesterAbschlagsfreierBeginn
        
        // Normiere auf Monatsanfang
        guard let gewuenschterRentenbeginn = s.abweichenderRentenbeginn else {
            fatalError("Abweichender Rentenbeginn ist nicht gesetzt")
        }

        let tatsaechlicherRentenbeginn = DateHelper.naechsterMonatserster(
            ab: DateHelper.mitternachtStabil(fuer: gewuenschterRentenbeginn)
        )
        
        // 4. Berechne Monate/Jahre bis Rentenbeginn
        let heute = DateHelper.ersterTagDesMonats(fuer: DateHelper.mitternachtStabil(fuer: Date()))
        let monateBisRente = max(0, DateHelper.monateZwischen(startDatum: heute, endDatum: tatsaechlicherRentenbeginn, includeCurrentPartialMonth: true))
        let jahreBisRente = Double(monateBisRente) / 12.0
        
        // 5. Zusatz-EP mit aktuellen Zeitwerten
        let zusRes = berechneZusaetzlicheRentenpunkteMitFestenZeitwerten(
            fuer: person,
            monate: monateBisRente,
            jahre: jahreBisRente,
            settings: s
        )
        
        // 6. Abschlag
        let abschlagProzent = berechneAbschlag(
            gewuenschterBeginn: tatsaechlicherRentenbeginn,
            regelaltersgrenze: regelaltersgrenze,
            fruehesterAbschlagsfreierBeginn: fruehesterAbschlagsfreierBeginn
        )
        
        // 7. Ergebnis
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
        
        // 8. Debug
        result.debugMonateBisRente = zusRes.monateBisRente
        result.debugJahreBisRente = zusRes.jahreBisRente
        result.debugJahresbrutto = zusRes.jahresbrutto
        result.debugBBGjaehrlich = zusRes.bbgJahr
        result.debugDurchschnittsentgelt = zusRes.durchschnittsentgelt
        result.debugCappedBrutto = zusRes.cappedBrutto
        result.debugEntgeltpunkteProJahr = zusRes.epProJahr
        result.debugZusRP = zusRes.zusaetzlicheRP
        
        print("[berechneRente] Monate bis Rente: \(zusRes.monateBisRente), Jahre bis Rente: \(zusRes.jahreBisRente)")
        print("[berechneRente] tatsaechlicherRentenbeginn: \(tatsaechlicherRentenbeginn)")
        
        return result
    }
    
    // MARK: - Rentenpunkte Berechnungen
    
    /// Berechnet Rentenpunkte pro Jahr aus dem Jahresbruttoeinkommen
    /// Formel: Entgeltpunkte = Jahreseinkommen / Durchschnittsentgelt (aktuelles Jahr)
    /// - Parameters:
    ///   - jahreseinkommen: Jahresbruttoeinkommen
    ///   - settings: Optionale AppSettings (nutzt Instanz-Settings wenn nicht angegeben)
    /// - Returns: Rentenpunkte pro Jahr
    func berechneRentenpunkteProJahr(jahreseinkommen: Double, settings: AppSettings? = nil) -> Double {
        let s = settings ?? self.appSettings
        guard s.durchschnittsentgelt > 0 else { return 0 }
        
        // Berücksichtige Beitragsbemessungsgrenze
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
    
    // MARK: - Abschlag Berechnungen
    
    private func berechneAbschlag(
        gewuenschterBeginn: Date,
        regelaltersgrenze: Date,
        fruehesterAbschlagsfreierBeginn: Date
    ) -> Double {
        
        guard gewuenschterBeginn < regelaltersgrenze else {
            return 0.0
        }
        if gewuenschterBeginn >= fruehesterAbschlagsfreierBeginn {
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
    
    // MARK: - Szenario Berechnungen
    
    func berechneSzenarien(fuer person: Person) -> [RentenSzenario] {
        var szenarien: [RentenSzenario] = []
        
        let normGeburt = DateHelper.mitternachtStabil(fuer: person.geburtsdatum)
        
        let regelaltersgrenze = appSettings.regelaltersgrenze
        let fruehesterAbschlagsfreierBeginn = appSettings.fruehesterAbschlagsfreierBeginn
        
        // Szenario 1: Regelaltersgrenze
        let regelszenario = berechneRente(fuer: person, appSettings: appSettings)
        szenarien.append(RentenSzenario(
            name: "Regelaltersgrenze",
            beschreibung: "Pünktlich zur gesetzlichen Regelaltersgrenze",
            ergebnis: regelszenario,
            empfehlung: .neutral
        ))
        
        // Szenario 2: Frühester abschlagsfreier Beginn (45 Jahre)
        if fruehesterAbschlagsfreierBeginn < regelaltersgrenze {
            let tempSettings = appSettings
            tempSettings.abweichenderRentenbeginn = fruehesterAbschlagsfreierBeginn
            let fruehszenario = berechneRente(fuer: person, appSettings: tempSettings)
            szenarien.append(RentenSzenario(
                name: "Abschlagsfrei früher",
                beschreibung: "Frühester Beginn ohne Abschläge (45 Beitragsjahre vorausgesetzt)",
                ergebnis: fruehszenario,
                empfehlung: .positiv
            ))
        }
        
        // Szenario 3: Mit 63 Jahren (falls möglich)
        if let alter63 = DateHelper.addiere(jahre: 63, zu: normGeburt) {
            if alter63 > DateHelper.mitternachtStabil(fuer: Date()) && alter63 > fruehesterAbschlagsfreierBeginn {
                let tempSettings = appSettings
                tempSettings.abweichenderRentenbeginn = DateHelper.naechsterMonatserster(ab: alter63)
                let szenario63 = berechneRente(fuer: person, appSettings: tempSettings)
                szenarien.append(RentenSzenario(
                    name: "Mit 63 Jahren",
                    beschreibung: "Rentenbeginn mit 63 Jahren (mit Abschlägen)",
                    ergebnis: szenario63,
                    empfehlung: .negativ
                ))
            }
        }
        
        // Szenario 4: Ein Jahr nach Regelaltersgrenze
        if let einJahrSpaeter = DateHelper.addiere(jahre: 1, zu: regelaltersgrenze) {
            let tempSettings = appSettings
            tempSettings.abweichenderRentenbeginn = DateHelper.naechsterMonatserster(ab: einJahrSpaeter)
            let spaeterSzenario = berechneRente(fuer: person, appSettings: tempSettings)
            szenarien.append(RentenSzenario(
                name: "Ein Jahr später",
                beschreibung: "Rentenbeginn ein Jahr nach Regelaltersgrenze",
                ergebnis: spaeterSzenario,
                empfehlung: .positiv
            ))
        }
        
        return szenarien
    }
    
    // MARK: - Hilfsfunktionen
    
    func berechneErforderlichesEinkommen(fuer rentenpunkte: Double) -> Double {
        return rentenpunkte * appSettings.durchschnittsentgelt
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

// MARK: - Extensions für bessere Usability

extension RentenCalculator {
    
    func schnellberechnung(fuer person: Person) -> Double {
        let ergebnis = berechneRente(fuer: person)
        return ergebnis.tatsaechlicheBruttoRente
    }
    
    func einflussGehaltsErhoehung(person: Person, neuesEinkommen: Double) -> Double {
        let urspruenglicheRente = schnellberechnung(fuer: person)
        
        let personMitErhoehung = person
        personMitErhoehung.monatlichesEinkommen = neuesEinkommen
        let neueRente = schnellberechnung(fuer: personMitErhoehung)
        
        return neueRente - urspruenglicheRente
    }
}
