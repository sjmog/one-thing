import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: OneThingStore
    @EnvironmentObject private var sync: SyncEngine
    @State private var sidebarOpen = UserDefaults.standard.bool(forKey: "sidebarOpen")
    @State private var showingSync = false
    @State private var showingDatePicker = false
    @FocusState private var focusedField: FocusedField?
    @AppStorage("onething-theme") private var theme = "light"
    @AppStorage("onething-hide-completed") private var hideCompleted = false
    @AppStorage("onething-nice-collapsed") private var niceCollapsed = false

    var body: some View {
        GeometryReader { proxy in
            let metrics = LayoutMetrics(
                size: proxy.size,
                safeArea: proxy.safeAreaInsets,
                sidebarOpen: sidebarOpen
            )
            ZStack(alignment: .topLeading) {
                Palette(theme: theme).surfaceSunken.ignoresSafeArea()

                if sidebarOpen {
                    SidebarView(
                        hideCompleted: $hideCompleted,
                        showingSync: $showingSync,
                        theme: $theme,
                        topInset: metrics.topInset,
                        bottomInset: metrics.bottomInset,
                        isCompact: metrics.isCompact,
                        focus: $focusedField
                    )
                    .frame(width: metrics.sidebarWidth)
                    .transition(.move(edge: .leading))
                    .zIndex(2)
                }

                if !(sidebarOpen && metrics.isCompact) {
                    PlanCanvas(niceCollapsed: $niceCollapsed, focus: $focusedField)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, metrics.contentTop)
                        .padding(.leading, metrics.contentLeft)
                        .padding(.trailing, metrics.contentRight)
                        .padding(.bottom, metrics.bottomInset)
                        .offset(x: metrics.contentOffset)
                        .transition(.opacity)
                }

                if !(sidebarOpen && metrics.isCompact) {
                    DateHeader(
                        date: store.selectedDate,
                        previous: { store.changeSelectedDate(by: -1) },
                        next: { store.changeSelectedDate(by: 1) },
                        openPicker: { showingDatePicker = true }
                    )
                    .position(x: metrics.dateCenterX, y: metrics.dateY)
                    .zIndex(3)
                }

                Button(action: toggleSidebar) {
                    Image(systemName: sidebarOpen && metrics.isCompact ? "xmark" : "line.3.horizontal")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Palette(theme: theme).tertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sidebarOpen ? "Close todo list" : "Open todo list")
                .position(x: metrics.toggleX, y: metrics.toggleY)
                .zIndex(3)
            }
            .animation(.easeInOut(duration: 0.2), value: sidebarOpen)
            .sheet(isPresented: $showingSync) {
                SyncSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { store.selectedDate },
                        set: { store.selectedDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .presentationDetents([.medium])
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .ignoresSafeArea()
        .task { sync.start() }
    }

    private func toggleSidebar() {
        sidebarOpen.toggle()
        UserDefaults.standard.set(sidebarOpen, forKey: "sidebarOpen")
    }
}

private enum FocusedField: Hashable {
    case goal
    case nice(Int)
    case week
    case todo(String)
    case newTodo
}

private struct LayoutMetrics {
    let size: CGSize
    let safeArea: EdgeInsets
    let sidebarOpen: Bool

    var isCompact: Bool { size.width <= 600 }
    var sidebarWidth: CGFloat { isCompact ? size.width : 280 }
    var topInset: CGFloat { isCompact ? max(safeArea.top, 59) : safeArea.top }
    var bottomInset: CGFloat { isCompact ? max(safeArea.bottom, 34) : safeArea.bottom }
    var contentTop: CGFloat {
        let webTop = min(max(size.height * 0.12 + (isCompact ? 15 : 0), 76), isCompact ? 117 : 112)
        return max(webTop + 58.734, toggleY + (isCompact ? 94 : 113))
    }
    var contentLeft: CGFloat {
        if sidebarOpen && !isCompact { return min(max(size.width * 0.08, 20), 72) }
        return isCompact ? 21.667 : 29.667
    }
    var contentRight: CGFloat { min(max(size.width * 0.08, 20), 72) }
    var contentOffset: CGFloat { sidebarOpen && !isCompact ? sidebarWidth : 0 }
    var toggleX: CGFloat { sidebarOpen && !isCompact ? 232 : (isCompact ? 30 : 34) }
    var toggleY: CGFloat { topInset + 22 }
    var dateY: CGFloat { toggleY }
    var dateCenterX: CGFloat {
        sidebarOpen && !isCompact ? sidebarWidth + (size.width - sidebarWidth) / 2 : size.width / 2
    }
}

private struct Palette {
    let theme: String

    var isDark: Bool { theme == "dark" }
    var surface: Color { isDark ? Color(hex: 0x292929) : Color(hex: 0xf7f7f2) }
    var surfaceSunken: Color { isDark ? Color(hex: 0x212121) : Color(hex: 0xf2f2ec) }
    var primary: Color { isDark ? Color(hex: 0xfcfcf8) : Color(hex: 0x292929) }
    var secondaryStrong: Color { isDark ? Color(hex: 0xacada8) : Color(hex: 0x4e4d4b) }
    var secondary: Color { isDark ? Color(hex: 0x9e9e99) : Color(hex: 0x72726e) }
    var tertiary: Color { isDark ? Color(hex: 0x818179) : Color(hex: 0xacada8) }
    var border: Color { isDark ? Color(hex: 0x404040) : Color(hex: 0xe5e5e0) }
    var accent: Color { Color(hex: isDark ? 0xb2c248 : 0x788c15) }
    var danger: Color { Color(hex: isDark ? 0xec7558 : 0xbd4a30) }
}

private struct PlanCanvas: View {
    @EnvironmentObject private var store: OneThingStore
    @Binding var niceCollapsed: Bool
    let focus: FocusState<FocusedField?>.Binding

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                GoalBlock(focus: focus)
                    .padding(.bottom, 37)

                NiceBlock(niceCollapsed: $niceCollapsed, focus: focus)
                    .padding(.bottom, niceCollapsed ? 49 : 49)

                WeekBlock(focus: focus)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct DateHeader: View {
    @AppStorage("onething-theme") private var theme = "light"
    let date: Date
    let previous: () -> Void
    let next: () -> Void
    let openPicker: () -> Void

    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: previous) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous day")

            Button(action: openPicker) {
                Text(displayDate(date))
                    .font(.system(size: 14))
                    .frame(minWidth: 96, minHeight: 44)
            }
            .accessibilityLabel("Choose date")

            Button(action: next) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next day")
        }
        .foregroundStyle(palette.tertiary)
        .buttonStyle(.plain)
    }

    private func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

