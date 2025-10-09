//
//  RentenErgebnis.swift
//  RentenRechner
//
//  Datenmodell für Berechnungsergebnisse der Rentenberechnung
//

import Foundation

struct RentenErgebnis: Codable, Identifiable {
    var id: UUID = UUID()
    let berechnungsdatum: Date
    
    // Grunddaten
    let regelaltersgrenze: Date
    let fruehesterAbschlagsfreierBeginn: Date
    let tatsaechlicherRentenbeginn: Date
    
    // Rentenpunkte
    let aktuelleRentenpunkte: Double
    let zusaetzlicheRentenpunkte: Double
    let gesamtRentenpunkte: Double
    
    // Rentenbeträge
    let theoretischeBruttoRente: Double // Ohne Abschläge
    let abschlagProzent: Double
    let abschlagBetrag: Double
    let tatsaechlicheBruttoRente: Double
    let zusatzrenten: Double
    let gesamtBruttoRente: Double
    let geschaetzteNettoRente: Double
    
    // Neue Abzugsfelder
    let sozialabgabenBetrag: Double
    let steuerBetrag: Double
    let gesamtAbzuege: Double
    
    // Zusatzinformationen
    let jahreVorRegelalter: Double
    let monateVorRegelalter: Int
    let verwendeterRentenwert: Double

    // Transiente (nicht codierte) Referenz auf Settings
    // Wichtig: Nicht in CodingKeys aufnehmen!
    var settings: AppSettings? = nil

    // DEBUG: Transiente Diagnose-Felder (nicht codiert)
    var debugMonateBisRente: Int? = nil
    var debugJahreBisRente: Double? = nil
    var debugJahresbrutto: Double? = nil
    var debugBBGjaehrlich: Double? = nil
    var debugDurchschnittsentgelt: Double? = nil
    var debugCappedBrutto: Double? = nil
    var debugEntgeltpunkteProJahr: Double? = nil
    var debugZusRP: Double? = nil

    // Nur die codierbaren Keys angeben – settings und Debug-Felder sind absichtlich nicht dabei
    enum CodingKeys: String, CodingKey {
        case id, berechnungsdatum,
             regelaltersgrenze, fruehesterAbschlagsfreierBeginn, tatsaechlicherRentenbeginn,
             aktuelleRentenpunkte, zusaetzlicheRentenpunkte, gesamtRentenpunkte,
             theoretischeBruttoRente, abschlagProzent, abschlagBetrag, tatsaechlicheBruttoRente,
             zusatzrenten, gesamtBruttoRente, geschaetzteNettoRente,
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
        
        // Transient speichern (nicht codiert)
        self.settings = appSettings
        
        // Gesetzliche Rente berechnen
        self.theoretischeBruttoRente = self.gesamtRentenpunkte * verwendeterRentenwert
        self.abschlagProzent = abschlagProzent
        self.abschlagBetrag = self.theoretischeBruttoRente * abschlagProzent
        self.tatsaechlicheBruttoRente = self.theoretischeBruttoRente - self.abschlagBetrag
        
        // Zusatzrenten
        self.zusatzrenten = person.gesamtZusatzrente
        self.gesamtBruttoRente = self.tatsaechlicheBruttoRente + self.zusatzrenten
        
        // Für Berechnungen stets mit einem konkreten Settings-Objekt arbeiten
        let s = appSettings ?? AppSettings()
        
        // 1. Sozialabgaben mit dynamischem DRV-Zuschuss:
        //    - KV: hälftiger Anteil des allgemeinen KV-Satzes (DRV zahlt die andere Hälfte)
        //    - Zusatzbeitrag: voll (kein Zuschuss)
        //    - Pflege: voll
        let kvHalb = s.krankenkassenBeitragssatz / 2.0
        let sozialabgabenSatz = kvHalb + s.krankenkassenZusatzbeitrag + s.pflegeversicherungsBeitrag
        let sozialabgaben = self.tatsaechlicheBruttoRente * sozialabgabenSatz
        let renteNachSozialabgaben = self.tatsaechlicheBruttoRente - sozialabgaben
        
        // 2. Steuerpflichtiger Anteil
        let steuerpflichtigerAnteil = renteNachSozialabgaben * s.steuerpflichtQuote
        
