import AppKit
import Carbon

@main
enum LayoutSwitchApp {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--help") {
            print("LayoutSwitch [--show-settings | --diagnose]\nRun the .app bundle to use the menu bar application.")
        } else if CommandLine.arguments.contains("--diagnose") {
            // Read-only diagnostics: no tap, permission request, or settings changes.
            let sources = InputSourceManager()
            sources.refresh()
            let result: [String: Any] = [
                "inputMonitoringGranted": CGPreflightListenEventAccess(),
                "secureInputEnabled": IsSecureEventInputEnabled(),
                "currentSourceID": sources.currentID ?? "",
                "sources": sources.sources.map { ["id": $0.id, "name": $0.name, "language": $0.language] },
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
               let output = String(data: data, encoding: .utf8) { print(output) }
        } else {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.run()
            withExtendedLifetime(delegate) {}
        }
    }
}
