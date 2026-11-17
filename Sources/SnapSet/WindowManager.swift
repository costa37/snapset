import AppKit
import ApplicationServices
import SwiftUI

func displayRole(isMain: Bool, isMirrored: Bool) -> String {
    if isMain { return isMirrored ? "Main (Mirrored)" : "Main" }
    return isMirrored ? "Mirrored" : "Extended"
}

struct Display: Identifiable {
    let id: String
    let name: String
    let area: CGRect
    static func connected() -> [Display] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
            let id = CFUUIDCreateString(nil, uuid)! as String
            let role = displayRole(isMain: CGDisplayIsMain(number.uint32Value) != 0, isMirrored: CGDisplayIsInMirrorSet(number.uint32Value) != 0)
            return Display(id: id, name: "\(role) · \(screen.localizedName) · \(Int(screen.frame.width))×\(Int(screen.frame.height)) · \(id.suffix(4))", area: screen.visibleFrame)
        }
    }
}

struct LiveWindow: Identifiable {
    var id = UUID()
    var appName: String
    var identity: WindowIdentity
    var element: AXUIElement
    var frame: CGRect?
    var minimized: Bool
    var fullScreen: Bool
    var title: String { identity.title.isEmpty ? "Untitled window" : identity.title }
    var unavailable: Bool { minimized || fullScreen }
    var state: String { minimized ? "Minimized" : (fullScreen ? "Full screen" : "Open") }
}

struct Scan {
    var windows: [LiveWindow] = []
    var unavailableApps: [String] = []
}

enum Accessibility {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    static func frame(_ window: AXUIElement) -> CGRect? {
        var point = CGPoint.zero, size = CGSize.zero
        guard let p = attribute(window, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = attribute(window, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID(),
              AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
    static func scan(apps: [NSRunningApplication]) -> Scan {
        var result = Scan()
        for app in apps {
            guard let bundle = app.bundleIdentifier else { continue }
            let name = app.localizedName ?? bundle
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.5)
            guard let windows = attribute(element, kAXWindowsAttribute) as? [AXUIElement] else {
                result.unavailableApps.append(name); continue
            }
            for window in windows where attribute(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole {
                AXUIElementSetMessagingTimeout(window, 0.5)
                result.windows.append(LiveWindow(appName: name,
                    identity: WindowIdentity(bundleID: bundle, title: attribute(window, kAXTitleAttribute) as? String ?? "", document: attribute(window, kAXDocumentAttribute) as? String ?? ""),
                    element: window, frame: frame(window),
                    minimized: attribute(window, kAXMinimizedAttribute) as? Bool == true,
                    fullScreen: attribute(window, "AXFullScreen") as? Bool == true))
            }
        }
        result.windows.sort { ($0.appName, $0.title) < ($1.appName, $1.title) }
        return result
    }
    static func place(_ window: LiveWindow, target: CGRect) -> String {
        guard !window.unavailable else { return "\(window.appName): \(window.state.lowercased()); skipped." }
        var point = target.origin, size = target.size
        guard let p = AXValueCreate(.cgPoint, &point), let s = AXValueCreate(.cgSize, &size) else { return "Unable to create window bounds." }
        _ = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, s)
        let moved = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, p)
        let resized = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, s)
        let positioned = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, p)
        guard moved == .success, resized == .success, positioned == .success else {
            return "\(window.appName) — \(window.title): app rejected position or size (\(moved.rawValue)/\(resized.rawValue)/\(positioned.rawValue))."
        }
        guard let actual = frame(window.element), abs(actual.minX - target.minX) < 3, abs(actual.minY - target.minY) < 3,
              abs(actual.width - target.width) < 3, abs(actual.height - target.height) < 3 else {
            return "\(window.appName) — \(window.title): requested layout; app adjusted its bounds."
        }
        return "\(window.appName) — \(window.title): placed."
    }
}

