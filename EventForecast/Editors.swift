import SwiftUI
import UniformTypeIdentifiers

struct TicketsEditor: View {
    @Bindable var model: ForecastModel
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            PricingGuide(model: model)

            AdaptiveValueControl(
                title: "Ticket price",
                value: $model.ticketPrice,
                range: 0 ... ticketPriceUpperBound,
                step: 1,
                prefix: "$",
                buttonStep: model.scale.ticketPriceButtonStep,
                tint: model.profit >= 0 ? ForecastTheme.profit : ForecastTheme.expense,
                compact: compact,
                markers: priceMarkers
            )

            AdaptiveValueControl(
                title: "Tickets available",
                value: $model.capacity,
                range: model.scale.capacityRange,
                step: model.scale.capacityStep,
                prefix: nil,
                buttonStep: model.scale.capacityButtonStep,
                tint: ForecastTheme.tickets,
                compact: compact
            )

            AdaptiveValueControl(
                title: "Expected attendance",
                value: Binding(
                    get: { model.attendance },
                    set: { model.attendance = min($0, model.capacity) }
                ),
                range: 0 ... max(model.capacity, 1),
                step: min(model.scale.capacityStep, max(model.capacity, 1)),
                prefix: nil,
                buttonStep: model.scale.capacityButtonStep,
                isEnabled: model.capacity > 0,
                tint: ForecastTheme.tickets,
                compact: compact
            )

        }
    }

    private var priceMarkers: [SliderMarker] {
        var markers: [SliderMarker] = []
        if let price = model.breakEvenTicketPrice {
            markers.append(SliderMarker(title: "Break-even", value: ceil(price), color: ForecastTheme.breakEven))
        }
        if model.profitTarget > 0, let price = model.targetTicketPrice {
            markers.append(SliderMarker(title: "Target", value: ceil(price), color: ForecastTheme.target))
        }
        return markers
    }

    private var ticketPriceUpperBound: Double {
        let contextualMinimum: Double
        switch model.scale {
        case .small: contextualMinimum = 100
        case .medium: contextualMinimum = 250
        case .large: contextualMinimum = 500
        }
        let largestRelevantPrice = max(model.ticketPrice, model.breakEvenTicketPrice ?? 0, model.targetTicketPrice ?? 0)
        return max(model.ticketPrice, min(max(contextualMinimum, largestRelevantPrice * 1.35), model.scale.ticketPriceRange.upperBound))
    }
}

private struct PricingGuide: View {
    let model: ForecastModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            priceOption(
                title: "Break-even price",
                value: model.breakEvenTicketPrice.map { ceil($0) },
                detail: model.breakEvenTickets.map { "\($0) tickets to break even" } ?? "Not reachable",
                color: ForecastTheme.breakEven,
                action: model.useBreakEvenTicketPrice
            )

            Divider().overlay(ForecastTheme.divider)

            priceOption(
                title: "Target ticket price",
                value: model.profitTarget > 0 ? model.targetTicketPrice.map { ceil($0) } : nil,
                detail: model.profitTargetTickets.map { "\($0) tickets for target" } ?? (model.profitTarget > 0 ? "Not reachable" : "Set a profit target"),
                color: ForecastTheme.target,
                action: model.useTargetTicketPrice
            )
        }
        .frame(minHeight: 54)
    }

    private func priceOption(
        title: String,
        value: Double?,
        detail: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ForecastTheme.secondaryText)
                    .lineLimit(1)
                Text(value.map(ForecastTheme.compactCurrency) ?? "—")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Use") {
                if reduceMotion {
                    action()
                } else {
                    withAnimation(ForecastMotion.control, action)
                }
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(ForecastTheme.accentForeground)
            .frame(width: 38, height: 30)
            .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .buttonStyle(.plain)
            .disabled(value == nil)
            .opacity(value == nil ? 0.42 : 1)
            .accessibilityLabel("Use \(title.lowercased())")
        }
    }
}

