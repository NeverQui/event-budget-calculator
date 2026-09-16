import SwiftUI

enum EventScrollDestination: String, Hashable {
    case top
    case saved
}

struct EventLibraryView: View {
    @Bindable var library: ForecastLibrary
    let model: ForecastModel
    let scrollDestination: EventScrollDestination
    let scrollRequest: Int
    let openForecast: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftDate = Date.now
    @State private var draftEndDate = Date.now
    @State private var eventDateApplies = true
    @State private var usesDateSpan = false
    @State private var showsCalendar = true
    @State private var showsEventEntry = false
    @State private var savedNotice: String?
    @State private var showsNewEventConfirmation = false
    @State private var selectedCalendarDate: Date?
    @State private var selectedRecordID: UUID?

    private var displayedRecords: [SavedForecast] {
        guard let selectedCalendarDate else { return library.records }
        return library.records.filter { $0.includes(selectedCalendarDate) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    eventEntrySection
                        .id(EventScrollDestination.top)

                    Divider().overlay(ForecastTheme.divider)

                    calendarSection

                    Divider().overlay(ForecastTheme.divider)

                    savedEventsSection
                        .id(EventScrollDestination.saved)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .onChange(of: scrollRequest) { _, _ in
                if reduceMotion {
                    proxy.scrollTo(scrollDestination, anchor: .top)
                } else {
                    withAnimation(ForecastMotion.navigation) {
                        proxy.scrollTo(scrollDestination, anchor: .top)
                    }
                }
            }
        }
        .background(ForecastTheme.canvas)
        .onAppear(perform: syncDraft)
        .onChange(of: library.activeRecordID) { _, _ in syncDraft() }
        .onChange(of: draftDate) { _, newDate in
            if draftEndDate < newDate { draftEndDate = newDate }
            persistScheduleIfNeeded()
        }
        .onChange(of: draftEndDate) { _, _ in persistScheduleIfNeeded() }
        .onChange(of: eventDateApplies) { _, _ in persistScheduleIfNeeded() }
        .onChange(of: usesDateSpan) { _, _ in persistScheduleIfNeeded() }
        .confirmationDialog(
            "Start a new event?",
            isPresented: $showsNewEventConfirmation,
            titleVisibility: .visible
        ) {
            if library.activeRecordID != nil, !library.isAutoSaveEnabled {
                Button("Save Current & Start New") {
                    _ = library.saveCurrent(
                        named: library.workingName,
                        eventDate: draftDate,
                        eventEndDate: usesDateSpan ? draftEndDate : nil,
                        eventDateApplies: eventDateApplies,
                        updateEventSchedule: true,
                        from: model
                    )
                    startNewEvent()
                }
                Button("Start Without Saving", role: .destructive, action: startNewEvent)
            } else {
                Button("Start New Event", action: startNewEvent)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(newEventConfirmationMessage)
        }
    }

    private var calendarSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Calendar")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    withAnimation(reduceMotion ? nil : ForecastMotion.navigation) {
                        showsCalendar.toggle()
                        if !showsCalendar { selectedCalendarDate = nil }
                    }
                } label: {
                    Label(showsCalendar ? "Hide" : "Show", systemImage: showsCalendar ? "calendar.badge.minus" : "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ForecastTheme.warning)
                }
                .buttonStyle(.plain)
            }

            if showsCalendar {
                EventCalendarView(records: library.records, selectedDate: $selectedCalendarDate)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var eventEntrySection: some View {
        Group {
            if showsEventEntry {
                currentForecastSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : ForecastMotion.navigation) {
                        showsEventEntry = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.black)
                            .frame(width: 32, height: 32)
                            .background(ForecastTheme.warning, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add event")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(ForecastTheme.primaryText)
                            Text("Reveal event setup and scheduling")
                                .font(.caption)
                                .foregroundStyle(ForecastTheme.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ForecastTheme.breakEven)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 54)
                    .budgetGlassSurface(tint: ForecastTheme.breakEven, cornerRadius: 14, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add event")
                .accessibilityHint("Shows event setup and scheduling")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var currentForecastSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Event setup")
                    .font(.headline.weight(.semibold))
                Spacer()
                if let savedNotice {
                    Label(savedNotice, systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ForecastTheme.warning)
                        .transition(.opacity)
                }
                Button {
                    withAnimation(reduceMotion ? nil : ForecastMotion.navigation) {
                        showsEventEntry = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ForecastTheme.secondaryText)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide event setup")
            }

            HStack(spacing: 8) {
                TextField("Event name", text: $library.workingName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(library.commitWorkingName)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(ForecastTheme.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Button(action: saveCurrent) {
                    Image(systemName: library.activeRecordID == nil ? "tray.and.arrow.down" : "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 40, height: 40)
                        .background(ForecastTheme.warning, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(primarySaveTitle)

                Button {
                    showsNewEventConfirmation = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ForecastTheme.primaryText)
                        .frame(width: 40, height: 40)
                        .background(ForecastTheme.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start new event with starter values")
            }

            Toggle("Event date", isOn: $eventDateApplies)
                .font(.subheadline.weight(.medium))
                .tint(ForecastTheme.warning)

            if eventDateApplies {
                DatePicker("Starts", selection: $draftDate, displayedComponents: .date)
                    .font(.subheadline.weight(.medium))
                    .tint(ForecastTheme.warning)

                Toggle("Date span", isOn: $usesDateSpan)
                    .font(.subheadline.weight(.medium))
                    .tint(ForecastTheme.warning)

                if usesDateSpan {
                    DatePicker("Ends", selection: $draftEndDate, in: draftDate..., displayedComponents: .date)
                        .font(.subheadline.weight(.medium))
                        .tint(ForecastTheme.warning)
                }
            }

            if library.activeRecordID != nil {
                Toggle("Auto-save every change", isOn: autoSaveBinding)
                    .font(.subheadline.weight(.medium))
                    .tint(ForecastTheme.warning)
            }

        }
    }

    private var savedEventsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selectedCalendarDate.map {
                    $0.formatted(date: .abbreviated, time: .omitted)
                } ?? "Saved events")
                    .font(.headline.weight(.semibold))

                Spacer()

                if selectedCalendarDate != nil {
                    Button("Show all") {
                        withAnimation(ForecastMotion.control) {
                            selectedCalendarDate = nil
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
            }
            .padding(.bottom, 8)

            if displayedRecords.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(ForecastTheme.secondaryText)
                    Text(selectedCalendarDate == nil ? "No saved events yet" : "No events on this date")
                        .font(.subheadline.weight(.semibold))
                    Text(selectedCalendarDate == nil
                         ? "Save the current budget to add it to your events."
                         : "Choose another date or show all saved events.")
                        .font(.caption)
                        .foregroundStyle(ForecastTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(displayedRecords) { record in
                    VStack(spacing: 0) {
                        SavedEventRow(
                            record: record,
                            isActive: library.activeRecordID == record.id,
                            isSelected: selectedRecordID == record.id,
                            select: { selectedRecordID = record.id },
                            open: {
                                library.open(record, in: model)
                                syncDraft()
                                openForecast()
                            },
                            duplicate: {
                                let copy = library.duplicate(record)
                                selectedRecordID = copy.id
                                showSavedNotice("Duplicated")
                            },
                            delete: { delete(record) }
                        )
                        Divider().overlay(ForecastTheme.divider)
                    }
                }
            }
        }
    }

    private var primarySaveTitle: String {
        library.activeRecordID == nil ? "Save event" : "Save changes"
    }

    private var autoSaveBinding: Binding<Bool> {
        Binding(
            get: { library.isAutoSaveEnabled },
            set: { enabled in
                library.setAutoSaveEnabled(enabled, from: model)
                showSavedNotice(enabled ? "Auto-save on" : "Manual mode")
            }
        )
    }

    private var newEventConfirmationMessage: String {
        if library.activeRecordID == nil {
            return "A fresh small-event example will replace the current unsaved values. Saved events are not affected."
        }
        if library.isAutoSaveEnabled {
            return "The open event is already saved. A fresh small-event example will open next."
        }
        return "Save your changes first, or continue with the previously saved version."
    }

    private func saveCurrent() {
        let saved = library.saveCurrent(
            named: library.workingName,
            eventDate: draftDate,
            eventEndDate: usesDateSpan ? draftEndDate : nil,
            eventDateApplies: eventDateApplies,
            updateEventSchedule: true,
            from: model
        )
        library.workingName = saved.name
        draftDate = saved.eventDate
        draftEndDate = saved.eventEndDate ?? saved.eventDate
        usesDateSpan = saved.eventEndDate != nil
        eventDateApplies = saved.eventDateApplies
        showSavedNotice("Saved")
        withAnimation(reduceMotion ? nil : ForecastMotion.navigation) {
            showsEventEntry = false
        }
    }

    private func startNewEvent() {
        library.detachCurrentForecast(named: "Event \(library.records.count + 1)")
        model.loadStarterEvent()
        draftDate = .now
        draftEndDate = .now
        usesDateSpan = false
        eventDateApplies = true
        selectedRecordID = nil
        showsEventEntry = false
        openForecast()
    }

    private func delete(_ record: SavedForecast) {
        library.delete(record)
        if library.activeRecordID == nil {
            draftDate = .now
        }
    }

    private func syncDraft() {
        let record = library.activeRecord
        draftDate = record?.eventDate ?? .now
        draftEndDate = record?.eventEndDate ?? record?.eventDate ?? .now
        usesDateSpan = record?.eventEndDate != nil
        eventDateApplies = record?.eventDateApplies ?? true
    }

    private func persistScheduleIfNeeded() {
        guard let activeRecordID = library.activeRecordID,
              library.isAutoSaveEnabled else { return }
        library.updateEventDate(
            activeRecordID,
            startDate: draftDate,
            endDate: usesDateSpan ? draftEndDate : nil,
            applies: eventDateApplies
        )
    }

    private func showSavedNotice(_ message: String) {
        if reduceMotion {
            savedNotice = message
        } else {
            withAnimation(ForecastMotion.control) {
                savedNotice = message
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard savedNotice == message else { return }
            if reduceMotion {
                savedNotice = nil
            } else {
                withAnimation(ForecastMotion.control) {
                    savedNotice = nil
                }
            }
        }
    }
}

private struct EventCalendarView: View {
    let records: [SavedForecast]
    @Binding var selectedDate: Date?

    @State private var visibleMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthDays: [CalendarCell] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth),
              let days = calendar.range(of: .day, in: .month, for: visibleMonth)
        else { return [] }

        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells = (0 ..< leading).map { CalendarCell(id: "leading-\($0)", date: nil) }
        for day in days {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start) {
                cells.append(CalendarCell(id: date.formatted(.iso8601), date: date))
            }
        }
        return cells
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let index = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[index...] + symbols[..<index])
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous month")

                Spacer()

                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline.weight(.semibold))

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next month")
            }
            .foregroundStyle(ForecastTheme.primaryText)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ForecastTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDays) { cell in
                    if let date = cell.date {
                        CalendarDayCell(
                            date: date,
                            recordCount: records.count { $0.includes(date, calendar: calendar) },
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            isToday: calendar.isDateInToday(date),
                            action: {
                                withAnimation(ForecastMotion.control) {
                                    if let selectedDate, calendar.isDate(selectedDate, inSameDayAs: date) {
                                        self.selectedDate = nil
                                    } else {
                                        selectedDate = date
                                    }
                                }
                            }
                        )
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }

    private func changeMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        withAnimation(ForecastMotion.navigation) {
            visibleMonth = next
            selectedDate = nil
        }
    }
}

private struct CalendarCell: Identifiable {
    let id: String
    let date: Date?
}

private struct CalendarDayCell: View {
    let date: Date
    let recordCount: Int
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(.caption.weight(isSelected || isToday ? .bold : .medium))

                HStack(spacing: 2) {
                    ForEach(0 ..< min(recordCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Color.black : ForecastTheme.warning)
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(height: 4)
            }
            .foregroundStyle(isSelected ? Color.black : ForecastTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ForecastTheme.warning)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ForecastTheme.warning.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(date: .long, time: .omitted)), \(recordCount) events")
    }
}

