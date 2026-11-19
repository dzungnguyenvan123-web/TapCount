import SwiftUI
import TapCountCore

struct TaskEditorSheet: View {
    enum Mode {
        case create
        case edit(CountTask)

        var title: String {
            switch self {
            case .create: "New Task"
            case .edit: "Edit Task"
            }
        }

        var saveLabel: String {
            switch self {
            case .create: "Create Task"
            case .edit: "Save Changes"
            }
        }
    }

    let mode: Mode
    let onSave: (String, String, TaskColor, ResetCadence, Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    @State private var name: String
    @State private var icon: String
    @State private var color: TaskColor
    @State private var resetCadence: ResetCadence
    @State private var hasGoal: Bool
    @State private var goalValue: Int

    init(
        mode: Mode,
        onSave: @escaping (String, String, TaskColor, ResetCadence, Int?) -> Void
    ) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _icon = State(initialValue: "drop.fill")
            _color = State(initialValue: .cyan)
            _resetCadence = State(initialValue: .daily)
            _hasGoal = State(initialValue: true)
            _goalValue = State(initialValue: 8)
        case let .edit(task):
            _name = State(initialValue: task.name)
            _icon = State(initialValue: task.icon)
            _color = State(initialValue: task.color)
            _resetCadence = State(initialValue: task.resetCadence)
            _hasGoal = State(initialValue: task.goal != nil)
            _goalValue = State(initialValue: task.goal ?? 8)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with live preview
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.swiftUIColor.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color.swiftUIColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.headline)
                    Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Preview of your task" : name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Name")
                            .font(.subheadline.weight(.medium))
                        TextField("e.g., Drink Water, Take Vitamins, Push-ups", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .focused($nameFocused)
                    }

                    // Reset Schedule
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Auto-Reset Schedule")
                            .font(.subheadline.weight(.medium))
                        Picker("Reset Schedule", selection: $resetCadence) {
                            ForEach(ResetCadence.allCases) { cadence in
                                Text(cadence.displayName).tag(cadence)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Text(resetCadence.descriptionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Goal
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $hasGoal) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Set Target Goal")
                                    .font(.subheadline.weight(.medium))
                                Text("Show a progress bar toward your target count")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        if hasGoal {
                            HStack(spacing: 10) {
                                Text("Target:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                TextField("", value: $goalValue, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 72)
                                    .multilineTextAlignment(.trailing)

                                Stepper("", value: $goalValue, in: 1...999)
                                    .labelsHidden()

                                Text(resetCadence == .never ? "total" : "per \(resetCadence == .daily ? "day" : "week")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .padding(.top, 2)
                        }
                    }

                    // Color Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.subheadline.weight(.medium))

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 12),
                            spacing: 10
                        ) {
                            ForEach(TaskColor.allCases) { swatch in
                                Button {
                                    color = swatch
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(swatch.swiftUIColor)
                                            .frame(width: 24, height: 24)

                                        if color == swatch {
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: 2)
                                                .frame(width: 30, height: 30)
                                        }
                                    }
                                    .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.plain)
                                .help(swatch.displayName)
                            }
                        }
                    }

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.subheadline.weight(.medium))

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                            spacing: 8
                        ) {
                            ForEach(IconCatalog.symbols, id: \.self) { symbol in
                                Button {
                                    icon = symbol
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(
                                                icon == symbol
                                                    ? color.swiftUIColor.opacity(0.22)
                                                    : Color.primary.opacity(0.05)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                    .strokeBorder(
                                                        icon == symbol ? color.swiftUIColor : .clear,
                                                        lineWidth: 1.5
                                                    )
                                            )

                                        Image(systemName: symbol)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(icon == symbol ? color.swiftUIColor : .primary)
                                    }
                                    .frame(height: 38)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(mode.saveLabel) {
                    let clampedGoal = hasGoal ? max(1, goalValue) : nil
                    onSave(name, icon, color, resetCadence, clampedGoal)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 450, height: 575)
        .onAppear {
            nameFocused = true
        }
    }
}
