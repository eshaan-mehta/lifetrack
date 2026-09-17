import SwiftUI

@main
struct LifeTrackApp: App {
    @State private var store = Store()
    @State private var foodLog = FoodLog()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(foodLog)
        }
    }
}
