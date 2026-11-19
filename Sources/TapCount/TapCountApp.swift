import AppKit
import SwiftUI
import TapCountCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onReopenRequested: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in the menu bar when the main window is closed.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            onReopenRequested?()
        }
        return true
    }
}

@main
struct TapCountApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    @State private var store = TaskStore()
    @State private var uiState = AppUIState()

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some Scene {
        Window("TapCount", id: "main") {
            MainWindowView(store: store, uiState: uiState)
                .frame(minWidth: 640, minHeight: 440)
                .onAppear {
                    store.refreshClock()
                    appDelegate.onReopenRequested = { [openWindow] in
                        openMainWindow(using: openWindow)
                    }
                }
                .onReceive(minuteTimer) { _ in
                    store.refreshClock()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    store.refreshClock()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    store.refreshClock()
                }
        }
        .defaultSize(width: 880, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task…") {
                    openMainWindow(using: openWindow)
                    uiState.presentNewTask()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo Last Tap Action") {
                    _ = store.undoLastAction()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!store.canUndo)
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle History Inspector") {
                    uiState.showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarPopoverView(
                store: store,
                uiState: uiState,
                onOpenMainWindow: {
                    openMainWindow(using: openWindow)
                }
            )
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "hand.tap.fill")
                if store.preferences.showCountInMenuBar && store.totalTapsToday > 0 {
                    Text("\(store.totalTapsToday)")
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func openMainWindow(using openWindow: OpenWindowAction) {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
