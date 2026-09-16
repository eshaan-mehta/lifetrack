import SwiftUI

@main
struct EverythingApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
