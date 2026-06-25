import AppKit

/// App-level command notifications. The native main menu (and its keyboard
/// shortcuts) posts these; the SwiftUI root view observes them. This bridges
/// AppKit's menu/responder world to SwiftUI state without coupling the two.
public extension Notification.Name {
    static let ifmFocusSearch = Notification.Name("ifmFocusSearch")
    static let ifmNewIdea = Notification.Name("ifmNewIdea")
    static let ifmNewSource = Notification.Name("ifmNewSource")
    static let ifmRefresh = Notification.Name("ifmRefresh")
    static let ifmRunLocalPass = Notification.Name("ifmRunLocalPass")
}

/// Builds the application's main menu. v1 shipped with *no* main menu, which meant
/// the standard Edit commands (⌘Z/⌘X/⌘C/⌘V/⌘A) did not work in the capture sheets
/// and there was no app/window menu. This restores native macOS behavior and adds
/// the app's own shortcuts, routed through `target` (the app delegate).
enum IFMMainMenu {
    static let appName = "Idea Fermentation Machine"

    static func build(target: AnyObject) -> NSMenu {
        let mainMenu = NSMenu()

        mainMenu.addItem(appMenuItem())
        mainMenu.addItem(fileMenuItem(target: target))
        mainMenu.addItem(editMenuItem())
        mainMenu.addItem(viewMenuItem(target: target))
        mainMenu.addItem(windowMenuItem())

        return mainMenu
    }

    private static func appMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu()
        menu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let hide = menu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.target = NSApp
        let hideOthers = menu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        hideOthers.target = NSApp
        menu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu
        return item
    }

    private static func fileMenuItem(target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "File")
        let newIdea = menu.addItem(withTitle: "New Idea", action: Selector(("ifmNewIdea:")), keyEquivalent: "n")
        newIdea.target = target
        let newSource = menu.addItem(withTitle: "New Source", action: Selector(("ifmNewSource:")), keyEquivalent: "n")
        newSource.keyEquivalentModifierMask = [.command, .shift]
        newSource.target = target
        menu.addItem(.separator())
        let find = menu.addItem(withTitle: "Find / Search", action: Selector(("ifmFocusSearch:")), keyEquivalent: "k")
        find.target = target
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        item.submenu = menu
        return item
    }

    private static func editMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        // Target nil → routed through the responder chain to the focused text view,
        // which is what makes copy/paste/undo work inside the capture sheets.
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        item.submenu = menu
        return item
    }

    private static func viewMenuItem(target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")
        let refresh = menu.addItem(withTitle: "Refresh", action: Selector(("ifmRefresh:")), keyEquivalent: "r")
        refresh.target = target
        let localPass = menu.addItem(withTitle: "Run Local Pass", action: Selector(("ifmRunLocalPass:")), keyEquivalent: "r")
        localPass.keyEquivalentModifierMask = [.command, .option]
        localPass.target = target
        item.submenu = menu
        return item
    }

    private static func windowMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        item.submenu = menu
        NSApp.windowsMenu = menu
        return item
    }
}
