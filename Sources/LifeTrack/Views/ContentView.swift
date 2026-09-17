import SwiftUI

enum AppTab: Hashable {
    case money, habits, food, status
}

struct ContentView: View {
    @State private var tab: AppTab = {
        switch DebugFlags.startTab {
        case "habits": return .habits
        case "food": return .food
        case "status": return .status
        default: return .money
        }
    }()

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
            VStack(spacing: 0) {
                ScreenHeader(title: title)
                ContentUnavailableView(title, systemImage: "tray", description: Text(detail))
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
