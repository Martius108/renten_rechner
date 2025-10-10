//
//  EingabeView.swift
//  RentenRechner
//
//  Eingabe aller benötigten Daten
//

import SwiftUI
import SwiftData

struct EingabeView: View {
    @Environment(\.modelContext) private var context
    @Query private var persons: [Person]
    
    @EnvironmentObject var viewModel: RentenrechnerViewModel
    
    @State private var rentenbeginnUI: Date = Date()
    @State private var hatUserRentenbeginnGeaendert = false
    @State private var isInitialLoad = true
    @State private var isProgrammaticChange = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        HeaderSection()
                        PersonalDatenSection(viewModel: viewModel, savePersonData: savePersonData)
                        BeruflicheDatenSection(viewModel: viewModel, savePersonData: savePersonData)
                        ZusatzrenteSection(viewModel: viewModel)
                        RentenoptionenSection(
                            viewModel: viewModel,
                            rentenbeginnUI: $rentenbeginnUI,
                            hatUserRentenbeginnGeaendert: $hatUserRentenbeginnGeaendert,
                            isInitialLoad: $isInitialLoad,
                            isProgrammaticChange: $isProgrammaticChange,
                            saveAppSettings: saveAppSettings
                        )
                        BerechnungsgrundlagenSection(viewModel: viewModel)
                        BerechnenButton(viewModel: viewModel)
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Berechnung läuft...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .frame(width: 150, height: 100)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("RentenRechner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        viewModel.resetEingaben()
                        rentenbeginnUI = viewModel.appSettings?.regelaltersgrenze ?? viewModel.getRegelaltersgrenze()
                        hatUserRentenbeginnGeaendert = false
                        saveAppSettings()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear(perform: onAppear)
            .onChange(of: viewModel.person.geburtsdatum) { _, newValue in
                viewModel.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: newValue)
                viewModel.appSettings?.updateRentenParameter(geburtsdatum: newValue)
                savePersonData()
                
                if let appSettings = viewModel.appSettings {
                    let neueRegelaltersgrenze = viewModel.getRegelaltersgrenze()
                    appSettings.regelaltersgrenze = neueRegelaltersgrenze
                    
                    if !hatUserRentenbeginnGeaendert {
                        appSettings.abweichenderRentenbeginn = neueRegelaltersgrenze
                        rentenbeginnUI = neueRegelaltersgrenze
                    }
                    
                    saveAppSettings()
                }
            }
            .onChange(of: viewModel.person.monatlichesEinkommen) { _, _ in savePersonData() }
            .onChange(of: viewModel.person.aktuelleRentenpunkte) { _, _ in savePersonData() }
            .onChange(of: viewModel.person.zusatzrente1) { _, _ in savePersonData() }
            .onChange(of: viewModel.person.zusatzrente2) { _, _ in savePersonData() }
        }
    }
    
    // MARK: - Lifecycle
    
    // MARK: - Lifecycle

    private func onAppear() {
        if let saved = persons.first {
            viewModel.person = saved
            viewModel.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: viewModel.person.geburtsdatum)
        } else {
            let newPerson = Person()
            context.insert(newPerson)
            try? context.save()
            viewModel.person = newPerson
        }
        viewModel.setModelContext(context)
        
        if let appSettings = viewModel.appSettings {
            let regelalter = viewModel.getRegelaltersgrenze()
            appSettings.regelaltersgrenze = regelalter
            appSettings.fruehesterAbschlagsfreierBeginn = viewModel.getFruehesterAbschlagsfreierBeginn()
            
            if !hatUserRentenbeginnGeaendert {
                appSettings.abweichenderRentenbeginn = regelalter
                rentenbeginnUI = regelalter
            }
            
            saveAppSettings()
        }
        
        // Debug: Ausgabe Regelaltersgrenze für 01.01.1970
        let geburtsdatum = DateHelper.erstelleDatum(jahr: 1970, monat: 1, tag: 1)!
        let regelaltersgrenze = DateHelper.addiere(jahre: 67, monate: 0, zu: geburtsdatum)!
        print("Regelaltersgrenze für 01.01.1970: \(regelaltersgrenze) / lokal: \(regelaltersgrenze.deutscheFormatierung)")
        
        // Toggle standardmäßig auf false
        hatUserRentenbeginnGeaendert = false
        
        print("[EingabeView onAppear] rentenbeginnUI: \(rentenbeginnUI)")
        print("[EingabeView onAppear] hatUserRentenbeginnGeaendert: \(hatUserRentenbeginnGeaendert)")
        print("[EingabeView onAppear] appSettings.regelaltersgrenze: \(viewModel.appSettings?.regelaltersgrenze ?? Date())")
        print("[EingabeView onAppear] appSettings.abweichenderRentenbeginn: \(viewModel.appSettings?.abweichenderRentenbeginn ?? Date())")
        
        viewModel.appSettings?.updateRentenParameter(geburtsdatum: viewModel.person.geburtsdatum)
        
        isInitialLoad = false
    }
    
    // MARK: - Save Helpers
    
    private func savePersonData() {
        viewModel.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: viewModel.person.geburtsdatum)
        do {
            try context.save()
            print("[EingabeView savePersonData] Person gespeichert")
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
    
    private func saveAppSettings() {
        if let appSettings = viewModel.appSettings {
            do {
                context.insert(appSettings)
                try context.save()
                print("[EingabeView saveAppSettings] AppSettings gespeichert")
            } catch {
                print("Fehler beim Speichern der AppSettings: \(error)")
            }
        }
    }
}