struct BudgetEditor: View {
    let title: String
    let totalTitle: String
    @Binding var total: Double
    @Binding var items: [MoneyItem]
    let kind: ItemizationKind
    let tint: Color
    let compact: Bool
    let markers: [SliderMarker]
    @Binding var isItemizedExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var amountScale: EventScale {
        EventScale.moneyScale(for: total)
    }

    private var itemizedTotal: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private var itemizedStatus: String {
        let difference = total - itemizedTotal
        if difference > 0.005 { return "\(ForecastTheme.compactCurrency(difference)) unallocated" }
        if difference < -0.005 { return "\(ForecastTheme.compactCurrency(abs(difference))) over" }
        return "Balanced"
    }

    var body: some View {
        VStack(spacing: compact ? 7 : 9) {
            AdaptiveValueControl(
                title: totalTitle,
                value: $total,
                range: 0 ... max(
                    amountScale.moneyRange.upperBound,
                    (markers.map(\.value).max() ?? 0) * 1.2
                ),
                step: amountScale.moneyStep,
                prefix: "$",
                buttonStep: amountScale.moneyButtonStep,
                tint: tint,
                compact: compact,
                markers: markers
            )

            VStack(spacing: 0) {
                Divider().overlay(ForecastTheme.divider)
                Button {
                    withAnimation(reduceMotion ? nil : ForecastMotion.scale) {
                        isItemizedExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)
                        Text("Itemized \(title.lowercased())")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ForecastTheme.primaryText)
                        Spacer()
                        Text(itemizedStatus)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ForecastTheme.secondaryText)
                            .lineLimit(1)
                        Image(systemName: isItemizedExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ForecastTheme.secondaryText)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(height: 31)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(isItemizedExpanded ? "Hide" : "Show") itemized \(title.lowercased())")
            }

            if isItemizedExpanded {
                ReconciliationSummary(total: total, itemized: itemizedTotal, tint: tint)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                ItemizedList(
                    items: $items,
                    newItemName: kind == .revenue ? "Revenue item" : "Expense item",
                    kind: kind
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : ForecastMotion.scale, value: isItemizedExpanded)
    }
}

private extension EventScale {
    static func moneyScale(for amount: Double) -> EventScale {
        if amount >= EventScale.medium.moneyRange.upperBound { return .large }
        if amount >= EventScale.small.moneyRange.upperBound { return .medium }
        return .small
    }
}

struct TargetEditor: View {
    @Bindable var model: ForecastModel
    let compact: Bool

    private var targetRange: ClosedRange<Double> {
        model.scale.profitTargetRange.lowerBound ... max(
            model.scale.profitTargetRange.upperBound,
            model.profitTarget
        )
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            AdaptiveValueControl(
                title: "Target profit",
                value: $model.profitTarget,
                range: targetRange,
                step: model.scale.profitTargetStep,
                prefix: "$",
                buttonStep: model.scale.profitTargetButtonStep,
                sliderExponent: 2,
                tint: ForecastTheme.target,
                compact: compact
            )

            HStack(spacing: 18) {
                TargetMetric(
                    title: "Revenue required",
                    value: ForecastTheme.compactCurrency(model.requiredRevenueForProfitTarget)
                )
                TargetMetric(
                    title: "Target attendance",
                    value: model.profitTargetTickets.map { "\($0) tickets" } ?? "Not reachable"
                )
            }
        }
    }
}

private struct TargetMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(ForecastTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ForecastTheme.target)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ItemizationKind: String, CaseIterable, Identifiable {
    case revenue
    case expenses

    var id: Self { self }

    var title: String {
        switch self {
        case .revenue: "Revenue"
        case .expenses: "Expenses"
        }
    }

    var tint: Color {
        switch self {
        case .revenue: ForecastTheme.revenue
        case .expenses: ForecastTheme.expense
        }
    }
}

private struct ReconciliationSummary: View {
    let total: Double
    let itemized: Double
    let tint: Color