private struct GoalBlock: View {
    @EnvironmentObject private var store: OneThingStore
    @AppStorage("onething-theme") private var theme = "light"
    let focus: FocusState<FocusedField?>.Binding

    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionLabel("GOAL")
            TextField("", text: goalBinding, axis: .vertical)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(palette.primary)
                .strikethrough(store.plan.goalCompleted)
                .opacity(store.plan.goalCompleted ? 0.4 : 1)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .frame(minWidth: 160, minHeight: 44, alignment: .leading)
                .focused(focus, equals: .goal)
                .submitLabel(.next)
                .gesture(completeSwipe)
        }
    }

    private var completeSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                if value.translation.width > 40, !store.plan.goalCompleted {
                    store.toggleGoal()
                } else if value.translation.width < -40, store.plan.goalCompleted {
                    store.toggleGoal()
                }
            }
    }

    private var goalBinding: Binding<String> {
        Binding(
            get: { store.plan.goal },
            set: { text in
                let submitted = text.hasNewline
                store.updateGoal(text.withoutNewlines)
                if submitted {
                    let index = store.plan.niceToDo.isEmpty ? store.addNiceItem() : 0
                    focus.wrappedValue = .nice(index)
                }
            }
        )
    }
}

private struct NiceBlock: View {
    @EnvironmentObject private var store: OneThingStore
    @AppStorage("onething-theme") private var theme = "light"
    @Binding var niceCollapsed: Bool
    let focus: FocusState<FocusedField?>.Binding

    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: niceCollapsed ? 0 : 13) {
            Button {
                niceCollapsed.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: niceCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.tertiary)
                        .opacity(niceCollapsed ? 1 : 0)
                        .frame(width: 16, height: 44)
                    SectionLabel("NICE TO DO")
                }
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .offset(x: -20)

            if !niceCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(displayItems.indices, id: \.self) { index in
                        NiceRow(index: index, focus: focus)
                    }
                }
            }
        }
    }

    private var displayItems: [NiceItem] {
        store.plan.niceToDo.isEmpty ? [NiceItem()] : store.plan.niceToDo
    }
}

