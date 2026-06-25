import AppKit
import IdeaFermentationCore
import SwiftUI

@MainActor
public final class IdeaFermentationAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var store: IdeaStore?
    private var captureServer: CaptureServer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let store = (try? IdeaStore.live()) ?? fallbackStore()
        self.store = store

        // The loopback capture server shares the single store instance and runs
        // on the main actor (see CaptureServer). Start it before the window so
        // captures work the instant the app is up.
        let captureServer = CaptureServer(store: store)
        captureServer.startIfEnabled()
        self.captureServer = captureServer

        makeWindow(store: store, captureServer: captureServer)
    }

    private func makeWindow(store: IdeaStore, captureServer: CaptureServer) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = IdeaFermentationRootView(store: store, captureServer: captureServer)
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

    // Re-show the window when the user clicks the Dock icon.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows, let store, let captureServer {
            makeWindow(store: store, captureServer: captureServer)
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
