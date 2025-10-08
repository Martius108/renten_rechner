//
//  DateHelper.swift
//  RentenRechner
//
//  Hilfsfunktionen für Datumsberechnungen in der Renten-App
//

import Foundation

class DateHelper {

    // MARK: - Stabiler Kalender (feste deutsche Zeitzone)
    // Wir nutzen einen festen gregorianischen Kalender mit deutscher Locale und Zeitzone
    static var stableCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "de_DE")
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")! // Deutsche Zeitzone
        return cal
    }()

    // MARK: - Formatierung

    /// Standard-Datumsformatter für deutsche Lokalisierung
    static let germanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Langer Datumsformatter für ausführliche Darstellung
    static let longGermanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    /// Monats-Jahr Formatter
    static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// Jahr Formatter
    static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    // MARK: - Datums-Normalisierung

    /// Normalisiert ein Datum auf Mitternacht (00:00) in deutscher Zeitzone
    /// Verhindert Tages-Drift durch Zeitzonen-Konvertierung
    /// - Parameter datum: Zu normalisierendes Datum
    /// - Returns: Datum auf Mitternacht normalisiert (Jahr, Monat, Tag bleiben erhalten)
    static func mitternachtStabil(fuer datum: Date) -> Date {
        let cal = stableCalendar
        let comps = cal.dateComponents([.year, .month, .day], from: datum)
        return cal.date(from: comps) ?? datum
    }

    // MARK: - Altersberechnungen

    static func berechneAlter(geburtsdatum: Date) -> Int {
        let cal = stableCalendar
        let heute = mitternachtStabil(fuer: Date())
        let geburt = mitternachtStabil(fuer: geburtsdatum)
        let components = cal.dateComponents([.year], from: geburt, to: heute)
        return components.year ?? 0
    }

    static func berechneAlter(geburtsdatum: Date, zum stichtag: Date) -> Int {
        let cal = stableCalendar
        let geburt = mitternachtStabil(fuer: geburtsdatum)
        let stich = mitternachtStabil(fuer: stichtag)
        let components = cal.dateComponents([.year], from: geburt, to: stich)
        return components.year ?? 0
    }

    static func berechneGenauesAlter(geburtsdatum: Date) -> (jahre: Int, monate: Int) {
        let cal = stableCalendar
        let heute = mitternachtStabil(fuer: Date())
        let geburt = mitternachtStabil(fuer: geburtsdatum)
        let components = cal.dateComponents([.year, .month], from: geburt, to: heute)
        return (jahre: components.year ?? 0, monate: components.month ?? 0)
    }

    // MARK: - Zeitspannen-Berechnungen

    /// Schnappt ein Datum auf den Monatsanfang (00:00 deutsche Zeit)
    static func ersterTagDesMonats(fuer datum: Date) -> Date {
        let cal = stableCalendar
        let normalized = mitternachtStabil(fuer: datum)
        let comps = cal.dateComponents([.year, .month], from: normalized)
        return cal.date(from: comps) ?? normalized
    }

    /// Nimmt den 1. des nächsten Monats, außer wenn bereits der 1., dann unverändert
    static func naechsterMonatserster(ab datum: Date) -> Date {
        let cal = stableCalendar
        let normalized = mitternachtStabil(fuer: datum)
        let comps = cal.dateComponents([.year, .month, .day], from: normalized)
        let monthStart = ersterTagDesMonats(fuer: normalized)
        if comps.day == 1 {
            return monthStart
        } else {
            return cal.date(byAdding: .month, value: 1, to: monthStart) ?? normalized
        }
    }

    /// Letzter Tag des Monats
    static func letzterTagDesMonats(fuer datum: Date) -> Date {
        let cal = stableCalendar
        let normalized = mitternachtStabil(fuer: datum)
        let start = ersterTagDesMonats(fuer: normalized)
        let nextMonth = cal.date(byAdding: .month, value: 1, to: start)!
        return cal.date(byAdding: .day, value: -1, to: nextMonth)!
    }

    /// Robuste Monatsdifferenz in vollen Monaten.
    /// Beide Daten werden auf Monatsanfang gesnappt, dann Year*12 + Month gerechnet.
    /// - Parameters:
    ///   - startDatum: Startdatum
    ///   - endDatum: Enddatum
    ///   - includeCurrentPartialMonth: Wenn true, wird ab dem nächsten Monat gezählt
    static func monateZwischen(startDatum: Date, endDatum: Date, includeCurrentPartialMonth: Bool = false) -> Int {
        let cal = stableCalendar
        let startNorm = mitternachtStabil(fuer: startDatum)
        let endNorm = mitternachtStabil(fuer: endDatum)
        
        var start = ersterTagDesMonats(fuer: startNorm)
        let end = ersterTagDesMonats(fuer: endNorm)

        if includeCurrentPartialMonth {
            // ab nächstem Monat zählen
            start = cal.date(byAdding: .month, value: 1, to: start) ?? start
        }

        let s = cal.dateComponents([.year, .month], from: start)
        let e = cal.dateComponents([.year, .month], from: end)

        let startTotal = (s.year ?? 0) * 12 + (s.month ?? 0)
        let endTotal = (e.year ?? 0) * 12 + (e.month ?? 0)

        return max(0, endTotal - startTotal)
    }

    static func jahreZwischen(startDatum: Date, endDatum: Date, includeCurrentPartialMonth: Bool = false) -> Double {
        let startNorm = mitternachtStabil(fuer: startDatum)
        let endNorm = mitternachtStabil(fuer: endDatum)
        let monate = monateZwischen(startDatum: startNorm, endDatum: endNorm, includeCurrentPartialMonth: includeCurrentPartialMonth)
        return Double(monate) / 12.0
    }

    /// Arbeitstage (Werktage Mo–Fr)
    static func arbeitstagezwischen(startDatum: Date, endDatum: Date) -> Int {
        let cal = stableCalendar
        var arbeitstage = 0
        var currentDate = mitternachtStabil(fuer: startDatum)
        let end = mitternachtStabil(fuer: endDatum)

        while currentDate <= end {
            let weekday = cal.component(.weekday, from: currentDate)
            // Montag = 2, Freitag = 6
            if weekday >= 2 && weekday <= 6 {
                arbeitstage += 1
            }
            currentDate = cal.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return arbeitstage
    }

    // MARK: - Datums-Manipulationen

    static func addiere(jahre: Int, zu datum: Date) -> Date? {
        let normalized = mitternachtStabil(fuer: datum)
        return stableCalendar.date(byAdding: .year, value: jahre, to: normalized)
    }

    static func addiere(jahre: Int, monate: Int, zu datum: Date) -> Date? {
        let normalized = mitternachtStabil(fuer: datum)
        var comps = DateComponents()
        comps.year = jahre
        comps.month = monate
        return stableCalendar.date(byAdding: comps, to: normalized)
    }

    static func erstelleDatum(jahr: Int, monat: Int, tag: Int) -> Date? {
        var comps = DateComponents()
        comps.year = jahr
        comps.month = monat
        comps.day = tag
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return stableCalendar.date(from: comps)
    }

    // MARK: - Validierungen

    static func istInVergangenheit(_ datum: Date) -> Bool {
        let normalized = mitternachtStabil(fuer: datum)
        let heute = mitternachtStabil(fuer: Date())
        return normalized < heute
    }

    static func istInZukunft(_ datum: Date) -> Bool {
        let normalized = mitternachtStabil(fuer: datum)
        let heute = mitternachtStabil(fuer: Date())
        return normalized > heute
    }

    static func istHeute(_ datum: Date) -> Bool {
        let cal = stableCalendar
        let normalized = mitternachtStabil(fuer: datum)
        let heute = mitternachtStabil(fuer: Date())
        return cal.isDate(normalized, inSameDayAs: heute)
    }

    static func istGueltigesGeburtsdatum(_ geburtsdatum: Date) -> Bool {
        let cal = stableCalendar
        let heute = mitternachtStabil(fuer: Date())
        let geburt = mitternachtStabil(fuer: geburtsdatum)
        let jahr1920 = cal.date(from: DateComponents(year: 1920, month: 1, day: 1))!
        let vor18Jahren = cal.date(byAdding: .year, value: -18, to: heute)!
        return geburt >= jahr1920 && geburt <= vor18Jahren
    }

    // MARK: - Rentenbeginn-Optionen

    static func rentenbeginnOptionen(ab startDatum: Date = Date()) -> [Date] {
        let cal = stableCalendar
        var optionen: [Date] = []
        let normalized = mitternachtStabil(fuer: startDatum)
        let startMonat = ersterTagDesMonats(fuer: normalized)

        for i in 0..<120 {
            if let neuesDatum = cal.date(byAdding: .month, value: i, to: startMonat) {
                optionen.append(neuesDatum)
            }
        }
        return optionen
    }

    // MARK: - Formatierte Ausgaben

    static func relativerZeitString(fuer datum: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        let normalized = mitternachtStabil(fuer: datum)
        let heute = mitternachtStabil(fuer: Date())
        return formatter.localizedString(for: normalized, relativeTo: heute)
    }

    static func formatiereZeitspanne(monate: Int) -> String {
        let jahre = monate / 12
        let verbleibeneMonate = monate % 12

        if jahre == 0 {
            return "\(verbleibeneMonate) Monat\(verbleibeneMonate == 1 ? "" : "e")"
        } else if verbleibeneMonate == 0 {
            return "\(jahre) Jahr\(jahre == 1 ? "" : "e")"
        } else {
            return "\(jahre) Jahr\(jahre == 1 ? "" : "e") \(verbleibeneMonate) Monat\(verbleibeneMonate == 1 ? "" : "e")"
        }
    }

    static func rentenbeginnBeschreibung(datum: Date, geburtsdatum: Date) -> String {
        let datumNorm = mitternachtStabil(fuer: datum)
        let geburtNorm = mitternachtStabil(fuer: geburtsdatum)
        let alter = berechneAlter(geburtsdatum: geburtNorm, zum: datumNorm)
        let datumString = germanDateFormatter.string(from: datumNorm)
        let relativString = relativerZeitString(fuer: datumNorm)
        return "\(datumString) (im Alter von \(alter) Jahren, \(relativString))"
    }
}

// MARK: - Extensions

extension Date {
    var deutscheFormatierung: String {
        DateHelper.germanDateFormatter.string(from: DateHelper.mitternachtStabil(fuer: self))
    }
    var langeDeutscheFormatierung: String {
        DateHelper.longGermanDateFormatter.string(from: DateHelper.mitternachtStabil(fuer: self))
    }
    var monatJahrFormatierung: String {
        DateHelper.monthYearFormatter.string(from: DateHelper.mitternachtStabil(fuer: self))
    }
    var jahrString: String {
        DateHelper.yearFormatter.string(from: DateHelper.mitternachtStabil(fuer: self))
    }
    var istVergangenheit: Bool {
        DateHelper.istInVergangenheit(self)
    }
    var istZukunft: Bool {
        DateHelper.istInZukunft(self)
    }
    var istHeute: Bool {
        DateHelper.istHeute(self)
    }
}

extension Calendar {
    /// Deutsche Kalenderkonfiguration
    static let deutsch: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()
}