private struct NiceRow: View {
    @EnvironmentObject private var store: OneThingStore
    @AppStorage("onething-theme") private var theme = "light"
    let index: Int
    let focus: FocusState<FocusedField?>.Binding
    @State private var rowWidth: CGFloat = 1
    @State private var rowHeight: CGFloat = 44
    @State private var swipeOffset: CGFloat = 0
    @State private var reorderReady = false

    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        ZStack(alignment: .leading) {
            displayText
            editor
        }
        .overlay(alignment: .leading) {
            strikeOverlay
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        rowWidth = proxy.size.width
                        rowHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size.width) { rowWidth = $0 }
                    .onChange(of: proxy.size.height) { rowHeight = $0 }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if showDisplayText {
                focus.wrappedValue = .nice(index)
            }
        }
        .gesture(completeSwipe)
        .simultaneousGesture(reorderGesture)
    }

    private var editor: some View {
        TextField("", text: binding, axis: .vertical)
            .font(.system(size: 16))
            .foregroundStyle(palette.secondaryStrong)
            .opacity(showDisplayText ? 0 : item.done ? 0.4 : 1)
            .lineLimit(1...3)
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .focused(focus, equals: .nice(index))
            .submitLabel(.next)
    }

    private var displayText: some View {
        Text(item.text.isEmpty ? " " : item.text)
            .font(.system(size: 16))
            .foregroundStyle(palette.secondaryStrong)
            .opacity(showDisplayText ? 0.4 : 0)
            .lineLimit(1...3)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .allowsHitTesting(false)
    }

    private var strikeOverlay: some View {
        GeometryReader { proxy in
            let width = strikeWidth(total: proxy.size.width)
            strikeText(width: proxy.size.width)
                .opacity(width > 0 ? 1 : 0)
                .mask(alignment: .leading) {
                    Rectangle().frame(width: width)
                }
        }
        .allowsHitTesting(false)
    }

    private func strikeText(width: CGFloat) -> some View {
        Text(item.text.isEmpty ? " " : item.text)
            .font(.system(size: 16))
            .foregroundStyle(.clear)
            .strikethrough(true, color: palette.secondaryStrong.opacity(0.55))
            .lineLimit(1...3)
            .frame(width: width, alignment: .leading)
            .frame(minHeight: 44, alignment: .leading)
    }

    private var completeSwipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if abs(value.translation.width) >= abs(value.translation.height) {
                    swipeOffset = value.translation.width
                }
            }
            .onEnded { value in
                defer {
                    withAnimation(.easeOut(duration: 0.16)) {
                        swipeOffset = 0
                    }
                }

                if store.plan.niceToDo.indices.contains(index) {
                    let threshold = max(rowWidth * 0.25, 44)
                    if value.translation.width > threshold, !item.done {
                        store.toggleNiceItem(at: index)
                    } else if value.translation.width < -threshold, item.done {
                        store.toggleNiceItem(at: index)
                    }
                }
            }
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.26)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, _) = value, !reorderReady {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    reorderReady = true
                }
            }
            .onEnded { value in
                defer { reorderReady = false }
                guard case let .second(true, drag?) = value else { return }
                let steps = Int((drag.translation.height / max(rowHeight, 44)).rounded())
                if steps != 0 {
                    store.moveNiceItem(from: index, to: index + steps)
                }
            }
    }

    private func strikeWidth(total: CGFloat) -> CGFloat {
        let base = item.done ? total : 0
        let width = base + swipeOffset
        return min(max(width, 0), total)
    }

    private var showDisplayText: Bool {
        item.done && swipeOffset == 0 && focus.wrappedValue != .nice(index)
    }

    private var item: NiceItem {
        store.plan.niceToDo.indices.contains(index) ? store.plan.niceToDo[index] : NiceItem()
    }

    private var binding: Binding<String> {
        Binding(
            get: { item.text },
            set: { text in
                let submitted = text.hasNewline
                let nextText = text.withoutNewlines
                var currentIndex = index
                if store.plan.niceToDo.indices.contains(index) {
                    store.updateNiceItem(at: index, text: nextText)
                } else if !nextText.isEmpty {
                    currentIndex = store.addNiceItem()
                    store.updateNiceItem(at: currentIndex, text: nextText)
                }

                if submitted, store.plan.niceToDo.indices.contains(currentIndex) {
                    let nextIndex = store.insertNiceItem(after: currentIndex)
                    focus.wrappedValue = .nice(nextIndex)
                }
            }
        )
    }
}

