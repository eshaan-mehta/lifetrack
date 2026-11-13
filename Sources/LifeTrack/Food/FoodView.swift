import SwiftUI

struct FoodView: View {
    @Environment(FoodLog.self) private var log
    @AppStorage("dailyCalorieGoal") private var goal = 2000

    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var showAdd = false
    @State private var showCalendar = false
    @State private var initialMode: AddFoodSheet.Mode = .voice

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DayHeader(day: day, isToday: isToday,
                              onPrevious: { shift(by: -1) },
                              onNext: { shift(by: 1) },
                              onPick: { showCalendar = true })
                    CalorieRing(consumed: log.calories(on: day), goal: goal)
                        .frame(maxWidth: 300)
                        .frame(height: 300)
                    DayList(title: listTitle, entries: log.entries(on: day), isToday: isToday)
                        .padding(.horizontal)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // Inset rather than overlay so the list always scrolls clear of the button.
            .safeAreaInset(edge: .bottom, spacing: 0) { addBar }
            .sheet(isPresented: $showAdd) {
                AddFoodSheet(
                    initialMode: initialMode,
                    onDescription: { log.add(.description($0), on: day) },
                    onPhoto: { log.add(.photo($0), on: day) }
                )
            }
            .sheet(isPresented: $showCalendar) {
                CalendarSheet(day: $day)
            }
        }
        .onAppear(perform: applyDebugFlags)
    }

    private var listTitle: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    // MARK: Day navigation

    private func shift(by days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: day) else { return }
        go(to: next)
    }

    private func go(to date: Date) {
        let target = Calendar.current.startOfDay(for: min(date, .now))
        withAnimation(.snappy) { day = target }
    }

    // MARK: Add button

    /// Bottom band: content fades out over the top strip, then the button sits on solid
    /// background so nothing shows behind it.
    private var addBar: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 36)
                .allowsHitTesting(false)
            addButton
                .padding(.top, 4)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        }
    }

    private var addButton: some View {
        Button {
            initialMode = .voice
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 68, height: 68)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.primary)
        // Hidden while a sheet is up so its glow does not bleed through the glass.
        .opacity(showAdd || showCalendar ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: showAdd || showCalendar)
        .accessibilityLabel("Add food")
    }

    /// Launch arguments used to screenshot specific states from the command line.
    private func applyDebugFlags() {
        if DebugFlags.demoFood && log.entries.isEmpty {
            log.add(.description("Oatmeal with blueberries and honey"), calories: 320)
            log.add(.description("Grilled chicken salad"), calories: 540)
            log.add(.description("Oat milk latte"), calories: 190)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            log.add(.description("Greek yogurt with granola"), on: yesterday, calories: 280)
            log.add(.description("Burrito bowl"), on: yesterday, calories: 760)
            log.add(.description("Pasta with tomato sauce"), on: yesterday, calories: 650)
        }
        if DebugFlags.dayOffset != 0,
           let start = Calendar.current.date(byAdding: .day, value: DebugFlags.dayOffset, to: .now) {
            day = Calendar.current.startOfDay(for: start)
        }
        switch DebugFlags.show {
        case "add", "voice":
            initialMode = .voice
            showAdd = true
        case "camera":
            initialMode = .camera
            showAdd = true
        case "calendar":
            showCalendar = true
        default:
            break
        }
    }
}

/// The date where the title used to be, with a small down chevron to say it opens the
/// calendar, and the step arrows right beside it. Getting back to today lives in the
/// calendar sheet.
private struct DayHeader: View {
    let day: Date
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onPick: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPick) {
                HStack(spacing: 6) {
                    Text(day.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(day.formatted(.dateTime.month(.wide).day().year()))
            .accessibilityHint("Opens a calendar to pick a day")

            HStack(spacing: 0) {
                stepButton("chevron.left", label: "Previous day", action: onPrevious)
                stepButton("chevron.right", label: "Next day", action: onNext)
                    .disabled(isToday)
                    .opacity(isToday ? 0.3 : 1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .animation(.snappy, value: isToday)
    }

    /// Bare glyph, no disc; the frame keeps a comfortable tap target.
    private func stepButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Monthly calendar. Picking a day closes it; Today jumps back and closes it.
private struct CalendarSheet: View {
    @Binding var day: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Pick a day").font(.headline)
                Spacer()
                Button("Today") {
                    day = Calendar.current.startOfDay(for: .now)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(Calendar.current.isDateInToday(day))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            DatePicker("Day", selection: $day, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 12)
                .onChange(of: day) { _, _ in dismiss() }

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(470)])
        .presentationDragIndicator(.visible)
        .tint(.primary)
    }
}

private struct DayList: View {
    let title: String
    let entries: [FoodEntry]
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .contentTransition(.numericText())
            if entries.isEmpty {
                Text(isToday
                     ? "Nothing logged yet. Tap + and say what you ate or snap a photo."
                     : "Nothing logged on this day. Tap + to add something.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        FoodRow(entry: entry)
                        if entry.id != entries.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

private struct FoodRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .lineLimit(2)
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let kcal = entry.calories {
                Text("\(kcal.formatted()) kcal")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            } else {
                Text("Analyzing…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch entry.source {
        case .photo(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        case .description:
            Image(systemName: "waveform")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
