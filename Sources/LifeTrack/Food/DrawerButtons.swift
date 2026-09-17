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

/// The drawer's round glyph button. Shape and size are fixed; the fill follows context:
/// light gray on the drawer, solid for the primary action (`prominent`), translucent dark
/// with a white symbol over the camera preview (`onImagery`).
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
        if onImagery { return .black.opacity(prominent ? 0.85 : 0.45) }
        return prominent ? Color.primary : Color.primary.opacity(0.08)
    }

    private var glyph: Color {
        if onImagery { return .white }
        return prominent ? Color(.systemBackground) : Color.primary
    }
}
