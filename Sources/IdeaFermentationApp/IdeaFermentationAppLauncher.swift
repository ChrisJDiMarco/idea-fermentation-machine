import AppKit

@MainActor
private var retainedDelegate: IdeaFermentationAppDelegate?

@MainActor
public func runIdeaFermentationApp() {
    let app = NSApplication.shared
    let delegate = IdeaFermentationAppDelegate()
    retainedDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
