// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EventForecastCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(
            name: "EventForecastCore",
            path: "EventForecast",
            exclude: [
                "Assets.xcassets", "Editors.swift", "EventForecastApp.swift",
                "EventLibraryView.swift", "ForecastReportView.swift", "ForecastTheme.swift",
                "ForecastView.swift", "ResultSummaryView.swift"
            ],
            sources: ["ForecastModel.swift", "ForecastLibrary.swift", "WorkspaceLayout.swift"]
        ),
        .testTarget(name: "EventForecastCoreTests", dependencies: ["EventForecastCore"], path: "Tests")
    ]
)
