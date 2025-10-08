//
//  ErgebnisView.swift
//  RentenRechner
//
//  Anzeige der Rentenberechnungsergebnisse
//

import SwiftUI

struct ErgebnisView: View {
    @EnvironmentObject var viewModel: RentenrechnerViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let ergebnis = viewModel.ergebnis {
                    LazyVStack(spacing: 24) {
                        headerCard(ergebnis)
                        
                        rentenpunkteCard(ergebnis)
                        
                        berechnungsdetailsCard(ergebnis)
                        
                        if !ergebnis.istAbschlagsfrei {
                            abschlagCard(ergebnis)
                        }
                        
                        zeitplanCard(ergebnis)
                        
                        weitereInformationenCard
                        
                        disclaimerCard
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                } else {
                    EmptyStateView()
                }
            }
            .navigationTitle("Ergebnis")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Header Card
    
    private func headerCard(_ ergebnis: RentenErgebnis) -> some View {
        GroupBox {
            VStack(spacing: 20) {
                // Hauptergebnis
                VStack(spacing: 8) {
                    Text("Ihre voraussichtliche Rente")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.formatCurrency(ergebnis.gesamtBruttoRente))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Brutto pro Monat (inkl. Zusatzrenten)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Zusätzliche Infos
                HStack(spacing: 20) {
                    VStack {
                        Text(viewModel.formatCurrency(ergebnis.geschaetzteNettoRente))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text("ca. Netto")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(ergebnis.rentenbeginnFormatted)
                            .font(.title3)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                        Text("Rentenbeginn")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .groupBoxStyle(HighlightGroupBoxStyle())
    }
    
    // MARK: - Rentenpunkte Card
    
    private func rentenpunkteCard(_ ergebnis: RentenErgebnis) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeader(title: "Rentenpunkte", icon: "chart.pie.fill")
                    Spacer()
                }
                
                // Visualisierung der Rentenpunkte
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bereits erworben")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.formatDecimal(ergebnis.aktuelleRentenpunkte))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zusätzlich bis Rente")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.formatDecimal(ergebnis.zusaetzlicheRentenpunkte))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Image(systemName: "equal")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gesamt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.formatDecimal(ergebnis.gesamtRentenpunkte))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                
                Divider()
                
                // Berechnungsdetails
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(
                        label: "Rentenwert",
                        value: "\(viewModel.formatCurrency(ergebnis.verwendeterRentenwert)) pro Punkt"
                    )
                    
                    DetailRow(
                        label: "Theoretische Bruttorente",
                        value: viewModel.formatCurrency(ergebnis.theoretischeBruttoRente)
                    )
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Berechnungsdetails Card
    
    private func berechnungsdetailsCard(_ ergebnis: RentenErgebnis) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Berechnungsdetails", icon: "function")
                
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(
                        label: "Gesamte Rentenpunkte",
                        value: viewModel.formatDecimal(ergebnis.gesamtRentenpunkte)
                    )
                    
                    DetailRow(
                        label: "× Rentenwert",
                        value: viewModel.formatCurrency(ergebnis.verwendeterRentenwert)
                    )
                    
                    DetailRow(
                        label: "= Theoretische Rente",
                        value: viewModel.formatCurrency(ergebnis.theoretischeBruttoRente),
                        isHighlighted: true
                    )
                    
                    if !ergebnis.istAbschlagsfrei {
                        DetailRow(
                            label: "- Abschlag (\(ergebnis.abschlagFormatted))",
                            value: "-\(viewModel.formatCurrency(ergebnis.abschlagBetrag))",
                            textColor: .red
                        )
                    }
                    
                    DetailRow(
                        label: "= Gesetzliche Bruttorente",
                        value: viewModel.formatCurrency(ergebnis.tatsaechlicheBruttoRente),
                        isHighlighted: true,
                        textColor: .blue
                    )
                    
                    DetailRow(
                        label: "- Summe Abzüge",
                        value: "-\(viewModel.formatCurrency(ergebnis.gesamtAbzuege))",
                        textColor: .red
                    )
                    
                    DetailRow(
                        label: "   Davon Steuer",
                        value: viewModel.formatCurrency(ergebnis.steuerBetrag),
                        textColor: .red
                    )
                    
                    if ergebnis.zusatzrenten > 0 {
                        DetailRow(
                            label: "+ Zusatzrenten",
                            value: viewModel.formatCurrency(ergebnis.zusatzrenten),
                            textColor: .green
                        )
                        
                        Divider()
                        
                        DetailRow(
                            label: "= Gesamte Nettorente",
                            value: viewModel.formatCurrency(ergebnis.geschaetzteNettoRente),
                            isHighlighted: true,
                            textColor: .primary
                        )
                    } else {
                        Divider()
                        
                        DetailRow(
                            label: "= Nettorente",
                            value: viewModel.formatCurrency(ergebnis.geschaetzteNettoRente),
                            isHighlighted: true,
                            textColor: .primary
                        )
                    }
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Abschlag Card
    
