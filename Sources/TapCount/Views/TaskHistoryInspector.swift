import Charts
import SwiftUI
import TapCountCore

struct TaskHistoryInspector: View {
    let store: TaskStore
    let task: CountTask
    let onEdit: () -> Void

    @State private var chartMode: ChartRange = .daily

    enum ChartRange: String, CaseIterable, Identifiable {
        case daily = "14 Days"
        case weekly = "8 Weeks"

        var id: String { rawValue }
    }

    private var accent: Color { task.color.swiftUIColor }
    private var stats: TaskStats { store.stats(for: task) }

    private var buckets: [HistoryBucket] {
        switch chartMode {
        case .daily:
            store.dailyHistory(for: task, days: 14)
        case .weekly:
            store.weeklyHistory(for: task, weeks: 8)
        }
    }

    private var chartGoalLine: Int? {
        guard let goal = task.goal else { return nil }
        switch (task.resetCadence, chartMode) {
        case (.daily, .daily), (.weekly, .weekly):
            return goal
        default:
            return nil
        }
    }

    private var recentEvents: [TapEvent] {
        Array(task.events.sorted { $0.timestamp > $1.timestamp }.prefix(50))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Task Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(accent.opacity(0.16))
                            .frame(width: 40, height: 40)
                        Image(systemName: task.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name)
                            .font(.headline)
                            .lineLimit(2)
                        Text("\(task.resetCadence.displayName) reset\(task.goal.map { " · Goal \($0)" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Edit") {
                        onEdit()
                    }
                    .controlSize(.small)
                }

                // Quick Tap / Decrement Controls
                HStack(spacing: 8) {
                    Button {
                        store.tap(taskID: task.id)
                    } label: {
                        Label("Tap +1", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)

                    Button {
                        store.decrement(taskID: task.id)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 28)
                    }
                    .buttonStyle(.bordered)
                    .disabled(stats.currentCount == 0)
                    .help("Decrement (-1)")
                }

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(
                        title: task.resetCadence.periodLabel,
                        value: "\(stats.currentCount)",
                        subtitle: task.goal.map { "of \($0) goal" } ?? "current"
                    )
                    StatTile(
                        title: "Streak",
                        value: "\(stats.currentStreak)",
                        subtitle: task.resetCadence == .weekly ? "weeks" : "days"
                    )
                    StatTile(
                        title: "7-Day Avg",
                        value: String(format: "%.1f", stats.sevenDayAverage),
                        subtitle: "per day"
                    )
                    StatTile(
                        title: "All-Time",
                        value: "\(stats.allTimeTotal)",
                        subtitle: "best \(stats.bestPeriodCount)"
                    )
                }

                // History Chart
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("History")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("Range", selection: $chartMode) {
                            ForEach(ChartRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 150)
                        .controlSize(.small)
                    }

                    Chart {
                        ForEach(buckets) { bucket in
                            BarMark(
                                x: .value("Date", bucket.startDate, unit: chartMode == .daily ? .day : .weekOfYear),
                                y: .value("Count", bucket.count)
                            )
                            .foregroundStyle(
                                (chartGoalLine != nil && bucket.count >= (chartGoalLine ?? .max))
                                    ? Color.green.gradient
                                    : accent.gradient
                            )
                            .cornerRadius(4)
                        }

                        if let goal = chartGoalLine {
                            RuleMark(y: .value("Goal", goal))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                        }
                    }
                    .frame(height: 155)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }

                // Recent Tap Log
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Taps")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if stats.currentCount > 0 {
                            Button("Reset \(task.resetCadence.periodLabel)") {
                                store.resetCurrentPeriod(taskID: task.id)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }

                    if recentEvents.isEmpty {
                        Text("No taps recorded yet. Click the card to start counting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(recentEvents) { event in
                                HStack {
                                    Circle()
                                        .fill(accent)
                                        .frame(width: 6, height: 6)

                                    Text(DateFormatters.tapTime.string(from: event.timestamp))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Button {
                                        store.removeEvent(taskID: task.id, eventID: event.id)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20, height: 20)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove this tap")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.035))
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            chartMode = task.resetCadence == .weekly ? .weekly : .daily
        }
        .onChange(of: task.id) { _, _ in
            chartMode = task.resetCadence == .weekly ? .weekly : .daily
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
