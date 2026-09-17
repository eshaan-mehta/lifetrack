import Foundation
import Observation
import UIKit

/// One thing eaten. Calories stay nil until the analysis step fills them in.
struct FoodEntry: Identifiable {
    enum Source {
        case description(String)
        case photo(UIImage)
    }

    let id = UUID()
    let date: Date
    let source: Source
    var calories: Int?

    var title: String {
        switch source {
        case .description(let text): return text
        case .photo: return "Photo"
        }
    }
}

/// In-memory log for now. Persisting to the Store comes with the analysis step.
@MainActor
@Observable
final class FoodLog {
    private(set) var entries: [FoodEntry] = []

    var todayEntries: [FoodEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var caloriesToday: Int {
        todayEntries.compactMap(\.calories).reduce(0, +)
    }

    func add(_ source: FoodEntry.Source, calories: Int? = nil) {
        entries.append(FoodEntry(date: Date(), source: source, calories: calories))
    }
}