    private func abschlagCard(_ ergebnis: RentenErgebnis) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Rentenabschlag")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aufgrund des früheren Rentenbeginns wird ein Abschlag von **\(ergebnis.abschlagFormatted)** berechnet.")
                        .font(.body)
                    
                    DetailRow(
                        label: "Monate vor Regelalter",
                        value: "\(ergebnis.monateVorRegelalter)"
                    )
                    
                    DetailRow(
                        label: "Abschlag pro Monat",
                        value: "0,3%"
                    )
                    
                    DetailRow(
                        label: "Gesamtabschlag",
                        value: ergebnis.abschlagFormatted,
                        textColor: .orange
                    )
                    
                    DetailRow(
                        label: "Verlust pro Monat",
                        value: viewModel.formatCurrency(ergebnis.abschlagBetrag),
                        textColor: .red
                    )
                    
                    DetailRow(
                        label: "Verlust pro Jahr",
                        value: viewModel.formatCurrency(ergebnis.abschlagBetrag * 12),
                        textColor: .red
                    )
                }
                
                Divider()
                
                Text("💡 Tipp: Bei Rentenbeginn zur Regelaltersgrenze (\(ergebnis.regelalterFormatted)) entfällt der Abschlag.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .groupBoxStyle(WarningGroupBoxStyle())
    }
    
    // MARK: - Zeitplan Card
    
    private func zeitplanCard(_ ergebnis: RentenErgebnis) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Zeitplan", icon: "calendar")
                
                VStack(alignment: .leading, spacing: 12) {
                    TimelineRow(
                        icon: "clock",
                        title: "Regelaltersgrenze",
                        date: ergebnis.regelaltersgrenze,
                        description: "Abschlagsfreier Rentenbeginn",
                        isHighlighted: ergebnis.istAbschlagsfrei
                    )
                    
                    TimelineRow(
                        icon: "star.circle",
                        title: "Frühester abschlagsfreier Beginn",
                        date: ergebnis.fruehesterAbschlagsfreierBeginn,
                        description: "Bei 45 Beitragsjahren",
                        isHighlighted: false
                    )
                    
                    TimelineRow(
                        icon: ergebnis.istAbschlagsfrei ? "checkmark.circle.fill" : "calendar.badge.exclamationmark",
                        title: "Ihr gewählter Rentenbeginn",
                        date: ergebnis.tatsaechlicherRentenbeginn,
                        description: ergebnis.istAbschlagsfrei ? "Abschlagsfrei" : "Mit Abschlag",
                        isHighlighted: true,
                        textColor: ergebnis.istAbschlagsfrei ? .green : .orange
                    )
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Weitere Informationen Card
    
    private var weitereInformationenCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Weitere Informationen")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("Erfahren Sie mehr über Grundrente, Grundsicherung und weitere gesetzliche Hintergründe zur Rentenberechnung.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                NavigationLink(destination: InfoView().environmentObject(viewModel)) {
                    HStack {
                        Spacer()
                        Text("Informationen öffnen")
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Disclaimer Card
    
    private var disclaimerCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Rechtliche Hinweise")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("""
                Diese Berechnung ist unverbindlich und basiert auf den aktuellen Werten bzw. den von Ihnen eingegebenen Einstellungen.
                Die tatsächliche Rentenhöhe kann aufgrund von Gesetzesänderungen, Anpassungen der Rentenwerte oder individuellen Faktoren abweichen.
                
                Für eine verbindliche Auskunft über Ihre Rente wenden Sie sich an die Deutsche Rentenversicherung.
                """)
                .font(.caption)
                .foregroundColor(.secondary)
                
                Link("Deutsche Rentenversicherung", destination: URL(string: "https://www.deutsche-rentenversicherung.de")!)
                    .font(.caption)
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

// MARK: - Helper Views

struct DetailRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false
    var textColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(isHighlighted ? .semibold : .medium)
                .foregroundColor(textColor)
        }
        .font(isHighlighted ? .body : .caption)
    }
}

struct TimelineRow: View {
    let icon: String
    let title: String
    let date: Date
    let description: String
    var isHighlighted: Bool = false
    var textColor: Color = .primary
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(textColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(isHighlighted ? .semibold : .medium)
                    .foregroundColor(textColor)
                
                Text(date.deutscheFormatierung)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Keine Berechnung vorhanden")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Führen Sie zuerst eine Rentenberechnung durch, um hier die Ergebnisse zu sehen.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct HighlightGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.blue.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct WarningGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background(Color.orange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.orange.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
