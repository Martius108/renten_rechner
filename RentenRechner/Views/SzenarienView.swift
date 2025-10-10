//
//  SzenarienView.swift
//  RentenRechner
//
//  Vergleich verschiedener Rentenbeginn-Szenarien
//

import SwiftUI

struct SzenarienView: View {
    @EnvironmentObject var viewModel: RentenrechnerViewModel
    @State private var selectedSzenario: RentenSzenario?
    @State private var showingComparison = false

    private var zusatzInfo: String? {
        if let settings = viewModel.appSettings,
           let abweichenderBeginn = settings.abweichenderRentenbeginn {
            
            let regelalter = settings.regelaltersgrenze
            
            let calendar = Calendar.current
            let startOfDayAbweichend = calendar.startOfDay(for: abweichenderBeginn)
            let startOfDayRegelalter = calendar.startOfDay(for: regelalter)
            
            debugPrint("abweichenderBeginn (StartOfDay): \(startOfDayAbweichend), regelalter (StartOfDay): \(startOfDayRegelalter)")
            
            if startOfDayAbweichend != startOfDayRegelalter {
                let info = "Gesetzliche Regelaltersgrenze: \(regelalter.deutscheFormatierung)"
                debugPrint("Debug: zusatzInfo gesetzt: \(info)")
                return info
            }
        }
        debugPrint("Debug: zusatzInfo gesetzt: nil")
        return nil
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.szenarien.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            headerSection

                            ForEach(Array(viewModel.szenarien.enumerated()), id: \.element.name) { index, szenario in
                                if index == 0 {
                                    // Hier nur noch die Property verwenden, keine Berechnung
                                    SzenarioCard(
                                        szenario: szenario,
                                        zusatzrente: viewModel.person.gesamtZusatzrente,
                                        rank: index + 1,
                                        isBest: szenario.name == viewModel.getBestesSzenario()?.name,
                                        onTap: {
                                            selectedSzenario = szenario
                                            showingComparison = true
                                        },
                                        customTitle: "Aktuelle Berechnung",
                                        additionalInfo: zusatzInfo
                                    )
                                } else {
                                    SzenarioCard(
                                        szenario: szenario,
                                        zusatzrente: viewModel.person.gesamtZusatzrente,
                                        rank: index + 1,
                                        isBest: szenario.name == viewModel.getBestesSzenario()?.name,
                                        onTap: {
                                            selectedSzenario = szenario
                                            showingComparison = true
                                        }
                                    )
                                }
                            }

                            vergleichsSection

                            Spacer(minLength: 100)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Szenarien")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !viewModel.szenarien.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Aktualisieren") {
                            viewModel.berechneSzenarien()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingComparison) {
                if let selectedSzenario = selectedSzenario {
                    SzenarioDetailView(
                        szenario: selectedSzenario,
                        zusatzrente: viewModel.person.gesamtZusatzrente
                    )
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    Text("Szenario-Vergleich")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Text("Vergleichen Sie verschiedene Rentenbeginn-Optionen und deren Auswirkungen auf Ihre Rente.")
                    .font(.body)
                    .foregroundColor(.secondary)

                if let bestesSezenario = viewModel.getBestesSzenario() {
                    Divider()

                    HStack {
                        Text("Beste Option: **\(bestesSezenario.name)** mit \(viewModel.formatCurrency(bestesSezenario.ergebnis.tatsaechlicheBruttoRente))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    // MARK: - Vergleichs Section

    private var vergleichsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "scale.3d")
                        .foregroundColor(.green)
                    Text("Schnell-Vergleich")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                if viewModel.szenarien.count >= 2 {
                    VStack(spacing: 12) {
                        ForEach(Array(viewModel.szenarien.prefix(3).enumerated()), id: \.element.name) { _, szenario in
                            QuickComparisonRow(
                                szenario: szenario,
                                baseline: viewModel.szenarien.first(where: { $0.name.contains("Regelalter") })
                            )
                        }
                    }
                } else {
                    Text("Mindestens 2 Szenarien erforderlich für Vergleich")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

// MARK: - Szenario Card

struct SzenarioCard: View {
    let szenario: RentenSzenario
    let zusatzrente: Double
    let rank: Int
    let isBest: Bool
    let onTap: () -> Void

    // Optionale Parameter für individuellen Titel und Zusatzinfo
    var customTitle: String? = nil
    var additionalInfo: String? = nil

    var body: some View {
        Button(action: onTap) {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    // Header mit Rang und Empfehlung
                    HStack {
                        HStack(spacing: 8) {
                            Text("#\(rank)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(rankColor)
                                .clipShape(Capsule())

                            if isBest {
                                //Image(systemName: "crown.fill")
                                    //.foregroundColor(.yellow)
                            }

                            Text(customTitle ?? szenario.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }

                    // Beschreibung oder Zusatzinfo anzeigen
                    if customTitle == "Aktuelle Berechnung", let info = additionalInfo {
                        Text(info)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(szenario.beschreibung)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    // Hauptergebnis
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monatliche Rente (gesetzlich)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(NumberFormatter.currency.string(from: NSNumber(value: szenario.ergebnis.tatsaechlicheBruttoRente)) ?? "€0")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(empfehlungColor)

                        if zusatzrente > 0 {
                            Text("Inkl. Zusatzrenten: \(NumberFormatter.currency.string(from: NSNumber(value: szenario.ergebnis.tatsaechlicheBruttoRente + zusatzrente)) ?? "€0")")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }

                    // Rentenbeginn
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Rentenbeginn")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(szenario.ergebnis.tatsaechlicherRentenbeginn.deutscheFormatierung)
                                .font(.body)
                                .fontWeight(.medium)
                        }

                        Spacer()
                    }
                }
                .padding()
            }
            .groupBoxStyle(SzenarioGroupBoxStyle(empfehlung: szenario.empfehlung, isBest: isBest))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    private var empfehlungColor: Color {
        switch szenario.empfehlung {
        case .positiv: return .green
        case .neutral: return .blue
        case .negativ: return .orange
        }
    }
}

// MARK: - Szenario Detail View

struct SzenarioDetailView: View {
    let szenario: RentenSzenario
    let zusatzrente: Double
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(szenario.empfehlung.symbol)
                                .font(.title)

                            VStack(alignment: .leading) {
                                Text(szenario.name)
                                    .font(.title)
                                    .fontWeight(.bold)

                                Text(szenario.beschreibung)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()
                    }

                    // Hauptergebnis
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ergebnis")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gesetzliche Bruttorente: \(viewCurrency(szenario.ergebnis.tatsaechlicheBruttoRente))")

                                if zusatzrente > 0 {
                                    Text("Inkl. Zusatzrenten: \(viewCurrency(szenario.ergebnis.tatsaechlicheBruttoRente + zusatzrente))")
                                        .foregroundColor(.blue)
                                }

                                Text("Geschätzte Nettorente: \(viewCurrency(szenario.ergebnis.geschaetzteNettoRente + zusatzrente))")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Szenario Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func viewCurrency(_ value: Double) -> String {
        NumberFormatter.currency.string(from: NSNumber(value: value)) ?? "€0"
    }
}

// MARK: - Group Box Styles (bestehender Code NICHT gelöscht)

struct SzenarioGroupBoxStyle: GroupBoxStyle {
    let empfehlung: SzenarioEmpfehlung
    let isBest: Bool

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: isBest ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: shadowColor, radius: isBest ? 8 : 4, x: 0, y: isBest ? 4 : 2)
    }

    private var backgroundColor: Color {
        if isBest {
            return Color.yellow.opacity(0.05)
        }

        switch empfehlung {
        case .positiv:
            return Color.green.opacity(0.03)
        case .neutral:
            return Color.blue.opacity(0.03)
        case .negativ:
            return Color.orange.opacity(0.03)
        }
    }

    private var borderColor: Color {
        if isBest {
            return Color.yellow.opacity(0.4)
        }

        switch empfehlung {
        case .positiv:
            return Color.green.opacity(0.3)
        case .neutral:
            return Color.blue.opacity(0.3)
        case .negativ:
            return Color.orange.opacity(0.3)
        }
    }

    private var shadowColor: Color {
        if isBest {
            return Color.yellow.opacity(0.2)
        }

        switch empfehlung {
        case .positiv:
            return Color.green.opacity(0.1)
        case .neutral:
            return Color.blue.opacity(0.1)
        case .negativ:
            return Color.orange.opacity(0.1)
        }
    }
}

// MARK: - Quick Comparison Row (ebenfalls nicht entfernt!)

struct QuickComparisonRow: View {
    let szenario: RentenSzenario
    let baseline: RentenSzenario?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(szenario.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(NumberFormatter.currency.string(from: NSNumber(value: szenario.ergebnis.tatsaechlicheBruttoRente)) ?? "€0")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(empfehlungColor)
            }

            Spacer()

            if let baseline = baseline, baseline.name != szenario.name {
                let unterschied = szenario.ergebnis.tatsaechlicheBruttoRente - baseline.ergebnis.tatsaechlicheBruttoRente

                HStack(spacing: 4) {
                    Image(systemName: unterschied >= 0 ? "arrow.up" : "arrow.down")
                        .foregroundColor(unterschied >= 0 ? .green : .red)

                    Text("\(unterschied >= 0 ? "+" : "")\(NumberFormatter.currency.string(from: NSNumber(value: abs(unterschied))) ?? "€0")")
                        .font(.caption)
                        .foregroundColor(unterschied >= 0 ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var empfehlungColor: Color {
        switch szenario.empfehlung {
        case .positiv: return .green
        case .neutral: return .blue
        case .negativ: return .orange
        }
    }
}

// MARK: - Extensions (wieder vorhanden!)

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}
