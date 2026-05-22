import SwiftUI

@MainActor
final class OneThingStore: ObservableObject {
    private let persistence: LocalPersistence
    private let sync: SyncEngine
    private let feedback = UINotificationFeedbackGenerator()
    private var pendingUndo: UndoAction?

    @Published var selectedDate: Date {
        didSet { reloadDate() }
    }
    @Published private(set) var plan: DailyPlan
    @Published private(set) var week: WeekGoal
    @Published private(set) var todos: [TodoItem]

    init(persistence: LocalPersistence, sync: SyncEngine) {
        self.persistence = persistence
        self.sync = sync
        self.selectedDate = Date()
        self.plan = persistence.loadPlan(for: Date())
        self.week = persistence.loadWeek(for: Date())
        self.todos = persistence.loadTodos()

        sync.onRemoteChange = { [weak self] in
            self?.reloadAll()
        }
    }

    var visibleTodos: [TodoItem] {
        todos.filter(\.done) + todos.filter { !$0.done }
    }

    var canUndo: Bool {
        pendingUndo != nil
    }

    var undoTitle: String {
        pendingUndo?.title ?? "last action"
    }

    func reloadAll() {
        plan = persistence.loadPlan(for: selectedDate)
        week = persistence.loadWeek(for: selectedDate)
        todos = persistence.loadTodos()
    }

    func updateGoal(_ text: String) {
        guard plan.goal != text else { return }
        rememberUndo("editing the goal", plan: true)
        plan.goal = text
        savePlan()
    }

    func toggleGoal() {
        rememberUndo(plan.goalCompleted ? "reopening the goal" : "completing the goal", plan: true)
        plan.goalCompleted.toggle()
        savePlan()
        if plan.goalCompleted {
            feedback.notificationOccurred(.success)
        }
    }

    func updateWeekGoal(_ text: String) {
        guard week.goal != text else { return }
        rememberUndo("editing the week goal", week: true)
        week.goal = text
        saveWeek()
    }

    func toggleWeekGoal() {
        rememberUndo(week.goalCompleted ? "reopening the week goal" : "completing the week goal", week: true)
        week.goalCompleted.toggle()
        saveWeek()
        if week.goalCompleted {
            feedback.notificationOccurred(.success)
        }
    }

    @discardableResult
    func addNiceItem(text: String = "") -> Int {
        rememberUndo("adding a nice to do", plan: true)
        plan.niceToDo.append(NiceItem(text: text))
        savePlan()
        return plan.niceToDo.count - 1
    }

    @discardableResult
    func insertNiceItem(after index: Int) -> Int {
        let insertIndex = min(max(index + 1, 0), plan.niceToDo.count)
        rememberUndo("adding a nice to do", plan: true)
        plan.niceToDo.insert(NiceItem(), at: insertIndex)
        savePlan()
        return insertIndex
    }

    func updateNiceItem(at index: Int, text: String) {
        guard plan.niceToDo.indices.contains(index) else { return }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deleteNiceItem(at: index)
            return
        }
        guard plan.niceToDo[index].text != text else { return }

