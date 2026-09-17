import SwiftUI

/// Smoke test screen: proves the binary runs and SQLite opened.
struct StatusView: View {
    @Environment(Store.self) private var store

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(title: "Status")
                List {
                    Section("Database") {
                        LabeledContent("SQLite", value: store.sqliteVersion.isEmpty ? "not open" : store.sqliteVersion)
                        if let error = store.openError {
                            LabeledContent("Error", value: error)
                        }
                        Text(store.url.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Section("Build") {
                        LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
                        LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? "?")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