private struct WeekBlock: View {
    @EnvironmentObject private var store: OneThingStore
    @AppStorage("onething-theme") private var theme = "light"
    let focus: FocusState<FocusedField?>.Binding

    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel("WEEK")
            TextField("", text: weekBinding, axis: .vertical)
                .font(.system(size: 16))
                .foregroundStyle(palette.secondaryStrong)
                .strikethrough(store.week.goalCompleted)
                .opacity(store.week.goalCompleted ? 0.4 : 1)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .frame(minWidth: 100, minHeight: 44, alignment: .leading)
                .focused(focus, equals: .week)
                .submitLabel(.done)
                .gesture(completeSwipe)
        }
    }

    private var completeSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                if value.translation.width > 40, !store.week.goalCompleted {
                    store.toggleWeekGoal()
                } else if value.translation.width < -40, store.week.goalCompleted {
                    store.toggleWeekGoal()
                }
            }
    }

    private var weekBinding: Binding<String> {
        Binding(
            get: { store.week.goal },
            set: { text in
                let submitted = text.hasNewline
                store.updateWeekGoal(text.withoutNewlines)
                if submitted {
                    focus.wrappedValue = nil
                }
            }
        )
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: OneThingStore
    @EnvironmentObject private var sync: SyncEngine
    @Binding var hideCompleted: Bool
    @Binding var showingSync: Bool
    @Binding var theme: String
    let topInset: CGFloat
    let bottomInset: CGFloat
    let isCompact: Bool
    let focus: FocusState<FocusedField?>.Binding
    @State private var newTodoText = ""

    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("TODO")
                Spacer()
            }
            .frame(height: 44)
            .padding(.top, topInset)
            .padding(.leading, isCompact ? 64 : 48)
            .padding(.trailing, 20)
            .padding(.bottom, 8)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(displayTodos) { item in
                        TodoRow(item: item, focus: focus)
                    }
                    TextField("", text: addTodoBinding, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.primary)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .frame(minHeight: 44, alignment: .leading)
                        .focused(focus, equals: .newTodo)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Spacer()

            HStack(spacing: 4) {
                FooterButton(systemName: hideCompleted ? "eye.slash" : "eye") {
                    hideCompleted.toggle()
                }
                FooterButton(systemName: syncIcon) {
                    showingSync = true
                }
                FooterButton(systemName: theme == "dark" ? "moon" : "sun.max") {
                    theme = theme == "dark" ? "light" : "dark"
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, max(bottomInset, 16))
        }
        .background(palette.surface.ignoresSafeArea())
    }

    private var displayTodos: [TodoItem] {
        store.visibleTodos.filter { !hideCompleted || !$0.done }
    }

    private var syncIcon: String {
        switch sync.status {
        case .syncing: "arrow.triangle.2.circlepath"
        default: "globe"
        }
    }

    private var addTodoBinding: Binding<String> {
        Binding(
            get: { newTodoText },
            set: { text in
                newTodoText = text.withoutNewlines
                if text.hasNewline,
                   !newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.addTodo(text: newTodoText)
                    newTodoText = ""
                    focus.wrappedValue = .newTodo
                }
            }
        )
    }
}

private struct TodoRow: View {
    @EnvironmentObject private var store: OneThingStore
    @AppStorage("onething-theme") private var theme = "light"
    let item: TodoItem
    let focus: FocusState<FocusedField?>.Binding
    @State private var rowWidth: CGFloat = 1
    @State private var rowHeight: CGFloat = 44
    @State private var swipeOffset: CGFloat = 0
    @State private var reorderReady = false

    private var palette: Palette { Palette(theme: theme) }

