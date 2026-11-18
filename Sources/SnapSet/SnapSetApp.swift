import SwiftUI
import AppKit
import Sparkle

// Select the property-wrapper type even on SDKs that also expose a State macro.
typealias ViewState<Value> = SwiftUI.State<Value>
typealias ViewFocus<Value: Hashable> = SwiftUI.FocusState<Value>

final class Updates: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheck = false
    private var observation: NSKeyValueObservation?
    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            DispatchQueue.main.async { self?.canCheck = updater.canCheckForUpdates }
        }
    }
    func check() { controller.checkForUpdates(nil) }
}

@main
struct SnapSetApp: App {
    @NSApplicationDelegateAdaptor(SnapSetDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

struct LayoutView: View {
    @ObservedObject var manager: WindowManager
    @ObservedObject var updates: Updates
    @ViewState<Int> private var selectedTab = 0
    @ViewState<String> private var appSearch = ""
    @ViewFocus<Bool> private var searchFocused
    private var searchTerm: String { appSearch.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func matchesApp(_ name: String) -> Bool {
        searchTerm.isEmpty || name.localizedCaseInsensitiveContains(searchTerm)
    }
    private var filteredWindows: [LiveWindow] { manager.windows.filter { matchesApp($0.appName) } }
    private var matchingRuleCount: Int { manager.configuration.rules.filter { matchesApp($0.appName) }.count }
    private func countLabel(_ matches: Int, total: Int) -> String {
        searchTerm.isEmpty ? "\(total)" : "\(matches)/\(total)"
    }
    private var noSearchResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundStyle(.secondary)
            Text("No apps match “\(searchTerm)”").font(.title3)
            Button("Clear search") { appSearch = "" }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("SnapSet").font(.largeTitle.bold())
                        Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Every window, in its place.").foregroundStyle(.secondary)
                }
                Spacer()
                if manager.busy { ProgressView().controlSize(.small) }
                Button("Refresh windows") { manager.refresh() }.disabled(manager.busy)
                Button("Apply layout") { manager.apply() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: [.command])
                    .disabled(manager.busy || manager.storageError != nil)
                    .help("Applies the complete layout, including apps hidden by search.")
            }
            if !manager.trusted {
                HStack {
                    Image(systemName: "lock.shield")
                    Text("Allow Accessibility access to list, move and resize other applications' windows.")
                    Spacer()
                    Button("Enable access…") { manager.requestAccess() }
                }.padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            if let error = manager.storageError {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(#"Filter apps (press "/" to focus)"#, text: $appSearch)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search apps")
                    .focused($searchFocused)
                    .help("Press / to focus search when not editing text.")
                if !appSearch.isEmpty {
                    Button { appSearch = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).help("Clear search").accessibilityLabel("Clear search")
                }
            }.padding(10).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            TabView(selection: $selectedTab) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Default: Main display + Wide centered—no Save needed. Save only exceptions. Layout applies when SnapSet opens or apps launch; use Apply layout to restore it now.")
                        .font(.callout).foregroundStyle(.secondary)
                    if manager.windows.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "macwindow.on.rectangle").font(.system(size: 42)).foregroundStyle(.secondary)
                            Text(manager.trusted ? "No standard windows found" : "Your open windows will appear here").font(.title2)
                            Text(manager.trusted ? "Open an application window and click Refresh windows." : "Enable Accessibility access, then refresh the list.").foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredWindows.isEmpty {
                        noSearchResults
                    } else {
                        Table(filteredWindows) {
                            TableColumn("Application / window") { window in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(window.appName).fontWeight(.semibold)
                                    Text(window.title).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(window.title)
                                    if window.unavailable { Text("\(window.state) · placement skipped until restored").font(.caption2).foregroundStyle(.orange) }
                                }.padding(.vertical, 5)
                            }.width(min: 220, ideal: 310)
                            TableColumn("Destination display · placement · save") { window in
                                LiveWindowControls(manager: manager, window: window).disabled(manager.busy)
                            }.width(min: 620, ideal: 720)
                        }
                    }
                    Text(manager.scanStatus).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }.padding(12).tabItem { Text("Open windows (\(countLabel(filteredWindows.count, total: manager.windows.count)))") }.tag(0)
                VStack(alignment: .leading, spacing: 10) {
                    Text("One rule per window, or explicitly all windows of an app. Disabled rules leave matching windows alone. Ambiguous matches and overlapping rules are skipped. All-app rules use the same rectangle for every window.")
                        .font(.callout).foregroundStyle(.secondary)
                    if manager.configuration.rules.isEmpty {
                        Text("No exceptions saved. All eligible windows use Main display + Wide centered.")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if matchingRuleCount == 0 {
                        noSearchResults
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach($manager.configuration.rules) { $rule in
                                    // Keep bindings attached to the original rule collection.
                                    if matchesApp(rule.appName) {
                                        SavedRuleRow(rule: $rule, displays: manager.displays,
                                            clearBinding: { manager.clearBinding(rule.id) }, remove: { manager.remove(rule.id) })
                                    }
                                }
                            }
                        }
                    }
                }.padding(12).disabled(manager.busy || manager.storageError != nil).tabItem { Text("Saved rules (\(countLabel(matchingRuleCount, total: manager.configuration.rules.count)))") }.tag(1)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Toggle("Apply after displays connect, change, or wake", isOn: $manager.configuration.onReconnect)
                    Toggle("Reapply an app's layout whenever it gains focus", isOn: $manager.configuration.onActivation)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 7) {
                    Button("Show configuration file") { manager.revealConfiguration() }
                    Button("Check for Updates…") { updates.check() }.disabled(!updates.canCheck)
                    Toggle("Automatically check for updates", isOn: Binding(get: { updates.controller.updater.automaticallyChecksForUpdates }, set: { updates.controller.updater.automaticallyChecksForUpdates = $0 }))
                }
            }.font(.callout)
            Divider()
            ScrollView {
                Text(manager.status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 68)
            Text("Settings stay on this Mac. Disconnected displays and full-screen/minimized windows are skipped. Some apps do not expose all windows to Accessibility.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(22)
            .background(SearchShortcut { searchFocused = true }.frame(width: 0, height: 0))
    }
}

