import SwiftUI

/// Geometry for the row of round buttons along the bottom of the drawer. The same in
/// every drawer state, so buttons sit in identical spots whether listening or shooting.
enum DrawerControls {
    static let horizontalPadding: CGFloat = 28
    static let bottomPadding: CGFloat = 32
    static let size: CGFloat = 54
    /// Shutter diameter, and the height of every bottom row so button centers never move
    /// between drawer states.
    static let shutterSize: CGFloat = 76
    static let rowHeight: CGFloat = 76
}

/// The drawer's round glyph button. Shape and size are fixed; the fill follows context.
/// On the drawer: light gray, or solid when `prominent` (the active mode or the primary
/// action). Over the camera preview (`onImagery`): translucent dark with a white symbol,
/// or a white disc with a black symbol when `prominent`.
struct RoundGlyphButton: View {
    let systemImage: String
    let label: String
    var prominent = false
    var onImagery = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundGlyph(systemImage: systemImage, prominent: prominent, onImagery: onImagery)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The disc on its own, for labels of non-Button controls such as PhotosPicker.
struct RoundGlyph: View {
    let systemImage: String
    var prominent = false
    var onImagery = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(glyph)
            .frame(width: DrawerControls.size, height: DrawerControls.size)
            .background(fill, in: Circle())
    }

    private var fill: Color {
        if onImagery { return prominent ? .white : .black.opacity(0.45) }
        return prominent ? Color.primary : Color.primary.opacity(0.08)
    }

    private var glyph: Color {
        if onImagery { return prominent ? .black : .white }
        return prominent ? Color(.systemBackground) : Color.primary
    }
}

/// Two-segment mode selector spanning the bottom of the drawer: the two corner buttons
/// joined into one pill. Selected segment is solid; over imagery the pill goes dark with a
/// white selected segment. Same height as the round buttons so it sits on the same line.
struct ModePill: View {
    enum Mode { case voice, camera }

    let selected: Mode
    var onImagery = false
    let onSelect: (Mode) -> Void

    private let inset: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let segmentWidth = (geo.size.width - inset * 2) / 2
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(highlight)
                    .frame(width: segmentWidth, height: geo.size.height - inset * 2)
                    .offset(x: inset + (selected == .camera ? segmentWidth : 0))
                    .animation(.snappy(duration: 0.28), value: selected)
                HStack(spacing: 0) {
                    segment(.voice, icon: "mic.fill", title: "Voice")
                    segment(.camera, icon: "camera", title: "Camera")
                }
                .padding(inset)
            }
        }
        .frame(height: DrawerControls.size)
    }

    private func segment(_ mode: Mode, icon: String, title: String) -> some View {
        Button { onSelect(mode) } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(mode == selected ? selectedText : text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == selected ? .isSelected : [])
    }

    private var track: Color { onImagery ? .black.opacity(0.45) : Color.primary.opacity(0.08) }
    private var highlight: Color { onImagery ? .white : Color.primary }
    private var text: Color { onImagery ? .white : Color.primary }
    private var selectedText: Color { onImagery ? .black : Color(.systemBackground) }
}
