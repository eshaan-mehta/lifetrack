import SwiftUI

/// Compact large title that sits right under the status bar. Used instead of the
/// navigation bar's large title, which leaves a big empty band at the top.
struct ScreenHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 2)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
