import Foundation
import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable {
    case plan
    case itemize
    case visuals
    case events

    var id: Self { self }

    var title: String {
        switch self {
        case .plan: "Plan"
        case .itemize: "Itemize"
        case .visuals: "Visuals"
        case .events: "Events"
        }
    }

    var systemImage: String {
        switch self {
        case .plan: "slider.horizontal.3"
        case .itemize: "list.bullet"
        case .visuals: "chart.xyaxis.line"
        case .events: "calendar"
        }
    }
}

enum WorkspaceSplit: Equatable {
    case editor
    case balanced
    case semiExpanded
    case visual
}

private enum EditorScrollAnchor: Hashable {
    case top
}

struct ForecastView: View {
    @Bindable var model: ForecastModel
    let library: ForecastLibrary

    @State private var selectedAppTab: AppTab = .plan
    @State private var selectedEditor: EditorTab = .tickets
    @State private var selectedVisualization: SummaryVisualization = .mix
    @State private var workspaceSplit: WorkspaceSplit = .editor
    @State private var pinnedWorkspaceSplit: WorkspaceSplit?
    @State private var expandedItemizations = Set<ItemizationKind>()
    @State private var eventScrollDestination: EventScrollDestination = .top
    @State private var eventScrollRequest = 0
    @State private var presentedSheet: ForecastSheet?
    @State private var actionNotice: String?
    @FocusState private var isEventNameFocused: Bool
    @AppStorage("eventForecast.appearance") private var appearanceRaw = ForecastAppearance.dark.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var appearance: ForecastAppearance {
        ForecastAppearance(rawValue: appearanceRaw) ?? .dark
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForecastTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                Divider().overlay(ForecastTheme.divider)

                workspaceContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ForecastBottomBar(
                    selection: appTabBinding,
                    selectedEditor: selectedEditor
                )
            }

