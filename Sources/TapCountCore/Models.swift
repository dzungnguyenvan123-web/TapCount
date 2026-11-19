import Foundation

public enum ResetCadence: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case never

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .never: "Never"
        }
    }

    public var periodLabel: String {
        switch self {
        case .daily: "Today"
        case .weekly: "This Week"
        case .never: "All Time"
        }
    }

    public var descriptionText: String {
        switch self {
        case .daily: "Resets at midnight each day"
        case .weekly: "Resets at the start of each week"
        case .never: "Counts continuously until manually reset"
        }
    }
}

public enum TaskColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue
    case cyan
    case teal
    case green
    case mint
    case yellow
    case orange
    case red
    case pink
    case purple
    case indigo
    case gray

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }
}

public struct TapEvent: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date

    public init(id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
    }
}

public struct CountTask: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var color: TaskColor
    public var resetCadence: ResetCadence
    public var goal: Int?
    public var createdAt: Date
    public var sortOrder: Int
    public var events: [TapEvent]

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "checkmark.circle.fill",
        color: TaskColor = .blue,
        resetCadence: ResetCadence = .daily,
        goal: Int? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        events: [TapEvent] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.resetCadence = resetCadence
        self.goal = goal.flatMap { $0 > 0 ? $0 : nil }
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.events = events
    }
}

public struct HistoryBucket: Identifiable, Equatable, Sendable {
    public let id: Date
    public let startDate: Date
    public let endDate: Date
    public let count: Int

    public init(startDate: Date, endDate: Date, count: Int) {
        self.id = startDate
        self.startDate = startDate
        self.endDate = endDate
        self.count = count
    }
}

public struct TaskStats: Equatable, Sendable {
    public let currentCount: Int
    public let allTimeTotal: Int
    public let currentStreak: Int
    public let bestPeriodCount: Int
    public let sevenDayAverage: Double

    public init(
        currentCount: Int,
        allTimeTotal: Int,
        currentStreak: Int,
        bestPeriodCount: Int,
        sevenDayAverage: Double
    ) {
        self.currentCount = currentCount
        self.allTimeTotal = allTimeTotal
        self.currentStreak = currentStreak
        self.bestPeriodCount = bestPeriodCount
        self.sevenDayAverage = sevenDayAverage
    }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var showCountInMenuBar: Bool

    public init(showCountInMenuBar: Bool = true) {
        self.showCountInMenuBar = showCountInMenuBar
    }
}

public struct StoreSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var tasks: [CountTask]
    public var preferences: AppPreferences

    public init(
        schemaVersion: Int = 1,
        tasks: [CountTask] = [],
        preferences: AppPreferences = AppPreferences()
    ) {
        self.schemaVersion = schemaVersion
        self.tasks = tasks
        self.preferences = preferences
    }
}

public enum UndoAction: Equatable, Sendable {
    case tapped(taskID: UUID, taskName: String, event: TapEvent)
    case decremented(taskID: UUID, taskName: String, removedEvent: TapEvent)
    case removedEvent(taskID: UUID, taskName: String, removedEvent: TapEvent)
    case resetPeriod(taskID: UUID, taskName: String, removedEvents: [TapEvent])
    case deletedTask(task: CountTask, index: Int)

    public var summary: String {
        switch self {
        case let .tapped(_, taskName, _):
            "+1 \(taskName)"
        case let .decremented(_, taskName, _):
            "-1 \(taskName)"
        case let .removedEvent(_, taskName, _):
            "Removed tap from \(taskName)"
        case let .resetPeriod(_, taskName, _):
            "Reset \(taskName)"
        case let .deletedTask(task, _):
            "Deleted \(task.name)"
        }
    }
}
