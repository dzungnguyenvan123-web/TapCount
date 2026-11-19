import AppKit
import SwiftUI
import TapCountCore

struct MenuBarPopoverView: View {
    let store: TaskStore
    let uiState: AppUIState
    let onOpenMainWindow: () -> Void

    @State private var showQuickAdd = false
    @State private var quickName = ""
    @State private var quickCadence: ResetCadence = .daily
    @State private var quickGoalText = ""
    @State private var quickColor: TaskColor = .blue
    @State private var quickIcon: String = "checkmark.circle.fill"
    @FocusState private var quickNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TapCount")
                        .font(.system(size: 14, weight: .bold))
                    Text(DateFormatters.compactDate.string(from: store.referenceDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showQuickAdd.toggle()
                        if showQuickAdd {
                            quickNameFocused = true
                        }
                    }
                } label: {
                    Image(systemName: showQuickAdd ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(showQuickAdd ? .secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(showQuickAdd ? "Close Quick Add" : "Quick Add Task")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Optional Inline Quick Add
            if showQuickAdd {
                quickAddForm
                    .transition(.move(edge: .top).combined(with: .opacity))
                Divider()
            }

            // Task List
            if store.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("No tasks yet")
                        .font(.subheadline.weight(.medium))
                    Button("Add Task") {
                        withAnimation(.snappy) {
                            showQuickAdd = true
                            quickNameFocused = true
                        }
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.tasks) { task in
                            MenuBarTaskRow(
                                task: task,
                                count: store.currentCount(for: task),
                                progress: store.progress(for: task),
                                isGoalMet: store.isGoalMet(for: task),
                                onTap: {
                                    store.tap(taskID: task.id)
                                },
                                onDecrement: {
                                    store.decrement(taskID: task.id)
                                }
                            )
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 340)
            }

            // Compact Undo Strip
            if let banner = store.lastActionBanner {
                Divider()
                HStack(spacing: 8) {
                    Text(banner.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") {
                        _ = store.undoLastAction()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.03))
            }

            Divider()

            // Footer
            HStack(spacing: 10) {
                Button {
                    onOpenMainWindow()
                } label: {
                    Label("Open Window", systemImage: "macwindow")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    store.preferences.showCountInMenuBar.toggle()
                } label: {
                    Image(systemName: store.preferences.showCountInMenuBar ? "number.circle.fill" : "number.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(store.preferences.showCountInMenuBar ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(
                    store.preferences.showCountInMenuBar
                        ? "Hide today's count in menu bar"
                        : "Show today's count in menu bar"
                )

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .frame(width: 320)
        .onAppear {
            store.refreshClock()
        }
    }

    private var quickAddForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Task name (e.g., Drink Water)", text: $quickName)
                .textFieldStyle(.roundedBorder)
                .focused($quickNameFocused)
                .onSubmit {
                    submitQuickAdd()
                }

            HStack(spacing: 8) {
                Picker("Reset", selection: $quickCadence) {
                    ForEach(ResetCadence.allCases) { cadence in
                        Text(cadence.displayName).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)

                TextField("Goal", text: $quickGoalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 54)
                    .controlSize(.small)
            }

            HStack(spacing: 6) {
                ForEach([TaskColor.cyan, .blue, .green, .orange, .pink, .purple], id: \.self) { color in
                    Button {
                        quickColor = color
                    } label: {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: quickColor == color ? 1.5 : 0)
                                    .padding(-2)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Add") {
                    submitQuickAdd()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(quickName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
    }

    private func submitQuickAdd() {
        let trimmed = quickName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let parsedGoal = Int(quickGoalText.trimmingCharacters(in: .whitespacesAndNewlines))
        let created = store.addTask(
            name: trimmed,
            icon: quickIcon,
            color: quickColor,
            resetCadence: quickCadence,
            goal: parsedGoal
        )
        uiState.selectedTaskID = created.id
        quickName = ""
        quickGoalText = ""
        withAnimation(.snappy) {
            showQuickAdd = false
        }
    }
}

private struct MenuBarTaskRow: View {
    let task: CountTask
    let count: Int
    let progress: Double?
    let isGoalMet: Bool
    let onTap: () -> Void
    let onDecrement: () -> Void

    @State private var isHovered = false
    @State private var pulse = false

    private var accent: Color { task.color.swiftUIColor }

    var body: some View {
        HStack(spacing: 8) {
            // Main clickable area (+1)
            Button {
                pulse = true
                onTap()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(110))
                    pulse = false
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(accent.opacity(0.16))
                            .frame(width: 30, height: 30)
                        Image(systemName: task.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(task.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if isGoalMet {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                            }
                        }

                        if let progress {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                    Capsule()
                                        .fill(isGoalMet ? Color.green : accent)
                                        .frame(width: max(progress > 0 ? 4 : 0, geo.size.width * progress))
                                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
                                }
                            }
                            .frame(height: 4)
                        } else {
                            Text(task.resetCadence.periodLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 4)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(count)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(count)))
                            .animation(.snappy(duration: 0.18), value: count)

                        if let goal = task.goal {
                            Text("/\(goal)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .scaleEffect(pulse ? 0.97 : 1.0)
            .animation(.spring(response: 0.16, dampingFraction: 0.65), value: pulse)

            // Decrement button
            Button {
                onDecrement()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.25 : (isHovered ? 1.0 : 0.6))
            .padding(.trailing, 6)
            .help("Decrement (-1)")
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.07) : Color.primary.opacity(0.03))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