            if let actionNotice {
                Text(actionNotice)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(ForecastTheme.warning, in: Capsule())
                    .padding(.top, 51)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        .tint(ForecastTheme.warning)
        .preferredColorScheme(appearance.colorScheme)
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .report:
                ForecastReportView(model: model, eventName: reportEventName)
            }
        }
        .onChange(of: model.persistenceSnapshot) { _, _ in
            guard library.isAutoSaveEnabled else { return }
            library.saveActive(from: model)
        }
        .onChange(of: workspaceSplit) { _, _ in
            synchronizeWorkspaceTab()
        }
        .onChange(of: selectedEditor) { _, _ in
            guard selectedAppTab != .events, workspaceSplit != .visual else { return }
            if selectedAppTab == .itemize,
               selectedEditor != .revenue,
               selectedEditor != .expenses {
                selectedAppTab = .plan
            }
            let destination = recommendedSplit(for: selectedEditor)
            if reduceMotion { workspaceSplit = destination }
            else { withAnimation(ForecastMotion.scale) { workspaceSplit = destination } }
        }
        .onChange(of: expandedItemizations) { _, _ in
            guard selectedAppTab != .events, workspaceSplit != .visual else { return }
            pinnedWorkspaceSplit = nil
            let destination = automaticSplit(for: selectedEditor)
            if reduceMotion { workspaceSplit = destination }
            else { withAnimation(ForecastMotion.scale) { workspaceSplit = destination } }
        }
    }

    private var workspaceContent: some View {
        ZStack {
            if selectedAppTab == .events {
                EventLibraryView(
                    library: library,
                    model: model,
                    scrollDestination: eventScrollDestination,
                    scrollRequest: eventScrollRequest,
                    openForecast: {
                        selectAppTab(.plan)
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                PlanWorkspace(
                    model: model,
                    selectedEditor: $selectedEditor,
                    selectedVisualization: $selectedVisualization,
                    split: $workspaceSplit,
                    expandedItemizations: $expandedItemizations,
                    openEditor: openEditorFromVisualization,
                    userChangedSplit: workspaceSplitChangedByUser
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 4) {
            TextField("Event name", text: workingNameBinding)
                .font(.headline.weight(.bold))
                .tracking(-0.2)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($isEventNameFocused)
                .onSubmit(library.commitWorkingName)
            .layoutPriority(1)

            Spacer()

            Button {
                performAnimated(model.undo)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!model.canUndo)
            .opacity(model.canUndo ? 1 : 0.32)
            .foregroundStyle(ForecastTheme.headerChrome)
            .accessibilityLabel("Undo")

            Button {
                performAnimated(model.redo)
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!model.canRedo)
            .opacity(model.canRedo ? 1 : 0.32)
            .foregroundStyle(ForecastTheme.headerChrome)
            .accessibilityLabel("Redo")

            Button(action: saveNow) {
                saveIcon
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(ForecastTheme.headerChrome)
            .accessibilityLabel(saveAccessibilityLabel)

            Button(action: toggleAppearance) {
                Image(systemName: appearance == .dark ? "sun.max" : "moon")
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(ForecastTheme.headerChrome)
            .accessibilityLabel("Switch to \(appearance == .dark ? "light" : "dark") mode")

            Menu {
                if library.activeRecordID != nil {
                    Toggle(isOn: autoSaveBinding) {
                        Label("Auto-save changes", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button("Save changes", systemImage: "square.and.arrow.down") {
                        saveNow()
                    }
                } else {
                    Button("Save event", systemImage: "square.and.arrow.down") {
                        saveNow()
                    }
                }

                if library.activeRecordID != nil {
                    Button("Duplicate event", systemImage: "plus.square.on.square") {
                        if library.duplicateActive(from: model) != nil {
                            showNotice("Event duplicated")
                        }
                    }
                }

                Button("Export budget", systemImage: "square.and.arrow.up") {
                    presentedSheet = .report
                }

                Button("Load starter event", systemImage: "sparkles") {
                    performAnimated {
                        library.detachCurrentForecast()
                        model.loadStarterEvent()
                    }
                }

                Divider()

                Button("Reset all to zero", systemImage: "arrow.counterclockwise", role: .destructive) {
                    performAnimated {
                        library.detachCurrentForecast()
                        model.resetToZero()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(ForecastTheme.headerChrome)
            .accessibilityLabel("Budget actions")
        }
        .frame(height: 40)
        .tint(ForecastTheme.headerChrome)
        .onChange(of: isEventNameFocused) { wasFocused, isFocused in
            if wasFocused && !isFocused {
                library.commitWorkingName()
            }
        }
    }

    private var reportEventName: String {
        library.workingName
    }

    private var workingNameBinding: Binding<String> {
        Binding(
            get: { library.workingName },
            set: { library.workingName = $0 }
        )
    }

    private var autoSaveBinding: Binding<Bool> {
        Binding(
            get: { library.isAutoSaveEnabled },
            set: { enabled in
                library.setAutoSaveEnabled(enabled, from: model)
                showNotice(enabled ? "Auto-save on" : "Manual save mode")
            }
        )
    }

    private var appTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedAppTab },
            set: selectAppTab
        )
    }

    private var hasUnsavedChanges: Bool {
        library.hasUnsavedChanges(from: model)
    }

    private var saveAccessibilityLabel: String {
        if library.isAutoSaveEnabled { return "Save event, auto-save on" }
        return hasUnsavedChanges ? "Save event, unsaved changes" : "Save event, all changes saved"
    }

    private var saveIcon: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "square.and.arrow.down")

            if library.isAutoSaveEnabled {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 9, height: 9)
                    .background(ForecastTheme.canvas.opacity(0.82), in: Circle())
                    .offset(x: 4, y: -2)
            } else if hasUnsavedChanges {
                Circle()
                    .fill(ForecastTheme.warning)
                    .frame(width: 7, height: 7)
                    .overlay { Circle().stroke(ForecastTheme.canvas, lineWidth: 1.5) }
                    .offset(x: 4, y: -2)
            }
        }
        .contentTransition(.symbolEffect(.replace))
    }

    private func selectAppTab(_ tab: AppTab) {
        let isRepeatedTap = selectedAppTab == tab
        let update = {
            switch tab {
            case .plan:
                selectedAppTab = .plan
                if isRepeatedTap {
                    selectedEditor = selectedEditor.nextPlanSection
                } else {
                    selectedEditor = .tickets
                }
                workspaceSplit = recommendedSplit(for: selectedEditor)
            case .itemize:
                selectedAppTab = .itemize
                let itemization: ItemizationKind
                if selectedEditor == .expenses {
                    itemization = .expenses
                } else {
                    itemization = .revenue
                }
                if selectedEditor != .revenue && selectedEditor != .expenses {
                    selectedEditor = .revenue
                }
                if expandedItemizations.contains(itemization) {
                    expandedItemizations.remove(itemization)
                } else {
                    expandedItemizations.insert(itemization)
                }
                workspaceSplit = automaticSplit(for: selectedEditor)
            case .visuals:
                selectedAppTab = .visuals
                if isRepeatedTap {
                    selectedVisualization = selectedVisualization.next
                }
                workspaceSplit = .visual
            case .events:
                selectedAppTab = .events
                eventScrollDestination = isRepeatedTap && eventScrollDestination == .top ? .saved : .top
                eventScrollRequest += 1
            }
        }

        if reduceMotion { update() }
        else { withAnimation(ForecastMotion.navigation, update) }
    }

    private func performAnimated(_ action: () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(ForecastMotion.control, action)
        }
    }

    private func saveNow() {
        isEventNameFocused = false
        _ = library.saveCurrent(named: library.workingName, from: model)
        showNotice("Event saved")
    }

    private func synchronizeWorkspaceTab() {
        guard selectedAppTab != .events, workspaceSplit == .visual else { return }
        selectedAppTab = .visuals
    }

    private func recommendedSplit(for editor: EditorTab) -> WorkspaceSplit {
        pinnedWorkspaceSplit ?? automaticSplit(for: editor)
    }

    private func automaticSplit(for editor: EditorTab) -> WorkspaceSplit {
        switch editor {
        case .tickets:
            return .editor
        case .revenue, .expenses:
            return .balanced
        case .target:
            return .balanced
        }
    }

    private func workspaceSplitChangedByUser(_ split: WorkspaceSplit) {
        switch split {
        case .editor:
            pinnedWorkspaceSplit = nil
        case .balanced, .semiExpanded:
            pinnedWorkspaceSplit = split
        case .visual:
            break
        }

        guard selectedAppTab == .visuals, split != .visual else { return }
        selectedAppTab = selectedEditor == .revenue || selectedEditor == .expenses ? .itemize : .plan
    }

    private func openEditorFromVisualization(_ editor: EditorTab) {
        let update = {
            selectedEditor = editor
            selectedAppTab = editor == .revenue || editor == .expenses ? .itemize : .plan
            workspaceSplit = recommendedSplit(for: editor)
        }
        if reduceMotion { update() }
        else { withAnimation(ForecastMotion.navigation, update) }
    }

    private func toggleAppearance() {
        let update = {
            appearanceRaw = appearance == .dark
                ? ForecastAppearance.light.rawValue
                : ForecastAppearance.dark.rawValue
        }
        if reduceMotion { update() }
        else { withAnimation(ForecastMotion.navigation, update) }
    }

    private func showNotice(_ message: String) {
        if reduceMotion {
            actionNotice = message
        } else {
            withAnimation(ForecastMotion.control) {
                actionNotice = message
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard actionNotice == message else { return }
            if reduceMotion {
                actionNotice = nil
            } else {
                withAnimation(ForecastMotion.control) {
                    actionNotice = nil
                }
            }
        }
    }
}

private struct PlanWorkspace: View {
    @Bindable var model: ForecastModel
    @Binding var selectedEditor: EditorTab
    @Binding var selectedVisualization: SummaryVisualization
    @Binding var split: WorkspaceSplit
    @Binding var expandedItemizations: Set<ItemizationKind>
    let openEditor: (EditorTab) -> Void
    let userChangedSplit: (WorkspaceSplit) -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 660
            let handleHeight: CGFloat = 34
            let editorHeight = min(compact ? 164 : 176, geometry.size.height * 0.27)
            let balancedHeight = min(compact ? 304 : 326, geometry.size.height * 0.54)
            let visualHeight = max(geometry.size.height - handleHeight, balancedHeight)
            let semiExpandedHeight = max(
                balancedHeight,
                min(
                    geometry.size.height * 0.75,
                    visualHeight - (compact ? 124 : 140)
                )
            )
            let restingHeight = summaryHeight(
                editor: editorHeight,
                balanced: balancedHeight,
                semiExpanded: semiExpandedHeight,
                visual: visualHeight
            )
            let interactiveHeight = min(
                max(restingHeight + dragTranslation, editorHeight),
                visualHeight
            )

            VStack(spacing: 0) {
                ResultSummaryView(
                    model: model,
                    compact: compact,
                    expanded: split == .semiExpanded || split == .visual,
                    minimized: split == .editor,
                    availableHeight: interactiveHeight,
                    visualization: $selectedVisualization,
                    selectEditor: openEditor
                )
                .padding(.horizontal, 16)
                .frame(height: interactiveHeight, alignment: .top)
                .clipped()

                visualizationHandle
                    .gesture(
                        expansionGesture(
                            restingHeight: restingHeight,
                            editorHeight: editorHeight,
                            balancedHeight: balancedHeight,
                            semiExpandedHeight: semiExpandedHeight,
                            visualHeight: visualHeight
                        )
                    )
                    .onTapGesture {
                        switch split {
                        case .editor: setSplit(.balanced, userInitiated: true)
                        case .balanced: setSplit(.semiExpanded, userInitiated: true)
                        case .semiExpanded: setSplit(.visual, userInitiated: true)
                        case .visual: setSplit(.semiExpanded, userInitiated: true)
                        }
                    }

                if split != .visual {
                    EditorTabBar(selection: editorBinding)
                        .padding(.horizontal, 14)
                        .padding(.top, 5)

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            Color.clear
                                .frame(height: 0)
                                .id(EditorScrollAnchor.top)

                            editor(compact: compact)
                                .id(selectedEditor)
                                .transition(.opacity.combined(with: .offset(x: 10)))
                                .padding(.horizontal, 16)
                                .padding(.top, compact ? 6 : 8)
                                .padding(.bottom, 24)
                        }
                        .onChange(of: selectedEditor) { _, _ in
                            Task { @MainActor in
                                await Task.yield()
                                if reduceMotion {
                                    proxy.scrollTo(EditorScrollAnchor.top, anchor: .top)
                                } else {
                                    withAnimation(ForecastMotion.navigation) {
                                        proxy.scrollTo(EditorScrollAnchor.top, anchor: .top)
                                    }
                                }
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .background(ForecastTheme.canvas)
            .animation(reduceMotion ? nil : ForecastMotion.navigation, value: selectedEditor)
        }
    }

    private var editorBinding: Binding<EditorTab> {
        Binding(
            get: { selectedEditor },
            set: setEditor
        )
    }

    private var visualizationHandle: some View {
        FluidWorkspaceDivider(
            tint: selectedEditor.tint,
            dragTranslation: dragTranslation,
            split: split
        )
        .frame(height: 34)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(split == .visual ? "Show budget inputs" : "Resize budget workspace")
        .accessibilityHint("Drag down for full visualizations or up for more input space")
        .accessibilityAddTraits(.isButton)
    }

    private func expansionGesture(
        restingHeight: CGFloat,
        editorHeight: CGFloat,
        balancedHeight: CGFloat,
        semiExpandedHeight: CGFloat,
        visualHeight: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let projectedHeight = min(
                    max(restingHeight + value.predictedEndTranslation.height, editorHeight),
                    visualHeight
                )
                let destinations: [(WorkspaceSplit, CGFloat)] = [
                    (.editor, editorHeight),
                    (.balanced, balancedHeight),
                    (.semiExpanded, semiExpandedHeight),
                    (.visual, visualHeight)
                ]
                let destination = destinations.min {
                    abs($0.1 - projectedHeight) < abs($1.1 - projectedHeight)
                }?.0 ?? .balanced
                setSplit(destination, userInitiated: true)
            }
    }

    private func summaryHeight(
        editor: CGFloat,
        balanced: CGFloat,
        semiExpanded: CGFloat,
        visual: CGFloat
    ) -> CGFloat {
        switch split {
        case .editor: editor
        case .balanced: balanced
        case .semiExpanded: semiExpanded
        case .visual: visual
        }
    }

    @ViewBuilder
    private func editor(compact: Bool) -> some View {
        switch selectedEditor {
        case .tickets:
            TicketsEditor(model: model, compact: compact)
        case .revenue:
            BudgetEditor(
                title: "Revenue",
                totalTitle: "Revenue",
                total: $model.additionalRevenue,
                items: $model.revenueItems,
                kind: .revenue,
                tint: ForecastTheme.revenue,
                compact: compact,
                markers: budgetMarkers(for: .revenue),
                isItemizedExpanded: itemizationBinding(for: .revenue)
            )
        case .expenses:
            BudgetEditor(
                title: "Expenses",
                totalTitle: "Total expenses",
                total: $model.expenseBudget,
                items: $model.expenseItems,
                kind: .expenses,
                tint: ForecastTheme.expense,
                compact: compact,
                markers: budgetMarkers(for: .expenses),
                isItemizedExpanded: itemizationBinding(for: .expenses)
            )
        case .target:
            TargetEditor(
                model: model,
                compact: compact
            )
        }
    }

    private func setEditor(_ editor: EditorTab) {
        if reduceMotion {
            selectedEditor = editor
        } else {
            withAnimation(ForecastMotion.navigation) {
                selectedEditor = editor
            }
        }
    }

    private func itemizationBinding(for kind: ItemizationKind) -> Binding<Bool> {
        Binding(
            get: { expandedItemizations.contains(kind) },
            set: { isExpanded in
                if isExpanded {
                    expandedItemizations.insert(kind)
                } else {
                    expandedItemizations.remove(kind)
                }
            }
        )
    }

    private func budgetMarkers(for kind: ItemizationKind) -> [SliderMarker] {
        var markers: [SliderMarker] = []
        switch kind {
        case .revenue:
            markers.append(
                SliderMarker(
                    title: "Break-even",
                    value: max(model.totalExpenses - model.ticketRevenue, 0),
                    color: ForecastTheme.breakEven
                )
            )
            if model.profitTarget > 0 {
                markers.append(
                    SliderMarker(
                        title: "Target",
                        value: max(model.totalExpenses + model.profitTarget - model.ticketRevenue, 0),
                        color: ForecastTheme.target
                    )
                )
            }
        case .expenses:
            markers.append(
                SliderMarker(
                    title: "Break-even",
                    value: model.totalRevenue,
                    color: ForecastTheme.breakEven
                )
            )
            if model.profitTarget > 0 {
                markers.append(
                    SliderMarker(
                        title: "Target",
                        value: max(model.totalRevenue - model.profitTarget, 0),
                        color: ForecastTheme.target
                    )
                )
            }
        }
        return markers
    }

    private func setSplit(_ newSplit: WorkspaceSplit, userInitiated: Bool = false) {
        if reduceMotion {
            split = newSplit
        } else {
            withAnimation(ForecastMotion.scale) {
                split = newSplit
            }
        }
        if userInitiated {
            userChangedSplit(newSplit)
        }
    }
}

private struct FluidWorkspaceDivider: View {
    let tint: Color
    let dragTranslation: CGFloat
    let split: WorkspaceSplit

    @State private var idlePhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDragging: Bool { abs(dragTranslation) > 0.5 }

    var body: some View {
        GeometryReader { geometry in
            let handleOffset = min(max(dragTranslation * 0.055, -5), 5)
            let stretch = 1 + min(abs(dragTranslation) / 520, 0.16)

            ZStack {
                FluidDividerShape(phase: reduceMotion ? 0 : idlePhase, pull: dragTranslation)
                    .stroke(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.03),
                                tint.opacity(isDragging ? 0.88 : 0.44),
                                ForecastTheme.breakEven.opacity(isDragging ? 0.78 : 0.30),
                                ForecastTheme.target.opacity(isDragging ? 0.66 : 0.22),
                                tint.opacity(isDragging ? 0.88 : 0.44),
                                tint.opacity(0.03)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: isDragging ? 2.6 : 1.35,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .blur(radius: isDragging ? 0.55 : 0.18)
                    .shadow(color: tint.opacity(isDragging ? 0.48 : 0.18), radius: isDragging ? 7 : 3)

                FluidDividerShape(phase: reduceMotion ? 0 : idlePhase, pull: dragTranslation)
                    .stroke(Color.white.opacity(isDragging ? 0.50 : 0.20), lineWidth: 0.55)

                HStack(spacing: 3) {
                    ForEach(0 ..< 3, id: \.self) { index in
                        Circle()
                            .fill(index == 1 ? tint : ForecastTheme.primaryText.opacity(0.52))
                            .frame(width: index == 1 ? 4 : 3, height: index == 1 ? 4 : 3)
                    }
                }
                .frame(width: 52, height: 15)
                .budgetGlassSurface(tint: tint, cornerRadius: 8, interactive: true)
                .scaleEffect(x: stretch, y: isDragging ? 1.08 : 1)
                .offset(y: handleOffset)
                .shadow(color: tint.opacity(isDragging ? 0.30 : 0.10), radius: 7)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 5.8).repeatForever(autoreverses: false)) {
                idlePhase = 1
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55), trigger: split)
    }
}

private struct FluidDividerShape: Shape {
    var phase: CGFloat
    var pull: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, pull) }
        set {
            phase = newValue.first
            pull = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = max(Int(rect.width / 5), 24)
        let centerY = rect.midY
        let pullAmount = min(max(pull * 0.075, -9), 9)
        let rippleAmount = min(abs(pull) * 0.012, 2.2)

        for step in 0 ... steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let x = rect.minX + rect.width * progress
            let distance = (progress - 0.5) / 0.23
            let influence = exp(-(distance * distance))
            let idleWave = sin((progress * 2 + phase * 2) * .pi) * 1.05
            let tensionRipple = sin((progress * 4 - phase * 2) * .pi) * rippleAmount * influence
            let y = centerY + idleWave + pullAmount * influence + tensionRipple

            if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

private struct ForecastBottomBar: View {
    @Binding var selection: AppTab
    let selectedEditor: EditorTab
    @Namespace private var activeNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        adaptiveGlassContainer
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .budgetGlassSurface(cornerRadius: 0)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ForecastTheme.divider)
                    .frame(height: 1)
            }
            .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private var adaptiveGlassContainer: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                tabButtons
            }
        } else {
            tabButtons
        }
