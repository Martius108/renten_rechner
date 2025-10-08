//
//  EingabeView.swift
//  RentenRechner
//
//  Eingabeformular für die Rentenberechnung
//

import SwiftUI
import SwiftData

struct EingabeView: View {
    @Environment(\.modelContext) private var context
    @Query private var persons: [Person]
    
    @EnvironmentObject var viewModel: RentenrechnerViewModel
    @State private var showingDatePicker = false
    @State private var showingRentenbeginnPicker = false
    
    // NEU: UI-Variable für Rentenbeginn und Flag für Nutzeränderung
    @State private var rentenbeginnUI: Date = Date()
    @State private var hatUserRentenbeginnGeaendert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Hauptinhalt
                ScrollView {
                    LazyVStack(spacing: 24) {
                        headerSection
                        
                        personalDatenSection
                        
                        beruflicheDatenSection
                        
                        zusatzrenteSection
                        
                        rentenoptionenSection
                        
                        berechnungsgrundlagenSection
                        
                        berechnenButton
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                
                // Loading Overlay
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
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                // Lade die gespeicherte Person aus SwiftData
                if let saved = persons.first {
                    viewModel.person = saved
                    // Normalisiere geladene Daten
                    viewModel.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: viewModel.person.geburtsdatum)
                    if let rb = viewModel.person.gewuenschterRentenbeginn {
                        viewModel.person.gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: rb)
                    }
                } else {
                    let newPerson = Person()
                    context.insert(newPerson)
                    try? context.save()
                    viewModel.person = newPerson
                }
                viewModel.setModelContext(context)
                
                // Initialisiere UI-Variable für Rentenbeginn mit Regelaltersgrenze
                rentenbeginnUI = viewModel.getRegelaltersgrenze()
                hatUserRentenbeginnGeaendert = false
                
