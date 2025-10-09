//
//  RentenrechnerViewModel.swift
//  RentenRechner
//
//  ViewModel für die Renten-App mit State Management und Berechnungslogik (SwiftData)
//

import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
class RentenrechnerViewModel: ObservableObject {
    
    // MARK: - SwiftData Context
    
    private var modelContext: ModelContext?
    
    // MARK: - Published Properties
    
    @Published var person: Person
    @Published var ergebnis: RentenErgebnis?
    @Published var szenarien: [RentenSzenario] = []
    @Published var isLoading = false
    @Published var fehlerMeldung: String?
    @Published var showingError = false
    @Published var appSettings: AppSettings? = nil
    
    // UI State
    @Published var fruehererRentenbeginnGewuenscht = false
    @Published var showingSzenarien = false
    @Published var selectedTab = 0
    
    // Validierungsstate
    @Published var geburtsdatumFehler: String?
    @Published var einkommenFehler: String?
    @Published var rentenpunkteFehler: String?
    @Published var rentenbeginnFehler: String?
    
    // MARK: - Private Properties
    
    private var calculator: RentenCalculator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public read-only accessor for Views
    var settings: AppSettings {
        appSettings ?? AppSettings()
    }
    
    // MARK: - Hilfs-Property für aktuellen wirksamen Rentenbeginn
    
    var aktuellerRentenbeginn: Date {
        guard fruehererRentenbeginnGewuenscht, let settings = appSettings,
              let rentenbeginn = settings.abweichenderRentenbeginn else {
            return getRegelaltersgrenze()
        }
        return rentenbeginn
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        
        // Initialisiere person mit einem Default-Wert, damit self vollständig initialisiert ist
        self.person = Person()
        
        // Initialisiere calculator mit nil, wird später aktualisiert
        self.calculator = RentenCalculator(appSettings: nil)
        
        // Jetzt kannst du self.appSettings sicher verwenden
        if let context = modelContext {
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            let savedSettings = try? context.fetch(settingsDescriptor)
            self.appSettings = savedSettings?.first
            
            if self.appSettings == nil {
                let newSettings = AppSettings()
                context.insert(newSettings)
                try? context.save()
                self.appSettings = newSettings
            }
            
            // Aktualisiere calculator mit geladenen appSettings
            self.calculator = RentenCalculator(appSettings: self.appSettings)
            
            // Person laden/ersetzen, falls vorhanden
            let descriptor = FetchDescriptor<Person>()
            let savedPersons = try? context.fetch(descriptor)
            if let savedPerson = savedPersons?.first {
                self.person = savedPerson
                self.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: self.person.geburtsdatum)
            }
        }
        
