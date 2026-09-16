import Foundation

enum WorkspaceSplit: Int, CaseIterable {
    case editor
    case balanced
    case semiExpanded
    case visual

    var title: String {
        switch self {
        case .editor: "More input space"
        case .balanced: "Balanced"
        case .semiExpanded: "Larger charts"
        case .visual: "Full charts"
        }
    }

    func adjacent(increasing: Bool) -> Self {
        Self(rawValue: rawValue + (increasing ? 1 : -1)) ?? self
    }
}

/// Geometry and snapping policy shared by touch, tap, and accessibility controls.
struct WorkspaceLayout: Equatable {
    static let handleHeight: CGFloat = 44

    let height: CGFloat
    var compact: Bool { height < 660 }
    var editor: CGFloat { min(compact ? 164 : 176, height * 0.27) }
    var balanced: CGFloat { min(compact ? 304 : 326, height * 0.54, visual) }
    var visual: CGFloat { max(height - Self.handleHeight, 0) }
    var semiExpanded: CGFloat {
        max(balanced, min(height * 0.75, visual - (compact ? 124 : 140)))
    }

    init(height: CGFloat) {
        self.height = max(height.isFinite ? height : 0, 0)
    }

    func summaryHeight(for split: WorkspaceSplit) -> CGFloat {
        switch split {
        case .editor: min(editor, visual)
        case .balanced: balanced
        case .semiExpanded: semiExpanded
        case .visual: visual
        }
    }

    func clamped(_ proposedHeight: CGFloat) -> CGFloat {
        min(max(proposedHeight, summaryHeight(for: .editor)), visual)
    }

    func destination(at height: CGFloat, projectedTravel: CGFloat) -> WorkspaceSplit {
        // A quick flick can help reach the next stop, but cannot skip the whole
        // workspace on the strength of a noisy velocity estimate.
        let projection = clamped(height + min(max(projectedTravel, -96), 96))
        return WorkspaceSplit.allCases.min {
            abs(summaryHeight(for: $0) - projection) < abs(summaryHeight(for: $1) - projection)
        } ?? .balanced
    }

    func overviewProgress(at height: CGFloat) -> CGFloat {
        min(max((height - editor) / max(balanced - editor, 1), 0), 1)
    }
}
