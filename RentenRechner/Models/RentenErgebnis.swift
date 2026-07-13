//
//  RentenErgebnis.swift
//  RentenRechner
//
//

import Foundation

struct RentenErgebnis: Codable, Identifiable {
    var id: UUID = UUID()
    let berechnungsdatum: Date
    
    let regelaltersgrenze: Date
    let fruehesterAbschlagsfreierBeginn: Date
    let tatsaechlicherRentenbeginn: Date
    
    let aktuelleRentenpunkte: Double
    let zusaetzlicheRentenpunkte: Double
    let gesamtRentenpunkte: Double
    
    let theoretischeBruttoRente: Double
    let abschlagProzent: Double
    let abschlagBetrag: Double
    let zuschlagProzent: Double
    let zuschlagBetrag: Double
    let tatsaechlicheBruttoRente: Double
    let geschaetzteNettoRente: Double
    
    let sozialabgabenBetrag: Double
    let steuerBetrag: Double
    let gesamtAbzuege: Double
    
    let jahreVorRegelalter: Double
    let monateVorRegelalter: Int
    let verwendeterRentenwert: Double

    var settings: AppSettings? = nil

    var debugMonateBisRente: Int? = nil
    var debugJahreBisRente: Double? = nil
    var debugJahresbrutto: Double? = nil
    var debugBBGjaehrlich: Double? = nil
    var debugDurchschnittsentgelt: Double? = nil
    var debugCappedBrutto: Double? = nil
    var debugEntgeltpunkteProJahr: Double? = nil
    var debugZusRP: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id, berechnungsdatum,
             regelaltersgrenze, fruehesterAbschlagsfreierBeginn, tatsaechlicherRentenbeginn,
             aktuelleRentenpunkte, zusaetzlicheRentenpunkte, gesamtRentenpunkte,
             theoretischeBruttoRente, abschlagProzent, abschlagBetrag, zuschlagProzent,
             zuschlagBetrag, tatsaechlicheBruttoRente, geschaetzteNettoRente,
             sozialabgabenBetrag, steuerBetrag, gesamtAbzuege,
             jahreVorRegelalter, monateVorRegelalter, verwendeterRentenwert
    }
    
    init(person: Person,
         regelaltersgrenze: Date,
         fruehesterAbschlagsfreierBeginn: Date,
         tatsaechlicherRentenbeginn: Date,
         aktuelleRentenpunkte: Double,
         zusaetzlicheRentenpunkte: Double,
         abschlagProzent: Double,
         verwendeterRentenwert: Double,
         appSettings: AppSettings? = nil) {
        
        self.berechnungsdatum = Date()
        self.regelaltersgrenze = regelaltersgrenze
        self.fruehesterAbschlagsfreierBeginn = fruehesterAbschlagsfreierBeginn
        self.tatsaechlicherRentenbeginn = tatsaechlicherRentenbeginn
        self.aktuelleRentenpunkte = aktuelleRentenpunkte
        self.zusaetzlicheRentenpunkte = zusaetzlicheRentenpunkte
        self.gesamtRentenpunkte = aktuelleRentenpunkte + zusaetzlicheRentenpunkte
        self.verwendeterRentenwert = verwendeterRentenwert
        
        self.settings = appSettings
        
        self.theoretischeBruttoRente = self.gesamtRentenpunkte * verwendeterRentenwert
        self.abschlagProzent = abschlagProzent
        self.abschlagBetrag = self.theoretischeBruttoRente * abschlagProzent

        let monateNachRegelalter = DateHelper.monateZwischen(
            startDatum: regelaltersgrenze,
            endDatum: tatsaechlicherRentenbeginn,
            includeCurrentPartialMonth: false
        )
        self.zuschlagProzent = tatsaechlicherRentenbeginn > regelaltersgrenze
            ? Double(monateNachRegelalter) * 0.005
            : 0.0
        self.zuschlagBetrag = self.theoretischeBruttoRente * self.zuschlagProzent
        self.tatsaechlicheBruttoRente = self.theoretischeBruttoRente - self.abschlagBetrag + self.zuschlagBetrag
        
        let s = appSettings ?? AppSettings()
        
        let kvHalb = s.krankenkassenBeitragssatz / 2.0
        let zusatzHalb = s.krankenkassenZusatzbeitrag / 2.0
        let sozialabgabenSatz = kvHalb + zusatzHalb + s.pflegeversicherungsBeitrag
        let sozialabgaben = self.tatsaechlicheBruttoRente * sozialabgabenSatz
        let renteNachSozialabgaben = self.tatsaechlicheBruttoRente - sozialabgaben
        
        let steuerpflichtigerAnteil = renteNachSozialabgaben * s.steuerpflichtQuote
        
        let monatlicheSteuerfreibetrag = s.steuerfreibetrag / 12.0
        let zuVersteuernderBetrag = max(0, steuerpflichtigerAnteil - monatlicheSteuerfreibetrag)
        
        let steuerLast = zuVersteuernderBetrag * s.durchschnittlicherSteuersatz
        
        let nettoRenteDRV = renteNachSozialabgaben - steuerLast
        self.geschaetzteNettoRente = nettoRenteDRV
        
        self.sozialabgabenBetrag = sozialabgaben
        self.steuerBetrag = steuerLast
        self.gesamtAbzuege = sozialabgaben + steuerLast
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: tatsaechlicherRentenbeginn, to: regelaltersgrenze)
        self.monateVorRegelalter = max(0, components.month ?? 0)
        self.jahreVorRegelalter = Double(self.monateVorRegelalter) / 12.0
    }
}

