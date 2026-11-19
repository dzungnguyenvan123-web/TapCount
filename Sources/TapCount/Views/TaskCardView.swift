import SwiftUI
import TapCountCore

struct TaskCardView: View {
    let task: CountTask
    let count: Int
    let progress: Double?
    let isGoalMet: Bool
    let isSelected: Bool
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let onTap: () -> Void
    let onDecrement: () -> Void
    let onInspect: () -> Void
    let onEdit: () -> Void
    let onReset: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var tapPulse = false
    @State private var showPlusOne = false

    private var accent: Color { task.color.swiftUIColor }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Primary tap surface
            Button {
                triggerTapFeedback()
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    // Top icon badge (leaves trailing space for corner controls)
                    HStack(alignment: .center) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(accent.opacity(0.16))
                                .frame(width: 40, height: 40)

                            Image(systemName: task.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        Spacer(minLength: 76)
                    }

                    // Title & cadence
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 5) {
                            Text(task.resetCadence.periodLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            if isGoalMet {
                                Label("Goal reached", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.green)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }

                    Spacer(minLength: 2)

                    // Counter readout & optional goal progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(count)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText(value: Double(count)))
                                .animation(.snappy(duration: 0.2), value: count)

                            if let goal = task.goal {
                                Text("/ \(goal)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if showPlusOne {
                                Text("+1")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.15), in: Capsule())
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }

                        if let progress {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                    Capsule()
                                        .fill(isGoalMet ? Color.green : accent)
                                        .frame(width: max(progress > 0 ? 6 : 0, geo.size.width * progress))
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress)
                                }
                            }
                            .frame(height: 6)
                        } else {
                            // Subtle visual baseline so cards with and without goals align cleanly
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap")
                                    .font(.system(size: 10))
                                Text("Click card to +1")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.tertiary)
                            .frame(height: 6)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? accent.opacity(0.75)
                                : (isHovered ? accent.opacity(0.35) : Color.primary.opacity(0.08)),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.10 : 0.04),
                    radius: isHovered ? 10 : 4,
                    y: isHovered ? 4 : 2
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(tapPulse ? 0.97 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.65), value: tapPulse)

            // Secondary corner controls (separate from primary +1 surface)
            HStack(spacing: 4) {
                Button {
                    onDecrement()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .opacity(count == 0 ? 0.3 : (isHovered ? 1.0 : 0.7))
                .help("Decrement (-1)")

                Button {
                    onInspect()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(
                            (isSelected ? accent.opacity(0.2) : Color.primary.opacity(0.06)),
                            in: Circle()
                        )
                        .foregroundStyle(isSelected ? accent : .secondary)
                }
                .buttonStyle(.plain)
                .opacity(isSelected || isHovered ? 1.0 : 0.65)
                .help("View History & Details")

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Task…", systemImage: "pencil")
                    }

                    Button {
                        onInspect()
                    } label: {
                        Label("History & Stats", systemImage: "chart.bar.xaxis")
                    }

                    Divider()

                    if canMoveLeft {
                        Button {
                            onMoveLeft()
                        } label: {
                            Label("Move Earlier", systemImage: "arrow.left")
                        }
                    }

                    if canMoveRight {
                        Button {
                            onMoveRight()
                        } label: {
                            Label("Move Later", systemImage: "arrow.right")
                        }
                    }

                    if canMoveLeft || canMoveRight {
                        Divider()
                    }

                    Button {
                        onReset()
                    } label: {
                        Label("Reset \(task.resetCadence.periodLabel)", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(count == 0)

                    Divider()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .opacity(isHovered ? 1.0 : 0.65)
                .help("More Actions")
            }
            .padding(12)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Tap (+1)") {
                triggerTapFeedback()
                onTap()
            }
            Button("Decrement (-1)") {
                onDecrement()
            }
            .disabled(count == 0)

            Divider()

            Button("Edit Task…") { onEdit() }
            Button("View History") { onInspect() }
            Button("Reset \(task.resetCadence.periodLabel)") { onReset() }
                .disabled(count == 0)

            Divider()

            Button("Delete Task", role: .destructive) { onDelete() }
        }
    }

    private func triggerTapFeedback() {
        tapPulse = true
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            showPlusOne = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            tapPulse = false
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.2)) {
                showPlusOne = false
            }
        }
    }
}
