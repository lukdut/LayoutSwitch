import AppKit
import Carbon
import Combine
import ServiceManagement
import ShortcutCore

struct SavedSettings: Codable {
    var shortcut: Shortcut = .default
    var enabled = true
    var selectedSourceIDs: [String]? = nil
}

enum MonitorStatus: Equatable {
    case running, paused, needsPermission, secureInput, recording, inactiveSession, failed

    var title: String {
        switch self {
        case .running: return "Переключение включено"
        case .paused: return "На паузе"
        case .needsPermission: return "Нужен доступ к мониторингу ввода"
        case .secureInput: return "macOS защищает ввод"
        case .recording: return "Запись сочетания"
        case .inactiveSession: return "Ожидание активного сеанса"
        case .failed: return "Не удалось включить мониторинг"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings: SavedSettings
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var currentSource: InputSource?
    @Published private(set) var status = MonitorStatus.needsPermission
    @Published private(set) var hasPermission = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordingHint = ""
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published var errorMessage: String?
    var onChange: (() -> Void)?

    private let defaults: UserDefaults
    private let inputSources = InputSourceManager()
    private let monitor = KeyboardMonitor()
    private let recorder = ShortcutRecorder()
    private var healthTimer: Timer?
    private var observations: [(NotificationCenter, NSObjectProtocol)] = []
    private var sessionAvailable = true

    var selectedIDs: [String] {
        InputSourceCycle.candidates(available: sources.map(\.id), selected: settings.selectedSourceIDs)
    }
    var canSwitch: Bool { selectedIDs.count >= 2 }
    var usesAllSources: Bool { settings.selectedSourceIDs == nil }
    var unavailableSourceCount: Int {
        (settings.selectedSourceIDs ?? []).filter { id in !sources.contains { $0.id == id } }.count
    }
    var loginEnabled: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var settings = defaults.data(forKey: "settings")
            .flatMap { try? JSONDecoder().decode(SavedSettings.self, from: $0) } ?? SavedSettings()
        if !settings.shortcut.isValid { settings.shortcut = .default }
        self.settings = settings

        monitor.onTrigger = { [weak self] in self?.switchLayout() }
        monitor.onInterruption = { [weak self] in self?.reconcileMonitoring() }
        recorder.onHint = { [weak self] in self?.recordingHint = $0 }
        recorder.onComplete = { [weak self] shortcut in
            guard let self else { return }
            self.isRecording = false
            if let shortcut { self.settings.shortcut = shortcut; self.persist() }
            self.reconcileMonitoring()
        }
    }

    func start() {
        refreshSources()
        reconcileMonitoring()
        observe(DistributedNotificationCenter.default(),
                NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)) {
            [weak self] in self?.refreshCurrentSource()
        }
        observe(DistributedNotificationCenter.default(),
                NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String)) {
            [weak self] in self?.refreshSources()
        }
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification) { [weak self] in
            self?.refreshSources()
            self?.reconcileMonitoring()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observe(workspace, name) { [weak self] in
                self?.sessionAvailable = false
                self?.recorder.cancel()
                self?.reconcileMonitoring()
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observe(workspace, name) { [weak self] in
                self?.sessionAvailable = true
                self?.monitor.stop()
                self?.refreshSources()
                self?.reconcileMonitoring()
            }
        }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcileMonitoring() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        healthTimer = timer
    }

    func stop() {
        healthTimer?.invalidate()
        healthTimer = nil
        recorder.cancel()
        monitor.stop()
        for (center, token) in observations { center.removeObserver(token) }
        observations.removeAll()
    }

    func setEnabled(_ enabled: Bool) {
        settings.enabled = enabled
        persist()
        reconcileMonitoring()
    }

    func restoreDefaultShortcut() {
        recorder.cancel()
        settings.shortcut = .default
        persist()
        monitor.stop()
        reconcileMonitoring()
    }

    func setIncluded(_ id: String, included: Bool) {
        var selection = Set(settings.selectedSourceIDs ?? sources.map(\.id))
        if included { selection.insert(id) } else { selection.remove(id) }
        let unavailable = (settings.selectedSourceIDs ?? []).filter { !sources.map(\.id).contains($0) }
        settings.selectedSourceIDs = (sources.map(\.id) + unavailable).filter { selection.contains($0) }
        persist()
        monitor.stop()
        reconcileMonitoring()
    }

    func useAllSources() {
        settings.selectedSourceIDs = nil
        persist()
        monitor.stop()
        reconcileMonitoring()
    }

    func refreshSources() {
        inputSources.refresh()
        publishInputSources()
    }

    private func refreshCurrentSource() {
        inputSources.refreshCurrent()
        if let id = inputSources.currentID, !inputSources.sources.contains(where: { $0.id == id }) {
            inputSources.refresh()
        }
        publishInputSources()
    }

    private func publishInputSources() {
        guard sources != inputSources.sources || currentSource != inputSources.current else { return }
        if sources != inputSources.sources { sources = inputSources.sources }
        if currentSource != inputSources.current { currentSource = inputSources.current }
        onChange?()
    }

    func switchLayout() {
        guard !isRecording, !IsSecureEventInputEnabled() else { return }
        let error = inputSources.selectNext(selectedIDs: settings.selectedSourceIDs)
        if errorMessage != error { errorMessage = error }
        publishInputSources()
    }

    func startRecording() {
        guard let window = NSApp.keyWindow else { return }
        isRecording = true
        reconcileMonitoring()
        recorder.start(in: window)
    }

    func cancelRecording() { recorder.cancel() }

    func requestPermission() {
        _ = CGRequestListenEventAccess()
        reconcileMonitoring()
    }

    func retryMonitoring() {
        monitor.stop()
        reconcileMonitoring()
    }

    func openPrivacySettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openKeyboardSettings() {
        openSettings("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось изменить автозапуск: \(error.localizedDescription)"
        }
        loginStatus = SMAppService.mainApp.status
        onChange?()
    }

    private func reconcileMonitoring() {
        let permission = CGPreflightListenEventAccess()
        if hasPermission != permission { hasPermission = permission }
        let login = SMAppService.mainApp.status
        if loginStatus != login { loginStatus = login }
        let next: MonitorStatus
        if !sessionAvailable { next = .inactiveSession }
        else if isRecording { next = .recording }
        else if !settings.enabled { next = .paused }
        else if !permission { next = .needsPermission }
        else if IsSecureEventInputEnabled() { next = .secureInput }
        else if monitor.isRunning || monitor.start(shortcut: settings.shortcut) { next = .running }
        else { next = .failed }
        if next != .running { monitor.stop() }
        if status != next { status = next; onChange?() }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "settings") }
        errorMessage = nil
        onChange?()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { action() }
        }
        observations.append((center, token))
    }

    private func openSettings(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}
