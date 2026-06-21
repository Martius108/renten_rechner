import XCTest
@testable import RentenRechner

final class RentenCalculatorTests: XCTestCase {
    func testGueltigkeitsjahrIstManuellGepflegterDatenstand() {
        XCTAssertEqual(AppSettings().gueltigkeitsjahr, 2026)
    }

    func testDefaultWerteEntsprechenDatenstand2026() {
        let settings = AppSettings()

        XCTAssertEqual(settings.durchschnittsentgelt, 51_944, accuracy: 0.01)
        XCTAssertEqual(settings.rentenwert, 42.52, accuracy: 0.01)
        XCTAssertEqual(settings.beitragsbemessungsgrenze, 101_400, accuracy: 0.01)
        XCTAssertEqual(settings.steuerfreibetrag, 12_348, accuracy: 0.01)
        XCTAssertEqual(settings.steuerpflichtQuote, 0.84, accuracy: 0.0001)
        XCTAssertEqual(settings.krankenkassenBeitragssatz, 0.146, accuracy: 0.0001)
        XCTAssertEqual(settings.krankenkassenZusatzbeitrag, 0.029, accuracy: 0.0001)
        XCTAssertEqual(settings.pflegeversicherungsBeitrag, 0.036, accuracy: 0.0001)
    }

    func testGespeicherteAlteStandardwerteWerdenAuf2026Aktualisiert() {
        let settings = AppSettings()
        settings.gueltigkeitsjahr = 2026
        settings.durchschnittsentgelt = 51_944
        settings.rentenwert = 40.79
        settings.beitragsbemessungsgrenze = 101_400
        settings.steuerfreibetrag = 12_196
        settings.steuerpflichtQuote = 0.835
        settings.krankenkassenZusatzbeitrag = 0.025

        XCTAssertTrue(settings.aktualisiereGesetzlicheStandardwerteAuf2026FallsNoetig())
        XCTAssertEqual(settings.rentenwert, 42.52, accuracy: 0.01)
        XCTAssertEqual(settings.steuerfreibetrag, 12_348, accuracy: 0.01)
        XCTAssertEqual(settings.steuerpflichtQuote, 0.84, accuracy: 0.0001)
        XCTAssertEqual(settings.krankenkassenZusatzbeitrag, 0.029, accuracy: 0.0001)
    }

    func testAktuelleOderManuellAbweichendeWerteWerdenNichtStaendigUeberschrieben() {
        let settings = AppSettings()
        settings.rentenwert = 42.60

        XCTAssertFalse(settings.aktualisiereGesetzlicheStandardwerteAuf2026FallsNoetig())
        XCTAssertEqual(settings.rentenwert, 42.60, accuracy: 0.01)
    }

    @MainActor
    func testDeutscheAnzeigeVerwendetKeineTausenderpunkte() {
        let settings = AppSettings()
        let viewModel = RentenrechnerViewModel()

        XCTAssertEqual(settings.gueltigkeitsjahrText, "2026")
        XCTAssertFalse(viewModel.formatCurrency(101_400).contains("101.400"))
        XCTAssertTrue(viewModel.formatCurrency(101_400).contains("101400"))
    }