#else
        tabButtons
#endif
    }

    private var tabButtons: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = selection == tab
                let tint = activeTint(for: tab)
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            if isSelected {
                                Capsule()
                                    .fill(tint.opacity(0.05))
                                    .frame(width: 44, height: 28)
                                    .matchedGeometryEffect(id: "active-tab", in: activeNamespace)
                                    .budgetGlassMorph(
                                        id: "active-tab-glass",
                                        namespace: activeNamespace,
                                        tint: tint,
                                        cornerRadius: 14
                                    )
                            }
                            navigationIcon(for: tab, isSelected: isSelected)
                                .frame(width: 44, height: 28)
                                .scaleEffect(isSelected && !reduceMotion ? 1.06 : 1)
                                .offset(y: isSelected && !reduceMotion ? -1 : 0)
                        }

                        Text(tab.title)
                            .font(.caption2.weight(isSelected ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? tint : ForecastTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func activeTint(for tab: AppTab) -> Color {
        switch tab {
        case .plan:
            return selectedEditor.tint
        case .itemize:
            return selectedEditor == .expenses ? ForecastTheme.expense : ForecastTheme.revenue
        case .visuals:
            return ForecastTheme.primaryText
        case .events:
            return ForecastTheme.breakEven
        }
    }

    @ViewBuilder
    private func navigationIcon(for tab: AppTab, isSelected: Bool) -> some View {
        if tab == .visuals {
            HStack(alignment: .bottom, spacing: 2) {
                Capsule().fill(isSelected ? ForecastTheme.tickets : ForecastTheme.secondaryText).frame(width: 4, height: 9)
                Capsule().fill(isSelected ? ForecastTheme.revenue : ForecastTheme.secondaryText).frame(width: 4, height: 15)
                Capsule().fill(isSelected ? ForecastTheme.expense : ForecastTheme.secondaryText).frame(width: 4, height: 12)
                Capsule().fill(isSelected ? ForecastTheme.target : ForecastTheme.secondaryText).frame(width: 4, height: 17)
            }
            .frame(width: 24, height: 20)
            .accessibilityHidden(true)
        } else {
            Image(systemName: tab.systemImage)
                .font(.system(size: 17, weight: isSelected ? .semibold : .medium))
                .symbolRenderingMode(.monochrome)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}

private struct EditorTabBar: View {
    @Binding var selection: EditorTab
    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(EditorTab.allCases) { tab in
                let isSelected = selection == tab
                Button {
                    if reduceMotion {
                        selection = tab
                    } else {
                        withAnimation(ForecastMotion.navigation) {
                            selection = tab
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.systemImage)
                                .font(.caption.weight(.semibold))
                            Text(tab.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? tab.tint : ForecastTheme.secondaryText)

                        ZStack {
                            Rectangle().fill(Color.clear).frame(height: 2)
                            if isSelected {
                                Capsule()
                                    .fill(tab.tint)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "editor-selection", in: selectionNamespace)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 37)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.title) editor")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

extension EditorTab {
    var nextPlanSection: EditorTab {
        switch self {
        case .tickets: .revenue
        case .revenue: .expenses
        case .expenses: .target
        case .target: .tickets
        }
    }

    var tint: Color {
        switch self {
        case .tickets: ForecastTheme.tickets
        case .revenue: ForecastTheme.revenue
        case .expenses: ForecastTheme.expense
        case .target: ForecastTheme.target
        }
    }
}

private enum ForecastSheet: String, Identifiable {
    case report

    var id: String { rawValue }
}

#Preview("Event Budget") {
    ForecastView(model: ForecastModel(), library: ForecastLibrary())
}