private struct SavedEventRow: View {
    let record: SavedForecast
    let isActive: Bool
    let isSelected: Bool
    let select: () -> Void
    let open: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private var resultColor: Color {
        if record.profit > 0 { return ForecastTheme.profit }
        if record.profit < 0 { return ForecastTheme.expense }
        return ForecastTheme.secondaryText
    }

    var body: some View {
        ZStack {
            HStack {
                Button(role: .destructive) {
                    settledOffset = 0
                    delete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 54)
                        .background(ForecastTheme.expense)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(ForecastMotion.control) { settledOffset = 0 }
                    duplicate()
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .foregroundStyle(Color.black)
                        .frame(width: 70, height: 54)
                        .background(ForecastTheme.warning)
                }
                .buttonStyle(.plain)
            }

            rowContent
                .offset(x: displayedOffset)
                .simultaneousGesture(swipeGesture)
                .onTapGesture(count: 2) {
                    guard settledOffset == 0 else { return }
                    open()
                }
                .onTapGesture {
                    if settledOffset != 0 {
                        withAnimation(ForecastMotion.control) { settledOffset = 0 }
                    } else {
                        select()
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityHint("Double-tap to open. Swipe right to delete or left to duplicate.")
        .accessibilityAction(named: "Open event", open)
        .accessibilityAction(named: "Duplicate event", duplicate)
        .accessibilityAction(named: "Delete event", delete)
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ForecastTheme.primaryText)
                        .lineLimit(1)
                    if isActive {
                        Text("Open")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ForecastTheme.warning)
                    }
                }