    @MainActor
    func testStilleBerechnungErzeugtErgebnisOhneTabwechsel() throws {
        let viewModel = RentenrechnerViewModel()
        let settings = AppSettings()
        let geburtsdatum = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 15))
        settings.updateRentenParameter(geburtsdatum: geburtsdatum)
        viewModel.appSettings = settings
        viewModel.person = Person(
            geburtsdatum: geburtsdatum,
            monatlichesEinkommen: 3_000,
            aktuelleRentenpunkte: 20
        )
        viewModel.selectedTab = 0

        viewModel.aktualisiereBerechnungOhneNavigation()

        XCTAssertNotNil(viewModel.ergebnis)
        XCTAssertFalse(viewModel.szenarien.isEmpty)
        XCTAssertEqual(viewModel.selectedTab, 0)
    }

    func testRentenpunkteProJahrWerdenAnBeitragsbemessungsgrenzeGedeckelt() {
        let settings = AppSettings()
        settings.durchschnittsentgelt = 50_000
        settings.beitragsbemessungsgrenze = 90_000

        let calculator = RentenCalculator(appSettings: settings)

        XCTAssertEqual(
            calculator.berechneRentenpunkteProJahr(jahreseinkommen: 120_000),
            1.8,
            accuracy: 0.000_001
        )
    }

    func testFruehesterAbschlagsfreierBeginnFuerJahrgang1963IstGeburtstagsabhaengig() throws {
        let geburtsdatum = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1963, monat: 7, tag: 20))

        let rentenbeginn = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: geburtsdatum)

        XCTAssertEqual(
            rentenbeginn,
            try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2028, monat: 6, tag: 1))
        )
    }

    func testRegelaltersgrenzeAbJahrgang1964LiegtBei67Jahren() throws {
        let geburtsdatum = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 15))

        let rentenbeginn = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: geburtsdatum)

        XCTAssertEqual(
            rentenbeginn,
            try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 2, tag: 1))
        )
    }

    func testRentenErgebnisBerechnetSozialabgabenSteuerUndNettoNachSettings() throws {
        let settings = AppSettings()
        settings.krankenkassenBeitragssatz = 0.146
        settings.krankenkassenZusatzbeitrag = 0.025
        settings.pflegeversicherungsBeitrag = 0.036
        settings.steuerpflichtQuote = 1.0
        settings.steuerfreibetrag = 0
        settings.durchschnittlicherSteuersatz = 0.10

        let person = Person(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 1)),
            aktuelleRentenpunkte: 10
        )

        let ergebnis = RentenErgebnis(
            person: person,
            regelaltersgrenze: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 1, tag: 1)),
            fruehesterAbschlagsfreierBeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 1, tag: 1)),
            tatsaechlicherRentenbeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 1, tag: 1)),
            aktuelleRentenpunkte: 10,
            zusaetzlicheRentenpunkte: 0,
            abschlagProzent: 0,
            verwendeterRentenwert: 40,
            appSettings: settings
        )

        XCTAssertEqual(ergebnis.tatsaechlicheBruttoRente, 400, accuracy: 0.001)
        XCTAssertEqual(ergebnis.sozialabgabenBetrag, 48.6, accuracy: 0.001)
        XCTAssertEqual(ergebnis.steuerBetrag, 35.14, accuracy: 0.001)
        XCTAssertEqual(ergebnis.geschaetzteNettoRente, 316.26, accuracy: 0.001)
    }

    func testZusatzUndHinterbliebenenrentenWerdenNichtMitgerechnet() throws {
        let person = Person(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 1)),
            aktuelleRentenpunkte: 10
        )

        let ergebnis = RentenErgebnis(
            person: person,
            regelaltersgrenze: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 1, tag: 1)),
            fruehesterAbschlagsfreierBeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 1, tag: 1)),
            tatsaechlicherRentenbeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 1, tag: 1)),
            aktuelleRentenpunkte: 10,
            zusaetzlicheRentenpunkte: 0,
            abschlagProzent: 0,
            verwendeterRentenwert: 40,
            appSettings: AppSettings()
        )

        XCTAssertEqual(ergebnis.tatsaechlicheBruttoRente, 400, accuracy: 0.001)
    }

    func testSpaetererRentenbeginnErhaeltZuschlag() throws {
        let person = Person(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 1)),
            aktuelleRentenpunkte: 10
        )

        let ergebnis = RentenErgebnis(
            person: person,
            regelaltersgrenze: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 1, tag: 1)),
            fruehesterAbschlagsfreierBeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 1, tag: 1)),
            tatsaechlicherRentenbeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2032, monat: 1, tag: 1)),
            aktuelleRentenpunkte: 10,
            zusaetzlicheRentenpunkte: 0,
            abschlagProzent: 0,
            verwendeterRentenwert: 40,
            appSettings: AppSettings()
        )

        XCTAssertEqual(ergebnis.zuschlagProzent, 0.06, accuracy: 0.000_001)
        XCTAssertEqual(ergebnis.zuschlagBetrag, 24, accuracy: 0.001)
        XCTAssertEqual(ergebnis.tatsaechlicheBruttoRente, 424, accuracy: 0.001)
    }

    func testSzenarienVeraendernDenGespeichertenRentenbeginnNicht() throws {
        let settings = AppSettings()
        let urspruenglicherBeginn = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2030, monat: 1, tag: 1))
        settings.regelaltersgrenze = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 2, tag: 1))
        settings.fruehesterAbschlagsfreierBeginn = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 2, tag: 1))
        settings.abweichenderRentenbeginn = urspruenglicherBeginn

        let person = Person(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 15)),
            monatlichesEinkommen: 3_000,
            aktuelleRentenpunkte: 20
        )

        _ = RentenCalculator(appSettings: settings).berechneSzenarien(fuer: person)

        XCTAssertEqual(settings.abweichenderRentenbeginn, urspruenglicherBeginn)
    }

    func testAktiverAbweichenderRentenbeginnBleibtBeiParameterUpdateErhalten() throws {
        let settings = AppSettings()
        let gespeicherterBeginn = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 1, tag: 1))
        settings.nutztAbweichendenRentenbeginn = true
        settings.abweichenderRentenbeginn = gespeicherterBeginn

        settings.updateRentenParameter(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 15))
        )

        XCTAssertTrue(settings.nutztAbweichendenRentenbeginn)
        XCTAssertEqual(settings.abweichenderRentenbeginn, gespeicherterBeginn)
    }

    func testInaktiverAbweichenderRentenbeginnFolgtDerRegelaltersgrenze() throws {
        let settings = AppSettings()
        settings.nutztAbweichendenRentenbeginn = false
        settings.abweichenderRentenbeginn = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 1, tag: 1))

        settings.updateRentenParameter(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 15))
        )

        XCTAssertEqual(settings.abweichenderRentenbeginn, settings.regelaltersgrenze)
    }

    func testSzenarienZeigenAktuellGewaehltOptionZuerst() throws {
        let settings = AppSettings()
        let gewaehlterBeginn = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2030, monat: 7, tag: 1))
        settings.regelaltersgrenze = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 2, tag: 1))
        settings.fruehesterAbschlagsfreierBeginn = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 2, tag: 1))
        settings.abweichenderRentenbeginn = gewaehlterBeginn

        let person = Person(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 15)),
            monatlichesEinkommen: 3_000,
            aktuelleRentenpunkte: 20
        )

        let szenarien = RentenCalculator(appSettings: settings).berechneSzenarien(fuer: person)

        XCTAssertEqual(szenarien.first?.name, "Aktuelle Auswahl")
        XCTAssertEqual(szenarien.first?.ergebnis.tatsaechlicherRentenbeginn, gewaehlterBeginn)
    }

    func testSzenarienDuplizierenAktuelleRegelaltersgrenzeNicht() throws {
        let settings = AppSettings()
        let regelaltersgrenze = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 2, tag: 1))
        settings.regelaltersgrenze = regelaltersgrenze
        settings.fruehesterAbschlagsfreierBeginn = try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 2, tag: 1))
        settings.abweichenderRentenbeginn = regelaltersgrenze

        let person = Person(
            geburtsdatum: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 1964, monat: 1, tag: 15)),
            monatlichesEinkommen: 3_000,
            aktuelleRentenpunkte: 20
        )

        let szenarien = RentenCalculator(appSettings: settings).berechneSzenarien(fuer: person)
        let regelaltersSzenarien = szenarien.filter {
            $0.ergebnis.tatsaechlicherRentenbeginn == regelaltersgrenze
        }

        XCTAssertEqual(regelaltersSzenarien.count, 1)
    }

    func testRentenErgebnisCodiertKeineTransientenSettingsOderDebugWerte() throws {
        let person = Person(aktuelleRentenpunkte: 1)
        var ergebnis = RentenErgebnis(
            person: person,
            regelaltersgrenze: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 1, tag: 1)),
            fruehesterAbschlagsfreierBeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2029, monat: 1, tag: 1)),
            tatsaechlicherRentenbeginn: try XCTUnwrap(DateHelper.erstelleDatum(jahr: 2031, monat: 1, tag: 1)),
            aktuelleRentenpunkte: 1,
            zusaetzlicheRentenpunkte: 0,
            abschlagProzent: 0,
            verwendeterRentenwert: 40,
            appSettings: AppSettings()
        )
        ergebnis.debugZusRP = 1.23

        let encoded = try JSONEncoder().encode(ergebnis)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertFalse(json.contains("settings"))
        XCTAssertFalse(json.contains("debugZusRP"))
        XCTAssertTrue(json.contains("gesamtRentenpunkte"))
    }
}
