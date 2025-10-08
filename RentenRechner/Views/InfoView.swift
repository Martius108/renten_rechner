//
//  InfoView.swift
//  RentenRechner
//
//  Informationsseite mit rechtlichen Hinweisen und App-Informationen
//

import SwiftUI

struct InfoView: View {
    @EnvironmentObject var viewModel: RentenrechnerViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    appInfoSection
                    
                    berechnungsgrundlagenSection
                    
                    grundrenteSection       // 🆕 NEUER ABSCHNITT
                    
                    rechtlicheHinweiseSection
                    
                    kontaktSection
                    
                    impressumSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Informationen")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                // App Icon und Name
                HStack {
                    Image(systemName: "eurosign.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RentenRechner Deutschland")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Entwickelt für iOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Beschreibung
                VStack(alignment: .leading, spacing: 12) {
                    Text("Über diese App")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("""
                    Der RentenRechner Deutschland hilft Ihnen dabei, Ihre zu erwartende gesetzliche Rente nach deutschem Rentenrecht zu berechnen.
                    
                    Die App berücksichtigt die aktuell hinterlegten Werte (\(viewModel.settings.gueltigkeitsjahr)) und bietet verschiedene Szenarien für Ihren Rentenbeginn.
                    
                    Wichtig: Diese App ersetzt keine professionelle Beratung und die Berechnungen sind unverbindlich.
                    """)
                    .font(.body)
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Berechnungsgrundlagen Section
    
    private var berechnungsgrundlagenSection: some View {
        GroupBox {
            let settings = viewModel.settings
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "function")
                        .foregroundColor(.blue)
                    Text("Berechnungsgrundlagen \(settings.gueltigkeitsjahr)")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    InfoDetailRow(
                        title: "Durchschnittsentgelt",
                        value: viewModel.formatCurrency(settings.durchschnittsentgelt),
                        description: "Basis für die Berechnung der Rentenpunkte"
                    )
                    
                    InfoDetailRow(
                        title: "Aktueller Rentenwert",
                        value: "\(viewModel.formatCurrency(settings.rentenwert)) pro Punkt",
                        description: "Wert eines Rentenpunktes"
                    )
                    
                    InfoDetailRow(
                        title: "Beitragsbemessungsgrenze",
                        value: viewModel.formatCurrency(settings.beitragsbemessungsgrenze),
                        description: "Maximales beitragspflichtiges Jahreseinkommen"
                    )
                    
                    InfoDetailRow(
                        title: "Abschlag pro Monat",
                        value: "0,3%",
                        description: "Bei früherem Renteneintritt vor Regelaltersgrenze"
                    )
                }
                
                Divider()
                
                Text("Diese Werte basieren auf der aktuellen Gesetzgebung und können sich in Zukunft ändern.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Grundrente / Grundsicherung Section (🆕)
    
    private var grundrenteSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "shield.lefthalf.fill")
                        .foregroundColor(.purple)
                    Text("Grundrente & Grundsicherung")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("""
                    In Deutschland gibt es keine einheitliche gesetzliche „Mindestrente“. Stattdessen greifen zwei Unterstützungsmechanismen:
                    
                    • Grundrente (seit 2021):
                      Versicherte mit mindestens 33 Jahren Grundrentenzeiten (z. B. Arbeit, Kindererziehung) erhalten einen Zuschlag, wenn ihre Rente sehr niedrig ist. Dadurch werden Rentenpunkte aufgestockt. Es gibt keinen Unterschied zwischen Männern und Frauen.
                    
                    • Grundsicherung im Alter:
                      Liegt das Gesamteinkommen unter dem Existenzminimum (abhängig von Wohnort und Miete), kann Grundsicherung beantragt werden. Diese wird vom Sozialamt gezahlt.
                    
                    Tipp: Falls Ihre berechnete Rente unter diesem Niveau liegt, besteht evtl. Anspruch auf Grundrente oder Grundsicherung.
                    """)
                    .font(.body)
                    .foregroundColor(.primary)
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Rechtliche Hinweise Section
    
    private var rechtlicheHinweiseSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Rechtliche Hinweise")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    DisclaimerPoint(
                        icon: "info.circle",
                        title: "Unverbindliche Berechnung",
                        text: "Alle Berechnungen sind unverbindlich und dienen nur zur groben Orientierung. Die tatsächliche Rentenhöhe kann abweichen."
                    )
                    
                    DisclaimerPoint(
                        icon: "calendar.badge.exclamationmark",
                        title: "Aktuelle Werte",
                        text: "Die Berechnung basiert auf den hinterlegten Werten (\(viewModel.settings.gueltigkeitsjahr)). Zukünftige Änderungen der Rentenformel oder -werte sind nicht berücksichtigt."
                    )
                    
                    DisclaimerPoint(
                        icon: "person.2",
                        title: "Individuelle Faktoren",
                        text: "Persönliche Faktoren wie Kindererziehungszeiten, Arbeitslosigkeit oder Krankheit werden vereinfacht behandelt."
                    )
                    
                    DisclaimerPoint(
                        icon: "building.columns",
                        title: "Offizielle Beratung",
                        text: "Für verbindliche Auskünfte wenden Sie sich an die Deutsche Rentenversicherung oder einen Rentenberater."
                    )
                }
                
                Divider()
                
                Text("Haftungsausschluss: Der Entwickler übernimmt keine Haftung für die Richtigkeit der Berechnungen oder daraus resultierende Entscheidungen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Kontakt Section
    
    private var kontaktSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.green)
                    Text("Hilfe & Kontakt")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 12) {
                    LinkRow(
                        icon: "safari",
                        title: "Deutsche Rentenversicherung",
                        subtitle: "Offizielle Website",
                        url: "https://www.deutsche-rentenversicherung.de"
                    )
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
    
    // MARK: - Impressum Section
    
    private var impressumSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.gray)
                    Text("Impressum")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("RentenRechner Deutschland")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("""
                    Entwickelt als Demo-App
                    Nur für Bildungszwecke
                    
                    Basierend auf öffentlich zugänglichen Informationen 
                    der Deutschen Rentenversicherung
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Datenschutz")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Diese App speichert alle Daten lokal auf Ihrem Gerät. Es werden keine Daten an externe Server übertragen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }
}

// MARK: - Helper Views

struct InfoDetailRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DisclaimerPoint: View {
    let icon: String
    let title: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
