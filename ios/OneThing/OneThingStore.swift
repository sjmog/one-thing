import SwiftUI

@MainActor
final class OneThingStore: ObservableObject {
    private let persistence: LocalPersistence
    private let sync: SyncEngine
    private let feedback = UINotificationFeedbackGenerator()

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

    func reloadAll() {
        plan = persistence.loadPlan(for: selectedDate)
        week = persistence.loadWeek(for: selectedDate)
        todos = persistence.loadTodos()
    }

    func updateGoal(_ text: String) {
        plan.goal = text
        savePlan()
    }

    func toggleGoal() {
        plan.goalCompleted.toggle()
        savePlan()
        if plan.goalCompleted {
            feedback.notificationOccurred(.success)
        }
    }

    func updateWeekGoal(_ text: String) {
        week.goal = text
        saveWeek()
    }

    func toggleWeekGoal() {
        week.goalCompleted.toggle()
        saveWeek()
        if week.goalCompleted {
            feedback.notificationOccurred(.success)
        }
    }

    @discardableResult
    func addNiceItem() -> Int {
        plan.niceToDo.append(NiceItem())
        savePlan()
        return plan.niceToDo.count - 1
    }

    @discardableResult
    func insertNiceItem(after index: Int) -> Int {
        let insertIndex = min(max(index + 1, 0), plan.niceToDo.count)
        plan.niceToDo.insert(NiceItem(), at: insertIndex)
        savePlan()
        return insertIndex
    }

    func updateNiceItem(at index: Int, text: String) {
        guard plan.niceToDo.indices.contains(index) else { return }
        plan.niceToDo[index].text = text
        savePlan()
    }

    func toggleNiceItem(at index: Int) {
        guard plan.niceToDo.indices.contains(index) else { return }
        plan.niceToDo[index].done.toggle()
        savePlan()
        if plan.niceToDo[index].done {
            feedback.notificationOccurred(.success)
        }
    }

    func deleteNiceItem(at index: Int) {
        guard plan.niceToDo.indices.contains(index) else { return }
        plan.niceToDo.remove(at: index)
        savePlan()
    }

    func moveNiceItem(from index: Int, to destination: Int) {
        guard plan.niceToDo.indices.contains(index) else { return }
        let target = min(max(destination, 0), plan.niceToDo.count - 1)
        guard target != index else { return }

        let item = plan.niceToDo.remove(at: index)
        plan.niceToDo.insert(item, at: target)
        savePlan()
    }

    @discardableResult
    func addTodo(text: String = "") -> String {
        let item = TodoItem(text: text)
        saveTodos(todos + [item])
        return item.id
    }

    @discardableResult
    func insertTodo(after id: String) -> String {
        var next = todos
        let item = TodoItem()
        let insertIndex = next.firstIndex { $0.id == id }.map { $0 + 1 } ?? next.count
        next.insert(item, at: insertIndex)
        saveTodos(next)
        return item.id
    }

    func updateTodo(id: String, text: String) {
        var next = todos
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].text = text
        saveTodos(next)
    }

    func toggleTodo(id: String) {
        var next = todos
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].done.toggle()
        let completed = next[index].done
        saveTodos(next)
        if completed {
            feedback.notificationOccurred(.success)
        }
    }

    func deleteTodo(id: String) {
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

        let item = next.remove(at: index)
        guard let targetIndex = next.firstIndex(where: { $0.id == group[targetGroupIndex] }) else { return }
        let insertIndex = targetGroupIndex > groupIndex ? targetIndex + 1 : targetIndex
        next.insert(item, at: min(insertIndex, next.count))
        saveTodos(next)
    }

    func changeSelectedDate(by days: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
    }

    private func reloadDate() {
        plan = persistence.loadPlan(for: selectedDate)
        week = persistence.loadWeek(for: selectedDate)
    }

    private func savePlan() {
        persistence.savePlan(plan, for: selectedDate)
        sync.recordPlan(plan, for: selectedDate)
    }

    private func saveWeek() {
        persistence.saveWeek(week, for: selectedDate)
        sync.recordWeek(week, for: selectedDate)
    }

    private func saveTodos(_ next: [TodoItem]) {
        let old = todos
        todos = next
        persistence.saveTodos(next)
        sync.recordTodosChanged(old: old, new: next)
    }
}
