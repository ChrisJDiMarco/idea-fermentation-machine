import AppKit
import IdeaFermentationCore
import SwiftUI

@MainActor
public final class IdeaFermentationAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var store: IdeaStore?
    private var captureServer: CaptureServer?
    // Owned by the app, NOT the window — so the autonomous scheduler + mind cadence keep
    // running with the window closed (they used to be tied to the window's @StateObject and
    // stopped the moment it closed). Closing the window now only hides the UI; the loops and
    // capture server run until the app quits.
    private var viewModel: ShellViewModel?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let store = (try? IdeaStore.live()) ?? fallbackStore()
        self.store = store

        // Install a native main menu. v1 had none, so the standard Edit commands
        // (⌘Z/⌘X/⌘C/⌘V/⌘A) did not work in the capture sheets. This also hosts the
        // app's own shortcuts (⌘N new idea, ⌘K find, ⌘R refresh).
        NSApp.mainMenu = IFMMainMenu.build(target: self)

        // The loopback capture server shares the single store instance and runs
        // on the main actor (see CaptureServer). Start it before the window so
        // captures work the instant the app is up.
        let captureServer = CaptureServer(store: store)
        captureServer.startIfEnabled()
        self.captureServer = captureServer

        // Create the view model once, here, so its scheduler/mind loops live for the whole
        // app session regardless of window state.
        let viewModel = ShellViewModel(store: store, captureServer: captureServer)
        self.viewModel = viewModel

        makeWindow(viewModel: viewModel)
    }

    // MARK: Menu command relays → SwiftUI (via NotificationCenter)

    @objc func ifmNewIdea(_ sender: Any?) { NotificationCenter.default.post(name: .ifmNewIdea, object: nil) }
    @objc func ifmNewSource(_ sender: Any?) { NotificationCenter.default.post(name: .ifmNewSource, object: nil) }
    @objc func ifmFocusSearch(_ sender: Any?) { NotificationCenter.default.post(name: .ifmFocusSearch, object: nil) }
    @objc func ifmRefresh(_ sender: Any?) { NotificationCenter.default.post(name: .ifmRefresh, object: nil) }
    @objc func ifmRunLocalPass(_ sender: Any?) { NotificationCenter.default.post(name: .ifmRunLocalPass, object: nil) }

    private func makeWindow(viewModel: ShellViewModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = IdeaFermentationRootView(model: viewModel)
        let minSize = NSSize(width: 1040, height: 680)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1536, height: 960)
        let launchSize = NSSize(
            width: min(1536, max(minSize.width, visibleFrame.width - 72)),
            height: min(960, max(minSize.height, visibleFrame.height - 72))
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: launchSize.width, height: launchSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Keep the reference valid after the user closes the window. Now that the app runs
        // headless in the background (loops + capture server), close→reopen is a primary
        // flow; with the AppKit default (isReleasedWhenClosed = true) `self.window` would
        // dangle to a freed object and reopen could crash. We reuse this same window instance.
        window.isReleasedWhenClosed = false
        window.title = "Idea Fermentation Machine"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = minSize
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    // Keep running with the window closed so the browser capture endpoint stays
    // alive. Quit with Cmd-Q or Dock → Quit.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // Re-show the window when the user clicks the Dock icon — re-attaching to the SAME
    // live view model, so nothing about the running loops or in-memory state resets.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows, let viewModel {
            makeWindow(viewModel: viewModel)
        }
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        captureServer?.stop()
    }

    private func fallbackStore() -> IdeaStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdeaFermentationMachine-\(UUID().uuidString)")
            .appendingPathComponent("ideas.sqlite")
        return try! IdeaStore(databaseURL: url)
    }
}
