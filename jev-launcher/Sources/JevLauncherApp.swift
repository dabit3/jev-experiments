import AppKit
import SwiftUI

@main
struct JevLauncherApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    MenuBarExtra("Launcher", systemImage: "bolt.fill") {
      Button("Toggle Launcher  ⌥Space") { delegate.togglePanel() }
      Divider()
      SettingsLink { Text("Settings…") }
      Button("Quit Launcher") { NSApplication.shared.terminate(nil) }
    }
    Settings {
      SettingsView(model: delegate.model)
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = LauncherModel()
  private var panel: LauncherPanelController?
  private var hotKey: HotKey?

  func applicationDidFinishLaunching(_ notification: Notification) {
    panel = LauncherPanelController(model: model)
    hotKey = HotKey { [weak self] in self?.togglePanel() }
    if ProcessInfo.processInfo.arguments.contains("--show") {
      togglePanel()
    }
  }

  func togglePanel() {
    panel?.toggle()
  }
}

struct SettingsView: View {
  @ObservedObject var model: LauncherModel
  @AppStorage(JevClient.apiKeyDefaultsKey) private var apiKey = ""
  @AppStorage("includeSpotlight") private var includeSpotlight = true
  @AppStorage("includeChromeHistory") private var includeHistory = true
  @AppStorage("localOnly") private var localOnly = false
  @State private var historyCleared = false

  var body: some View {
    Form {
      Section("TypeSafe") {
        SecureField("API key", text: $apiKey)
        Text(
          ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"] == nil
            ? "TYPESAFE_API_KEY is not set in the environment; the key above is used instead."
            : "TYPESAFE_API_KEY is set in the environment and takes precedence."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Section("Search and privacy") {
        Toggle("Search files with Spotlight", isOn: $includeSpotlight)
        Toggle("Include Chrome browsing history", isOn: $includeHistory)
        Toggle("Keep searches on this Mac", isOn: $localOnly)
        Text(
          "Local mode disables online ranking. Otherwise only your query, context and a short list of candidate metadata are sent. File contents and clipboard text stay on this Mac."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Section("Personal library") {
        Text(
          "Successful opens teach the launcher your preferences. Pins and saved workspaces appear before you type."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        Button(historyCleared ? "Launch history cleared" : "Clear launch history") {
          model.clearHistory()
          historyCleared = true
        }
        Text("Keeps your pins and saved workspaces. Does not change Chrome history.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Permissions") {
        Text(
          "Dark Mode, Sleep and Empty Trash send Apple Events to System Events / Finder. macOS asks for Automation permission the first time."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .padding()
    .onChange(of: includeSpotlight) { _, _ in model.preferencesChanged() }
    .onChange(of: includeHistory) { _, _ in model.preferencesChanged() }
    .onChange(of: localOnly) { _, _ in model.preferencesChanged() }
  }
}
