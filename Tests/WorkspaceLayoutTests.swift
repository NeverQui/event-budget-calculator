import XCTest
@testable import EventForecastCore

final class WorkspaceLayoutTests: XCTestCase {
    func testStopsStayOrderedInsideShortAndTallWorkspaces() {
        for height: CGFloat in [0, 20, 44, 200, 400, 590, 740, 1_000] {
            let layout = WorkspaceLayout(height: height)
            let stops = WorkspaceSplit.allCases.map(layout.summaryHeight)
            XCTAssertEqual(stops, stops.sorted())
            XCTAssertTrue(stops.allSatisfy { $0 >= 0 && $0 <= layout.visual })
            XCTAssertEqual(layout.clamped(-1_000), stops.first)
            XCTAssertEqual(layout.clamped(10_000), stops.last)
        }
    }

    func testReleaseAtEachStopKeepsThatStop() {
        let layout = WorkspaceLayout(height: 740)
        for split in WorkspaceSplit.allCases {
            XCTAssertEqual(layout.destination(at: layout.summaryHeight(for: split), projectedTravel: 0), split)
        }
    }

    func testShortFlickCannotSkipStraightToFullCharts() {
        let layout = WorkspaceLayout(height: 740)
        XCTAssertEqual(layout.destination(at: layout.editor + 6, projectedTravel: 10_000), .balanced)
        XCTAssertEqual(layout.destination(at: layout.visual - 6, projectedTravel: -10_000), .semiExpanded)
    }

    func testLiveHeightTracksFingerBeforeClamping() {
        let layout = WorkspaceLayout(height: 740)
        let origin = layout.balanced
        for translation: CGFloat in [-50, -10, 0, 10, 50] {
            XCTAssertEqual(layout.clamped(origin + translation) - origin, translation)
        }
    }

    func testSummaryRevealAndAccessibleStopsHaveBounds() {
        let layout = WorkspaceLayout(height: 740)
        XCTAssertEqual(layout.overviewProgress(at: layout.editor), 0)
        XCTAssertEqual(layout.overviewProgress(at: layout.balanced), 1)
        XCTAssertEqual(layout.overviewProgress(at: layout.visual), 1)
        XCTAssertEqual(WorkspaceSplit.editor.adjacent(increasing: false), .editor)
        XCTAssertEqual(WorkspaceSplit.editor.adjacent(increasing: true), .balanced)
        XCTAssertEqual(WorkspaceSplit.visual.adjacent(increasing: true), .visual)
        XCTAssertEqual(WorkspaceSplit.visual.adjacent(increasing: false), .semiExpanded)
    }
}