// MARK: - RentenoptionenSection mit eingebetteter onChange-Logik

struct RentenoptionenSection: View {
    @ObservedObject var viewModel: RentenrechnerViewModel
    @Binding var rentenbeginnUI: Date
    @Binding var hatUserRentenbeginnGeaendert: Bool
    @Binding var isInitialLoad: Bool
    @Binding var isProgrammaticChange: Bool
    let saveAppSettings: () -> Void
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Rentenoptionen", icon: "calendar.badge.clock")
                
                Toggle("Abweichender Rentenbeginn", isOn: $hatUserRentenbeginnGeaendert)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: hatUserRentenbeginnGeaendert) { _, newValue in
                        guard !isInitialLoad else { return }
                        isProgrammaticChange = true
                        if newValue {
                            if let settings = viewModel.appSettings,
                               let abweichenderBeginn = settings.abweichenderRentenbeginn,
                               abweichenderBeginn == settings.regelaltersgrenze {
                                rentenbeginnUI = abweichenderBeginn
                                print("[RentenoptionenSection] rentenbeginnUI zurückgesetzt auf abweichenderBeginn (Regelaltersgrenze)")
                            }
                        } else {
                            if let settings = viewModel.appSettings {
                                settings.abweichenderRentenbeginn = settings.regelaltersgrenze
                                rentenbeginnUI = settings.regelaltersgrenze
                                saveAppSettings()
                                print("[RentenoptionenSection] Toggle aus: abweichenderRentenbeginn und rentenbeginnUI auf Regelaltersgrenze gesetzt")
                            }
                        }
                        DispatchQueue.main.async {
                            isProgrammaticChange = false
                        }
                    }
                
                if hatUserRentenbeginnGeaendert {
                    VStack(alignment: .leading, spacing: 8) {
                        if let appSettings = viewModel.appSettings {
                                    let beginnDatum = appSettings.fruehesterAbschlagsfreierBeginn
                                    Text("Frühester abschlagsfreier Beginn: \(beginnDatum.deutscheFormatierung)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                        
                        DatePicker(
                            "Gewünschter Rentenbeginn",
                            selection: $rentenbeginnUI,
                            in: Calendar.current.date(byAdding: .year, value: 60, to: viewModel.person.geburtsdatum)!...Calendar.current.date(byAdding: .year, value: 70, to: viewModel.person.geburtsdatum)!,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(CompactDatePickerStyle())
                        .onChange(of: rentenbeginnUI) { _, newValue in
                            guard !isInitialLoad && !isProgrammaticChange else { return }
                            if let appSettings = viewModel.appSettings {
                                appSettings.abweichenderRentenbeginn = DateHelper.mitternachtStabil(fuer: newValue)
                                let formatter = DateFormatter()
                                formatter.dateStyle = .short
                                formatter.timeStyle = .none
                                print("[RentenoptionenSection] appSettings.abweichenderRentenbeginn gesetzt auf: \(formatter.string(from: newValue))")
                                saveAppSettings()
                            }
                            hatUserRentenbeginnGeaendert = true
                            print("[RentenoptionenSection] hatUserRentenbeginnGeaendert gesetzt auf true")
                        }
                        
                        if let fehler = viewModel.rentenbeginnFehler {
                            ErrorText(fehler)
                        }
                        
                        // Zusatzinformationen zum abschlagsfreien Beginn
                        ZusatzinformationenAbschlagsfrei(gewählterBeginn: rentenbeginnUI, viewModel: viewModel)
                    }
                } else {
                    InfoText("Der Rentenbeginn entspricht der Regelaltersgrenze.")
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

private struct ZusatzinformationenAbschlagsfrei: View {
    let gewählterBeginn: Date
    @ObservedObject var viewModel: RentenrechnerViewModel
    
    var body: some View {
        let regelalter = DateHelper.mitternachtStabil(fuer: viewModel.getRegelaltersgrenze())
        let fruehesterAbschlagsfrei = DateHelper.mitternachtStabil(fuer: viewModel.getFruehesterAbschlagsfreierBeginn())
        let gewuenschterBeginnNorm = DateHelper.mitternachtStabil(fuer: gewählterBeginn)
        
        Group {
            if gewuenschterBeginnNorm < regelalter && gewuenschterBeginnNorm < fruehesterAbschlagsfrei {
                let monateVorRegelalter = DateHelper.monateZwischen(
                    startDatum: gewuenschterBeginnNorm,
                    endDatum: regelalter
                )
                let prozent = Double(monateVorRegelalter) * 0.3
                WarningRow(text: "⚠️ \(monateVorRegelalter) Monate vor Regelalter = bis zu \(String(format: "%.1f", prozent))% Abschlag")
            } else if gewuenschterBeginnNorm >= fruehesterAbschlagsfrei && gewuenschterBeginnNorm < regelalter {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("✅ Abschlagsfreier Rentenbeginn (45 Beitragsjahre)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if gewuenschterBeginnNorm >= regelalter {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("✅ Abschlagsfreier Rentenbeginn (Regelaltersgrenze)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Subviews

struct HeaderSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eurosign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Deutsche Rentenberechnung")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Berechnen Sie Ihre zu erwartende gesetzliche Rente")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
}

struct PersonalDatenSection: View {
    @ObservedObject var viewModel: RentenrechnerViewModel
    let savePersonData: () -> Void
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Persönliche Angaben", icon: "person.fill")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Geschlecht")
                        .font(.headline)
                    
                    Picker("Geschlecht", selection: $viewModel.person.geschlecht) {
                        ForEach(Geschlecht.allCases, id: \.self) { geschlecht in
                            Text(geschlecht.displayName).tag(geschlecht)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.person.geschlecht) { _, _ in
                        savePersonData()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Geburtsdatum")
                        .font(.headline)
                    
                    DatePicker(
                        "Geburtsdatum",
                        selection: Binding(
                            get: { viewModel.person.geburtsdatum },
                            set: { newValue in
                                viewModel.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: newValue)
                                viewModel.appSettings?.updateRentenParameter(geburtsdatum: newValue)
                                savePersonData()
                            }
                        ),
                        in: Date.distantPast...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    
                    if let fehler = viewModel.geburtsdatumFehler {
                        ErrorText(fehler)
                    }
                }
                
                InfoRow(
                    label: "Aktuelles Alter",
                    value: "\(viewModel.person.alter) Jahre",
                    icon: "calendar"
                )
                
                InfoRow(
                    label: "Regelaltersgrenze",
                    value: viewModel.getRegelaltersgrenze().deutscheFormatierung,
                    icon: "clock"
                )
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

struct BeruflicheDatenSection: View {
    @ObservedObject var viewModel: RentenrechnerViewModel
    let savePersonData: () -> Void
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Berufliche Daten", icon: "briefcase.fill")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monatliches Bruttoeinkommen")
                        .font(.headline)
                    
                    HStack {
                        TextField("0", value: $viewModel.person.monatlichesEinkommen, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("€")
                            .foregroundColor(.secondary)
                    }
                    
                    if let fehler = viewModel.einkommenFehler {
                        ErrorText(fehler)
                    } else {
                        InfoText("Jahreseinkommen: \(viewModel.formatCurrency(viewModel.person.jahresbruttoeinkommen))")
                        InfoText("Rentenpunkte pro Jahr: \(viewModel.formatDecimal(viewModel.getRentenpunkteProJahr()))")
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bereits erworbene Rentenpunkte")
                        .font(.headline)
                    
                    TextField("0,0", value: $viewModel.person.aktuelleRentenpunkte, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if let fehler = viewModel.rentenpunkteFehler {
                        ErrorText(fehler)
                    } else {
                        InfoText("Aus Ihrem aktuellen Rentenbescheid")
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aktuelle Rente (optional)")
                        .font(.headline)
                    
                    HStack {
                        TextField("0", value: .init(
                            get: { viewModel.person.aktuelleRente ?? 0 },
                            set: {
                                viewModel.person.aktuelleRente = $0 > 0 ? $0 : nil
                                savePersonData()
                            }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("€")
                            .foregroundColor(.secondary)
                    }
                    
                    InfoText("Laut Ihrem letzten Rentenbescheid")
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

struct ZusatzrenteSection: View {
    @ObservedObject var viewModel: RentenrechnerViewModel
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Zusatzrenten", icon: "building.columns.fill")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zusatzrente 1 (z.B. Betriebsrente)")
                        .font(.headline)
                    
                    HStack {
                        TextField("0", value: $viewModel.person.zusatzrente1, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("€/Monat")
                            .foregroundColor(.secondary)
                    }
                    InfoText("Betriebsrente, Riester-Rente, etc.")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zusatzrente 2 (z.B. Private Rente)")
                        .font(.headline)
                    
                    HStack {
                        TextField("0", value: $viewModel.person.zusatzrente2, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("€/Monat")
                            .foregroundColor(.secondary)
                    }
                    InfoText("Private Rentenversicherung, Rürup-Rente, etc.")
                }
                
                if viewModel.person.gesamtZusatzrente > 0 {
                    InfoRow(
                        label: "Gesamt-Zusatzrenten",
                        value: viewModel.formatCurrency(viewModel.person.gesamtZusatzrente),
                        icon: "plus.circle"
                    )
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

struct BerechnungsgrundlagenSection: View {
    @ObservedObject var viewModel: RentenrechnerViewModel
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Berechnungsgrundlagen", icon: "info.circle")
                
                let settings = viewModel.settings
                
                InfoRow(
                    label: "Durchschnittsentgelt",
                    value: viewModel.formatCurrency(settings.durchschnittsentgelt),
                    icon: "chart.bar"
                )
                
                InfoRow(
                    label: "Rentenwert",
                    value: "\(viewModel.formatCurrency(settings.rentenwert)) pro Punkt",
                    icon: "eurosign.circle"
                )
                
                InfoRow(
                    label: "Beitragsbemessungsgrenze",
                    value: viewModel.formatCurrency(settings.beitragsbemessungsgrenze),
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                InfoText("Diese Werte gelten für \(settings.gueltigkeitsjahr) und können sich ändern.")
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

struct BerechnenButton: View {
    @ObservedObject var viewModel: RentenrechnerViewModel
    
    var body: some View {
        Button(action: {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            print("[EingabeView] Berechnen Button gedrückt")
            print("[EingabeView] Aktueller rentenbeginnUI: \(viewModel.appSettings?.abweichenderRentenbeginn ?? Date())")
            viewModel.berechneRente()
        }) {
            HStack {
                Text("Rente berechnen")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                viewModel.istEingabeGueltig ?
                Color.blue : Color.gray
            )
            .cornerRadius(16)
        }
        .disabled(!viewModel.istEingabeGueltig || viewModel.isLoading)
        .padding(.top)
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

struct InfoText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct ErrorText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.red)
    }
}

struct WarningRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
