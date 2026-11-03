import SwiftUI

public struct PreferencesView: View {
    @State private var columns: Int = 7
    @State private var rows: Int = 5
    @State private var hiddenCount: Int = 0
    @State private var savedMessage: String?

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("Grid Dimensions").font(.headline)) {
                Picker("Columns per page:", selection: $columns) {
                    Text("5 Columns").tag(5)
                    Text("6 Columns").tag(6)
                    Text("7 Columns (Classic Apple)").tag(7)
                    Text("8 Columns").tag(8)
                    Text("9 Columns (Ultra-wide)").tag(9)
                }

                Picker("Rows per page:", selection: $rows) {
                    Text("4 Rows").tag(4)
                    Text("5 Rows (Classic Apple)").tag(5)
                    Text("6 Rows").tag(6)
                }

                Text("Items per page: \(columns * rows)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Global Shortcuts").font(.headline)) {
                HStack {
                    Text("Toggle Launchpad:")
                    Spacer()
                    Text("⌥ Option + Space  hoặc  F4")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            Section(header: Text("App Management").font(.headline)) {
                HStack {
                    Text("Hidden Applications: \(hiddenCount)")
                    Spacer()
                    Button("Unhide All") {
                        unhideAllApps()
                    }
                    .disabled(hiddenCount == 0)
                }

                HStack {
                    Text("Layout Arrangement:")
                    Spacer()
                    Button("Reset to Default Layout") {
                        resetLayout()
                    }
                }
            }

            if let message = savedMessage {
                Section {
                    Text(message)
                        .foregroundColor(.green)
                        .font(.footnote)
                }
            }
        }
        .padding(20)
        .frame(width: 460, height: 340)
        .onAppear {
            loadConfig()
        }
        .onChange(of: columns) { _, _ in saveConfig() }
        .onChange(of: rows) { _, _ in saveConfig() }
    }

    private func loadConfig() {
        let config = LayoutPersistenceService.shared.load()
        self.columns = config.columnsCount
        self.rows = config.rowsCount
        self.hiddenCount = config.hiddenAppIds.count
    }

    private func saveConfig() {
        var config = LayoutPersistenceService.shared.load()
        config.columnsCount = columns
        config.rowsCount = rows
        LayoutPersistenceService.shared.save(config)
        showMessage("Changes saved! Updates on next Launchpad open.")
    }

    private func unhideAllApps() {
        var config = LayoutPersistenceService.shared.load()
        config.hiddenAppIds.removeAll()
        LayoutPersistenceService.shared.save(config)
        self.hiddenCount = 0
        showMessage("All apps unhidden successfully!")
    }

    private func resetLayout() {
        LayoutPersistenceService.shared.reset()
        loadConfig()
        showMessage("Layout reset to default!")
    }

    private func showMessage(_ msg: String) {
        withAnimation {
            savedMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                savedMessage = nil
            }
        }
    }
}
