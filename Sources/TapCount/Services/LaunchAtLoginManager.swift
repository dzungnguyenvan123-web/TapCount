import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginManager {
    private(set) var isEnabled: Bool = false
    private(set) var requiresApproval: Bool = false
    private(set) var statusMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
            statusMessage = nil
        case .requiresApproval:
            isEnabled = true
            requiresApproval = true
            statusMessage = "Approval required in System Settings → General → Login Items."
        case .notRegistered:
            isEnabled = false
            requiresApproval = false
            statusMessage = nil
        case .notFound:
            isEnabled = false
            requiresApproval = false
            statusMessage = "Launch TapCount from TapCount.app (or Applications) to enable Launch at Login."
        @unknown default:
            isEnabled = false
            requiresApproval = false
            statusMessage = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                    try SMAppService.mainApp.unregister()
                }
            }
            statusMessage = nil
            refresh()
        } catch {
            refresh()
            statusMessage = "Could not update login item: \(error.localizedDescription)"
        }
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
