import SwiftUI
import AppKit

@MainActor
final class MainWindowController {
    private var window: NSWindow?
    private let viewModel: SpacesViewModel

    init(viewModel: SpacesViewModel) { self.viewModel = viewModel }

    func show() {
        viewModel.reload()
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: MainView(viewModel: viewModel))
        let w = NSWindow(contentViewController: hosting)
        w.title = "SpaceName"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.setContentSize(NSSize(width: 380, height: 460))
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

private struct MainView: View {
    @ObservedObject var viewModel: SpacesViewModel

    var body: some View {
        Group {
            if viewModel.displays.isEmpty {
                ContentUnavailableView("Spaces unavailable",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("SpaceName couldn't read your Spaces. Make sure you're on a desktop and try again."))
            } else {
                List {
                    ForEach(viewModel.displays, id: \.displayID) { display in
                        Section(header: Text(displayTitle(display))) {
                            ForEach(display.spaces, id: \.uuid) { space in
                                SpaceRow(space: space, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
        .toolbar {
            Button { viewModel.reload() } label: { Image(systemName: "arrow.clockwise") }
        }
    }

    private func displayTitle(_ d: DisplaySpaces) -> String {
        viewModel.displays.count > 1 ? "Display: \(d.displayID)" : "Desktops"
    }
}

private struct SpaceRow: View {
    let space: SpaceInfo
    @ObservedObject var viewModel: SpacesViewModel
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text("\(space.desktopNumber)")
                .font(.system(.body, design: .rounded)).foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            TextField("Desktop \(space.desktopNumber)", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { viewModel.rename(space, to: text) }
            if space.isCurrent {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            }
        }
        .onAppear { text = viewModel.customName(for: space) }
    }
}
