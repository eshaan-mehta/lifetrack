import SwiftUI

/// Big number for today's calories with a ring showing progress toward the goal.
struct CalorieRing: View {
    let consumed: Int
    let goal: Int

    private var fraction: Double { goal > 0 ? Double(consumed) / Double(goal) : 0 }
    private var progress: Double { min(fraction, 1) }
    private var overGoal: Bool { fraction > 1 }
    private var percent: Int { Int((fraction * 100).rounded()) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 22, lineCap: .round))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringStyle, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)
            VStack(spacing: 4) {
                Text(consumed.formatted())
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("of \(goal.formatted()) kcal")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(overGoal ? "\(percent)% · over goal" : "\(percent)%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(overGoal ? Color.orange : Color.secondary)
            }
        }
        .padding(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(consumed) of \(goal) calories eaten today")
    }

    private var ringStyle: AnyShapeStyle {
        if overGoal {
            return AnyShapeStyle(Color.orange)
        }
        return AnyShapeStyle(AngularGradient(colors: [.green, .mint, .green], center: .center))
    }
}
