import Charts
import SwiftUI

enum SummaryVisualization: String, CaseIterable, Identifiable {
    case mix
    case budget
    case attendance
    case pricing

    var id: Self { self }

    var title: String {
        switch self {
        case .mix: "Mix"
        case .budget: "Budget"
        case .attendance: "Attendance"
        case .pricing: "Pricing"
        }
    }

    var systemImage: String {
        switch self {
        case .mix: "chart.pie"
        case .budget: "chart.bar.fill"
        case .attendance: "person.2.fill"
        case .pricing: "slider.horizontal.below.square.filled.and.square"
        }
    }

    var next: SummaryVisualization {
        let options = Self.allCases
        guard let index = options.firstIndex(of: self) else { return .mix }
        return options[(index + 1) % options.count]
    }
}

private enum ForecastOutcome {
    case empty
    case profit
    case loss
    case breakEven
}

struct ResultSummaryView: View {
    let model: ForecastModel
    let compact: Bool
    let expanded: Bool
    let overviewProgress: CGFloat
    let availableHeight: CGFloat
    @Binding var visualization: SummaryVisualization
    let selectEditor: (EditorTab) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: compact ? 8 : 11) {
            ForecastHeadlineMetrics(
                model: model,
                expanded: expanded,
                condensed: overviewProgress < 0.5,
                overviewProgress: overviewProgress,
                selectTarget: { selectEditor(.target) }
            )

            Divider().overlay(ForecastTheme.divider)

            ZStack(alignment: .top) {
                if overviewProgress < 1 {
                    CompactVisualizationOverview(model: model, selectEditor: selectEditor)
                        .opacity(Double(1 - min(overviewProgress * 2, 1)))
                        .allowsHitTesting(overviewProgress < 0.5)
                        .accessibilityElement(children: .contain)
                        .accessibilityHidden(overviewProgress >= 0.5)
                        .transition(.opacity)
                }

                if overviewProgress > 0 {
                    VStack(spacing: compact ? 8 : 11) {
                        VisualizationPager(
                            model: model,
                            compact: compact,
                            expanded: expanded,
                            availableHeight: availableHeight,
                            visualization: $visualization,
                            selectEditor: selectEditor
                        )
                        VisualMetricStrip(model: model, selectEditor: selectEditor)
                    }
                    .opacity(Double(max((overviewProgress - 0.35) / 0.65, 0)))
                    .allowsHitTesting(overviewProgress >= 0.5)
                    .accessibilityElement(children: .contain)
                    .accessibilityHidden(overviewProgress < 0.5)
                    .transition(.opacity)
                }
            }
        }
        .padding(.vertical, compact ? 8 : 11)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : ForecastMotion.data, value: model.persistenceSnapshot)
        .accessibilityElement(children: .contain)
    }
}

struct ForecastHeadlineMetrics: View {
    let model: ForecastModel
    let expanded: Bool
    var condensed = false
    var overviewProgress: CGFloat? = nil
    let selectTarget: () -> Void

    private var detailProgress: CGFloat { overviewProgress ?? (condensed ? 0 : 1) }

    private var outcome: ForecastOutcome {
        guard model.hasForecastValues else { return .empty }
        if model.profit > 0.005 { return .profit }
        if model.profit < -0.005 { return .loss }
        return .breakEven
    }