    var body: some View {
        ZStack(alignment: .leading) {
            displayText
            editor
        }
        .overlay(alignment: .leading) {
            strikeOverlay
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        rowWidth = proxy.size.width
                        rowHeight = proxy.size.height
                    }
                    .onChange(of: proxy.size.width) { rowWidth = $0 }
                    .onChange(of: proxy.size.height) { rowHeight = $0 }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if showDisplayText {
                focus.wrappedValue = .todo(item.id)
            }
        }
        .gesture(completeSwipe)
        .simultaneousGesture(reorderGesture)
    }

    private var editor: some View {
        TextField("", text: binding, axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(palette.primary)
            .opacity(showDisplayText ? 0 : item.done ? 0.4 : 1)
            .textFieldStyle(.plain)
            .lineLimit(1...4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .focused(focus, equals: .todo(item.id))
            .submitLabel(.next)
    }

    private var displayText: some View {
        Text(item.text.isEmpty ? " " : item.text)
            .font(.system(size: 15))
            .foregroundStyle(palette.primary)
            .opacity(showDisplayText ? 0.4 : 0)
            .lineLimit(1...4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .allowsHitTesting(false)
    }

    private var strikeOverlay: some View {
        GeometryReader { proxy in
            let width = strikeWidth(total: proxy.size.width)
            strikeText(width: proxy.size.width)
                .opacity(width > 0 ? 1 : 0)
                .mask(alignment: .leading) {
                    Rectangle().frame(width: width)
                }
        }
        .allowsHitTesting(false)
    }

    private func strikeText(width: CGFloat) -> some View {
        Text(item.text.isEmpty ? " " : item.text)
            .font(.system(size: 15))
            .foregroundStyle(.clear)
            .strikethrough(true, color: palette.primary.opacity(0.55))
            .lineLimit(1...4)
            .frame(width: width, alignment: .leading)
            .frame(minHeight: 44, alignment: .leading)
    }

    private var completeSwipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if abs(value.translation.width) >= abs(value.translation.height) {
                    swipeOffset = value.translation.width
                }
            }
            .onEnded { value in
                defer {
                    withAnimation(.easeOut(duration: 0.16)) {
                        swipeOffset = 0
                    }
                }

                let threshold = max(rowWidth * 0.25, 44)
                if value.translation.width > threshold, !item.done {
                    store.toggleTodo(id: item.id)
                } else if value.translation.width < -threshold, item.done {
                    store.toggleTodo(id: item.id)
                }
            }
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.26)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, _) = value, !reorderReady {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    reorderReady = true
                }
            }
            .onEnded { value in
                defer { reorderReady = false }
                guard case let .second(true, drag?) = value else { return }
                let steps = Int((drag.translation.height / max(rowHeight, 44)).rounded())
                if steps != 0 {
                    store.moveTodo(id: item.id, by: steps)
                }
            }
    }

    private func strikeWidth(total: CGFloat) -> CGFloat {
        let base = item.done ? total : 0
        let width = base + swipeOffset
        return min(max(width, 0), total)
    }

    private var showDisplayText: Bool {
        item.done && swipeOffset == 0 && focus.wrappedValue != .todo(item.id)
    }

    private var binding: Binding<String> {
        Binding(
            get: { store.todos.first(where: { $0.id == item.id })?.text ?? item.text },
            set: { text in
                let submitted = text.hasNewline
                store.updateTodo(id: item.id, text: text.withoutNewlines)
                if submitted {
                    let id = store.insertTodo(after: item.id)
                    focus.wrappedValue = .todo(id)
                }
            }
        )
    }
}

private struct FooterButton: View {
    @AppStorage("onething-theme") private var theme = "light"
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Palette(theme: theme).tertiary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

private struct SectionLabel: View {
    @AppStorage("onething-theme") private var theme = "light"
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .tracking(3)
            .foregroundStyle(Palette(theme: theme).tertiary)
    }
}

private struct SyncSheet: View {
    @EnvironmentObject private var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @State private var passphrase = ""
    @State private var message: String?
    @FocusState private var passphraseFocused: Bool
    @AppStorage("onething-theme") private var theme = "light"

    private var palette: Palette { Palette(theme: theme) }
    private var canConnect: Bool {
        passphrase.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionLabel(sync.isEnabled ? "SYNC CONNECTED" : "SYNC ACROSS DEVICES")
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(palette.secondaryStrong)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                if sync.isEnabled {
                    Text("Your data is syncing across devices.")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.secondaryStrong)
                    Button("Sync now") {
                        Task { await sync.syncNow() }
                    }
                    .buttonStyle(SheetActionButtonStyle(color: palette.accent))
                    Button("Disconnect", role: .destructive) {
                        sync.disconnect()
                    }
                    .buttonStyle(SheetActionButtonStyle(color: palette.danger))
                } else {
                    Text("Enter a passphrase to sync your data across devices. Use the same passphrase on all your devices.")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.secondaryStrong)
                    SecureField("Passphrase", text: $passphrase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($passphraseFocused)
                        .submitLabel(.done)
                        .onSubmit(connect)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .foregroundStyle(palette.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(palette.surfaceSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(palette.border, lineWidth: 1)
                        )
                    Button("Connect") {
                        connect()
                    }
                    .buttonStyle(SheetActionButtonStyle(color: canConnect ? palette.accent : palette.border))
                    .disabled(!canConnect)
                }

                if let message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    passphraseFocused = false
                }
            }
        }
    }

    private func connect() {
        guard canConnect else { return }
        message = "Connecting..."
        Task {
            do {
                try await sync.connect(passphrase: passphrase)
                passphrase = ""
                message = "Connected! Your data is now syncing."
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

private struct SheetActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(configuration.isPressed ? 0.82 : 1))
            )
    }
}

private extension String {
    var hasNewline: Bool {
        rangeOfCharacter(from: .newlines) != nil
    }

    var withoutNewlines: String {
        components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
