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

    func entries(on day: Date) -> [FoodEntry] {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date > $1.date }
    }

    func calories(on day: Date) -> Int {
        entries(on: day).compactMap(\.calories).reduce(0, +)
    }

    /// Logs to the given day. Today gets the real time; a past day gets now's time of day
    /// placed on that date, so backfilled entries still sort sensibly.
    func add(_ source: FoodEntry.Source, on day: Date = .now, calories: Int? = nil) {
        entries.append(FoodEntry(date: Self.timestamp(on: day), source: source, calories: calories))
    }

    private static func timestamp(on day: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return .now }
        let time = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0,
                             second: time.second ?? 0, of: day) ?? day
    }
}