    private var difference: Double { total - itemized }
    private var differenceTitle: String {
        if difference > 0.005 { return "Unallocated" }
        if difference < -0.005 { return "Over by" }
        return "Balanced"
    }

    var body: some View {
        HStack(spacing: 12) {
            reconciliationMetric("Set total", value: total, color: tint)
            Divider().overlay(ForecastTheme.divider)
            reconciliationMetric("Itemized", value: itemized, color: ForecastTheme.primaryText)
            Divider().overlay(ForecastTheme.divider)
            reconciliationMetric(
                differenceTitle,
                value: abs(difference),
                color: difference < -0.005 ? ForecastTheme.expense : (difference > 0.005 ? ForecastTheme.warning : ForecastTheme.profit)
            )
        }
        .frame(height: 38)
        .animation(ForecastMotion.data, value: itemized)
    }

    private func reconciliationMetric(_ title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(ForecastTheme.secondaryText)
            Text(ForecastTheme.compactCurrency(value))
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ItemizedList: View {
    @Binding var items: [MoneyItem]
    let newItemName: String
    let kind: ItemizationKind
    @State private var draggingItemID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { kind.tint }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach($items) { $item in
                let index = items.firstIndex(where: { $0.id == item.id }) ?? 0
                ItemizedMoneyRow(
                    item: $item,
                    tint: kind == .revenue
                        ? ForecastTheme.revenueShade(at: index)
                        : ForecastTheme.expenseShade(at: index),
                    beginDragging: {
                        draggingItemID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                )
                .modifier(
                    SwipeToDeleteModifier(
                        itemName: item.name,
                        delete: {
                            withAnimation(reduceMotion ? nil : ForecastMotion.control) {
                                items.removeAll { $0.id == item.id }
                            }
                        }
                    )
                )
                .onDrop(
                    of: [UTType.text],
                    delegate: ItemizedDropDelegate(
                        destinationID: item.id,
                        items: $items,
                        draggingItemID: $draggingItemID,
                        reduceMotion: reduceMotion
                    )
                )

                .accessibilityAction(named: "Move up") { moveItem(item.id, by: -1) }
                .accessibilityAction(named: "Move down") { moveItem(item.id, by: 1) }

                Divider().overlay(ForecastTheme.divider)
            }

            if items.count < MoneyItem.maximumPerLedger {
                Button {
                    items.append(MoneyItem(name: "\(newItemName) \(items.count + 1)", amount: 0))
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
            }
        }
    }
    private func moveItem(_ id: UUID, by offset: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items.indices.contains(index + offset) else { return }
        withAnimation(reduceMotion ? nil : ForecastMotion.control) {
            items.swapAt(index, index + offset)
        }
    }
}

private struct ItemizedMoneyRow: View {
    @Binding var item: MoneyItem
    let tint: Color
    let beginDragging: () -> NSItemProvider

    private var amountScale: EventScale {
        EventScale.moneyScale(for: item.amount)
    }

    var body: some View {
        AdaptiveValueControl(
            title: "",
            value: $item.amount,
            range: amountScale.moneyRange,
            step: amountScale.moneyStep,
            prefix: "$",
            buttonStep: amountScale.moneyButtonStep,
            tint: tint,
            compact: true,
            editableTitle: $item.name,
            leadingColor: tint
        )
        .contentShape(Rectangle())
        .onDrag { beginDragging() }
        .padding(.vertical, 4)
        .background(ForecastTheme.canvas)
    }
}

private struct SwipeToDeleteModifier: ViewModifier {
    let itemName: String
    let delete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private var displayedOffset: CGFloat {
        min(max(settledOffset + dragOffset, -78), 0)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Spacer()
                Button(role: .destructive, action: performDelete) {
                    Text("Delete")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 74)
                        .frame(maxHeight: .infinity)
                        .background(ForecastTheme.expense)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(displayedOffset > -1)
            }

            content
                .offset(x: displayedOffset)
        }
        .clipped()
        .simultaneousGesture(swipeGesture)
        .accessibilityAction(named: "Delete \(itemName)", performDelete)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .updating($dragOffset) { value, state, _ in
                guard value.startLocation.y < 36,
                      abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard value.startLocation.y < 36,
                      abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                if value.predictedEndTranslation.width < -128 {
                    performDelete()
                } else {
                    withAnimation(reduceMotion ? nil : ForecastMotion.control) {
                        settledOffset = value.translation.width < -32 ? -74 : 0
                    }
                }
            }
    }