                Text(record.eventDateLabel)
                    .font(.caption2)
                    .foregroundStyle(ForecastTheme.secondaryText)

                HStack(spacing: 10) {
                    Label(ForecastTheme.compactCurrency(record.ticketPrice), systemImage: "ticket")
                        .foregroundStyle(ForecastTheme.tickets)
                    Label(ForecastTheme.compactCurrency(record.totalRevenue), systemImage: "banknote")
                        .foregroundStyle(ForecastTheme.revenue)
                    Label(ForecastTheme.compactCurrency(record.totalExpenses), systemImage: "creditcard")
                        .foregroundStyle(ForecastTheme.expense)
                }
                .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(record.profit >= 0 ? "Profit" : "Loss")
                    .font(.caption2)
                    .foregroundStyle(ForecastTheme.secondaryText)
                Text(ForecastTheme.compactCurrency(abs(record.profit)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(resultColor)
                    .monospacedDigit()
            }

        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(isSelected ? ForecastTheme.warning.opacity(0.055) : ForecastTheme.canvas)
        .contentShape(Rectangle())
    }

    private var displayedOffset: CGFloat {
        min(max(settledOffset + dragOffset, -70), 70)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let projected = settledOffset + value.predictedEndTranslation.width
                let destination: CGFloat
                if projected > 34 {
                    destination = 70
                } else if projected < -34 {
                    destination = -70
                } else {
                    destination = 0
                }
                withAnimation(ForecastMotion.control) { settledOffset = destination }
            }
    }
}