struct LiveWindowControls: View {
    @ObservedObject var manager: WindowManager
    let window: LiveWindow
    @ViewState<String> private var displayID = Display.mainTarget
    @ViewState<Placement> private var placement: Placement = .wide
    var body: some View {
        HStack(spacing: 10) {
            Picker("Display", selection: $displayID) {
                Text("Main display (follows system)").tag(Display.mainTarget)
                if displayID != Display.mainTarget && !manager.displays.contains(where: { $0.id == displayID }) {
                    Text(displayID.isEmpty ? "Choose display" : "Saved display (disconnected)").tag(displayID)
                }
                ForEach(manager.displays) { Text($0.name).tag($0.id) }
            }.labelsHidden().frame(minWidth: 240)
            Picker("Placement", selection: $placement) {
                ForEach(Placement.allCases) { Text($0.rawValue).tag($0) }
            }.labelsHidden().frame(width: 205)
            Button(manager.rule(for: window) == nil ? "Save" : "Update") {
                manager.saveWindow(window, displayID: displayID, placement: placement)
            }.disabled(manager.storageError != nil || (displayID != Display.mainTarget && !manager.displays.contains(where: { $0.id == displayID })))
                .frame(width: 65)
        }.onAppear { load() }
        .onChange(of: manager.rule(for: window)?.displayID) { _ in load() }
        .onChange(of: manager.rule(for: window)?.placement) { _ in load() }
    }
    private func load() {
        let saved = manager.rule(for: window)
        displayID = saved?.displayID ?? Display.mainTarget
        placement = saved?.placement ?? .wide
    }
}

struct SavedRuleRow: View {
    @Binding var rule: Rule
    let displays: [Display]
    let clearBinding: () -> Void
    let remove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(rule.appName, isOn: $rule.enabled).fontWeight(.semibold)
                Text(rule.bundleID).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(action: remove) { Image(systemName: "trash") }.help("Remove rule")
            }
            HStack {
                Picker("Match", selection: $rule.matchKind) { ForEach(MatchKind.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 215)
                    .onChange(of: rule.matchKind) { _ in clearBinding() }
                if rule.matchKind != .all {
                    TextField(rule.matchKind == .document ? "Document URL" : "Window title or stable title fragment", text: $rule.matchValue)
                        .textFieldStyle(.roundedBorder).onChange(of: rule.matchValue) { _ in clearBinding() }
                } else { Text("All standard windows of this application will overlap at this placement.").font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Picker("Display", selection: $rule.displayID) {
                    Text("Main display (follows system)").tag(Display.mainTarget)
                    if rule.displayID != Display.mainTarget && !displays.contains(where: { $0.id == rule.displayID }) { Text("\(rule.displayName) (disconnected)").tag(rule.displayID) }
                    ForEach(displays) { Text($0.name).tag($0.id) }
                }.onChange(of: rule.displayID) { id in if id == Display.mainTarget { rule.displayName = "Main display" } else if let display = displays.first(where: { $0.id == id }) { rule.displayName = display.name } }
                Picker("Placement", selection: $rule.placement) { ForEach(Placement.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 290)
            }
            if rule.matchKind != .all && rule.matchValue.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("No persistent identity: this rule works only for its selected live window until you enter a unique title or document URL.").font(.caption).foregroundStyle(.orange)
            }
        }.padding(14).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}