    private func performDelete() {
        withAnimation(reduceMotion ? nil : ForecastMotion.control) {
            settledOffset = -78
            delete()
        }
    }
}

private struct ItemizedDropDelegate: DropDelegate {
    let destinationID: UUID
    @Binding var items: [MoneyItem]
    @Binding var draggingItemID: UUID?
    let reduceMotion: Bool

    func dropEntered(info: DropInfo) {
        guard let draggingItemID,
              draggingItemID != destinationID,
              let sourceIndex = items.firstIndex(where: { $0.id == draggingItemID }),
              let destinationIndex = items.firstIndex(where: { $0.id == destinationID })
        else { return }

        withAnimation(reduceMotion ? nil : ForecastMotion.control) {
            items.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItemID = nil
        return true
    }
}

struct SliderMarker: Identifiable {
    let title: String
    let value: Double
    let color: Color

    var id: String { title }
}

struct AdaptiveValueControl: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let prefix: String?
    var suffix: String? = nil
    var buttonStep: Double = 1
    var sliderExponent: Double = 1
    var isEnabled: Bool = true
    let tint: Color
    let compact: Bool
    var markers: [SliderMarker] = []
    var editableTitle: Binding<String>? = nil
    var leadingColor: Color? = nil

    @State private var draft = ""
    @State private var heldSliderRange: ClosedRange<Double>?
    @State private var heldSliderStep: Double?
    @State private var isSliderEditing = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: compact ? 12 : 14) {
            HStack(spacing: 6) {
                if let leadingColor {
                    Circle()
                        .fill(leadingColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                if let editableTitle {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ForecastTheme.secondaryText.opacity(0.72))
                        .accessibilityHidden(true)
                    TextField("Item name", text: editableTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .textInputAutocapitalization(.words)
                        .lineLimit(1)
                } else if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }

                Spacer(minLength: 6)

                stepButton(systemImage: "minus", delta: -buttonStep)

                HStack(spacing: 1) {
                    if let prefix {
                        Text(prefix).foregroundStyle(ForecastTheme.secondaryText)
                    }
                    TextField("Value", text: $draft)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .focused($isFocused)
                        .accessibilityLabel("\(controlTitle) value")
                    if let suffix {
                        Text(suffix).foregroundStyle(ForecastTheme.secondaryText)
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .frame(width: compact ? 82 : 88, height: compact ? 34 : 36)
                .padding(.horizontal, 4)
                .budgetGlassSurface(cornerRadius: 8, interactive: true)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            ForecastTheme.primaryText.opacity(isFocused ? 0.55 : 0.18),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                }

                stepButton(systemImage: "plus", delta: buttonStep)
            }

            valueSlider
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        adjustValue(by: buttonStep)
                    case .decrement:
                        adjustValue(by: -buttonStep)
                    @unknown default:
                        break
                    }
                }
        }
        .padding(.vertical, compact ? 2 : 4)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.46)
        .onAppear { syncDraft() }
        .onChange(of: value) { _, _ in
            if !isFocused { syncDraft() }
        }
        .onChange(of: isFocused) { oldValue, newValue in
            if oldValue && !newValue {
                commitDraft()
                syncDraft()
            }
        }
        .toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var controlTitle: String { editableTitle?.wrappedValue ?? title }

    private func stepButton(systemImage: String, delta: Double) -> some View {
        Button {
            adjustValue(by: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(ForecastTheme.primaryText)
                .frame(width: compact ? 34 : 36, height: compact ? 34 : 36)
                .budgetGlassSurface(cornerRadius: 8, interactive: true)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ForecastTheme.divider, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(systemImage == "plus" ? "Increase" : "Decrease") \(controlTitle)")
        .accessibilityHint("Changes by \(shortValue(buttonStep))")
    }

    private func adjustValue(by delta: Double) {
        if isFocused {
            let base = parsedDraftValue ?? value
            let nextValue = (base + delta).clamped(to: range)
            draft = nextValue.formatted(.number.precision(.fractionLength(0)))
            value = nextValue
            isFocused = false
            return
        }
        let nextValue = (value + delta).clamped(to: range)
        if reduceMotion {
            value = nextValue
        } else {
            withAnimation(ForecastMotion.control) {
                value = nextValue
            }
        }
    }

    @ViewBuilder
    private var valueSlider: some View {
        ZStack {
            if sliderExponent == 1 {
                Slider(
                    value: validatedSliderValue,
                    in: effectiveSliderRange,
                    step: effectiveSliderStep,
                    onEditingChanged: handleSliderEditing
                ) {
                    Text(controlTitle)
                }
                .modifier(ValueSliderStyle(tint: tint, accessibilityValue: accessibilityValue))
                .modifier(BudgetSliderGlassModifier(tint: tint))
            } else {
                Slider(
                    value: curvedSliderValue,
                    in: 0 ... 1,
                    onEditingChanged: handleSliderEditing
                ) {
                    Text(controlTitle)
                }
                .modifier(ValueSliderStyle(tint: tint, accessibilityValue: accessibilityValue))
                .modifier(BudgetSliderGlassModifier(tint: tint))
            }

            if !markers.isEmpty {
                GeometryReader { geometry in
                    let inset: CGFloat = 14
                    let usableWidth = max(geometry.size.width - inset * 2, 1)
                    ForEach(markers) { marker in
                        let normalized = markerPosition(marker.value)
                        VStack(spacing: 1) {
                            Circle()
                                .fill(marker.color)
                                .frame(width: 6, height: 6)
                        }
                        .position(x: inset + usableWidth * normalized, y: geometry.size.height / 2)
                        .accessibilityHidden(true)
                    }
                }
                .allowsHitTesting(false)
            }

            if let activeMarker {
                GeometryReader { geometry in
                    let inset: CGFloat = 14
                    let usableWidth = max(geometry.size.width - inset * 2, 1)
                    Circle()
                        .fill(activeMarker.color)
                        .overlay { Circle().stroke(ForecastTheme.primaryText, lineWidth: 2) }
                        .frame(width: 22, height: 22)
                        .position(
                            x: inset + usableWidth * markerPosition(activeMarker.value),
                            y: geometry.size.height / 2
                        )
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
                .allowsHitTesting(false)
            }
        }
        .frame(height: 22)
        .modifier(BudgetSliderGlassModifier(tint: tint))
        .accessibilityHint(markerAccessibilityHint)
        .animation(reduceMotion ? nil : ForecastMotion.control, value: activeMarker?.id)
        .sensoryFeedback(.selection, trigger: activeMarker?.id)
    }

    private var activeMarker: SliderMarker? {
        guard value.isFinite else { return nil }
        let tolerance = max(effectiveSliderStep / 2, 0.5)
        return markers.min { abs($0.value - value) < abs($1.value - value) }
            .flatMap { abs($0.value - value) <= tolerance ? $0 : nil }
    }

    private func markerPosition(_ markerValue: Double) -> Double {
        let sliderRange = effectiveSliderRange
        let span = sliderRange.upperBound - sliderRange.lowerBound
        guard markerValue.isFinite, span.isFinite, span > 0 else { return 0 }
        return ((markerValue - sliderRange.lowerBound) / span).clamped(to: 0 ... 1)
    }

    private var markerAccessibilityHint: String {
        guard !markers.isEmpty else { return "" }
        return markers.map { "\($0.title) \($0.value.formatted(ForecastTheme.currencyFormat))" }.joined(separator: ", ")
    }

    private var curvedSliderValue: Binding<Double> {
        Binding(
            get: {
                let sliderRange = effectiveSliderRange
                let span = sliderRange.upperBound - sliderRange.lowerBound
                guard value.isFinite, span.isFinite, span > 0, sliderExponent.isFinite, sliderExponent > 0 else { return 0 }
                let normalized = ((value - sliderRange.lowerBound) / span).clamped(to: 0 ... 1)
                return pow(normalized, 1 / sliderExponent)
            },
            set: { position in
                guard position.isFinite else { return }
                let sliderRange = effectiveSliderRange
                let sliderStep = effectiveSliderStep
                let span = sliderRange.upperBound - sliderRange.lowerBound
                let normalized = position.clamped(to: 0 ... 1)
                let rawValue = sliderRange.lowerBound + pow(normalized, sliderExponent) * span
                guard rawValue.isFinite else { return }
                value = snappedValue(rawValue.rounded(to: sliderStep).clamped(to: sliderRange))
            }
        )
    }

    private var validatedSliderValue: Binding<Double> {
        Binding(
            get: {
                guard value.isFinite else { return effectiveSliderRange.lowerBound }
                return value.clamped(to: effectiveSliderRange)
            },
            set: { newValue in
                guard newValue.isFinite else { return }
                value = snappedValue(newValue.clamped(to: effectiveSliderRange))
            }
        )
    }

    private var effectiveSliderRange: ClosedRange<Double> {
        heldSliderRange ?? range
    }

    private var effectiveSliderStep: Double {
        heldSliderStep ?? step
    }

    private func snappedValue(_ proposedValue: Double) -> Double {
        guard !markers.isEmpty else { return proposedValue }
        let span = effectiveSliderRange.upperBound - effectiveSliderRange.lowerBound
        let threshold = max(effectiveSliderStep * 1.5, span * 0.012)
        guard let marker = markers.min(by: {
            abs($0.value - proposedValue) < abs($1.value - proposedValue)
        }), abs(marker.value - proposedValue) <= threshold else {
            return proposedValue
        }
        return marker.value.clamped(to: effectiveSliderRange)
    }

    private func handleSliderEditing(_ editing: Bool) {
        isSliderEditing = editing
        if editing {
            heldSliderRange = range
            heldSliderStep = step
            return
        }

        // Let Slider finish its gesture transaction before adopting a range or
        // step that may have changed because the event scale changed mid-drag.
        Task { @MainActor in
            await Task.yield()
            guard !isSliderEditing else { return }
            let releaseScale = {
                heldSliderRange = nil
                heldSliderStep = nil
            }
            if reduceMotion { releaseScale() }
            else { withAnimation(ForecastMotion.scale, releaseScale) }
        }
    }

    private func syncDraft() {
        draft = value.formatted(.number.precision(.fractionLength(0)))
    }

    private func commitDraft() {
        guard let parsed = parsedDraftValue else { return }
        let committedValue = parsed.clamped(to: range)
        if reduceMotion { value = committedValue }
        else {
            withAnimation(ForecastMotion.control) {
                value = committedValue
            }
        }
    }

    private var parsedDraftValue: Double? {
        let normalized = draft.replacingOccurrences(of: ",", with: "")
        guard !normalized.isEmpty,
              let parsed = Double(normalized),
              parsed.isFinite else { return nil }
        return parsed
    }

    private func shortValue(_ value: Double) -> String {
        if prefix == "$" { return ForecastTheme.compactCurrency(value) }
        return ForecastTheme.compactNumber(value)
    }

    private var accessibilityValue: String {
        if prefix == "$" { return value.formatted(ForecastTheme.currencyFormat) }
        return value.formatted(.number.precision(.fractionLength(0)))
    }
}

private struct ValueSliderStyle: ViewModifier {
    let tint: Color
    let accessibilityValue: String

    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .foregroundStyle(ForecastTheme.secondaryText)
            .tint(tint)
            .accessibilityValue(accessibilityValue)
    }
}
