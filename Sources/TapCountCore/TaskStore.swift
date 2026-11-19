import Foundation
import Observation

@MainActor
@Observable
public final class TaskStore {
    public private(set) var tasks: [CountTask] = []
    public var preferences: AppPreferences = AppPreferences() {
        didSet {
            if preferences != oldValue {
                persist()
            }
        }
    }

    public private(set) var undoStack: [UndoAction] = []
    public private(set) var lastActionBanner: UndoAction?
    public private(set) var referenceDate: Date
    public private(set) var lastError: String?

    private let persistence: TaskPersistence
    private let calculator: PeriodCalculator
    private let nowProvider: @Sendable () -> Date
    private let maxUndoEntries = 50

    public init(
        persistence: TaskPersistence = JSONFilePersistence(),
        calendar: Calendar = .autoupdatingCurrent,
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        seedDefaultsIfEmpty: Bool = true
    ) {
        self.persistence = persistence
        self.calculator = PeriodCalculator(calendar: calendar)
        self.nowProvider = nowProvider
        self.referenceDate = nowProvider()

        loadFromDisk(seedDefaultsIfEmpty: seedDefaultsIfEmpty)
    }

    // MARK: - Queries

    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    public var totalTapsToday: Int {
        let now = referenceDate
        let dayRange = calculator.calendar.dateInterval(of: .day, for: now)
        guard let dayRange else { return 0 }
        return tasks.reduce(0) { sum, task in
            sum + task.events.filter { $0.timestamp >= dayRange.start && $0.timestamp < dayRange.end }.count
        }
    }

    public func currentCount(for task: CountTask) -> Int {
        calculator.currentCount(for: task, at: referenceDate)
    }

    public func progress(for task: CountTask) -> Double? {
        calculator.progress(for: task, at: referenceDate)
    }

    public func isGoalMet(for task: CountTask) -> Bool {
        calculator.isGoalMet(for: task, at: referenceDate)
    }

    public func activeEvents(for task: CountTask) -> [TapEvent] {
        calculator.activeEvents(for: task, at: referenceDate)
    }

    public func dailyHistory(for task: CountTask, days: Int = 14) -> [HistoryBucket] {
        calculator.dailyHistory(for: task, days: days, endingAt: referenceDate)
    }

    public func weeklyHistory(for task: CountTask, weeks: Int = 8) -> [HistoryBucket] {
        calculator.weeklyHistory(for: task, weeks: weeks, endingAt: referenceDate)
    }

    public func stats(for task: CountTask) -> TaskStats {
        calculator.stats(for: task, at: referenceDate)
    }

    public func task(withID id: UUID) -> CountTask? {
        tasks.first { $0.id == id }
    }

    // MARK: - Clock Refresh

    public func refreshClock() {
        referenceDate = nowProvider()
    }

    // MARK: - Counting Mutations

    @discardableResult
    public func tap(taskID: UUID) -> TapEvent? {
        refreshClock()
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        let event = TapEvent(timestamp: referenceDate)
        tasks[index].events.append(event)
        recordUndo(.tapped(taskID: taskID, taskName: tasks[index].name, event: event))
        persist()
        return event
    }

    @discardableResult
    public func decrement(taskID: UUID) -> TapEvent? {
        refreshClock()
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        let active = calculator.activeEvents(for: tasks[index], at: referenceDate)
        guard let latestEvent = active.max(by: { $0.timestamp < $1.timestamp }) else {
            return nil
        }
        guard let eventIndex = tasks[index].events.lastIndex(where: { $0.id == latestEvent.id }) else {
            return nil
        }
        let removed = tasks[index].events.remove(at: eventIndex)
        recordUndo(.decremented(taskID: taskID, taskName: tasks[index].name, removedEvent: removed))
        persist()
        return removed
    }