// MARK: - Computed Properties
extension RentenErgebnis {
    var istAbschlagsfrei: Bool { abschlagProzent == 0.0 }
    var hatZuschlag: Bool { zuschlagProzent > 0.0 }
    
    var rentenbeginnFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: tatsaechlicherRentenbeginn)
    }
    
    var regelalterFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: regelaltersgrenze)
    }
    
    var abschlagFormatted: String {
        String(format: "%.1f%%", abschlagProzent * 100)
    }
    
    func vergleichSzenario(neuerRentenbeginn: Date, person: Person, calculator: RentenCalculator) -> RentenErgebnis {
        let tempSettings = calculator.appSettings.copy()
        tempSettings.abweichenderRentenbeginn = neuerRentenbeginn
        return calculator.berechneRente(fuer: person, appSettings: tempSettings)
    }
}

extension RentenErgebnis {
    static func empty(for person: Person, appSettings: AppSettings) -> RentenErgebnis {
        RentenErgebnis(
            person: person,
            regelaltersgrenze: appSettings.regelaltersgrenze,
            fruehesterAbschlagsfreierBeginn: appSettings.fruehesterAbschlagsfreierBeginn,
            tatsaechlicherRentenbeginn: appSettings.abweichenderRentenbeginn ?? appSettings.regelaltersgrenze,
            aktuelleRentenpunkte: max(0, person.aktuelleRentenpunkte),
            zusaetzlicheRentenpunkte: 0,
            abschlagProzent: 0,
            verwendeterRentenwert: appSettings.rentenwert,
            appSettings: appSettings
        )
    }
}

// MARK: - Export und Sharing
extension RentenErgebnis {
    func alsExportDictionary() -> [String: Any] {
        [
            "berechnungsdatum": berechnungsdatum,
            "rentenbeginn": rentenbeginnFormatted,
            "regelaltersgrenze": regelalterFormatted,
            "gesamtRentenpunkte": String(format: "%.2f", gesamtRentenpunkte),
            "bruttoRenteGesetzlich": String(format: "%.2f€", tatsaechlicheBruttoRente),
            "gesamtAbzuege": String(format: "%.2f€", gesamtAbzuege),
            "nettoRente": String(format: "%.2f€", geschaetzteNettoRente),
            "abschlag": istAbschlagsfrei ? "Kein Abschlag" : abschlagFormatted,
            "monateVorRegelalter": monateVorRegelalter
        ]
    }
    
    func alsTextReport() -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "de_DE")
        let jahr = settings?.gueltigkeitsjahr ?? Calendar.current.component(.year, from: Date())
        
        var r = """
        📊 RENTENBERECHNUNG
        ==================
        
        Berechnet am: \(f.string(from: berechnungsdatum))
        
        🎂 RENTENBEGINN
        Gewählter Rentenbeginn: \(rentenbeginnFormatted)
        Regelaltersgrenze: \(regelalterFormatted)
        \(monateVorRegelalter > 0 ? "⚠️ \(monateVorRegelalter) Monate vor Regelalter" : "✅ Pünktlich zur Regelaltersgrenze")
        
        💰 RENTENPUNKTE
        Bereits erworben: \(String(format: "%.2f", aktuelleRentenpunkte))
        Zusätzlich bis Rentenbeginn: \(String(format: "%.2f", zusaetzlicheRentenpunkte))
        Gesamt: \(String(format: "%.2f", gesamtRentenpunkte))
        
        💵 GESETZLICHE RENTE
        Theoretische Bruttorente: \(String(format: "%.2f€", theoretischeBruttoRente))
        """
        if !istAbschlagsfrei {
            r += "\nAbschlag (\(abschlagFormatted)): -\(String(format: "%.2f€", abschlagBetrag))"
        }
        if hatZuschlag {
            r += "\nZuschlag (\(String(format: "%.1f%%", zuschlagProzent * 100))): +\(String(format: "%.2f€", zuschlagBetrag))"
        }
        r += "\nTatsächliche Bruttorente: \(String(format: "%.2f€", tatsaechlicheBruttoRente))"
        r += "\nSumme Abzüge: -\(String(format: "%.2f€", gesamtAbzuege))"
        r += "\n\n💰 GESCHÄTZTE NETTORENTE: \(String(format: "%.2f€", geschaetzteNettoRente))"
        
        r += """
        
        ⚖️ RECHTLICHE HINWEISE
        Diese Berechnung ist unverbindlich und basiert auf den
        Werten von \(jahr) bzw. den von Ihnen eingegebenen Werten.
        Zusatzrenten, Betriebsrenten, Hinterbliebenenrenten und
        Hinzuverdienste sind nicht enthalten.
        Für eine verbindliche Auskunft wenden Sie sich bitte
        an die Deutsche Rentenversicherung.
        
        Erstellt mit RentenRechner Deutschland
        """
        return r
    }
}
