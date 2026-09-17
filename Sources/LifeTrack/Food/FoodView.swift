import SwiftUI

struct FoodView: View {
    @Environment(FoodLog.self) private var log
    @AppStorage("dailyCalorieGoal") private var goal = 2000

    @State private var showAdd = false
    @State private var showCamera = false
    @State private var cameraRequested = false
    @State private var initialMode: AddFoodSheet.Mode = .menu

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenHeader(title: "Food")
                    CalorieRing(consumed: log.caloriesToday, goal: goal)
                        .frame(maxWidth: 300)
                        .frame(height: 300)
                    TodayList(entries: log.todayEntries)
                        .padding(.horizontal)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // Inset rather than overlay so the list always scrolls clear of the button.
            .safeAreaInset(edge: .bottom, spacing: 0) { addBar }
            .sheet(isPresented: $showAdd, onDismiss: presentCameraIfRequested) {
                AddFoodSheet(
                    initialMode: initialMode,
                    onDescription: { log.add(.description($0)) },
                    onCamera: {
                        cameraRequested = true
                        showAdd = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCapture { log.add(.photo($0)) }
                    .ignoresSafeArea()
            }
        }
        .onAppear(perform: applyDebugFlags)
    }

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
            initialMode = .menu
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 68, height: 68)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.green)
        // Hidden while the drawer is up so its glow does not bleed through the glass.
        .opacity(showAdd || showCamera ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: showAdd)
        .accessibilityLabel("Add food")
    }

    private func presentCameraIfRequested() {
        guard cameraRequested else { return }
        cameraRequested = false
        showCamera = true
    }

    /// Launch arguments used to screenshot specific states from the command line.
    private func applyDebugFlags() {
        if DebugFlags.demoFood && log.entries.isEmpty {
            log.add(.description("Oatmeal with blueberries and honey"), calories: 320)
            log.add(.description("Grilled chicken salad"), calories: 540)
            log.add(.description("Oat milk latte"), calories: 190)
        }
        switch DebugFlags.show {
        case "add":
            initialMode = .menu
            showAdd = true
        case "voice":
            initialMode = .voice
            showAdd = true
        default:
            break
        }
    }
}

private struct TodayList: View {
    let entries: [FoodEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.title3.weight(.semibold))
            if entries.isEmpty {
                Text("Nothing logged yet. Tap + and say what you ate or snap a photo.")
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
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
