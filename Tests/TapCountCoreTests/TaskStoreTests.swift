import Foundation
import Testing
@testable import TapCountCore

@MainActor
struct TaskStoreTests {
    private final class ClockBox: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let cal = makeCalendar()
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TapCountTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    @Test("Tap increments count and persists across reloads")
    func tapAndPersist() {
        let url = tempStoreURL()
        let clock = ClockBox(makeDate(2026, 11, 19, hour: 9))
        let persistence = JSONFilePersistence(fileURL: url)

        let store = TaskStore(
            persistence: persistence,
            calendar: makeCalendar(),
            nowProvider: { clock.now },
            seedDefaultsIfEmpty: false
        )

        let water = store.addTask(
            name: "Drink Water",
            icon: "drop.fill",
            color: .cyan,
            resetCadence: .daily,
            goal: 8
        )
        store.tap(taskID: water.id)
        store.tap(taskID: water.id)
        store.tap(taskID: water.id)

        #expect(store.currentCount(for: store.task(withID: water.id)!) == 3)
        #expect(store.progress(for: store.task(withID: water.id)!) == 3.0 / 8.0)
        #expect(store.isGoalMet(for: store.task(withID: water.id)!) == false)

        // Reload from JSON file
        let reloaded = TaskStore(
            persistence: persistence,
            calendar: makeCalendar(),
            nowProvider: { clock.now },
            seedDefaultsIfEmpty: false
        )
        #expect(reloaded.tasks.count == 1)
        let reloadedWater = reloaded.task(withID: water.id)!
        #expect(reloaded.currentCount(for: reloadedWater) == 3)
    }

    @Test("Daily cadence auto-resets at midnight while keeping yesterday's history")
    func dailyAutoResetPreservesHistory() {
        let url = tempStoreURL()
        let clock = ClockBox(makeDate(2026, 11, 18, hour: 15))
        let store = TaskStore(
            persistence: JSONFilePersistence(fileURL: url),
            calendar: makeCalendar(),
            nowProvider: { clock.now },
            seedDefaultsIfEmpty: false
        )

        let water = store.addTask(
            name: "Drink Water",
            icon: "drop.fill",
            color: .cyan,
            resetCadence: .daily,
            goal: 2
        )
        store.tap(taskID: water.id)
        store.tap(taskID: water.id)
        #expect(store.currentCount(for: store.task(withID: water.id)!) == 2)
        #expect(store.isGoalMet(for: store.task(withID: water.id)!) == true)

        // Advance to next day
        clock.now = makeDate(2026, 11, 19, hour: 8)
        store.refreshClock()

        let updated = store.task(withID: water.id)!
        #expect(store.currentCount(for: updated) == 0)
        #expect(store.stats(for: updated).allTimeTotal == 2)
        #expect(store.stats(for: updated).currentStreak == 1) // Yesterday met goal -> streak stays alive mid-day

        let history = store.dailyHistory(for: updated, days: 2)
        #expect(history.count == 2)
        #expect(history[0].count == 2) // Nov 18
        #expect(history[1].count == 0) // Nov 19

        // Decrement at 0 today must NOT delete yesterday's taps
        let removed = store.decrement(taskID: water.id)
        #expect(removed == nil)
        #expect(store.stats(for: store.task(withID: water.id)!).allTimeTotal == 2)
    }

    @Test("Weekly cadence resets on new week and preserves prior week history")
    func weeklyAutoResetPreservesHistory() {
        let url = tempStoreURL()
        // 2026-11-15 is a Sunday (end of week with Monday firstWeekday)
        let clock = ClockBox(makeDate(2026, 11, 15, hour: 18))
        let store = TaskStore(
            persistence: JSONFilePersistence(fileURL: url),
            calendar: makeCalendar(),
            nowProvider: { clock.now },
            seedDefaultsIfEmpty: false
        )

        let workout = store.addTask(
            name: "Workout",
            icon: "dumbbell.fill",
            color: .green,
            resetCadence: .weekly,
            goal: 3
        )
        store.tap(taskID: workout.id)
        store.tap(taskID: workout.id)
        #expect(store.currentCount(for: store.task(withID: workout.id)!) == 2)

        // Advance to Monday (new week)
        clock.now = makeDate(2026, 11, 16, hour: 9)
        store.refreshClock()

        let updated = store.task(withID: workout.id)!
        #expect(store.currentCount(for: updated) == 0)
        let weekly = store.weeklyHistory(for: updated, weeks: 2)
        #expect(weekly.count == 2)
        #expect(weekly[0].count == 2)
        #expect(weekly[1].count == 0)
    }

    @Test("Never cadence accumulates across days without auto-resetting")
    func neverCadenceAccumulates() {
        let url = tempStoreURL()
        let clock = ClockBox(makeDate(2026, 11, 10, hour: 10))
        let store = TaskStore(
            persistence: JSONFilePersistence(fileURL: url),
            calendar: makeCalendar(),
            nowProvider: { clock.now },
            seedDefaultsIfEmpty: false
        )

        let books = store.addTask(
            name: "Books Read",
            icon: "book.fill",
            color: .purple,
            resetCadence: .never,
            goal: 10
        )
        store.tap(taskID: books.id)

        clock.now = makeDate(2026, 11, 19, hour: 10)
        store.tap(taskID: books.id)

        #expect(store.currentCount(for: store.task(withID: books.id)!) == 2)
    }

    @Test("Undo reverses tap, decrement, reset, and task deletion")
    func undoWorkflow() {
        let url = tempStoreURL()
        let clock = ClockBox(makeDate(2026, 11, 18, hour: 10))
        let store = TaskStore(
            persistence: JSONFilePersistence(fileURL: url),
            calendar: makeCalendar(),
            nowProvider: { clock.now },
            seedDefaultsIfEmpty: false
        )

        let coffee = store.addTask(
            name: "Coffee",
            icon: "cup.and.saucer.fill",
            color: .orange,
            resetCadence: .daily,
            goal: nil
        )
        // Yesterday tap
        store.tap(taskID: coffee.id)

        // Today taps
        clock.now = makeDate(2026, 11, 19, hour: 9)
        store.tap(taskID: coffee.id)
        clock.now = makeDate(2026, 11, 19, hour: 11)
        store.tap(taskID: coffee.id)
        #expect(store.currentCount(for: store.task(withID: coffee.id)!) == 2)

        // Decrement then Undo
        store.decrement(taskID: coffee.id)
        #expect(store.currentCount(for: store.task(withID: coffee.id)!) == 1)
        _ = store.undoLastAction()
        #expect(store.currentCount(for: store.task(withID: coffee.id)!) == 2)

        // Reset today preserves yesterday's tap; Undo restores today's 2 taps
        store.resetCurrentPeriod(taskID: coffee.id)
        #expect(store.currentCount(for: store.task(withID: coffee.id)!) == 0)
        #expect(store.stats(for: store.task(withID: coffee.id)!).allTimeTotal == 1)
        _ = store.undoLastAction()
        #expect(store.currentCount(for: store.task(withID: coffee.id)!) == 2)
        #expect(store.stats(for: store.task(withID: coffee.id)!).allTimeTotal == 3)

        // Delete task then Undo restores it
        store.deleteTask(id: coffee.id)
        #expect(store.tasks.isEmpty)
        _ = store.undoLastAction()
        #expect(store.tasks.count == 1)
        #expect(store.tasks[0].id == coffee.id)
    }
}
