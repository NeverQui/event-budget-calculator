import XCTest
@testable import EventForecastCore

final class ForecastRegressionTests: XCTestCase {
    @MainActor
    func testStarterForecastAndIndependentItemization() async {
        let model = ForecastModel()
        XCTAssertEqual(model.ticketRevenue, 3_150)
        XCTAssertEqual(model.totalRevenue, 3_650)
        XCTAssertEqual(model.profit, 1_650)
        XCTAssertEqual(model.profitMargin, 1_650 / 3_650, accuracy: 0.00001)
        XCTAssertEqual(model.breakEvenTickets, 43)
        XCTAssertEqual(model.profitTargetTickets, 72)
        XCTAssertEqual(model.recommendedTicketPrice, 28)
        model.expenseItems[0].amount = 1_000
        XCTAssertEqual(model.totalExpenses, 2_000, "Itemization must not silently replace the chosen budget.")
        XCTAssertEqual(model.expenseItemizedDifference, -100)
    }

    @MainActor
    func testFreeTicketsWhenOtherRevenueCoversCostsAndTarget() async {
        let model = ForecastModel()
        model.ticketPrice = 0
        model.attendance = 0
        model.additionalRevenue = 3_000
        XCTAssertEqual(model.breakEvenTickets, 0)
        XCTAssertEqual(model.profitTargetTickets, 0)
        XCTAssertEqual(model.breakEvenTicketPrice, 0)
        XCTAssertEqual(model.targetTicketPrice, 0)
        model.additionalRevenue = 2_000
        XCTAssertEqual(model.breakEvenTickets, 0)
        XCTAssertNil(model.profitTargetTickets)
        XCTAssertNil(model.targetTicketPrice)
        model.additionalRevenue = 0
        XCTAssertNil(model.breakEvenTickets)
        XCTAssertNil(model.breakEvenTicketPrice)
        model.profitTarget = 0
        XCTAssertNil(model.profitTargetTickets)
    }

    @MainActor
    func testTicketThresholdsRoundUpAndGuardIntegerOverflow() async {
        let model = ForecastModel()
        model.ticketPrice = 30
        model.expenseBudget = 91
        model.additionalRevenue = 0
        XCTAssertEqual(model.breakEvenTickets, 4)
        model.ticketPrice = 0.00000000000000000001
        XCTAssertNil(model.breakEvenTickets)
        XCTAssertNil(model.profitTargetTickets)
    }

    @MainActor
    func testScaleSurvivesRestorationAndUndo() async {
        let model = ForecastModel()
        model.selectScale(.medium)
        XCTAssertEqual(model.scale, .medium)
        XCTAssertEqual(model.capacity, 120)
        let saved = model.persistenceSnapshot
        model.replaceCurrentForecast(with: saved)
        XCTAssertEqual(model.scale, .medium)
        model.ticketPrice = 40
        model.undo()
        XCTAssertEqual(model.persistenceSnapshot, saved)
        model.redo()
        XCTAssertEqual(model.ticketPrice, 40)
        XCTAssertEqual(model.scale, .medium)
    }

    @MainActor
    func testCapacityClampsAttendanceAndOpeningClearsHistory() async {
        let model = ForecastModel()
        let starter = model.persistenceSnapshot
        model.capacity = 50
        XCTAssertEqual(model.ticketsSold, 50)
        model.undo()
        XCTAssertEqual(model.capacity, 120)
        XCTAssertEqual(model.ticketsSold, 90)
        model.replaceCurrentForecast(with: starter)
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.canRedo)
    }

    @MainActor
    func testManualNameEditsWaitForSave() async throws {
        let suite = "EventForecastTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ForecastModel()
        let library = ForecastLibrary(defaults: defaults)
        library.saveCurrent(named: "Original", from: model)
        library.workingName = "  Revised  "
        library.commitWorkingName()
        XCTAssertEqual(library.workingName, "Revised")
        XCTAssertEqual(library.activeRecord?.name, "Original")
        XCTAssertTrue(library.hasUnsavedChanges(from: model))
        XCTAssertEqual(ForecastLibrary(defaults: defaults).records.first?.name, "Original")
        library.saveCurrent(named: library.workingName, from: model)
        XCTAssertEqual(ForecastLibrary(defaults: defaults).records.first?.name, "Revised")
        XCTAssertFalse(library.hasUnsavedChanges(from: model))
    }

    @MainActor
    func testAutoSaveKeepsWorkingNameAndLedgerOrder() async throws {
        let suite = "EventForecastTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ForecastModel()
        let library = ForecastLibrary(defaults: defaults)
        library.saveCurrent(named: "Original", from: model)
        library.setAutoSaveEnabled(true, from: model)
        library.workingName = "Draft name"
        model.revenueItems.swapAt(0, 1)
        library.saveActive(from: model)
        XCTAssertEqual(library.workingName, "Draft name")
        let restored = try XCTUnwrap(ForecastLibrary(defaults: defaults).records.first)
        XCTAssertEqual(restored.name, "Draft name")
        XCTAssertEqual(restored.revenueItems, model.revenueItems)
        library.workingName = "Final name"
        library.commitWorkingName()
        XCTAssertEqual(library.activeRecord?.name, "Final name")
    }

    @MainActor
    func testSavedForecastRoundTripAndLegacyScale() async throws {
        let model = ForecastModel()
        model.selectScale(.large)
        let original = SavedForecast(name: "Test", model: model)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedForecast.self, from: data)
        XCTAssertEqual(decoded, original)
        decoded.apply(to: model)
        XCTAssertEqual(model.persistenceSnapshot, original.persistenceSnapshot)
        let scale = try JSONDecoder().decode(EventScale.self, from: Data("\"massive\"".utf8))
        XCTAssertEqual(scale, .large)
    }
}
