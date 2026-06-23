import SwiftUI

struct AppearanceView: View {
    @ObservedObject var settings: Settings
    let isLoginEnabled: () -> Bool
    let setLoginEnabled: (Bool) -> Void

    @State private var loginOn: Bool = false

    var body: some View {
        Form {
            Section("Overlays") {
                Toggle("Show overlay on switch", isOn: bool(\.switchHUDEnabled))
                Toggle("Persistent label", isOn: bool(\.persistentLabelEnabled))
                Toggle("Show name in menu bar", isOn: bool(\.menuBarNameEnabled))
                Toggle("Run at Login", isOn: Binding(
                    get: { loginOn },
                    set: { newValue in setLoginEnabled(newValue); loginOn = isLoginEnabled() }))
            }

            Section("Sizes") {
                sizeRow(title: "Persistent label size",
                        value: number(\.labelFontSize),
                        range: Settings.labelFontSizeRange,
                        previewSize: settings.labelFontSize)
                sizeRow(title: "Switch HUD size",
                        value: number(\.hudFontSize),
                        range: Settings.hudFontSizeRange,
                        previewSize: settings.hudFontSize)
            }

            Section("Position") {
                Picker("Persistent label corner", selection: corner) {
                    ForEach(OverlayCorner.allCases, id: \.self) { c in
                        Text(cornerLabel(c)).tag(c)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginOn = isLoginEnabled() }
    }

    @ViewBuilder
    private func sizeRow(title: String, value: Binding<Double>,
                         range: ClosedRange<Double>, previewSize: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(previewSize)) pt").foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
            HStack {
                Spacer()
                OverlayCard(text: "Desktop", fontSize: CGFloat(previewSize))
                    .scaleEffect(previewSize > 34 ? 34 / previewSize : 1, anchor: .center)  // shrink large previews to fit
                    .frame(height: 64)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Bindings (every write goes through the persisting Settings setter)

    private func bool(_ key: ReferenceWritableKeyPath<Settings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: key] }, set: { settings[keyPath: key] = $0 })
    }
    private func number(_ key: ReferenceWritableKeyPath<Settings, Double>) -> Binding<Double> {
        Binding(get: { settings[keyPath: key] }, set: { settings[keyPath: key] = $0 })
    }
    private var corner: Binding<OverlayCorner> {
        Binding(get: { settings.overlayCorner }, set: { settings.overlayCorner = $0 })
    }

    private func cornerLabel(_ c: OverlayCorner) -> String {
        switch c {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}
