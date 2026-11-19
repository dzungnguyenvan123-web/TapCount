import Foundation

public struct PeriodCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    /// Returns the inclusive start and exclusive end of the active period for the given cadence and reference date.
    /// Returns `nil` for `.never` (meaning all recorded events belong to the active period).
    public func activePeriodRange(for cadence: ResetCadence, at date: Date) -> DateInterval? {
        switch cadence {
        case .daily:
            return calendar.dateInterval(of: .day, for: date)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date)
        case .never:
            return nil
        }
    }

    public func activeEvents(for task: CountTask, at date: Date) -> [TapEvent] {
        guard let range = activePeriodRange(for: task.resetCadence, at: date) else {
            return task.events
        }
        return task.events.filter { event in
            event.timestamp >= range.start && event.timestamp < range.end
        }
    }

    public func currentCount(for task: CountTask, at date: Date) -> Int {
        activeEvents(for: task, at: date).count
    }

    public func progress(for task: CountTask, at date: Date) -> Double? {
        guard let goal = task.goal, goal > 0 else { return nil }
        return min(Double(currentCount(for: task, at: date)) / Double(goal), 1.0)
    }

    public func isGoalMet(for task: CountTask, at date: Date) -> Bool {
        guard let goal = task.goal, goal > 0 else { return false }
        return currentCount(for: task, at: date) >= goal
    }

    /// Returns daily buckets for the last `days` calendar days (oldest to newest, ending with `date`'s day).
    public func dailyHistory(for task: CountTask, days: Int = 14, endingAt date: Date) -> [HistoryBucket] {
        guard days > 0 else { return [] }
        let todayStart = calendar.startOfDay(for: date)

        var countsByDay: [Date: Int] = [:]
        for event in task.events {
            let dayStart = calendar.startOfDay(for: event.timestamp)
            countsByDay[dayStart, default: 0] += 1
        }

        return (0..<days).reversed().compactMap { offset in
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            else {
                return nil
            }
            return HistoryBucket(
                startDate: dayStart,
                endDate: dayEnd,
                count: countsByDay[dayStart, default: 0]
            )
        }
    }

    /// Returns weekly buckets for the last `weeks` calendar weeks (oldest to newest, ending with `date`'s week).
    public func weeklyHistory(for task: CountTask, weeks: Int = 8, endingAt date: Date) -> [HistoryBucket] {
        guard weeks > 0,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: date)
        else {
            return []
        }

        var countsByWeek: [Date: Int] = [:]
        for event in task.events {
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: event.timestamp) {
                countsByWeek[weekInterval.start, default: 0] += 1
            }
        }

        return (0..<weeks).reversed().compactMap { offset in
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek.start),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)
            else {
                return nil
            }
            return HistoryBucket(
                startDate: interval.start,
                endDate: interval.end,
                count: countsByWeek[interval.start, default: 0]
            )
        }
    }

    /// Computes summary statistics for the task as of `date`.
    public func stats(for task: CountTask, at date: Date) -> TaskStats {
        let active = currentCount(for: task, at: date)
        let total = task.events.count

        let last7 = dailyHistory(for: task, days: 7, endingAt: date)
        let sevenDaySum = last7.reduce(0) { $0 + $1.count }
        let sevenDayAverage = Double(sevenDaySum) / 7.0

        let best: Int
        let streak: Int

        switch task.resetCadence {
        case .daily, .never:
            var countsByDay: [Date: Int] = [:]
            for event in task.events {
                let dayStart = calendar.startOfDay(for: event.timestamp)
                countsByDay[dayStart, default: 0] += 1
            }
            best = countsByDay.values.max() ?? 0
            streak = dailyStreak(countsByDay: countsByDay, goal: task.goal, at: date)

        case .weekly:
            var countsByWeek: [Date: Int] = [:]
            for event in task.events {
                if let interval = calendar.dateInterval(of: .weekOfYear, for: event.timestamp) {
                    countsByWeek[interval.start, default: 0] += 1
                }
            }
            best = countsByWeek.values.max() ?? 0
            streak = weeklyStreak(countsByWeek: countsByWeek, goal: task.goal, at: date)
        }

        return TaskStats(
            currentCount: active,
            allTimeTotal: total,
            currentStreak: streak,
            bestPeriodCount: best,
            sevenDayAverage: sevenDayAverage
        )
    }

    private func dailyStreak(countsByDay: [Date: Int], goal: Int?, at date: Date) -> Int {
        let threshold = max(goal ?? 1, 1)
        let today = calendar.startOfDay(for: date)

        // If today hasn't reached threshold yet, start checking from yesterday so an active streak isn't lost mid-day.
        var cursor: Date
        if countsByDay[today, default: 0] >= threshold {
            cursor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  countsByDay[yesterday, default: 0] >= threshold
        {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while countsByDay[cursor, default: 0] >= threshold {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func weeklyStreak(countsByWeek: [Date: Int], goal: Int?, at date: Date) -> Int {
        let threshold = max(goal ?? 1, 1)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }

        var cursorStart: Date
        if countsByWeek[thisWeek.start, default: 0] >= threshold {
            cursorStart = thisWeek.start
        } else if let prevAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start),
                  let prevWeek = calendar.dateInterval(of: .weekOfYear, for: prevAnchor),
                  countsByWeek[prevWeek.start, default: 0] >= threshold
        {
            cursorStart = prevWeek.start
        } else {
            return 0
        }

        var streak = 0
        while countsByWeek[cursorStart, default: 0] >= threshold {
            streak += 1
            guard let prevAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursorStart),
                  let prevWeek = calendar.dateInterval(of: .weekOfYear, for: prevAnchor)
            else {
                break
            }
            cursorStart = prevWeek.start
        }
        return streak
    }
}
