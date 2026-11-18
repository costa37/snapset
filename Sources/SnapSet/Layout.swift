import Foundation
import CoreGraphics

enum Placement: String, Codable, CaseIterable, Identifiable {
    case maximize = "Maximized (within desktop)"
    case wide = "Wide centered"
    case center = "Half width, centered"
    case right = "Right half"
    case left = "Left half"
    case compact = "Compact, centered"
    case almost = "Almost maximized"
    var id: String { rawValue }

    func rect(in area: CGRect) -> CGRect {
        let inset = area.insetBy(dx: 12, dy: 12)
        switch self {
        case .wide: return CGRect(x: area.minX + area.width / 6, y: area.minY, width: area.width * 2 / 3, height: area.height)
        case .maximize: return area
        case .almost: return inset
        case .left: return CGRect(x: inset.minX, y: inset.minY, width: (inset.width - 12) / 2, height: inset.height)
        case .right: return CGRect(x: inset.midX + 6, y: inset.minY, width: (inset.width - 12) / 2, height: inset.height)
        case .center: return CGRect(x: area.minX + area.width * 0.25, y: inset.minY, width: area.width * 0.5, height: inset.height)
        case .compact:
            let width = area.width * 0.40
            let height = area.height * 0.60
            return CGRect(
                x: area.minX + area.width * 0.25,
                y: area.maxY - area.height * 0.20 - height,
                width: width,
                height: height
            )
        }
    }
}

// Accessibility uses a top-left origin relative to the primary display.
func accessibilityRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
}
