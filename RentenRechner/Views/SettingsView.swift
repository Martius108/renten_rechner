//
//  SettingsView.swift
//  RentenRechner
//
//  Einstellungen für Änderungen der DRV
//

import SwiftUI
import SwiftData

// Kleiner Toast-View
private struct SaveToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text("Gespeichert")
                .foregroundColor(.white)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.green.opacity(0.9))
        .clipShape(Capsule())
        .shadow(radius: 6)
    }
}

// Keyboard-Dismiss Helper
extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @EnvironmentObject var viewModel: RentenrechnerViewModel
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    if let setting = settings.first {
                        EditableSettingsContent(
                            setting: setting,
                            onSaved: { showSuccessToast() }
                        )
                    } else {
                        EmptyView()
                    }
                }
                .listStyle(.insetGrouped)

                if showSavedToast {
                    SaveToast()
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            // Zusätzlicher "Fertig"-Button oben rechts, falls keine Tastatur sichtbar ist
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        // Speichere nur, wenn ein Datensatz existiert
                        if !settings.isEmpty {
                            try? context.save()
                            // Tastatur schließen
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                            to: nil, from: nil, for: nil)
                            showSuccessToast()
                        }
                    }
                }
            }
            
            .onAppear {
                if settings.isEmpty {
                    let neues = AppSettings()
                    context.insert(neues)
                    try? context.save()
                }
            }
        }
    }

    private func showSuccessToast() {
        withAnimation(.spring(duration: 0.25)) { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(duration: 0.25)) { showSavedToast = false }
        }
    }
}

struct EditableSettingsContent: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var viewModel: RentenrechnerViewModel
    @Bindable var setting: AppSettings
    var onSaved: () -> Void

    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case durchschnittsentgelt, rentenwert, bbg, steuerfreibetrag,
             steuerpflichtQuote, durchschnittlicherSteuersatz,
             kvSatz, kvZusatz, pvSatz
    }

    var body: some View {
        rentenparameterSection
        steuernUndAbgabenSection
        werteSection
        infoSection
        .toolbar {
            // "Fertig" innerhalb der Tastatur-Leiste
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { saveAndDismiss() }
                    .font(.body.weight(.semibold))
            }
        }
    }

    // MARK: - Sections

    private var rentenparameterSection: some View {
        Section("Aktuelle Rentenparameter") {
            numberField(
                title: "Durchschnittsentgelt",
                suffix: "€",
                binding: $setting.durchschnittsentgelt,
                field: .durchschnittsentgelt
            )

            numberField(
                title: "Rentenwert pro Punkt",
                suffix: "€",
                binding: $setting.rentenwert,
                field: .rentenwert
            )

            numberField(
                title: "Beitragsbemessungsgrenze",
                suffix: "€",
                binding: $setting.beitragsbemessungsgrenze,
                field: .bbg
            )
        }
    }

    private var steuernUndAbgabenSection: some View {
        Section("Steuern & Sozialabgaben") {
            numberField(
                title: "Steuerfreibetrag",
                suffix: "€",
                binding: $setting.steuerfreibetrag,
                field: .steuerfreibetrag
            )

            numberField(title: "Steuerpflicht-Quote (0.0 - 1.0)", suffix: "",
                        binding: $setting.steuerpflichtQuote, field: .steuerpflichtQuote)
            Text("Aktuell: \(String(format: "%.1f", setting.steuerpflichtQuote * 100))%")
                .font(.caption)
                .foregroundColor(.blue)

            numberField(title: "Durchschnittlicher Steuersatz (0.0 - 1.0)", suffix: "",
                        binding: $setting.durchschnittlicherSteuersatz, field: .durchschnittlicherSteuersatz)
            Text("Aktuell: \(String(format: "%.1f", setting.durchschnittlicherSteuersatz * 100))%")
                .font(.caption)
                .foregroundColor(.blue)

            numberField(title: "Krankenkassen-Beitragssatz (0.0 - 1.0)", suffix: "",
                        binding: $setting.krankenkassenBeitragssatz, field: .kvSatz)
            Text("Aktuell: \(String(format: "%.1f", setting.krankenkassenBeitragssatz * 100))%")
                .font(.caption)
                .foregroundColor(.blue)

            numberField(title: "KV-Zusatzbeitrag (0.0 - 1.0)", suffix: "",
                        binding: $setting.krankenkassenZusatzbeitrag, field: .kvZusatz)
            Text("Aktuell: \(String(format: "%.1f", setting.krankenkassenZusatzbeitrag * 100))%")
                .font(.caption)
                .foregroundColor(.blue)

            numberField(title: "Pflegeversicherung (0.0 - 1.0)", suffix: "",
                        binding: $setting.pflegeversicherungsBeitrag, field: .pvSatz)
            Text("Aktuell: \(String(format: "%.1f", setting.pflegeversicherungsBeitrag * 100))% (3,6% mit Kindern / 4,2% kinderlos)")
                .font(.caption)
                .foregroundColor(.blue)
        }
    }

    private var werteSection: some View {
        Section("Berechnete Werte") {
            if let e = viewModel.ergebnis {
                let basis = e.tatsaechlicheBruttoRente > 0 ? e.tatsaechlicheBruttoRente : e.gesamtBruttoRente
                let proz = basis > 0 ? (e.sozialabgabenBetrag / basis) : 0.0
                rowLabelValue(
                    "Sozialabgaben",
                    value: String(format: "%.1f%%", proz * 100.0),
                    valueColor: .blue
                )
            } else {
                rowLabelValue("Sozialabgaben", value: "–", valueColor: .secondary)
            }
        }
    }

    private var infoSection: some View {
        Section("Weitere Informationen") {
            NavigationLink(destination: InfoView()) {
                Label("Zur Info-Seite", systemImage: "info.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Row-Builders

    private func rowLabelValue(_ title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 44)
    }

    private func numberField(title: String, suffix: String, binding: Binding<Double>, field: Field) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            TextField(title, value: binding, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .submitLabel(.done)
                .onSubmit { saveAndDismiss() }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(suffix)
                .foregroundColor(.secondary)
        }
        .frame(minHeight: 44)
    }

    // MARK: - Save

    private func saveAndDismiss() {
        // Persistiere Änderungen am gebundenen AppSettings-Datensatz
        try? context.save()

        // Fokus löschen und Tastatur schließen
        focusedField = nil
        hideKeyboard()

        // Haptisches Feedback und Toast
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSaved()
    }
}
