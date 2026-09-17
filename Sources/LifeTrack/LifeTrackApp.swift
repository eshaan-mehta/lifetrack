import SwiftUI

@main
struct LifeTrackApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = Store()
    @State private var foodLog = FoodLog()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(foodLog)
                // Fetch the on-device speech model in the background so voice capture
                // never has to wait for it. Retries on each return to the foreground.
                .task { SpeechModelInstaller.shared.warmUp() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { SpeechModelInstaller.shared.warmUp() }
                }
        }
    }
}
