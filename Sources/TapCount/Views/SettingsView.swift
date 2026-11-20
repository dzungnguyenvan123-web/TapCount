import AppKit
import SwiftUI
import TapCountCore

struct SettingsView: View {
    let store: TaskStore
    let launchAtLogin: LaunchAtLoginManager

    private var dataFileURL: URL {
        JSONFilePersistence().fileURL
    }

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Launch TapCount at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                if let message = launchAtLogin.statusMessage {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(launchAtLogin.requiresApproval ? .orange : .secondary)

                        if launchAtLogin.requiresApproval {
                            Button("Open Login Items Settings…") {
                                launchAtLogin.openSystemSettingsLoginItems()
                            }
                            .controlSize(.small)
                        }
                    }
                } else {
                    Text("Automatically start TapCount when you log in to your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Menu Bar") {
                Toggle(
                    "Show today's tap count in menu bar",
                    isOn: Binding(
                        get: { store.preferences.showCountInMenuBar },
                        set: { store.preferences.showCountInMenuBar = $0 }
                    )
                )
            }

            Section("Data Storage") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local JSON Store")
                        Text(dataFileURL.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([dataFileURL])
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 300)
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