    public func removeEvent(taskID: UUID, eventID: UUID) {
        refreshClock()
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }),
              let eventIndex = tasks[taskIndex].events.firstIndex(where: { $0.id == eventID })
        else {
            return
        }
        let removed = tasks[taskIndex].events.remove(at: eventIndex)
        recordUndo(.removedEvent(taskID: taskID, taskName: tasks[taskIndex].name, removedEvent: removed))
        persist()
    }

    public func resetCurrentPeriod(taskID: UUID) {
        refreshClock()
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let activeIDs = Set(calculator.activeEvents(for: tasks[index], at: referenceDate).map(\.id))
        guard !activeIDs.isEmpty else { return }

        let removed = tasks[index].events.filter { activeIDs.contains($0.id) }
        tasks[index].events.removeAll { activeIDs.contains($0.id) }
        recordUndo(.resetPeriod(taskID: taskID, taskName: tasks[index].name, removedEvents: removed))
        persist()
    }

    // MARK: - Task CRUD

    @discardableResult
    public func addTask(
        name: String,
        icon: String,
        color: TaskColor,
        resetCadence: ResetCadence,
        goal: Int?
    ) -> CountTask {
        refreshClock()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Untitled Task" : trimmed
        let nextOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
        let task = CountTask(
            name: finalName,
            icon: icon,
            color: color,
            resetCadence: resetCadence,
            goal: goal,
            createdAt: referenceDate,
            sortOrder: nextOrder
        )
        tasks.append(task)
        persist()
        return task
    }

    public func updateTask(
        id: UUID,
        name: String,
        icon: String,
        color: TaskColor,
        resetCadence: ResetCadence,
        goal: Int?
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[index].name = trimmed.isEmpty ? tasks[index].name : trimmed
        tasks[index].icon = icon
        tasks[index].color = color
        tasks[index].resetCadence = resetCadence
        tasks[index].goal = goal.flatMap { $0 > 0 ? $0 : nil }
        persist()
    }

    public func deleteTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let removed = tasks.remove(at: index)
        reindexSortOrder()
        recordUndo(.deletedTask(task: removed, index: index))
        persist()
    }

    public func moveTask(id: UUID, direction: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let target = index + direction
        guard target >= 0, target < tasks.count else { return }
        tasks.swapAt(index, target)
        reindexSortOrder()
        persist()
    }

    // MARK: - Undo

    @discardableResult
    public func undoLastAction() -> UndoAction? {
        guard let action = undoStack.popLast() else { return nil }
        switch action {
        case let .tapped(taskID, _, event):
            if let index = tasks.firstIndex(where: { $0.id == taskID }) {
                tasks[index].events.removeAll { $0.id == event.id }
            }

        case let .decremented(taskID, _, removedEvent),
             let .removedEvent(taskID, _, removedEvent):
            if let index = tasks.firstIndex(where: { $0.id == taskID }) {
                tasks[index].events.append(removedEvent)
                tasks[index].events.sort { $0.timestamp < $1.timestamp }
            }

        case let .resetPeriod(taskID, _, removedEvents):
            if let index = tasks.firstIndex(where: { $0.id == taskID }) {
                tasks[index].events.append(contentsOf: removedEvents)
                tasks[index].events.sort { $0.timestamp < $1.timestamp }
            }

        case let .deletedTask(task, originalIndex):
            let clamped = min(max(originalIndex, 0), tasks.count)
            tasks.insert(task, at: clamped)
            reindexSortOrder()
        }

        lastActionBanner = undoStack.last
        persist()
        return action
    }

    public func dismissActionBanner() {
        lastActionBanner = nil
    }

    // MARK: - Private Helpers

    private func recordUndo(_ action: UndoAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
        lastActionBanner = action
    }

    private func reindexSortOrder() {
        for idx in tasks.indices {
            tasks[idx].sortOrder = idx
        }
    }

    private func loadFromDisk(seedDefaultsIfEmpty: Bool) {
        do {
            if let snapshot = try persistence.load() {
                tasks = snapshot.tasks.sorted { $0.sortOrder < $1.sortOrder }
                preferences = snapshot.preferences
            } else if seedDefaultsIfEmpty {
                tasks = Self.defaultStarterTasks(now: referenceDate)
                persist()
            }
        } catch {
            lastError = "Failed to load saved data: \(error.localizedDescription)"
            if seedDefaultsIfEmpty && tasks.isEmpty {
                tasks = Self.defaultStarterTasks(now: referenceDate)
            }
        }
    }

    private func persist() {
        let snapshot = StoreSnapshot(
            schemaVersion: 1,
            tasks: tasks,
            preferences: preferences
        )
        do {
            try persistence.save(snapshot)
            lastError = nil
        } catch {
            lastError = "Failed to save data: \(error.localizedDescription)"
        }
    }

    public static func defaultStarterTasks(now: Date = Date()) -> [CountTask] {
        [
            CountTask(
                name: "Drink Water",
                icon: "drop.fill",
                color: .cyan,
                resetCadence: .daily,
                goal: 8,
                createdAt: now,
                sortOrder: 0
            ),
            CountTask(
                name: "Stretch Break",
                icon: "figure.walk",
                color: .green,
                resetCadence: .daily,
                goal: 4,
                createdAt: now,
                sortOrder: 1
            ),
            CountTask(
                name: "Coffee",
                icon: "cup.and.saucer.fill",
                color: .orange,
                resetCadence: .daily,
                goal: nil,
                createdAt: now,
                sortOrder: 2
            ),
        ]
    }
}
