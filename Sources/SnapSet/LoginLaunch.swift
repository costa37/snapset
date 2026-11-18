import AppKit
import ServiceManagement
import SwiftUI

final class LoginLaunch: ObservableObject {
    @Published private(set) var requested: Bool
    @Published private(set) var message = ""
    private let defaults = UserDefaults.standard
    private let preferenceKey = "launchAtLoginRequested"
    private let registeredPathKey = "loginRegistrationPath"
    private var lastError: String?
    private var observer: NSObjectProtocol?
    private var installed: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/"
        return path.hasPrefix("/Applications/") || path.hasPrefix(userApps)
    }
    init() {
        requested = UserDefaults.standard.object(forKey: "launchAtLoginRequested") as? Bool ?? true
        reconcile()
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
    }
    private func reconcile() {
        guard installed else { refresh(); return }
        if requested && defaults.string(forKey: registeredPathKey) != Bundle.main.bundlePath {
            register()
        } else { refresh() }
    }
    func setEnabled(_ value: Bool) {
        lastError = nil
        requested = value
        defaults.set(value, forKey: preferenceKey)
        guard installed else { refresh(); return }
        if value { register() }
        else {
            do { try SMAppService.mainApp.unregister(); message = "" }
            catch { lastError = "Could not disable launch at login: \(error.localizedDescription)" }
            refresh()
        }
    }
    private func register() {
        do {
            try SMAppService.mainApp.register()
            defaults.set(Bundle.main.bundlePath, forKey: registeredPathKey)
            message = ""
            refresh()
        } catch { lastError = "Launch at login could not be enabled: \(error.localizedDescription)"; refresh() }
    }
    func refresh() {
        guard installed else {
            message = requested ? "Move SnapSet to Applications to activate launch at login." : ""
            return
        }
        switch SMAppService.mainApp.status {
        case .enabled:
            requested = true; defaults.set(true, forKey: preferenceKey)
            message = lastError ?? ""
        case .requiresApproval:
            message = "Approve SnapSet in System Settings → General → Login Items."
        case .notRegistered:
            if defaults.string(forKey: registeredPathKey) == Bundle.main.bundlePath {
                requested = false; defaults.set(false, forKey: preferenceKey)
            }
            message = lastError ?? ""
        case .notFound:
            message = "Launch at login is unavailable. Reopen SnapSet from Applications."
        @unknown default:
            message = "Check SnapSet's status in Login Items."
        }
    }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