        rememberUndo("editing a nice to do", plan: true)
        plan.niceToDo[index].text = text
        savePlan()
    }

    func toggleNiceItem(at index: Int) {
        guard plan.niceToDo.indices.contains(index) else { return }
        rememberUndo(plan.niceToDo[index].done ? "reopening a nice to do" : "completing a nice to do", plan: true)
        plan.niceToDo[index].done.toggle()
        savePlan()
        if plan.niceToDo[index].done {
            feedback.notificationOccurred(.success)
        }
    }

    func deleteNiceItem(at index: Int) {
        guard plan.niceToDo.indices.contains(index) else { return }
        rememberUndo("deleting a nice to do", plan: true)
        plan.niceToDo.remove(at: index)
        savePlan()
    }

    func moveNiceItem(from index: Int, to destination: Int) {
        guard plan.niceToDo.indices.contains(index) else { return }
        let target = min(max(destination, 0), plan.niceToDo.count - 1)
        guard target != index else { return }

        rememberUndo("reordering a nice to do", plan: true)
        let item = plan.niceToDo.remove(at: index)
        plan.niceToDo.insert(item, at: target)
        savePlan()
    }

    @discardableResult
    func addTodo(text: String = "") -> String {
        rememberUndo("adding a todo", todos: true)
        let item = TodoItem(text: text)
        saveTodos(todos + [item])
        return item.id
    }

    @discardableResult
    func insertTodo(after id: String) -> String {
        var next = todos
        let item = TodoItem()
        let insertIndex = next.firstIndex { $0.id == id }.map { $0 + 1 } ?? next.count
        rememberUndo("adding a todo", todos: true)
        next.insert(item, at: insertIndex)
        saveTodos(next)
        return item.id
    }

    func updateTodo(id: String, text: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deleteTodo(id: id)
            return
        }

        var next = todos
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        guard next[index].text != text else { return }
        rememberUndo("editing a todo", todos: true)
        next[index].text = text
        saveTodos(next)
    }

    func toggleTodo(id: String) {
        var next = todos
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        rememberUndo(next[index].done ? "reopening a todo" : "completing a todo", todos: true)
        next[index].done.toggle()
        let completed = next[index].done
        saveTodos(next)
        if completed {
            feedback.notificationOccurred(.success)
        }
    }

    func deleteTodo(id: String) {
        guard todos.contains(where: { $0.id == id }) else { return }
        rememberUndo("deleting a todo", todos: true)
        saveTodos(todos.filter { $0.id != id })
    }

    func moveTodo(id: String, by offset: Int) {
        guard offset != 0 else { return }
        var next = todos
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        let moving = next[index]
        let group = next.filter { $0.done == moving.done }.map(\.id)
        guard let groupIndex = group.firstIndex(of: id) else { return }
        let targetGroupIndex = min(max(groupIndex + offset, 0), group.count - 1)
        guard targetGroupIndex != groupIndex else { return }

        rememberUndo("reordering a todo", todos: true)
        let item = next.remove(at: index)
        guard let targetIndex = next.firstIndex(where: { $0.id == group[targetGroupIndex] }) else { return }
        let insertIndex = targetGroupIndex > groupIndex ? targetIndex + 1 : targetIndex
        next.insert(item, at: min(insertIndex, next.count))
        saveTodos(next)
    }

    func undoLastAction() {
        guard let action = pendingUndo else { return }
        pendingUndo = nil

        if let plan = action.plan, let date = action.restoreDate {
            savePlan(plan, for: date)
        }

        if let week = action.week, let date = action.restoreDate {
            saveWeek(week, for: date)
        }

        if let todos = action.todos {
            saveTodos(todos)
        }

        if let date = action.restoreDate {
            selectedDate = date
        }
        reloadAll()
        feedback.notificationOccurred(.success)
    }

    func changeSelectedDate(by days: Int) {
        let nextDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        guard DateKeys.dayString(nextDate) != DateKeys.dayString(selectedDate) else { return }
        rememberUndo("changing the date", date: true)
        selectedDate = nextDate
    }

    private func reloadDate() {
        plan = persistence.loadPlan(for: selectedDate)
        week = persistence.loadWeek(for: selectedDate)
    }

    private func savePlan() {
        savePlan(plan, for: selectedDate)
    }

    private func saveWeek() {
        saveWeek(week, for: selectedDate)
    }

    private func saveTodos(_ next: [TodoItem]) {
        let old = todos
        todos = next
        persistence.saveTodos(next)
        sync.recordTodosChanged(old: old, new: next)
    }

    private func savePlan(_ plan: DailyPlan, for date: Date) {
        persistence.savePlan(plan, for: date)
        sync.recordPlan(plan, for: date)
    }

    private func saveWeek(_ week: WeekGoal, for date: Date) {
        persistence.saveWeek(week, for: date)
        sync.recordWeek(week, for: date)
    }

    private func rememberUndo(
        _ title: String,
        date includeDate: Bool = false,
        plan includePlan: Bool = false,
        week includeWeek: Bool = false,
        todos includeTodos: Bool = false
    ) {
        pendingUndo = UndoAction(
            title: title,
            restoreDate: includeDate || includePlan || includeWeek ? selectedDate : nil,
            plan: includePlan ? plan : nil,
            week: includeWeek ? week : nil,
            todos: includeTodos ? todos : nil
        )
    }
}

private struct UndoAction {
    var title: String
    var restoreDate: Date?
    var plan: DailyPlan?
    var week: WeekGoal?
    var todos: [TodoItem]?
}
