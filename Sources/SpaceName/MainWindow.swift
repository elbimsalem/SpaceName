import SwiftUI
import AppKit

enum WindowTab: Hashable { case spaceNames, appearance }

@MainActor
final class WindowTabSelection: ObservableObject {
    @Published var tab: WindowTab = .spaceNames
}

@MainActor
final class MainWindowController {
    private var window: NSWindow?
    private let viewModel: SpacesViewModel
    private let settings: Settings
    private let isLoginEnabled: () -> Bool
    private let setLoginEnabled: (Bool) -> Void
    private let selection = WindowTabSelection()

    init(viewModel: SpacesViewModel,
         settings: Settings,
         isLoginEnabled: @escaping () -> Bool,
         setLoginEnabled: @escaping (Bool) -> Void) {
        self.viewModel = viewModel
        self.settings = settings
        self.isLoginEnabled = isLoginEnabled
        self.setLoginEnabled = setLoginEnabled
    }

    func show(tab: WindowTab = .spaceNames) {
        viewModel.reload()
        selection.tab = tab
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let root = MainView(viewModel: viewModel, settings: settings, selection: selection,
                            isLoginEnabled: isLoginEnabled, setLoginEnabled: setLoginEnabled)
        let hosting = NSHostingController(rootView: root)
        let w = NSWindow(contentViewController: hosting)
        w.title = "SpaceName"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.setContentSize(NSSize(width: 420, height: 520))
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

private struct MainView: View {
    @ObservedObject var viewModel: SpacesViewModel
    @ObservedObject var settings: Settings
    @ObservedObject var selection: WindowTabSelection
    let isLoginEnabled: () -> Bool
    let setLoginEnabled: (Bool) -> Void

    var body: some View {
        TabView(selection: $selection.tab) {
            SpaceNamesView(viewModel: viewModel)
                .tabItem { Label("Space Names", systemImage: "rectangle.3.group") }
                .tag(WindowTab.spaceNames)

            AppearanceView(settings: settings,
                           isLoginEnabled: isLoginEnabled,
                           setLoginEnabled: setLoginEnabled)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
                .tag(WindowTab.appearance)
        }
        .frame(minWidth: 400, minHeight: 480)
        .padding(.top, 4)
    }
}

private struct SpaceNamesView: View {
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
        .toolbar { Button { viewModel.reload() } label: { Image(systemName: "arrow.clockwise") } }
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
                .onChange(of: text) { _, newValue in viewModel.rename(space, to: newValue) }
                .onSubmit { viewModel.rename(space, to: text) }
            if space.isCurrent {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            }
        }
        .onAppear { text = viewModel.customName(for: space) }
    }
}
