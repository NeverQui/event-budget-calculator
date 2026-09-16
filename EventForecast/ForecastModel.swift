import Foundation
import Observation

enum EventScale: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: Self { self }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var shortTitle: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }

    var capacityRange: ClosedRange<Double> {
        switch self {
        case .small: 0 ... 500
        case .medium: 0 ... 5_000
        case .large: 0 ... 50_000
        }
    }

    var capacityStep: Double {
        switch self {
        case .small: 5
        case .medium: 50
        case .large: 500
        }
    }

    var capacityButtonStep: Double {
        switch self {
        case .small: 1
        case .medium: 10
        case .large: 100
        }
    }

    var moneyRange: ClosedRange<Double> {
        switch self {
        case .small: 0 ... 25_000
        case .medium: 0 ... 250_000
        case .large: 0 ... 2_500_000
        }
    }

    var moneyStep: Double {
        switch self {
        case .small: 50
        case .medium: 500
        case .large: 5_000
        }
    }

    var profitTargetRange: ClosedRange<Double> {
        switch self {
        case .small: 0 ... 10_000
        case .medium: 0 ... 100_000
        case .large: 0 ... 1_000_000
        }
    }

    var profitTargetStep: Double {
        switch self {
        case .small: 10
        case .medium: 100
        case .large: 1_000
        }
    }

    var moneyButtonStep: Double { moneyStep }
    var profitTargetButtonStep: Double { profitTargetStep }

    var ticketPriceRange: ClosedRange<Double> {
        switch self {
        case .small: 0 ... 500
        case .medium: 0 ... 1_000
        case .large: 0 ... 2_000
        }
    }

    var ticketPriceStep: Double {
        switch self {
        case .small: 5
        case .medium: 10
        case .large: 25
        }
    }

    var ticketPriceButtonStep: Double {
        switch self {
        case .small: 1
        case .medium: 5
        case .large: 10
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        // Preserve records from the retired largest scale by bringing them into
        // the largest scale the current product supports.
        self = value == "massive" ? .large : (EventScale(rawValue: value) ?? .small)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum EditorTab: String, CaseIterable, Identifiable {
    case tickets
    case revenue
    case expenses
    case target

    var id: Self { self }

    var title: String {
        switch self {
        case .tickets: "Tickets"
        case .revenue: "Revenue"
        case .expenses: "Expenses"
        case .target: "Target"
        }
    }

    var systemImage: String {
        switch self {
        case .tickets: "ticket"
        case .revenue: "banknote"
        case .expenses: "creditcard"
        case .target: "scope"
        }
    }
}

struct MoneyItem: Identifiable, Codable, Equatable {
    static let maximumPerLedger = 20

    let id: UUID
    var name: String
    var amount: Double

    init(id: UUID = UUID(), name: String, amount: Double) {
        self.id = id
        self.name = name
        self.amount = amount
    }
}

struct ForecastPersistenceSnapshot: Equatable {
    let scale: EventScale
    let capacity: Double
    let attendance: Double
    let ticketPrice: Double
    let profitTarget: Double
    let additionalRevenue: Double
    let expenseBudget: Double
    let revenueItems: [MoneyItem]
    let expenseItems: [MoneyItem]
}

@MainActor
@Observable
final class ForecastModel {
    var scale: EventScale = .small {
        didSet { scheduleHistoryRecord() }
    }
    var capacity: Double = 120 {
        didSet {
            attendance = min(attendance, capacity)
            updateScaleForCapacity()
            scheduleHistoryRecord()
        }
    }
    var attendance: Double = 90 {
        didSet { scheduleHistoryRecord() }
    }
    var ticketPrice: Double = 35 {
        didSet { scheduleHistoryRecord() }
    }
    var profitTarget: Double = 1_000 {
        didSet { scheduleHistoryRecord() }
    }
    var additionalRevenue: Double = 500 {
        didSet { scheduleHistoryRecord() }
    }
    var expenseBudget: Double = 2_000 {
        didSet { scheduleHistoryRecord() }
    }

    var revenueItems: [MoneyItem] = [
        MoneyItem(name: "Local sponsor", amount: 300),
        MoneyItem(name: "Concessions", amount: 125),
        MoneyItem(name: "Merchandise", amount: 75)
    ] {
        didSet { scheduleHistoryRecord() }
    }

    var expenseItems: [MoneyItem] = [
        MoneyItem(name: "Venue", amount: 900),
        MoneyItem(name: "Marketing", amount: 200),
        MoneyItem(name: "Equipment", amount: 450),
        MoneyItem(name: "Staffing", amount: 350),
        MoneyItem(name: "Other", amount: 100)
    ] {
        didSet { scheduleHistoryRecord() }
    }

    private(set) var canUndo = false
    private(set) var canRedo = false

    @ObservationIgnored private var undoSnapshots: [ForecastPersistenceSnapshot] = []
    @ObservationIgnored private var redoSnapshots: [ForecastPersistenceSnapshot] = []
    @ObservationIgnored private var lastCommittedSnapshot: ForecastPersistenceSnapshot!
    @ObservationIgnored private var pendingBaseline: ForecastPersistenceSnapshot?
    @ObservationIgnored private var historyTask: Task<Void, Never>?
    @ObservationIgnored private var isApplyingSnapshot = false

    init() {
        lastCommittedSnapshot = persistenceSnapshot
    }

    var ticketsSold: Int {
        Int(min(attendance, capacity).rounded())
    }

    var ticketRevenue: Double {
        Double(ticketsSold) * ticketPrice
    }

    var totalRevenue: Double {
        ticketRevenue + additionalRevenue
    }

    var totalExpenses: Double {
        expenseBudget
    }

    var profit: Double {
        totalRevenue - totalExpenses
    }

    var profitMargin: Double {
        totalRevenue > 0 ? profit / totalRevenue : 0
    }

    var breakEvenTickets: Int? {
        guard ticketPrice > 0 else { return nil }
        let requiredTicketRevenue = max(totalExpenses - additionalRevenue, 0)
        return Int(ceil(requiredTicketRevenue / ticketPrice))
    }

    var breakEvenTicketPrice: Double? {
        guard ticketsSold > 0 else { return nil }
        return max((totalExpenses - additionalRevenue) / Double(ticketsSold), 0)
    }

    var targetTicketPrice: Double? {
        guard ticketsSold > 0 else { return nil }
        return max((totalExpenses + profitTarget - additionalRevenue) / Double(ticketsSold), 0)
    }

    var recommendedTicketPrice: Double? {
        let raw = profitTarget > 0 ? targetTicketPrice : breakEvenTicketPrice
        return raw.map(ceil)
    }

    var requiredRevenueForProfitTarget: Double {
        totalExpenses + profitTarget
    }

    var profitTargetDifference: Double {
        profit - profitTarget
    }

    var hasMetProfitTarget: Bool {
        profitTarget > 0 && profitTargetDifference >= 0
    }

    var profitTargetTickets: Int? {
        guard profitTarget > 0, ticketPrice > 0 else { return nil }
        let requiredTicketRevenue = max(requiredRevenueForProfitTarget - additionalRevenue, 0)
        return Int(ceil(requiredTicketRevenue / ticketPrice))
    }

    var revenueItemizedTotal: Double {
        revenueItems.reduce(0) { $0 + $1.amount }
    }

    var expenseItemizedTotal: Double {
        expenseItems.reduce(0) { $0 + $1.amount }
    }

    var revenueItemizedDifference: Double {
        additionalRevenue - revenueItemizedTotal
    }

    var expenseItemizedDifference: Double {
        expenseBudget - expenseItemizedTotal
    }

    var hasForecastValues: Bool {
        capacity > 0 || attendance > 0 || ticketPrice > 0 || additionalRevenue > 0 || totalExpenses > 0 || profitTarget > 0
    }

    var persistenceSnapshot: ForecastPersistenceSnapshot {
        ForecastPersistenceSnapshot(
            scale: scale,
            capacity: capacity,
            attendance: attendance,
            ticketPrice: ticketPrice,
            profitTarget: profitTarget,
            additionalRevenue: additionalRevenue,
            expenseBudget: expenseBudget,
            revenueItems: revenueItems,
            expenseItems: expenseItems
        )
    }

    func selectScale(_ newScale: EventScale) {
        scale = newScale
        capacity = min(capacity, newScale.capacityRange.upperBound)
    }

    func useRecommendedTicketPrice() {
        guard let recommendedTicketPrice else { return }
        ticketPrice = recommendedTicketPrice.clamped(to: scale.ticketPriceRange)
    }

    func useBreakEvenTicketPrice() {
        guard let breakEvenTicketPrice else { return }
        ticketPrice = ceil(breakEvenTicketPrice).clamped(to: scale.ticketPriceRange)
    }

    func useTargetTicketPrice() {
        guard let targetTicketPrice else { return }
        ticketPrice = ceil(targetTicketPrice).clamped(to: scale.ticketPriceRange)
    }

    func undo() {
        commitPendingHistory()
        guard let previous = undoSnapshots.popLast() else { return }
        redoSnapshots.append(persistenceSnapshot)
        applySnapshot(previous)
        lastCommittedSnapshot = previous
        updateHistoryAvailability()
    }

    func redo() {
        commitPendingHistory()
        guard let next = redoSnapshots.popLast() else { return }
        undoSnapshots.append(persistenceSnapshot)
        applySnapshot(next)
        lastCommittedSnapshot = next
        updateHistoryAvailability()
    }

    func replaceCurrentForecast(with snapshot: ForecastPersistenceSnapshot) {
        historyTask?.cancel()
        pendingBaseline = nil
        undoSnapshots.removeAll()
        redoSnapshots.removeAll()
        applySnapshot(snapshot)
        lastCommittedSnapshot = persistenceSnapshot
        updateHistoryAvailability()
    }

    func projectedProfit(at price: Double) -> Double {
        Double(ticketsSold) * price + additionalRevenue - totalExpenses
    }

    func resetTickets() {
        capacity = 0
        attendance = 0
        ticketPrice = 0
    }

    func resetRevenue() {
        additionalRevenue = 0
        revenueItems = revenueItems.map { item in
            var resetItem = item
            resetItem.amount = 0
            return resetItem
        }
    }

    func resetExpenses() {
        expenseBudget = 0
        expenseItems = expenseItems.map { item in
            var resetItem = item
            resetItem.amount = 0
            return resetItem
        }
    }

    func resetProfitTarget() {
        profitTarget = 0
    }

    func resetToZero() {
        resetTickets()
        resetRevenue()
        resetExpenses()
        resetProfitTarget()
    }

    func loadStarterEvent() {
        scale = .small
        capacity = 120
        attendance = 90
        ticketPrice = 35
        profitTarget = 1_000
        additionalRevenue = 500
        expenseBudget = 2_000
        revenueItems = [
            MoneyItem(name: "Local sponsor", amount: 300),
            MoneyItem(name: "Concessions", amount: 125),
            MoneyItem(name: "Merchandise", amount: 75)
        ]
        expenseItems = [
            MoneyItem(name: "Venue", amount: 900),
            MoneyItem(name: "Marketing", amount: 200),
            MoneyItem(name: "Equipment", amount: 450),
            MoneyItem(name: "Staffing", amount: 350),
            MoneyItem(name: "Other", amount: 100)
        ]
    }

    private func updateScaleForCapacity() {
        let inferredScale: EventScale
        if capacity >= EventScale.medium.capacityRange.upperBound {
            inferredScale = .large
        } else if capacity >= EventScale.small.capacityRange.upperBound {
            inferredScale = .medium
        } else {
            inferredScale = .small
        }
        if scale != inferredScale {
            scale = inferredScale
        }
    }

    private func scheduleHistoryRecord() {
        guard !isApplyingSnapshot, lastCommittedSnapshot != nil else { return }
        if pendingBaseline == nil {
            pendingBaseline = lastCommittedSnapshot
        }
        historyTask?.cancel()
        historyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            self?.commitPendingHistory()
        }
    }

    private func commitPendingHistory() {
        historyTask?.cancel()
        historyTask = nil
        guard let baseline = pendingBaseline else { return }
        pendingBaseline = nil
        let current = persistenceSnapshot
        guard current != baseline else { return }
        undoSnapshots.append(baseline)
        if undoSnapshots.count > 80 {
            undoSnapshots.removeFirst(undoSnapshots.count - 80)
        }
        redoSnapshots.removeAll()
        lastCommittedSnapshot = current
        updateHistoryAvailability()
    }

    private func applySnapshot(_ snapshot: ForecastPersistenceSnapshot) {
        isApplyingSnapshot = true
        scale = snapshot.scale
        capacity = snapshot.capacity
        attendance = min(snapshot.attendance, snapshot.capacity)
        ticketPrice = snapshot.ticketPrice
        profitTarget = snapshot.profitTarget
        additionalRevenue = snapshot.additionalRevenue
        expenseBudget = snapshot.expenseBudget
        revenueItems = snapshot.revenueItems
        expenseItems = snapshot.expenseItems
        isApplyingSnapshot = false
    }

    private func updateHistoryAvailability() {
        canUndo = !undoSnapshots.isEmpty
        canRedo = !redoSnapshots.isEmpty
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    func rounded(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}
