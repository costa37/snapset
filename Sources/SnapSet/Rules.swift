import Foundation

// Accessibility window references survive title changes only while the window lives.
// Persistent rules intentionally never use array order or a transient window number.
enum MatchKind: String, Codable, CaseIterable, Identifiable {
    case document = "Document URL"
    case title = "Exact title"
    case contains = "Title contains"
    case all = "All app windows"
    var id: String { rawValue }
}

struct WindowIdentity: Equatable {
    var bundleID: String
    var title: String
    var document: String
}

struct Rule: Codable, Identifiable {
    var id = UUID()
    var enabled = true
    var appName: String
    var bundleID: String
    var displayID: String
    var displayName: String
    var placement: Placement = .almost
    var matchKind: MatchKind = .title
    var matchValue = ""

    func matches(_ window: WindowIdentity) -> Bool {
        guard bundleID == window.bundleID else { return false }
        switch matchKind {
        case .all: return true
        case .document: return !matchValue.isEmpty && window.document == matchValue
        case .title: return !matchValue.isEmpty && window.title == matchValue
        case .contains: return !matchValue.trimmingCharacters(in: .whitespaces).isEmpty && window.title.localizedCaseInsensitiveContains(matchValue)
        }
    }
}

struct Configuration: Codable {
    var schemaVersion = 2
    var rules: [Rule] = []
    var onReconnect = true
    var onActivation = false
}

struct Assignment {
    var ruleIndex: Int
    var windowIndex: Int
}

struct MatchPlan {
    var assignments: [Assignment] = []
    var messages: [String] = []
}

// Resolve all rules together: overlapping rules cannot race to move one window twice.
func makePlan(rules: [Rule], windows: [WindowIdentity], bindings: [UUID: Int] = [:]) -> MatchPlan {
    var plan = MatchPlan()
    for (ri, rule) in rules.enumerated() where rule.enabled {
        let matches: [Int]
        if rule.matchKind != .all, let bound = bindings[rule.id], windows.indices.contains(bound), windows[bound].bundleID == rule.bundleID {
            matches = [bound]
        } else {
            matches = windows.indices.filter { rule.matches(windows[$0]) }
        }
        if matches.isEmpty { plan.messages.append("\(rule.appName): no matching window."); continue }
        if rule.matchKind != .all && matches.count > 1 {
            plan.messages.append("\(rule.appName): ambiguous rule (\(matches.count) windows); skipped.")
            continue
        }
        plan.assignments += matches.map { Assignment(ruleIndex: ri, windowIndex: $0) }
    }
    let conflicts = Dictionary(grouping: plan.assignments, by: \.windowIndex).filter { $0.value.count > 1 }
    for (_, assignments) in conflicts {
        let names = assignments.map { rules[$0.ruleIndex].appName }.joined(separator: ", ")
        plan.messages.append("Conflicting rules for \(names); that window was skipped.")
    }
    plan.assignments.removeAll { conflicts[$0.windowIndex] != nil }
    return plan
}