        // 3. Steuerfreibetrag (monatlich)
        let monatlicheSteuerfreibetrag = s.steuerfreibetrag / 12.0
        let zuVersteuernderBetrag = max(0, steuerpflichtigerAnteil - monatlicheSteuerfreibetrag)
        
        // 4. Steuer
        let steuerLast = zuVersteuernderBetrag * s.durchschnittlicherSteuersatz
        
        // 5. Nettorente
        let nettoRenteDRV = renteNachSozialabgaben - steuerLast
        self.geschaetzteNettoRente = nettoRenteDRV + self.zusatzrenten
        
        // 6. Abzüge separat speichern
        self.sozialabgabenBetrag = sozialabgaben
        self.steuerBetrag = steuerLast
        self.gesamtAbzuege = sozialabgaben + steuerLast
        
        // Zeitdifferenz
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: tatsaechlicherRentenbeginn, to: regelaltersgrenze)
        self.monateVorRegelalter = max(0, components.month ?? 0)
        self.jahreVorRegelalter = Double(self.monateVorRegelalter) / 12.0
    }
}

// MARK: - Computed Properties
extension RentenErgebnis {
    var istAbschlagsfrei: Bool { abschlagProzent == 0.0 }
    
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
    
    func rentenpunkteProJahr(monatlichesEinkommen: Double) -> Double {
        // Fallback auf typischen Wert, falls settings fehlt
        let entgelt = settings?.durchschnittsentgelt ?? 50_493.0
        return monatlichesEinkommen * 12.0 / entgelt
    }
}

// MARK: - Szenario Vergleiche
extension RentenErgebnis {
    func vergleichSzenario(neuerRentenbeginn: Date, person: Person, calculator: RentenCalculator) -> RentenErgebnis {
        let tempSettings = calculator.appSettings.copy()
        tempSettings.abweichenderRentenbeginn = neuerRentenbeginn
        return calculator.berechneRente(fuer: person, appSettings: tempSettings)
    }
    
    func unterschiedZu(_ anderes: RentenErgebnis) -> RentenVergleich {
        RentenVergleich(
            urspruenglicheRente: self.gesamtBruttoRente,
            neueRente: anderes.gesamtBruttoRente,
            unterschiedMonatlich: anderes.gesamtBruttoRente - self.gesamtBruttoRente,
            unterschiedJaehrlich: (anderes.gesamtBruttoRente - self.gesamtBruttoRente) * 12.0,
            abschlagUnterschied: anderes.abschlagProzent - self.abschlagProzent
        )
    }
}

// MARK: - Vergleichsstruktur
struct RentenVergleich {
    let urspruenglicheRente: Double
    let neueRente: Double
    let unterschiedMonatlich: Double
    let unterschiedJaehrlich: Double
    let abschlagUnterschied: Double
    
    var istBesser: Bool { unterschiedMonatlich > 0 }
    
    var unterschiedFormatted: String {
        let p = unterschiedMonatlich >= 0 ? "+" : ""
        return "\(p)\(String(format: "%.2f", unterschiedMonatlich))€"
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
            "zusatzrenten": String(format: "%.2f€", zusatzrenten),
            "gesamtBruttoRente": String(format: "%.2f€", gesamtBruttoRente),
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
        // Wenn Settings fehlen (z. B. nach Decoding), Jahr sinnvoll ableiten:
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
        r += "\nTatsächliche Bruttorente: \(String(format: "%.2f€", tatsaechlicheBruttoRente))"
        r += "\nSumme Abzüge: -\(String(format: "%.2f€", gesamtAbzuege))"
        if zusatzrenten > 0 {
            r += "\n➕ Zusatzrenten: \(String(format: "%.2f€", zusatzrenten))"
        }
        r += "\n\n💰 NETTOGESAMTRENTE: \(String(format: "%.2f€", geschaetzteNettoRente))"
        
        r += """
        
        ⚖️ RECHTLICHE HINWEISE
        Diese Berechnung ist unverbindlich und basiert auf den
        Werten von \(jahr) bzw. den von Ihnen eingegebenen Werten. 
        Für eine verbindliche Auskunft wenden Sie sich bitte
        an die Deutsche Rentenversicherung.
        
        Erstellt mit RentenRechner Deutschland
        """
        return r
    }
}