final class WindowManager: ObservableObject {
    @Published var configuration = Configuration() { didSet { save() } }
    @Published var displays: [Display] = []
    @Published var windows: [LiveWindow] = []
    @Published var status = "Refresh open windows, choose a display and placement, then save a rule."
    @Published var scanStatus = ""
    @Published var trusted = AXIsProcessTrusted()
    @Published var busy = false
    @Published var storageError: String?
    private var observers: [NSObjectProtocol] = []
    private var reconnectWork: DispatchWorkItem?
    private var pendingApply = false
    private var sessionBindings: [UUID: AXUIElement] = [:]
    private let queue = DispatchQueue(label: "SnapSet.accessibility", qos: .userInitiated)
    let file: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = support.appendingPathComponent("SnapSet/layout.json")
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let loaded = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: file))
                guard loaded.schemaVersion == 2 else { throw CocoaError(.coderReadCorrupt) }
                configuration = loaded
            } else {
                let legacy = support.appendingPathComponent("WindowHarbor/layout.json")
                if FileManager.default.fileExists(atPath: legacy.path) {
                    configuration = try migrateLegacy(Data(contentsOf: legacy))
                    status = "Imported Window Harbor settings. Re-select a window for disabled single-window rules in Saved rules."
                    save()
                }
            }
        } catch { storageError = "Could not load layout.json: \(error.localizedDescription). Your file has been preserved; resolve it before saving." }
        displays = Display.connected()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleReconnect() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleReconnect() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, self.configuration.onActivation,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier,
                  self.configuration.rules.contains(where: { $0.enabled && $0.bundleID == id }) else { return }
            self.apply(bundleID: id)
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        refresh()
    }

    private func save() {
        guard storageError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(configuration).write(to: file, options: .atomic)
        } catch { storageError = "Could not save layout: \(error.localizedDescription). Restart SnapSet after resolving the storage problem." }
    }
    func revealConfiguration() {
        if FileManager.default.fileExists(atPath: file.path) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
        else { NSWorkspace.shared.open(file.deletingLastPathComponent().deletingLastPathComponent()) }
    }
    func requestAccess() {
        trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    private func scheduleReconnect() {
        reconnectWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.displays = Display.connected()
            if self.configuration.onReconnect { self.apply() } else { self.refresh() }
        }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
    private func apps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy != .prohibited && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
    }
    private func adopt(_ scan: Scan) {
        windows = scan.windows.map { fresh in
            var result = fresh
            if let existing = windows.first(where: { CFEqual($0.element, fresh.element) }) { result.id = existing.id }
            return result
        }
        scanStatus = "\(windows.count) standard windows found." + (scan.unavailableApps.isEmpty ? "" : " Could not inspect: " + scan.unavailableApps.joined(separator: ", ") + ".")
    }
    func refresh() {
        trusted = AXIsProcessTrusted()
        displays = Display.connected()
        guard trusted, !busy else { return }
        busy = true
        let applications = apps()
        queue.async {
            let scan = Accessibility.scan(apps: applications)
            DispatchQueue.main.async {
                self.adopt(scan); self.finish()
            }
        }
    }
    private func finish() {
        busy = false
        if pendingApply { pendingApply = false; apply() }
    }
    func currentDisplay(for window: LiveWindow) -> String {
        guard let frame = window.frame else { return displays.first?.id ?? "" }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return displays.max(by: { a, b in
            let ar = accessibilityRect(a.area, primaryHeight: primaryHeight).intersection(frame)
            let br = accessibilityRect(b.area, primaryHeight: primaryHeight).intersection(frame)
            return (ar.isNull ? 0 : ar.width * ar.height) < (br.isNull ? 0 : br.width * br.height)
        })?.id ?? ""
    }
    func rule(for window: LiveWindow) -> Rule? {
        let matches = configuration.rules.filter { rule in
            if rule.matchKind != .all, let binding = sessionBindings[rule.id] { return CFEqual(binding, window.element) }
            return rule.matches(window.identity)
        }
        return matches.count == 1 ? matches.first : nil
    }
    func saveWindow(_ window: LiveWindow, displayID: String, placement: Placement) {
        guard storageError == nil, let display = displays.first(where: { $0.id == displayID }) else { return }
        if var existing = rule(for: window), existing.matchKind != .all,
           let index = configuration.rules.firstIndex(where: { $0.id == existing.id }) {
            existing.displayID = display.id; existing.displayName = display.name; existing.placement = placement
            configuration.rules[index] = existing
            sessionBindings[existing.id] = window.element
        } else {
            let document = window.identity.document
            let rule = Rule(appName: window.appName, bundleID: window.identity.bundleID, displayID: display.id, displayName: display.name,
                placement: placement, matchKind: document.isEmpty ? .title : .document, matchValue: document.isEmpty ? window.identity.title : document)
            configuration.rules.append(rule)
            sessionBindings[rule.id] = window.element
        }
        status = "Rule saved. It tracks this window while open; after restart, its document/title must match uniquely. Edit matching in Saved rules."
    }
    func clearBinding(_ id: UUID) { sessionBindings.removeValue(forKey: id) }
    func remove(_ id: UUID) {
        sessionBindings.removeValue(forKey: id)
        configuration.rules.removeAll { $0.id == id }
    }
    func apply(bundleID: String? = nil) {
        trusted = AXIsProcessTrusted()
        guard trusted else { status = "Enable Accessibility access to inspect and move windows."; return }
        guard storageError == nil else { return }
        guard !busy else { pendingApply = true; return }
        displays = Display.connected()
        let rules = configuration.rules.filter { $0.enabled && (bundleID == nil || $0.bundleID == bundleID) }
        guard !rules.isEmpty else { status = "No enabled rules to apply."; return }
        let screens = displays, bindings = sessionBindings, applications = apps()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        busy = true; status = "Applying layout…"
        queue.async {
            let scan = Accessibility.scan(apps: applications)
            let indexes = bindings.compactMapValues { element in scan.windows.firstIndex { CFEqual(element, $0.element) } }
            let plan = makePlan(rules: rules, windows: scan.windows.map(\.identity), bindings: indexes)
            var messages = plan.messages
            var rebound: [UUID: AXUIElement] = [:]
            for assignment in plan.assignments {
                let rule = rules[assignment.ruleIndex], window = scan.windows[assignment.windowIndex]
                if rule.matchKind != .all { rebound[rule.id] = window.element }
                guard let display = screens.first(where: { $0.id == rule.displayID }) else {
                    messages.append("\(rule.appName): intended display disconnected; skipped."); continue
                }
                messages.append(Accessibility.place(window, target: accessibilityRect(rule.placement.rect(in: display.area), primaryHeight: primaryHeight)))
            }
            DispatchQueue.main.async {
                self.adopt(scan)
                for (id, element) in rebound { self.sessionBindings[id] = element }
                self.status = messages.joined(separator: "\n")
                self.finish()
            }
        }
    }
}

private struct LegacyConfiguration: Decodable {
    struct LegacyRule: Decodable {
        var appName: String; var bundleID: String; var displayID: String; var displayName: String
        var placement: Placement; var enabled: Bool; var allWindows: Bool
    }
    var rules: [LegacyRule]; var onReconnect: Bool; var onActivation: Bool
}
func migrateLegacy(_ data: Data) throws -> Configuration {
    let old = try JSONDecoder().decode(LegacyConfiguration.self, from: data)
    return Configuration(rules: old.rules.map {
        Rule(enabled: $0.enabled && $0.allWindows, appName: $0.appName, bundleID: $0.bundleID, displayID: $0.displayID,
            displayName: $0.displayName, placement: $0.placement, matchKind: $0.allWindows ? .all : .title)
    }, onReconnect: old.onReconnect, onActivation: old.onActivation)
}
