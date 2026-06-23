import AppKit

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let settings: Settings
    private let store: SpaceStore
    private let monitor = CGSSpacesMonitor()
    private let overlay: OverlayController
    private let viewModel: SpacesViewModel
    private var statusController: StatusItemController!
    private var windowController: MainWindowController!

    override init() {
        let defaults = UserDefaults.standard
        self.settings = Settings(defaults: defaults)
        self.store = SpaceStore(directory: SpaceStore.defaultDirectory())
        self.overlay = OverlayController(settings: settings)
        self.viewModel = SpacesViewModel(provider: monitor, store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = MainWindowController(
            viewModel: viewModel,
            settings: settings,
            isLoginEnabled: { LoginItem.isEnabled },
            setLoginEnabled: { [weak self] on in self?.setLoginEnabled(on) })

        statusController = StatusItemController(
            settings: settings,
            onOpen: { [weak self] in self?.windowController.show(tab: .spaceNames) },
            onOpenSettings: { [weak self] in self?.windowController.show(tab: .appearance) },
            onUninstall: { Uninstaller.run() })

        settings.onChange = { [weak self] in
            self?.applyCurrentState()
            self?.statusController.rebuildMenu()
        }
        viewModel.onRename = { [weak self] in self?.applyCurrentState() }
        monitor.onChange = { [weak self] _ in self?.handleSpaceChange() }
        monitor.start()

        applyCurrentState(flashHUD: false)
    }

    private func setLoginEnabled(_ on: Bool) {
        do { try LoginItem.setEnabled(on) }
        catch {
            let a = NSAlert(error: error); a.messageText = "Couldn't change the login item."; a.runModal()
        }
        statusController.rebuildMenu()
    }

    private func handleSpaceChange() {
        viewModel.reload()
        applyCurrentState(flashHUD: true)
    }

    private func applyCurrentState(flashHUD: Bool = false) {
        overlay.refreshConfiguration()
        let active = monitor.currentActiveSpace()
        let name = active.map { NameResolver.displayName(for: $0, store: store) }
        if flashHUD, let name { overlay.flashHUD(name) }
        overlay.updatePersistentLabel(name)
        statusController.setCurrentName(name)
    }
}
