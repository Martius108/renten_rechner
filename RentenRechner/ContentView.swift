//
//  ContentView.swift
//  RentenRechner
//
//  Haupt-Tab-View der Renten-App
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RentenrechnerViewModel()
    
    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            
            EingabeView()
                .tabItem {
                    Image(systemName: "plus.slash.minus")
                    Text("Berechnung")
                }
                .tag(0)
            
            ErgebnisView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Ergebnis")
                }
                .tag(1)
                .disabled(!viewModel.hatErgebnis)
            
            SzenarienView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Szenarien")
                }
                .tag(2)
                .disabled(viewModel.szenarien.isEmpty)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .environmentObject(viewModel)
        .accentColor(.blue)
        .onAppear {
            viewModel.loadPersonData()
        }
        .alert("Fehler", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.fehlerMeldung ?? "Ein unbekannter Fehler ist aufgetreten")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