        setupValidation()
        setupFruehererRentenbeginnBinding()
        loadSampleDataIfNeeded()
    }
    
    // MARK: - SwiftData Setup
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadAppSettings()
        loadPersonData()
    }
    
    // MARK: - Validation Setup
    
    private func setupValidation() {
        // Geburtsdatum
        $person
            .map(\.geburtsdatum)
            .removeDuplicates()
            .map { geburtsdatum in
                if !DateHelper.istGueltigesGeburtsdatum(geburtsdatum) {
                    return "Bitte geben Sie ein gültiges Geburtsdatum ein (zwischen 1940 und heute minus 18 Jahre)"
                }
                return nil
            }
            .assign(to: \.geburtsdatumFehler, on: self)
            .store(in: &cancellables)
        
        // Einkommen
        $person
            .map(\.monatlichesEinkommen)
            .removeDuplicates()
            .map { [weak self] einkommen in
                guard let self = self else { return nil }
                let maxMonatlich = (self.appSettings?.beitragsbemessungsgrenze ?? 96_600.0) / 12.0
                if einkommen < 0 {
                    return "Das Einkommen darf nicht negativ sein"
                } else if einkommen > maxMonatlich {
                    return "Das monatliche Einkommen darf \(String(format: "%.0f€", maxMonatlich)) nicht überschreiten (Beitragsbemessungsgrenze)"
                }
                return nil
            }
            .assign(to: \.einkommenFehler, on: self)
            .store(in: &cancellables)
        
        // Rentenpunkte
        $person
            .map(\.aktuelleRentenpunkte)
            .removeDuplicates()
            .map { punkte in
                if punkte < 0 {
                    return "Rentenpunkte dürfen nicht negativ sein"
                } else if punkte > 200 {
                    return "Die Anzahl der Rentenpunkte scheint unrealistisch hoch (über 200)"
                }
                return nil
            }
            .assign(to: \.rentenpunkteFehler, on: self)
            .store(in: &cancellables)
        
        // Rentenbeginn Warnungen
        Publishers.CombineLatest($fruehererRentenbeginnGewuenscht, $appSettings)
            .map { [weak self] (fruehererBeginn, settings) -> String? in
                guard let self = self, fruehererBeginn, let settings = settings,
                      let rentenbeginn = settings.abweichenderRentenbeginn else {
                    return nil
                }
                let validierung = self.calculator.validiereRentenbeginn(
                    datum: rentenbeginn,
                    geburtsdatum: self.person.geburtsdatum
                )
                return validierung.istGueltig ? validierung.warnung : "Ungültiger Rentenbeginn"
            }
            .assign(to: \.rentenbeginnFehler, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Binding für Toggle "Früherer Rentenbeginn gewünscht"
    
    private func setupFruehererRentenbeginnBinding() {
        $fruehererRentenbeginnGewuenscht
            .removeDuplicates()
            .sink { [weak self] isOn in
                guard let self = self else { return }
                if isOn {
                    if let settings = self.appSettings, settings.abweichenderRentenbeginn == Date() {
                        let startwert = settings.fruehesterAbschlagsfreierBeginn
                        print("[ViewModel] Setze Startwert für früheren Rentenbeginn: \(startwert)")
                        settings.abweichenderRentenbeginn = DateHelper.mitternachtStabil(fuer: startwert)
                    }
                } else {
                    print("[ViewModel] Entferne früheren Rentenbeginn, Toggle aus")
                    if let settings = self.appSettings {
                        settings.abweichenderRentenbeginn = settings.regelaltersgrenze
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var istEingabeGueltig: Bool {
        geburtsdatumFehler == nil &&
        einkommenFehler == nil &&
        rentenpunkteFehler == nil &&
        rentenbeginnFehler == nil
    }
    
    var hatErgebnis: Bool { ergebnis != nil }
    
    var aktuelleBerechnungsgrundlagen: String {
        let settings = appSettings ?? AppSettings()
        return """
        Berechnungsgrundlagen \(settings.gueltigkeitsjahr):
        • Durchschnittsentgelt: \(String(format: "%.0f€", settings.durchschnittsentgelt))
        • Rentenwert: \(String(format: "%.2f€", settings.rentenwert))
        • Beitragsbemessungsgrenze: \(String(format: "%.0f€", settings.beitragsbemessungsgrenze))
        """
    }
    
    // MARK: - Actions
    
    func berechneRente() {
        guard istEingabeGueltig else {
            fehlerMeldung = "Bitte korrigieren Sie die fehlerhaften Eingaben"
            showingError = true
            return
        }
        
        // Normalisieren
        person.geburtsdatum = DateHelper.mitternachtStabil(fuer: person.geburtsdatum)
        savePersonData()
        
        print("[ViewModel berechneRente] Aufruf mit abweichendem Rentenbeginn: \(String(describing: appSettings?.abweichenderRentenbeginn))")
        
        withAnimation { isLoading = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            let berechnetesErgebnis = self.calculator.berechneRente(
                fuer: self.person,
                appSettings: self.appSettings
            )
            
            print("[ViewModel berechneRente] Ergebnis: zusätzliche RP = \(berechnetesErgebnis.zusaetzlicheRentenpunkte)")
            
            withAnimation {
                self.ergebnis = berechnetesErgebnis
                self.selectedTab = 1
                self.isLoading = false
            }
            self.berechneSzenarien()
        }
    }
    
    func berechneSzenarien() {
        guard istEingabeGueltig else { return }
        
        person.geburtsdatum = DateHelper.mitternachtStabil(fuer: person.geburtsdatum)
        
        let aktuellerPerson = person
        
        let berechneteSzenarien = calculator.berechneSzenarien(fuer: aktuellerPerson)
        self.szenarien = berechneteSzenarien
    }
    
    func resetEingaben() {
        withAnimation {
            if let context = modelContext {
                context.delete(person)
                try? context.save()
            }
            person = Person()
            if let context = modelContext {
                context.insert(person)
                try? context.save()
            }
            ergebnis = nil
            szenarien = []
            fruehererRentenbeginnGewuenscht = false
            showingSzenarien = false
            selectedTab = 0
            fehlerMeldung = nil
            showingError = false
        }
    }
    
    // MARK: - SwiftData Loading/Saving
    
    func savePersonData() {
        guard let context = modelContext else { return }
        person.geburtsdatum = DateHelper.mitternachtStabil(fuer: person.geburtsdatum)
        do {
            context.insert(person)
            try context.save()
        } catch {
            print("Fehler beim Speichern der Person: \(error)")
            handleError(error)
        }
    }
    
    func loadPersonData() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Person>()
            let savedPersons = try context.fetch(descriptor)
            if let savedPerson = savedPersons.first {
                self.person = savedPerson
                self.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: self.person.geburtsdatum)
            } else {
                let newPerson = Person()
                context.insert(newPerson)
                self.person = newPerson
                try context.save()
            }
        } catch {
            print("Fehler beim Laden der Person: \(error)")
            handleError(error)
        }
    }
    
    func loadAppSettings() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<AppSettings>()
            let savedSettings = try context.fetch(descriptor)
            if let settings = savedSettings.first {
                self.appSettings = settings
            } else {
                let newSettings = AppSettings()
                context.insert(newSettings)
                self.appSettings = newSettings
                try context.save()
            }
            self.calculator = RentenCalculator(appSettings: self.appSettings)
        } catch {
            print("Fehler beim Laden der AppSettings: \(error)")
            handleError(error)
        }
    }
    
    private func loadSampleDataIfNeeded() {
        if person.monatlichesEinkommen == 0 && person.aktuelleRentenpunkte == 0 {
            person.geschlecht = .maennlich
            let sampleDate = Calendar.current.date(byAdding: .year, value: -45, to: Date()) ?? Date()
            person.geburtsdatum = DateHelper.mitternachtStabil(fuer: sampleDate)
            person.monatlichesEinkommen = 3500.0
            person.aktuelleRentenpunkte = 25.5
            savePersonData()
        }
    }
    
    // MARK: - Helper Functions
    
    func getRentenpunkteProJahr() -> Double {
        calculator.berechneRentenpunkteProJahr(jahreseinkommen: person.jahresbruttoeinkommen)
    }
    
    func getMaximalesJahreseinkommen() -> Double {
        appSettings?.beitragsbemessungsgrenze ?? 96_600.0
    }
    
    func getRegelaltersgrenze() -> Date {
        let regelalter = RegelaltersgrenzenTabelle.regelaltersdatum(fuer: person.geburtsdatum)
        return DateHelper.naechsterMonatserster(ab: regelalter)
    }
    
    func getFruehesterAbschlagsfreierBeginn() -> Date {
        if let fruehester = appSettings?.fruehesterAbschlagsfreierBeginn {
            return fruehester
        }
        let fruehester = RegelaltersgrenzenTabelle.fruehesterAbschlagsfreierBeginnDatum(fuer: person.geburtsdatum)
        return DateHelper.naechsterMonatserster(ab: fruehester)
    }
    
    // MARK: - Sharing & Export
    
    func getShareText() -> String {
        guard let ergebnis = ergebnis else {
            return "Noch keine Rentenberechnung durchgeführt"
        }
        return ergebnis.alsTextReport()
    }
    
    func getExportData() -> [String: Any] {
        guard let ergebnis = ergebnis else { return [:] }
        return ergebnis.alsExportDictionary()
    }
    
    // MARK: - Scenario Comparison
    
    func vergleicheSzenarien(_ szenario1: RentenSzenario, _ szenario2: RentenSzenario) -> RentenVergleich {
        szenario1.ergebnis.unterschiedZu(szenario2.ergebnis)
    }
    
    func getBestesSzenario() -> RentenSzenario? {
        szenarien.max { $0.ergebnis.tatsaechlicheBruttoRente < $1.ergebnis.tatsaechlicheBruttoRente }
    }
    
    // MARK: - UI Helpers
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: amount)) ?? "€0,00"
    }
    
    func formatPercentage(_ percentage: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: percentage)) ?? "0,0%"
    }
    
    func formatDecimal(_ number: Double, digits: Int = 2) -> String {
        String(format: "%.\(digits)f", number)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        fehlerMeldung = nil
        showingError = false
    }
    
    private func handleError(_ error: Error) {
        fehlerMeldung = error.localizedDescription
        showingError = true
        isLoading = false
    }
}

