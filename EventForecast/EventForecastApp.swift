import SwiftUI

@main
struct EventForecastApp: App {
    @State private var model = ForecastModel()
    @State private var library = ForecastLibrary()

    var body: some Scene {
        WindowGroup {
            ForecastView(model: model, library: library)
                .environment(\.locale, Locale(identifier: "en_US"))
        }
    }
}
