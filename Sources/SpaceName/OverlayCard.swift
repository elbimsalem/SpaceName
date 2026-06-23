import SwiftUI

/// The translucent name card shown by the overlays — shared so the Appearance
/// tab previews match the real HUD/label exactly. Padding derives from the font
/// size so a single number drives the whole card.
struct OverlayCard: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, fontSize * 0.8)
            .padding(.vertical, fontSize * 0.5)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: fontSize * 0.45, style: .continuous))
            .fixedSize()
    }
}
