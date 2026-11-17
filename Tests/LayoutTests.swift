import Foundation
import CoreGraphics
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b, "Expected \(a) == \(b)") }
func XCTAssertTrue(_ value: Bool) { precondition(value) }

struct LayoutTests {
    func testCoordinateConversionAcrossDisplayArrangements() {
        // Primary display is 900 points tall; monitors may have negative origins.
        XCTAssertEqual(accessibilityRect(CGRect(x: -1920, y: 0, width: 1920, height: 1080), primaryHeight: 900), CGRect(x: -1920, y: -180, width: 1920, height: 1080))
        XCTAssertEqual(accessibilityRect(CGRect(x: 0, y: 900, width: 1200, height: 800), primaryHeight: 900), CGRect(x: 0, y: -800, width: 1200, height: 800))
        XCTAssertEqual(accessibilityRect(CGRect(x: 0, y: -800, width: 1200, height: 800), primaryHeight: 900), CGRect(x: 0, y: 900, width: 1200, height: 800))
    }
    func testPresetsStayInUsableScreenArea() {
        for area in [CGRect(x: -1920, y: 40, width: 1920, height: 1040), CGRect(x: 0, y: -900, width: 1440, height: 875)] {
            for placement in Placement.allCases { XCTAssertTrue(area.contains(placement.rect(in: area))) }
            let wide = Placement.wide.rect(in: area)
            XCTAssertTrue(abs(wide.midX - area.midX) < 0.001)
            XCTAssertEqual(wide.minY, area.minY)
            XCTAssertEqual(wide.height, area.height)
            XCTAssertTrue(abs(wide.width / area.width - 2.0 / 3.0) < 0.001)
            let left = Placement.left.rect(in: area), right = Placement.right.rect(in: area)
            XCTAssertEqual(left.width, right.width)
            XCTAssertEqual(right.minX - left.maxX, 12)
            XCTAssertEqual(Placement.center.rect(in: area).midX, area.midX)
        }
    }
    func testSavedRulesRoundTrip() throws {
        let config = Configuration(rules: [Rule(appName: "Test", bundleID: "test.app", displayID: "stable-display", displayName: "Office", placement: .center)], onReconnect: true)
        let restored = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(restored.rules.first?.displayID, "stable-display")
        XCTAssertEqual(restored.rules.first?.placement, .center)
        XCTAssertTrue(restored.onReconnect)
    }
}

@main struct RunTests { static func main() throws {
let tests = LayoutTests()
tests.testCoordinateConversionAcrossDisplayArrangements()
tests.testPresetsStayInUsableScreenArea()
try tests.testSavedRulesRoundTrip()
try testMatchingAndMigration()
XCTAssertEqual(Rule(appName: "Test", bundleID: "test", displayID: "screen", displayName: "Screen").placement, .wide)
XCTAssertEqual(displayRole(isMain: true, isMirrored: false), "Main")
XCTAssertEqual(displayRole(isMain: false, isMirrored: false), "Extended")
XCTAssertEqual(displayRole(isMain: false, isMirrored: true), "Mirrored")
XCTAssertEqual(displayRole(isMain: true, isMirrored: true), "Main (Mirrored)")
print("Passed: coordinates, presets, persistence, matching, conflicts, migration.")
} }

func testMatchingAndMigration() throws {
    let windows = [WindowIdentity(bundleID: "test.app", title: "Project Alpha — Browser", document: ""),
                   WindowIdentity(bundleID: "test.app", title: "Project Beta — Browser", document: ""),
                   WindowIdentity(bundleID: "other.app", title: "Project Alpha — Browser", document: "")]
    var a = Rule(appName: "Test", bundleID: "test.app", displayID: "screen", displayName: "Screen", matchKind: .contains, matchValue: "Alpha")
    var b = a; b.id = UUID(); b.matchValue = "Beta"
    var plan = makePlan(rules: [a,b], windows: windows)
    XCTAssertEqual(plan.assignments.map(\.windowIndex), [0,1])
    XCTAssertTrue(plan.messages.isEmpty)
    a.matchValue = "Project"
    plan = makePlan(rules: [a], windows: windows)
    XCTAssertTrue(plan.assignments.isEmpty)
    XCTAssertTrue(plan.messages.first!.contains("ambiguous"))
    plan = makePlan(rules: [a], windows: windows, bindings: [a.id: 1])
    XCTAssertEqual(plan.assignments.first?.windowIndex, 1)
    a.matchKind = .all
    plan = makePlan(rules: [a,b], windows: windows)
    XCTAssertEqual(plan.assignments.map(\.windowIndex), [0])
    XCTAssertTrue(plan.messages.first!.contains("Conflicting"))
    a.enabled = false
    plan = makePlan(rules: [a,b], windows: windows)
    XCTAssertEqual(plan.assignments.map(\.windowIndex), [1])
    b.matchKind = .document; b.matchValue = "file:///work/report.txt"
    plan = makePlan(rules: [b], windows: [WindowIdentity(bundleID: "test.app", title: "Changed title", document: b.matchValue)])
    XCTAssertEqual(plan.assignments.count, 1)
    b.matchKind = .title; b.matchValue = ""
    XCTAssertTrue(makePlan(rules: [b], windows: windows).assignments.isEmpty)
    let legacy = Data(#"{"rules":[{"appName":"Test","bundleID":"test.app","displayID":"screen","displayName":"Office","placement":"Almost maximized","enabled":true,"allWindows":false}],"onReconnect":true,"onActivation":false}"#.utf8)
    let migrated = try migrateLegacy(legacy)
    XCTAssertEqual(migrated.schemaVersion, 2)
    XCTAssertTrue(!migrated.rules[0].enabled)
    XCTAssertTrue(migrated.onReconnect)
}