                // Aktualisiere Rentenparameter bei initialem Laden
                viewModel.appSettings?.updateRentenParameter(geburtsdatum: viewModel.person.geburtsdatum)
            }
            .onChange(of: viewModel.person.geburtsdatum) { _, newValue in
                // Normalisiere Datum
                viewModel.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: newValue)
                // Aktualisiere Rentenparameter in AppSettings
                viewModel.appSettings?.updateRentenParameter(geburtsdatum: newValue)
                savePersonData()
                
                // Wenn früherer Rentenbeginn gewünscht, setze Rentenbeginn auf Regelaltersgrenze
                if viewModel.fruehererRentenbeginnGewuenscht {
                    let regelalter = viewModel.getRegelaltersgrenze()
                    rentenbeginnUI = regelalter
                    viewModel.person.gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: regelalter)
                    savePersonData()
                }
            }
            .onChange(of: viewModel.person.monatlichesEinkommen) { _, _ in
                savePersonData()
            }
            .onChange(of: viewModel.person.aktuelleRentenpunkte) { _, _ in
                savePersonData()
            }
            .onChange(of: viewModel.person.zusatzrente1) { _, _ in
                savePersonData()
            }
            .onChange(of: viewModel.person.zusatzrente2) { _, _ in
                savePersonData()
            }
            .onChange(of: viewModel.fruehererRentenbeginnGewuenscht) { oldValue, newValue in
                if !newValue {
                    viewModel.person.gewuenschterRentenbeginn = nil
                    hatUserRentenbeginnGeaendert = false
                } else if !hatUserRentenbeginnGeaendert {
                    // Wenn Toggle aktiviert wird, aber Nutzer noch nicht geändert hat,
                    // setze UI-Variable und Modell auf frühesten abschlagsfreien Beginn
                    rentenbeginnUI = viewModel.getFruehesterAbschlagsfreierBeginn()
                    viewModel.person.gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: rentenbeginnUI)
                    savePersonData()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func savePersonData() {
        // Normalisierung vor dem Speichern
        viewModel.person.geburtsdatum = DateHelper.mitternachtStabil(fuer: viewModel.person.geburtsdatum)
        if let rb = viewModel.person.gewuenschterRentenbeginn {
            viewModel.person.gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: rb)
        }
        do {
            try context.save()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
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
    
    // MARK: - Personal Daten Section
    
    private var personalDatenSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Persönliche Angaben", icon: "person.fill")
                
                // Geschlecht
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
                
                // Geburtsdatum mit Normalisierung
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
                                
                                if viewModel.fruehererRentenbeginnGewuenscht {
                                    let regelalter = viewModel.getRegelaltersgrenze()
                                    rentenbeginnUI = regelalter
                                    viewModel.person.gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: regelalter)
                                    savePersonData()
                                }
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
                
                // Aktuelles Alter
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
    
    // MARK: - Berufliche Daten Section
    
    private var beruflicheDatenSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Berufliche Daten", icon: "briefcase.fill")
                
                // Monatliches Einkommen
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
                
                // Aktuelle Rentenpunkte
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
                
                // Aktuelle Rente (optional)
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
    
    // MARK: - Zusatzrenten Section
    
    private var zusatzrenteSection: some View {
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
    
    // MARK: - Rentenoptionen Section
    
    private var rentenoptionenSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Rentenoptionen", icon: "calendar.badge.clock")
                
                // Toggle für früheren Rentenbeginn
                Toggle("Früherer Rentenbeginn gewünscht", isOn: $viewModel.fruehererRentenbeginnGewuenscht)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: viewModel.fruehererRentenbeginnGewuenscht) { oldValue, newValue in
                        if !newValue {
                            viewModel.person.gewuenschterRentenbeginn = nil
                            hatUserRentenbeginnGeaendert = false
                        } else if !hatUserRentenbeginnGeaendert {
                            // Wenn Toggle aktiviert wird, aber Nutzer noch nicht geändert hat,
                            // setze UI-Variable und Modell auf frühesten abschlagsfreien Beginn
                            rentenbeginnUI = viewModel.getFruehesterAbschlagsfreierBeginn()
                            viewModel.person.gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: rentenbeginnUI)
                            savePersonData()
                        }
                    }
                
                // Rentenbeginn-Picker mit Normalisierung
                if viewModel.fruehererRentenbeginnGewuenscht {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gewünschter Rentenbeginn")
                            .font(.headline)
                        
                        DatePicker(
                            "Rentenbeginn",
                            selection: $rentenbeginnUI,
                            in: Calendar.current.date(byAdding: .year, value: 60, to: viewModel.person.geburtsdatum)!...Calendar.current.date(byAdding: .year, value: 70, to: viewModel.person.geburtsdatum)!,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(CompactDatePickerStyle())
                        .onChange(of: rentenbeginnUI) { _, newValue in
                            hatUserRentenbeginnGeaendert = true
                            viewModel.person.gewuenschterRentenbeginn = DateHelper.mitternachtStabil(fuer: newValue)
                            savePersonData()
                        }
                        
                        if let fehler = viewModel.rentenbeginnFehler {
                            ErrorText(fehler)
                        }
                    }
                    
                    // Zusatzinformationen
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(
                            label: "Frühester abschlagsfreier Beginn",
                            value: viewModel.getFruehesterAbschlagsfreierBeginn().deutscheFormatierung,
                            icon: "checkmark.circle"
                        )
                        
                        if let gewuenschterBeginn = viewModel.person.gewuenschterRentenbeginn {
                            let regelalter = DateHelper.mitternachtStabil(fuer: viewModel.getRegelaltersgrenze())
                            let fruehesterAbschlagsfrei = DateHelper.mitternachtStabil(fuer: viewModel.getFruehesterAbschlagsfreierBeginn())
                            let gewuenschterBeginnNorm = DateHelper.mitternachtStabil(fuer: gewuenschterBeginn)
                            
                            // Nur Warnung, wenn VOR BEIDEN abschlagsfreien Terminen
                            if gewuenschterBeginnNorm < regelalter && gewuenschterBeginnNorm < fruehesterAbschlagsfrei {
                                let monateVorRegelalter = DateHelper.monateZwischen(
                                    startDatum: gewuenschterBeginnNorm,
                                    endDatum: regelalter
                                )
                                
                                let prozent = Double(monateVorRegelalter) * 0.3
                                WarningRow(text: "⚠️ \(monateVorRegelalter) Monate vor Regelalter = bis zu \(String(format: "%.1f", prozent))% Abschlag")
                            } else if gewuenschterBeginnNorm >= fruehesterAbschlagsfrei && gewuenschterBeginnNorm < regelalter {
                                // Abschlagsfrei durch 45 Beitragsjahre
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
                                // Abschlagsfrei durch Regelalter
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
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Berechnungsgrundlagen Section
    
    private var berechnungsgrundlagenSection: some View {
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
    
    // MARK: - Berechnen Button
    
    private var berechnenButton: some View {
        Button(action: {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
