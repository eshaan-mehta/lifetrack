import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Money", systemImage: "dollarsign.circle") {
                Placeholder(title: "Money", detail: "Expenses and finances will live here.")
            }
            Tab("Habits", systemImage: "checkmark.circle") {
                Placeholder(title: "Habits", detail: "Daily habits will live here.")
            }
            Tab("Food", systemImage: "fork.knife") {
                Placeholder(title: "Food", detail: "Nutrition will live here.")
            }
            Tab("Status", systemImage: "info.circle") {
                StatusView()
            }
        }
    }
}

struct Placeholder: View {
    let title: String
    let detail: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "tray", description: Text(detail))
                .navigationTitle(title)
        }
    }
}
