import SwiftUI

enum AppTab: Hashable {
    case money, habits, food, status
}

struct ContentView: View {
    @State private var tab: AppTab = DebugFlags.startTab == "food" ? .food : .money

    var body: some View {
        TabView(selection: $tab) {
            Tab("Money", systemImage: "dollarsign.circle", value: .money) {
                Placeholder(title: "Money", detail: "Expenses and finances will live here.")
            }
            Tab("Habits", systemImage: "checkmark.circle", value: .habits) {
                Placeholder(title: "Habits", detail: "Daily habits will live here.")
            }
            Tab("Food", systemImage: "fork.knife", value: .food) {
                FoodView()
            }
            Tab("Status", systemImage: "info.circle", value: .status) {
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