    private var outcomeColor: Color {
        switch outcome {
        case .empty: ForecastTheme.primaryText
        case .profit: ForecastTheme.profit
        case .loss: ForecastTheme.expense
        case .breakEven: ForecastTheme.breakEven
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(resultTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ForecastTheme.secondaryText)
                Text(ForecastTheme.compactCurrency(abs(model.profit)))
                    .font(.system(size: expanded ? 34 : 24 + 5 * detailProgress, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(outcomeColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
                HStack(spacing: 7) {
                    Text(outcome == .empty ? "—" : model.profitMargin.formatted(.percent.precision(.fractionLength(1))))
                        .monospacedDigit()
                    Text(statusTitle)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(outcomeColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(ForecastTheme.divider)

            Button(action: selectTarget) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Profit target")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ForecastTheme.target)
                    Text(model.profitTarget > 0 ? ForecastTheme.compactCurrency(model.profitTarget) : "Set target")
                        .font(.system(size: expanded ? 26 : 20 + 3 * detailProgress, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(ForecastTheme.target)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())
                    Text(targetStatus)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(targetStatusColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.profitTarget > 0
                                ? "Profit target \(model.profitTarget.formatted(ForecastTheme.currencyFormat)), \(targetStatus)"
                                : "Set profit target")
            .accessibilityHint("Opens the Target editor")
        }
        .frame(height: expanded ? 78 : 52 + 14 * detailProgress)
    }

    private var resultTitle: String {
        switch outcome {
        case .empty, .breakEven: "Projected result"
        case .profit: "Projected profit"
        case .loss: "Projected loss"
        }
    }

    private var statusTitle: String {
        switch outcome {
        case .empty: "No budget data"
        case .profit: "Profitable"
        case .loss: "At a loss"
        case .breakEven: "Break even"
        }
    }

    private var targetStatus: String {
        guard model.profitTarget > 0 else { return "Optional" }
        if model.profitTargetDifference >= 0 {
            return "\(ForecastTheme.compactCurrency(model.profitTargetDifference)) above"
        }
        return "\(ForecastTheme.compactCurrency(abs(model.profitTargetDifference))) needed"
    }

    private var targetStatusColor: Color {
        guard model.profitTarget > 0 else { return ForecastTheme.secondaryText }
        return model.hasMetProfitTarget ? ForecastTheme.profit : ForecastTheme.warning
    }
}

private struct CompactVisualizationOverview: View {
    let model: ForecastModel
    let selectEditor: (EditorTab) -> Void

    var body: some View {
        HStack(spacing: 12) {
            BudgetMixChart(model: model, expanded: false)
                .frame(width: 88, height: 74)

            Divider().overlay(ForecastTheme.divider)

            VStack(spacing: 5) {
                metric("Ticket revenue", value: model.ticketRevenue, color: ForecastTheme.tickets, editor: .tickets)
                metric("Revenue", value: model.additionalRevenue, color: ForecastTheme.revenue, editor: .revenue)
                metric("Expenses", value: model.totalExpenses, color: ForecastTheme.expense, editor: .expenses)
            }
        }
        .frame(height: 76)
        .accessibilityElement(children: .contain)
    }

    private func metric(_ title: String, value: Double, color: Color, editor: EditorTab) -> some View {
        Button { selectEditor(editor) } label: {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ForecastTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(ForecastTheme.compactCurrency(value))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the \(editor.title) section")
    }
}

struct VisualizationsView: View {
    let model: ForecastModel

    @State private var primaryVisualization: SummaryVisualization = .mix
    @State private var secondaryVisualization: SummaryVisualization = .pricing
    @State private var showsSecondVisualization = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                ForecastHeadlineMetrics(model: model, expanded: true, selectTarget: {})

                Divider().overlay(ForecastTheme.divider)

                layoutControls

                VisualizationPanel(model: model, visualization: primaryVisualization, height: showsSecondVisualization ? 230 : 310)

                if showsSecondVisualization {
                    VisualizationPanel(model: model, visualization: secondaryVisualization, height: 230)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                VisualMetricStrip(model: model, selectEditor: { _ in })
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(ForecastTheme.canvas)
        .animation(reduceMotion ? nil : ForecastMotion.navigation, value: showsSecondVisualization)
    }

    private var layoutControls: some View {
        HStack(spacing: 8) {
            visualizationMenu(selection: $primaryVisualization, excluding: showsSecondVisualization ? secondaryVisualization : nil)

            if showsSecondVisualization {
                visualizationMenu(selection: $secondaryVisualization, excluding: primaryVisualization)
            }

            Button {
                showsSecondVisualization.toggle()
            } label: {
                Image(systemName: showsSecondVisualization ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(showsSecondVisualization ? ForecastTheme.target : ForecastTheme.secondaryText)
                    .frame(width: 42, height: 38)
                    .background(ForecastTheme.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsSecondVisualization ? "Show one visualization" : "Stack two visualizations")
        }
        .sensoryFeedback(.selection, trigger: showsSecondVisualization)
    }

    private func visualizationMenu(
        selection: Binding<SummaryVisualization>,
        excluding excluded: SummaryVisualization?
    ) -> some View {
        Menu {
            ForEach(SummaryVisualization.allCases.filter { $0 != excluded }) { visualization in
                Button {
                    selection.wrappedValue = visualization
                } label: {
                    Label(visualization.title, systemImage: visualization.systemImage)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selection.wrappedValue.systemImage)
                Text(selection.wrappedValue.title)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(ForecastTheme.secondaryText)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ForecastTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(ForecastTheme.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

private struct VisualizationPager: View {
    let model: ForecastModel
    let compact: Bool
    let expanded: Bool
    let availableHeight: CGFloat
    @Binding var visualization: SummaryVisualization
    let selectEditor: (EditorTab) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chartHeight: CGFloat {
        if expanded {
            return max(compact ? 112 : 124, availableHeight - (compact ? 190 : 210))
        }
        return compact ? 112 : 124
    }

    var body: some View {
        VStack(spacing: 7) {
            VisualizationSelector(selection: $visualization)

            TabView(selection: $visualization) {
                ForEach(SummaryVisualization.allCases) { option in
                    VisualizationContent(
                        model: model,
                        visualization: option,
                        expanded: expanded,
                        selectEditor: selectEditor
                    )
                        .tag(option)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: chartHeight)
            .animation(reduceMotion ? nil : ForecastMotion.data, value: model.persistenceSnapshot)
            .animation(reduceMotion ? nil : ForecastMotion.paging, value: visualization)
        }
        .sensoryFeedback(.selection, trigger: visualization)

    }
}

private struct VisualizationSelector: View {
    @Binding var selection: SummaryVisualization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: selection.systemImage)
                    .contentTransition(.symbolEffect(.replace))
                Text(selection.title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ForecastTheme.primaryText)

            Spacer()

            HStack(spacing: 8) {
                ForEach(SummaryVisualization.allCases) { option in
                    Button {
                        if reduceMotion {
                            selection = option
                        } else {
                            withAnimation(ForecastMotion.paging) { selection = option }
                        }
                    } label: {
                        Capsule()
                            .fill(selection == option ? Color.white : Color.white.opacity(0.24))
                            .frame(width: selection == option ? 15 : 5, height: 5)
                            .frame(width: 19, height: 18)
                            .scaleEffect(selection == option && !reduceMotion ? 1.08 : 1)
                            .shadow(color: Color.black.opacity(0.24), radius: 1, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show \(option.title) visualization")
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
        }
    }
}

private extension SummaryVisualization {
    var indicatorColor: Color {
        switch self {
        case .mix: ForecastTheme.revenue
        case .budget: ForecastTheme.expense
        case .attendance: ForecastTheme.tickets
        case .pricing: ForecastTheme.target
        }
    }
}

private struct VisualizationPanel: View {
    let model: ForecastModel
    let visualization: SummaryVisualization
    let height: CGFloat

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: visualization.systemImage)
                Text(visualization.title)
                Spacer()
                HStack(spacing: 3) {
                    ForEach(SummaryVisualization.allCases) { option in
                        Circle()
                            .fill(option == visualization ? Color.white : Color.white.opacity(0.24))
                            .frame(width: option == visualization ? 6 : 3, height: option == visualization ? 6 : 3)
                    }
                }
                .accessibilityHidden(true)
            }
            .font(.caption.weight(.semibold))

            VisualizationContent(model: model, visualization: visualization, expanded: true)
                .frame(height: height)
        }
    }
}

private struct VisualizationContent: View {
    let model: ForecastModel
    let visualization: SummaryVisualization
    let expanded: Bool
    var selectEditor: (EditorTab) -> Void = { _ in }

    @ViewBuilder
    var body: some View {
        switch visualization {
        case .mix:
            BudgetMixChart(model: model, expanded: expanded)
        case .budget:
            BudgetRailsChart(model: model, expanded: expanded)
        case .attendance:
            AttendanceProgressChart(model: model, expanded: expanded)
        case .pricing:
            PricingThresholdChart(model: model, expanded: expanded)
        }
    }
}

struct VisualMetricStrip: View {
    let model: ForecastModel
    let selectEditor: (EditorTab) -> Void

    var body: some View {
        HStack(spacing: 12) {
            metric("Tickets", value: model.ticketRevenue, color: ForecastTheme.tickets, editor: .tickets)
            Divider().overlay(ForecastTheme.divider)
            metric("Revenue", value: model.additionalRevenue, color: ForecastTheme.revenueSecondary, editor: .revenue)
            Divider().overlay(ForecastTheme.divider)
            metric("Expenses", value: model.totalExpenses, color: ForecastTheme.expense, editor: .expenses)
        }
        .frame(height: 46)
    }

    private func metric(_ title: String, value: Double, color: Color, editor: EditorTab) -> some View {
        Button { selectEditor(editor) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(ForecastTheme.secondaryText)
                    .lineLimit(1)
                Text(ForecastTheme.compactCurrency(value))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the \(editor.title) section")
    }
}

private struct ChartDatum: Identifiable {
    let id: String
    let title: String
    let value: Double
    let color: Color
    var destination: EditorTab? = nil
}

private func itemizedChartData(
    items: [MoneyItem],
    total: Double,
    kind: ItemizationKind
) -> [ChartDatum] {
    let validItems = items.enumerated().filter { $0.element.amount.isFinite && $0.element.amount > 0 }
    let itemizedTotal = validItems.reduce(0) { $0 + $1.element.amount }
    let scale = itemizedTotal > total && itemizedTotal > 0 ? max(total, 0) / itemizedTotal : 1
    var result = validItems.map { index, item in
        ChartDatum(
            id: "\(kind.rawValue)-\(item.id)",
            title: item.name,
            value: item.amount * scale,
            color: kind == .revenue
                ? ForecastTheme.revenueShade(at: index)
                : ForecastTheme.expenseShade(at: index),
            destination: kind == .revenue ? .revenue : .expenses
        )
    }

    let unallocated = max(total - min(itemizedTotal, total), 0)
    if unallocated > 0.005 || result.isEmpty {
        result.append(
            ChartDatum(
                id: "\(kind.rawValue)-unallocated",
                title: kind == .revenue ? "Other revenue" : "Other expenses",
                value: result.isEmpty ? max(total, 0) : unallocated,
                color: kind == .revenue ? ForecastTheme.revenueSecondary : ForecastTheme.expenseSecondary,
                destination: kind == .revenue ? .revenue : .expenses
            )
        )
    }
    return result.filter { $0.value > 0 }
}

private struct BudgetMixChart: View {
    let model: ForecastModel
    let expanded: Bool
    @State private var selectedAngle: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var data: [ChartDatum] {
        var result = [
            ChartDatum(
                id: "tickets",
                title: "Ticket revenue",
                value: model.ticketRevenue,
                color: ForecastTheme.tickets,
                destination: .tickets
            )
        ]
        if expanded {
            result += itemizedChartData(items: model.revenueItems, total: model.additionalRevenue, kind: .revenue)
            result += itemizedChartData(items: model.expenseItems, total: model.totalExpenses, kind: .expenses)
        } else {
            result += [
                ChartDatum(id: "additional", title: "Revenue", value: model.additionalRevenue, color: ForecastTheme.revenueSecondary, destination: .revenue),
                ChartDatum(id: "expenses", title: "Expenses", value: model.totalExpenses, color: ForecastTheme.expense, destination: .expenses)
            ]
        }
        return result.filter { $0.value.isFinite && $0.value > 0 }
    }

    private var dataSignature: [Double] {
        data.map { $0.value.isFinite ? max($0.value, 0) : 0 }
    }

    private var total: Double {
        data.reduce(0) { $0 + $1.value }
    }

    private var selectedDatum: ChartDatum? {
        guard let selectedAngle,
              selectedAngle.isFinite,
              selectedAngle >= 0,
              selectedAngle <= total else { return nil }
        var cumulative: Double = 0
        for datum in data {
            cumulative += datum.value
            if selectedAngle <= cumulative { return datum }
        }
        return data.last
    }

    var body: some View {
        ZStack {
            if data.isEmpty {
                Circle()
                    .stroke(ForecastTheme.raised, lineWidth: expanded ? 30 : 17)
                    .padding(expanded ? 18 : 10)
                    .accessibilityLabel("No budget data")
            } else {
                Chart(data) { datum in
                    SectorMark(
                        angle: .value("Amount", datum.value),
                        innerRadius: .ratio(expanded ? 0.64 : 0.70),
                        angularInset: expanded ? 2.5 : 1.5
                    )
                    .cornerRadius(expanded ? 4 : 2)
                    .foregroundStyle(datum.color)
                    .opacity(selectedDatum == nil || selectedDatum?.id == datum.id ? 1 : 0.34)
                }
                .chartLegend(.hidden)
                .chartAngleSelection(value: validatedAngleSelection)
                .accessibilityLabel("Budget mix chart with ticket revenue, revenue items, and expense items")
                .animation(reduceMotion ? nil : ForecastMotion.data, value: dataSignature)
            }

            VStack(spacing: 1) {
                if let selectedDatum {
                    Text(selectedDatum.title)
                        .font(expanded ? .caption.weight(.semibold) : .caption2.weight(.semibold))
                        .foregroundStyle(ForecastTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .transition(.opacity)
                }
                Text(selectedDatum.map { ForecastTheme.compactCurrency($0.value) }
                     ?? ForecastTheme.compactCurrency(abs(model.profit)))
                    .font(expanded ? .title3.weight(.bold) : .caption.weight(.bold))
                    .foregroundStyle(selectedDatum?.color ?? (model.profit >= 0 ? ForecastTheme.profit : ForecastTheme.expense))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: expanded ? 118 : 66)
            .allowsHitTesting(false)
        }
        .padding(.vertical, expanded ? 3 : 1)
        .onChange(of: total) { _, newTotal in
            guard let selectedAngle else { return }
            if !newTotal.isFinite || newTotal <= 0 || selectedAngle > newTotal {
                self.selectedAngle = nil
            }
        }
    }

    private var validatedAngleSelection: Binding<Double?> {
        Binding(
            get: {
                guard let selectedAngle,
                      selectedAngle.isFinite,
                      selectedAngle >= 0,
                      selectedAngle <= total else { return nil }
                return selectedAngle
            },
            set: { newValue in
                guard let newValue else {
                    selectedAngle = nil
                    return
                }
                guard newValue.isFinite,
                      newValue >= 0,
                      newValue <= total else {
                    selectedAngle = nil
                    return
                }
                selectedAngle = newValue
            }
        )
    }
}

private struct BudgetRailsChart: View {
    let model: ForecastModel
    let expanded: Bool
    @State private var selectedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var data: [ChartDatum] {
        if expanded {
            return [
                ChartDatum(id: "tickets", title: "Ticket revenue", value: model.ticketRevenue, color: ForecastTheme.tickets, destination: .tickets)
            ]
                + itemizedChartData(items: model.revenueItems, total: model.additionalRevenue, kind: .revenue)
                + itemizedChartData(items: model.expenseItems, total: model.totalExpenses, kind: .expenses)
        }
        return [
            ChartDatum(id: "revenue", title: "Revenue", value: model.totalRevenue, color: ForecastTheme.revenue, destination: .revenue),
            ChartDatum(id: "expenses", title: "Expenses", value: model.totalExpenses, color: ForecastTheme.expense, destination: .expenses)
        ]
    }

    private var maximum: Double { max(data.map(\.value).max() ?? 0, 1) }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if expanded {
                    ScrollView(showsIndicators: false) {
                        railRows
                            .padding(.vertical, 6)
                    }
                } else {
                    railRows
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            if let selected = data.first(where: { $0.id == selectedID }) {
                ChartTooltip(title: selected.title, value: selected.value, color: selected.color)
                    .allowsHitTesting(false)
            }
        }
        .animation(reduceMotion ? nil : ForecastMotion.data, value: model.persistenceSnapshot)
    }

    private var railRows: some View {
        VStack(spacing: expanded ? 11 : 7) {
            ForEach(data) { datum in
                    Button {
                        withAnimation(reduceMotion ? nil : ForecastMotion.control) {
                            selectedID = selectedID == datum.id ? nil : datum.id
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(datum.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(ForecastTheme.secondaryText)
                                .frame(width: expanded ? 116 : 58, alignment: .leading)
                                .lineLimit(1)

                            GeometryReader { geometry in
                                Capsule().fill(ForecastTheme.raised)
                                Capsule()
                                    .fill(datum.color)
                                    .frame(width: max(geometry.size.width * datum.value / maximum, datum.value > 0 ? 4 : 0))
                            }
                            .frame(height: expanded ? 15 : 10)

                            Text(ForecastTheme.compactCurrency(datum.value))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(datum.color)
                                .monospacedDigit()
                                .frame(width: expanded ? 70 : 54, alignment: .trailing)
                        }
                        .opacity(selectedID == nil || selectedID == datum.id ? 1 : 0.35)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(datum.title), \(datum.value.formatted(ForecastTheme.currencyFormat))")
                }
            }
    }
}

private struct AttendanceProgressChart: View {
    let model: ForecastModel
    let expanded: Bool
    @State private var showsTooltip = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetAttendance: Double { Double(model.profitTargetTickets ?? 0) }
    private var breakEvenAttendance: Double { Double(model.breakEvenTickets ?? 0) }
    private var upperBound: Double { max(model.capacity, targetAttendance, breakEvenAttendance, 1) }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: expanded ? 18 : 8) {
                HStack {
                    metric("Expected", value: "\(model.ticketsSold)", color: ForecastTheme.tickets)
                    Spacer()
                    metric("Capacity", value: "\(Int(model.capacity))", color: ForecastTheme.primaryText)
                }

                GeometryReader { geometry in
                    let width = geometry.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(ForecastTheme.raised)
                        Capsule()
                            .fill(ForecastTheme.tickets)
                            .frame(width: max(width * model.attendance / upperBound, model.attendance > 0 ? 4 : 0))

                        thresholdMarker(value: breakEvenAttendance, width: width, color: ForecastTheme.breakEven)
                        thresholdMarker(value: targetAttendance, width: width, color: ForecastTheme.target)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(reduceMotion ? nil : ForecastMotion.control) { showsTooltip.toggle() }
                    }
                }
                .frame(height: expanded ? 24 : 16)

                HStack {
                    metric("Break even", value: model.breakEvenTickets.map(String.init) ?? "—", color: ForecastTheme.breakEven)
                    Spacer()
                    metric("Target", value: model.profitTargetTickets.map(String.init) ?? "—", color: ForecastTheme.target, trailing: true)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            if showsTooltip {
                ChartTooltip(title: "Expected attendance", value: model.attendance, color: ForecastTheme.tickets, currency: false)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Expected attendance \(model.ticketsSold), capacity \(Int(model.capacity)), break-even attendance \(model.breakEvenTickets ?? 0), target attendance \(model.profitTargetTickets ?? 0)")
        .animation(reduceMotion ? nil : ForecastMotion.data, value: model.persistenceSnapshot)
    }

    private func thresholdMarker(value: Double, width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: 3, height: expanded ? 32 : 24)
            .offset(x: max(min(width * value / upperBound - 1.5, width - 3), 0))
    }

    private func metric(_ title: String, value: String, color: Color, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(ForecastTheme.secondaryText)
            Text(value).font(.caption.weight(.bold)).foregroundStyle(color).monospacedDigit()
        }
    }
}

private struct PricingThresholdChart: View {
    let model: ForecastModel
    let expanded: Bool
    @State private var showsTooltip = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var breakEven: Double { ceil(model.breakEvenTicketPrice ?? 0) }
    private var target: Double { ceil(model.targetTicketPrice ?? 0) }
    private var upperBound: Double { max(model.ticketPrice, breakEven, target, 25) * 1.25 }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: expanded ? 18 : 8) {
                HStack {
                    metric("Current price", value: model.ticketPrice, color: model.profit >= 0 ? ForecastTheme.profit : ForecastTheme.expense)
                    Spacer()
                    metric(model.profit >= 0 ? "Projected profit" : "Projected loss", value: abs(model.profit), color: model.profit >= 0 ? ForecastTheme.profit : ForecastTheme.expense, trailing: true)
                }

                GeometryReader { geometry in
                    let width = geometry.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(ForecastTheme.expense.opacity(0.72))
                        Capsule()
                            .fill(ForecastTheme.profit.opacity(0.82))
                            .frame(width: max(width * (upperBound - breakEven) / upperBound, 0))
                            .offset(x: width * breakEven / upperBound)

                        thresholdMarker(value: breakEven, width: width, color: ForecastTheme.breakEven)
                        thresholdMarker(value: target, width: width, color: ForecastTheme.target)

                        Circle()
                            .fill(model.profit >= 0 ? ForecastTheme.profit : ForecastTheme.expense)
                            .overlay { Circle().stroke(ForecastTheme.primaryText, lineWidth: 2) }
                            .frame(width: expanded ? 22 : 18, height: expanded ? 22 : 18)
                            .offset(x: max(min(width * model.ticketPrice / upperBound - (expanded ? 11 : 9), width - (expanded ? 22 : 18)), 0))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(reduceMotion ? nil : ForecastMotion.control) { showsTooltip.toggle() }
                    }
                }
                .frame(height: expanded ? 24 : 16)

                HStack {
                    metric("Break even", value: breakEven, color: ForecastTheme.breakEven)
                    Spacer()
                    metric("Target price", value: target, color: ForecastTheme.target, trailing: true)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            if showsTooltip {
                ChartTooltip(title: "Current ticket price", value: model.ticketPrice, color: model.profit >= 0 ? ForecastTheme.profit : ForecastTheme.expense)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current ticket price \(model.ticketPrice.formatted(ForecastTheme.currencyFormat)), break-even price \(breakEven.formatted(ForecastTheme.currencyFormat)), target price \(target.formatted(ForecastTheme.currencyFormat))")
        .animation(reduceMotion ? nil : ForecastMotion.data, value: model.persistenceSnapshot)
    }

    private func thresholdMarker(value: Double, width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: 3, height: expanded ? 32 : 24)
            .offset(x: max(min(width * value / upperBound - 1.5, width - 3), 0))
    }

    private func metric(_ title: String, value: Double, color: Color, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(ForecastTheme.secondaryText)
            Text(ForecastTheme.compactCurrency(value)).font(.caption.weight(.bold)).foregroundStyle(color).monospacedDigit()
        }
    }
}

private struct ChartTooltip: View {
    let title: String
    let value: Double
    let color: Color
    var currency = true

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).foregroundStyle(ForecastTheme.secondaryText)
            Text(currency ? ForecastTheme.compactCurrency(value) : ForecastTheme.compactNumber(value))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(ForecastTheme.surface.opacity(0.96), in: Capsule())
        .overlay { Capsule().stroke(ForecastTheme.divider, lineWidth: 1) }
        .fixedSize()
        .transition(.opacity)
    }
}