// MARK: - Extensions

extension RentenrechnerViewModel {
    
    var istBereitsImRentenalter: Bool {
        let heute = DateHelper.mitternachtStabil(fuer: Date())
        let regelalter = getRegelaltersgrenze()
        return heute >= regelalter
    }
    
    var jahreZurRente: Double {
        let heute = DateHelper.mitternachtStabil(fuer: Date())
        let regelalter = getRegelaltersgrenze()
        if heute >= regelalter { return 0 }
        return DateHelper.jahreZwischen(startDatum: heute, endDatum: regelalter)
    }
    
    var empfehlung: String {
        guard let ergebnis = ergebnis else {
            return "Führen Sie zuerst eine Berechnung durch"
        }
        if ergebnis.istAbschlagsfrei {
            return "✅ Ihr gewählter Rentenbeginn ist optimal - keine Abschläge!"
        } else {
            let abschlagProzent = ergebnis.abschlagProzent * 100
            if abschlagProzent < 3.6 {
                return "⚠️ Geringer Abschlag von \(formatPercentage(ergebnis.abschlagProzent)) - eventuell vertretbar"
            } else {
                return "❌ Hoher Abschlag von \(formatPercentage(ergebnis.abschlagProzent)) - später in Rente gehen könnte sich lohnen"
            }
        }
    }
}

// MARK: - Sample Data for Testing

#if DEBUG
extension RentenrechnerViewModel {
    
    static func sampleViewModel(with context: ModelContext) -> RentenrechnerViewModel {
        let vm = RentenrechnerViewModel(modelContext: context)
        vm.person.geschlecht = .weiblich
        let sampleDate = Calendar.current.date(byAdding: .year, value: -42, to: Date())!
        vm.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: sampleDate)
        vm.person.monatlichesEinkommen = 4200.0
        vm.person.aktuelleRentenpunkte = 28.5
        vm.person.aktuelleRente = 1250.0
        vm.savePersonData()
        return vm
    }
    
    func loadTestData() {
        person.geschlecht = .maennlich
        let testDate1 = Calendar.current.date(byAdding: .year, value: -48, to: Date())!
        person.geburtsdatum = DateHelper.mitternachtStabil(fuer: testDate1)
        person.monatlichesEinkommen = 5500.0
        person.aktuelleRentenpunkte = 32.8
        person.aktuelleRente = 1420.0
        fruehererRentenbeginnGewuenscht = true
        savePersonData()
    }
}
#endif
