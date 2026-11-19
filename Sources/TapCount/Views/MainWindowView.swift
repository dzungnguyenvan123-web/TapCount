import SwiftUI
import TapCountCore

@MainActor
@Observable
final class AppUIState {
    var selectedTaskID: UUID?
    var showInspector: Bool = false
    var editorMode: EditorSheetItem?

    struct EditorSheetItem: Identifiable {
        let id = UUID()
        let mode: TaskEditorSheet.Mode
    }

    func presentNewTask() {
        editorMode = EditorSheetItem(mode: .create)
    }

    func presentEdit(_ task: CountTask) {
        editorMode = EditorSheetItem(mode: .edit(task))
    }
}

struct MainWindowView: View {
    let store: TaskStore
    @Bindable var uiState: AppUIState

    @State private var cadenceFilter: CadenceFilter = .all
    @State private var searchText: String = ""

    enum CadenceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case daily = "Daily"
        case weekly = "Weekly"
        case never = "Never"

        var id: String { rawValue }

        func matches(_ cadence: ResetCadence) -> Bool {
            switch self {
            case .all: true
            case .daily: cadence == .daily
            case .weekly: cadence == .weekly
            case .never: cadence == .never
            }
        }
    }

    private var filteredTasks: [CountTask] {
        store.tasks.filter { task in
            guard cadenceFilter.matches(task.resetCadence) else { return false }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty { return true }
            return task.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedTask: CountTask? {
        if let id = uiState.selectedTaskID, let found = store.task(withID: id) {
            return found
        }
        return filteredTasks.first ?? store.tasks.first
    }

    private var goalProgressSummary: String? {
        let tasksWithGoals = store.tasks.filter { $0.goal != nil }
        guard !tasksWithGoals.isEmpty else { return nil }
        let reached = tasksWithGoals.filter { store.isGoalMet(for: $0) }.count
        return "\(reached) of \(tasksWithGoals.count) goals reached"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Strip
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(DateFormatters.headerDate.string(from: store.referenceDate))
                                .font(.system(size: 22, weight: .bold))

                            HStack(spacing: 10) {
                                Label("\(store.totalTapsToday) taps today", systemImage: "hand.tap.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let goalSummary = goalProgressSummary {
                                    Text("•")
                                        .foregroundStyle(.tertiary)
                                    Label(goalSummary, systemImage: "target")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.top, 4)

                    // Error banner if persistence failed
                    if let error = store.lastError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(10)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Grid or Empty State
                    if filteredTasks.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 220, maximum: 290), spacing: 14)],
                            spacing: 14
                        ) {
                            ForEach(filteredTasks) { task in
                                let fullIndex = store.tasks.firstIndex(where: { $0.id == task.id }) ?? 0
                                TaskCardView(
                                    task: task,
                                    count: store.currentCount(for: task),
                                    progress: store.progress(for: task),
                                    isGoalMet: store.isGoalMet(for: task),
                                    isSelected: uiState.showInspector && selectedTask?.id == task.id,
                                    canMoveLeft: cadenceFilter == .all && searchText.isEmpty && fullIndex > 0,
                                    canMoveRight: cadenceFilter == .all && searchText.isEmpty && fullIndex < store.tasks.count - 1,
                                    onTap: {
                                        store.tap(taskID: task.id)
                                        uiState.selectedTaskID = task.id
                                    },
                                    onDecrement: {
                                        store.decrement(taskID: task.id)
                                        uiState.selectedTaskID = task.id
                                    },
                                    onInspect: {
                                        if uiState.showInspector && uiState.selectedTaskID == task.id {
                                            uiState.showInspector = false
                                        } else {
                                            uiState.selectedTaskID = task.id
                                            uiState.showInspector = true
                                        }
                                    },
                                    onEdit: {
                                        uiState.presentEdit(task)
                                    },
                                    onReset: {
                                        store.resetCurrentPeriod(taskID: task.id)
                                    },
                                    onMoveLeft: {
                                        store.moveTask(id: task.id, direction: -1)
                                    },
                                    onMoveRight: {
                                        store.moveTask(id: task.id, direction: 1)
                                    },
                                    onDelete: {
                                        if uiState.selectedTaskID == task.id {
                                            uiState.selectedTaskID = nil
                                        }
                                        store.deleteTask(id: task.id)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .padding(.bottom, store.lastActionBanner == nil ? 12 : 64)
            }

            // Floating Undo Toast
            if let banner = store.lastActionBanner {
                HStack(spacing: 12) {
                    Text(banner.summary)
                        .font(.system(size: 13, weight: .medium))

                    Divider()
                        .frame(height: 14)

                    Button {
                        _ = store.undoLastAction()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderless)

                    Button {
                        store.dismissActionBanner()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: store.lastActionBanner)
        .background(Color(nsColor: .windowBackgroundColor))
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter tasks")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("Filter", selection: $cadenceFilter) {
                    ForEach(CadenceFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    uiState.presentNewTask()
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .help("New Task (⌘N)")

                Button {
                    if !uiState.showInspector && uiState.selectedTaskID == nil {
                        uiState.selectedTaskID = selectedTask?.id
                    }
                    uiState.showInspector.toggle()
                } label: {
                    Label("History", systemImage: "sidebar.right")
                }
                .help("Toggle History Inspector (⌘I)")
            }
        }
        .inspector(isPresented: $uiState.showInspector) {
            Group {
                if let task = selectedTask {
                    TaskHistoryInspector(
                        store: store,
                        task: task,
                        onEdit: {
                            uiState.presentEdit(task)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "No Task Selected",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Create a task or click its chart icon to inspect history and stats.")
                    )
                }
            }
            .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .sheet(item: $uiState.editorMode) { item in
            TaskEditorSheet(mode: item.mode) { name, icon, color, cadence, goal in
                switch item.mode {
                case .create:
                    let created = store.addTask(
                        name: name,
                        icon: icon,
                        color: color,
                        resetCadence: cadence,
                        goal: goal
                    )
                    uiState.selectedTaskID = created.id
                case let .edit(existing):
                    store.updateTask(
                        id: existing.id,
                        name: name,
                        icon: icon,
                        color: color,
                        resetCadence: cadence,
                        goal: goal
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if store.tasks.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No Tasks Yet")
                    .font(.title3.weight(.semibold))
                Text("Add things you want to track—like drinking water, taking breaks, or daily habits—then click to count.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                Button {
                    uiState.presentNewTask()
                } label: {
                    Label("Create Your First Task", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        } else {
            ContentUnavailableView(
                "No Matching Tasks",
                systemImage: "magnifyingglass",
                description: Text("Try clearing your search or switching the reset schedule filter.")
            )
        }
    }
}
