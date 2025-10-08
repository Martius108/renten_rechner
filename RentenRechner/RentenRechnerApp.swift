//
//  App.swift
//  RentenRechner
//
//  Haupteinstiegspunkt der iOS RentenRechner App
//

import SwiftUI
import SwiftData

@main
struct RentenRechnerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // SwiftData Container
        .modelContainer(for: [AppSettings.self, Person.self])
        .environment(\.locale, Locale(identifier: "de_DE"))
    }
    
    // MARK: - App Configuration
    
    private func configureAppearance() {
        // Navigation Bar Appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.systemBackground
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Tab Bar Appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Tint Color für die gesamte App
        UIView.appearance().tintColor = UIColor.systemBlue
    }
}
