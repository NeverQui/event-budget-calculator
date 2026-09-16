import Foundation
import Observation

struct SavedForecast: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var eventDate: Date
    var eventEndDate: Date?
    var eventDateApplies: Bool
    var updatedAt: Date
    var scale: EventScale
    var capacity: Double
    var attendance: Double
    var ticketPrice: Double
    var profitTarget: Double
    var additionalRevenue: Double
    var expenseBudget: Double
    var revenueItems: [MoneyItem]
    var expenseItems: [MoneyItem]
    var autoSaveEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case eventDate
        case eventEndDate
        case eventDateApplies
        case updatedAt
        case scale
        case capacity
        case attendance
        case ticketPrice
        case profitTarget
        case additionalRevenue
        case expenseBudget
        case revenueItems
        case expenseItems
        case autoSaveEnabled

        // Legacy keys retained only for migration.
        case incomes
        case expenses
    }

    @MainActor
    init(
        id: UUID = UUID(),
        name: String,
        model: ForecastModel,
        eventDate: Date = .now,
        eventEndDate: Date? = nil,
        eventDateApplies: Bool = true,
        updatedAt: Date = .now,
        autoSaveEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.eventDate = eventDate
        self.eventEndDate = eventEndDate
        self.eventDateApplies = eventDateApplies
        self.updatedAt = updatedAt
        scale = model.scale
        capacity = model.capacity
        attendance = model.attendance
        ticketPrice = model.ticketPrice
        profitTarget = model.profitTarget
        additionalRevenue = model.additionalRevenue
        expenseBudget = model.expenseBudget
        revenueItems = model.revenueItems
        expenseItems = model.expenseItems
        self.autoSaveEnabled = autoSaveEnabled
    }

    init(id: UUID = UUID(), copying source: SavedForecast, name: String) {
        self.id = id
        self.name = name
        eventDate = source.eventDate
        eventEndDate = source.eventEndDate
        eventDateApplies = source.eventDateApplies
        updatedAt = .now
        scale = source.scale
        capacity = source.capacity
        attendance = source.attendance
        ticketPrice = source.ticketPrice
        profitTarget = source.profitTarget
        additionalRevenue = source.additionalRevenue
        expenseBudget = source.expenseBudget
        revenueItems = source.revenueItems
        expenseItems = source.expenseItems
        autoSaveEnabled = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        eventDate = try container.decodeIfPresent(Date.self, forKey: .eventDate) ?? updatedAt
        eventEndDate = try container.decodeIfPresent(Date.self, forKey: .eventEndDate)
        eventDateApplies = try container.decodeIfPresent(Bool.self, forKey: .eventDateApplies) ?? true
        scale = try container.decode(EventScale.self, forKey: .scale)
        capacity = try container.decode(Double.self, forKey: .capacity)
        attendance = try container.decode(Double.self, forKey: .attendance)
        ticketPrice = try container.decode(Double.self, forKey: .ticketPrice)
        profitTarget = try container.decodeIfPresent(Double.self, forKey: .profitTarget) ?? 0

        let legacyRevenueItems = try container.decodeIfPresent([MoneyItem].self, forKey: .incomes) ?? []
        let legacyExpenseItems = try container.decodeIfPresent([MoneyItem].self, forKey: .expenses) ?? []
        revenueItems = try container.decodeIfPresent([MoneyItem].self, forKey: .revenueItems) ?? legacyRevenueItems
        expenseItems = try container.decodeIfPresent([MoneyItem].self, forKey: .expenseItems) ?? legacyExpenseItems
        additionalRevenue = try container.decodeIfPresent(Double.self, forKey: .additionalRevenue)
            ?? revenueItems.reduce(0) { $0 + $1.amount }
        expenseBudget = try container.decodeIfPresent(Double.self, forKey: .expenseBudget)
            ?? expenseItems.reduce(0) { $0 + $1.amount }
        autoSaveEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSaveEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(eventDate, forKey: .eventDate)
        try container.encodeIfPresent(eventEndDate, forKey: .eventEndDate)
        try container.encode(eventDateApplies, forKey: .eventDateApplies)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(scale, forKey: .scale)
        try container.encode(capacity, forKey: .capacity)
        try container.encode(attendance, forKey: .attendance)
        try container.encode(ticketPrice, forKey: .ticketPrice)
        try container.encode(profitTarget, forKey: .profitTarget)
        try container.encode(additionalRevenue, forKey: .additionalRevenue)
        try container.encode(expenseBudget, forKey: .expenseBudget)
        try container.encode(revenueItems, forKey: .revenueItems)
        try container.encode(expenseItems, forKey: .expenseItems)
        try container.encode(autoSaveEnabled, forKey: .autoSaveEnabled)
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

    func includes(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard eventDateApplies else { return false }
        let start = calendar.startOfDay(for: eventDate)
        let end = calendar.startOfDay(for: eventEndDate ?? eventDate)
        let candidate = calendar.startOfDay(for: date)
        return candidate >= min(start, end) && candidate <= max(start, end)
    }

    var eventDateLabel: String {
        guard eventDateApplies else { return "No event date" }
        guard let eventEndDate,
              !Calendar.current.isDate(eventDate, inSameDayAs: eventEndDate) else {
            return eventDate.formatted(date: .abbreviated, time: .omitted)
        }
        return "\(eventDate.formatted(date: .abbreviated, time: .omitted)) - \(eventEndDate.formatted(date: .abbreviated, time: .omitted))"
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

    @MainActor
    func apply(to model: ForecastModel) {
        model.replaceCurrentForecast(
            with: ForecastPersistenceSnapshot(
                scale: scale,
                capacity: capacity,
                attendance: min(attendance, capacity),
                ticketPrice: ticketPrice,
                profitTarget: profitTarget,
                additionalRevenue: additionalRevenue,
                expenseBudget: expenseBudget,
                revenueItems: revenueItems,
                expenseItems: expenseItems
            )
        )
    }
}

@MainActor
@Observable
final class ForecastLibrary {
    private(set) var records: [SavedForecast] = []
    private(set) var activeRecordID: UUID?
    var workingName = "Untitled Event"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey = "eventForecast.savedForecasts.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    var activeRecord: SavedForecast? {
        guard let activeRecordID else { return nil }
        return records.first { $0.id == activeRecordID }
    }

    var activeRecordName: String? {
        activeRecord?.name
    }

    var isAutoSaveEnabled: Bool {
        activeRecord?.autoSaveEnabled ?? false
    }

    func hasUnsavedChanges(from model: ForecastModel) -> Bool {
        guard let activeRecord else { return true }
        return activeRecord.name != normalizedName(workingName)
            || activeRecord.persistenceSnapshot != model.persistenceSnapshot
    }

    @discardableResult
    func saveCurrent(
        named proposedName: String,
        eventDate proposedDate: Date? = nil,
        eventEndDate proposedEndDate: Date? = nil,
        eventDateApplies proposedDateApplies: Bool? = nil,
        updateEventSchedule: Bool = false,
        from model: ForecastModel,
        asNew: Bool = false
    ) -> SavedForecast {
        let name = normalizedName(proposedName)

        if !asNew,
           let activeRecordID,
           let index = records.firstIndex(where: { $0.id == activeRecordID }) {
            let current = records[index]
            let updated = SavedForecast(
                id: activeRecordID,
                name: name,
                model: model,
                eventDate: updateEventSchedule ? (proposedDate ?? current.eventDate) : current.eventDate,
                eventEndDate: updateEventSchedule ? proposedEndDate : current.eventEndDate,
                eventDateApplies: updateEventSchedule ? (proposedDateApplies ?? current.eventDateApplies) : current.eventDateApplies,
                autoSaveEnabled: current.autoSaveEnabled
            )
            records[index] = updated
            workingName = updated.name
            sortAndPersist()
            return updated
        }

        let saved = SavedForecast(
            name: name,
            model: model,
            eventDate: proposedDate ?? .now,
            eventEndDate: proposedEndDate,
            eventDateApplies: proposedDateApplies ?? true
        )
        records.append(saved)
        activeRecordID = saved.id
        workingName = saved.name
        sortAndPersist()
        return saved
    }

    func saveActive(from model: ForecastModel) {
        guard let activeRecord else { return }
        _ = saveCurrent(
            named: activeRecord.name,
            eventDate: activeRecord.eventDate,
            eventEndDate: activeRecord.eventEndDate,
            eventDateApplies: activeRecord.eventDateApplies,
            from: model
        )
    }

    func setAutoSaveEnabled(_ enabled: Bool, from model: ForecastModel) {
        guard let activeRecordID,
              let index = records.firstIndex(where: { $0.id == activeRecordID })
        else { return }

        let current = records[index]
        records[index] = SavedForecast(
            id: current.id,
            name: current.name,
            model: model,
            eventDate: current.eventDate,
            eventEndDate: current.eventEndDate,
            eventDateApplies: current.eventDateApplies,
            autoSaveEnabled: enabled
        )
        sortAndPersist()
    }

    func open(_ record: SavedForecast, in model: ForecastModel) {
        record.apply(to: model)
        activeRecordID = record.id
        workingName = record.name
    }

    func rename(_ recordID: UUID, to proposedName: String) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }
        records[index].name = normalizedName(proposedName)
        records[index].updatedAt = .now
        if activeRecordID == recordID {
            workingName = records[index].name
        }
        sortAndPersist()
    }

    func commitWorkingName() {
        workingName = normalizedName(workingName)
        if let activeRecordID {
            rename(activeRecordID, to: workingName)
        }
    }

    @discardableResult
    func duplicate(_ record: SavedForecast, makeActive: Bool = false) -> SavedForecast {
        let copy = SavedForecast(copying: record, name: availableCopyName(for: record.name))
        records.append(copy)
        if makeActive {
            activeRecordID = copy.id
            workingName = copy.name
        }
        sortAndPersist()
        return copy
    }

    @discardableResult
    func duplicateActive(from model: ForecastModel) -> SavedForecast? {
        guard let activeRecord else { return nil }
        let copy = SavedForecast(
            name: availableCopyName(for: activeRecord.name),
            model: model,
            eventDate: activeRecord.eventDate,
            eventEndDate: activeRecord.eventEndDate,
            eventDateApplies: activeRecord.eventDateApplies
        )
        records.append(copy)
        activeRecordID = copy.id
        workingName = copy.name
        sortAndPersist()
        return copy
    }

    func updateEventDate(
        _ recordID: UUID,
        startDate: Date,
        endDate: Date?,
        applies: Bool
    ) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }
        records[index].eventDate = startDate
        records[index].eventEndDate = endDate
        records[index].eventDateApplies = applies
        records[index].updatedAt = .now
        sortAndPersist()
    }

    func delete(_ record: SavedForecast) {
        records.removeAll { $0.id == record.id }
        if activeRecordID == record.id {
            activeRecordID = nil
            workingName = "Untitled Event"
        }
        persist()
    }

    func detachCurrentForecast(named name: String = "Untitled Event") {
        activeRecordID = nil
        workingName = normalizedName(name)
    }

    private func normalizedName(_ proposedName: String) -> String {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Event" : trimmed
    }

    private func availableCopyName(for original: String) -> String {
        let base = "\(original) Copy"
        if !records.contains(where: { $0.name.caseInsensitiveCompare(base) == .orderedSame }) {
            return base
        }
        var number = 2
        while records.contains(where: { $0.name.caseInsensitiveCompare("\(base) \(number)") == .orderedSame }) {
            number += 1
        }
        return "\(base) \(number)"
    }

    private func sortAndPersist() {
        records.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func restore() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedForecast].self, from: data)
        else { return }
        records = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }
}
