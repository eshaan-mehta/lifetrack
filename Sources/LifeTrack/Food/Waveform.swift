import SwiftUI

/// Siri-style listening waveform: three layered sine waves whose amplitude follows the
/// microphone level. Breathes gently when quiet, flattens when paused.
struct Waveform: View {
    let level: Float
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active)) { context in
            Canvas { canvas, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let amplitude = active ? 0.14 + Double(level) * 0.86 : 0.04
                let midY = size.height / 2
                let reach = size.height / 2 - 3

                for wave in 0..<3 {
                    let frequency = 1.5 + Double(wave) * 0.55
                    let speed = 2.0 + Double(wave) * 0.7
                    let scale = 1.0 - Double(wave) * 0.3
                    var path = Path()
                    for x in stride(from: 0.0, through: size.width, by: 2) {
                        let nx = x / size.width
                        let envelope = sin(nx * .pi)   // taper at both ends
                        let y = midY + sin(nx * .pi * 2 * frequency + time * speed)
                            * amplitude * scale * envelope * reach
                        if x == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    canvas.stroke(
                        path,
                        with: .color(.primary.opacity(0.95 - Double(wave) * 0.3)),
                        style: StrokeStyle(lineWidth: 3 - CGFloat(wave) * 0.6, lineCap: .round)
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}
