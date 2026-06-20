import Foundation
import ServiceManagement

/// Launch-at-login via the modern ServiceManagement API (macOS 13+).
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("[Aurora] Launch-at-login toggle failed: \(error.localizedDescription)")
            return false
        }
    }
}
