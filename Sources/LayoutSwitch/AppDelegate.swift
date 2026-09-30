import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var statusSymbol: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second copy would receive the same gesture and switch twice.
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
                .activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        configureApplicationMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        model.onChange = { [weak self] in self?.updateStatusItem() }
        model.start()
        updateStatusItem()
        if !model.hasPermission || CommandLine.arguments.contains("--show-settings") ||
            !UserDefaults.standard.bool(forKey: "hasOpenedSettings") {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        addItem(model.status.title, to: menu)
        addItem("Раскладка: \(model.currentSource?.name ?? "не определена")", to: menu)
        for shortcut in model.settings.shortcuts {
            addItem("Сочетание: \(shortcut.displayName)", to: menu)
        }
        if !model.canSwitch { addItem("Выберите хотя бы две раскладки", to: menu) }
        if let error = model.errorMessage { addItem(error, to: menu) }
        menu.addItem(.separator())
        let next = addItem("Следующая раскладка", action: #selector(switchLayout), to: menu)
        next.isEnabled = model.canSwitch && !model.isRecording && model.status != .secureInput
        addItem(model.settings.enabled ? "Приостановить" : "Возобновить", action: #selector(toggleEnabled), to: menu)
        menu.addItem(.separator())
        addItem("Настройки…", action: #selector(showSettings), key: ",", to: menu)
        menu.addItem(.separator())
        addItem("Завершить LayoutSwitch", action: #selector(quit), key: "q", to: menu)
    }

    func windowWillClose(_ notification: Notification) { model.cancelRecording() }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 790),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "LayoutSwitch — Настройки"
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.minSize = NSSize(width: 600, height: 640)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            window.setFrameAutosaveName("LayoutSwitchSettings")
            settingsWindow = window
        }
        model.refreshSources()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UserDefaults.standard.set(true, forKey: "hasOpenedSettings")
    }

    @objc private func toggleEnabled() { model.setEnabled(!model.settings.enabled) }
    @objc private func switchLayout() { model.switchLayout() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let symbol: String
        switch model.status {
        case .running: symbol = "keyboard"
        case .paused, .recording: symbol = "pause.circle"
        default: symbol = "keyboard.badge.ellipsis"
        }
        if statusSymbol != symbol {
            statusSymbol = symbol
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "LayoutSwitch")
                ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: "LayoutSwitch")
            button.image?.isTemplate = true
        }
        let title = " \(model.currentSource?.badge ?? "—")"
        if button.title != title { button.title = title }
        let toolTip = "LayoutSwitch · \(model.status.title) · \(model.shortcutSummary)"
        if button.toolTip != toolTip { button.toolTip = toolTip }
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector? = nil, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = action != nil
        menu.addItem(item)
        return item
    }

    private func configureApplicationMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        addItem("Настройки…", action: #selector(showSettings), key: ",", to: appMenu)
        appMenu.addItem(.separator())
        addItem("Завершить LayoutSwitch", action: #selector(quit), key: "q", to: appMenu)
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }
}
