import AppKit
import SwiftUI

@MainActor
final class OverlayController {
    private let settings: Settings
    private let hudPanel = OverlayPanel()
    private let labelPanel = OverlayPanel()
    private var hudDismissWork: DispatchWorkItem?

    init(settings: Settings) {
        self.settings = settings
    }

    private func card(_ text: String, fontSize: CGFloat, padding: CGFloat) -> NSView {
        let host = NSHostingView(rootView: OverlayCardView(text: text, fontSize: fontSize, padding: padding))
        host.layout()
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        return host
    }

    // MARK: HUD

    func flashHUD(_ name: String) {
        guard settings.switchHUDEnabled else { return }
        let view = card(name, fontSize: 34, padding: 28)
        hudPanel.setContentSize(view.fittingSize)
        hudPanel.contentView = view
        centerOnActiveScreen(hudPanel)
        hudPanel.alphaValue = 0
        hudPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; hudPanel.animator().alphaValue = 1 }

        hudDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fadeOutHUD() }
        hudDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func fadeOutHUD() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            hudPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in self?.hudPanel.orderOut(nil) })
    }

    // MARK: Persistent label

    func updatePersistentLabel(_ name: String?) {
        guard settings.persistentLabelEnabled, let name else {
            labelPanel.orderOut(nil)
            return
        }
        let view = card(name, fontSize: 13, padding: 10)
        labelPanel.setContentSize(view.fittingSize)
        labelPanel.contentView = view
        positionInCorner(labelPanel, corner: settings.overlayCorner)
        labelPanel.orderFrontRegardless()
    }

    func refreshConfiguration() {
        if !settings.persistentLabelEnabled { labelPanel.orderOut(nil) }
    }

    // MARK: Positioning

    private func centerOnActiveScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        let s = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: f.midX - s.width / 2, y: f.midY - s.height / 2))
    }

    private func positionInCorner(_ panel: NSPanel, corner: OverlayCorner) {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        let s = panel.frame.size
        let m: CGFloat = 16
        let x: CGFloat = (corner == .topLeft || corner == .bottomLeft) ? v.minX + m : v.maxX - s.width - m
        let y: CGFloat = (corner == .topLeft || corner == .topRight) ? v.maxY - s.height - m : v.minY + m
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct OverlayCardView: View {
    let text: String
    let fontSize: CGFloat
    let padding: CGFloat
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, padding)
            .padding(.vertical, padding * 0.6)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .fixedSize()
    }
}
