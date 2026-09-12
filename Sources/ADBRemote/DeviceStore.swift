import AppKit
import SwiftUI
import Observation

@MainActor @Observable
final class DeviceStore {
    var devices: [AndroidDevice] = []
    var nearbyDevices: [NearbyDevice] = []
    var selectedID: String?
    var isRefreshing = false
    var status = "Ready"
    var errorMessage: String?
    var dependencies: DependencyReport
    var showDependencySetup: Bool
    var aliases: [String: String] { didSet { UserDefaults.standard.set(aliases, forKey: "deviceAliases") } }
    var manualDevices: [ManualDevice] { didSet { saveManualDevices() } }

    init() {
        aliases = UserDefaults.standard.dictionary(forKey: "deviceAliases") as? [String: String] ?? [:]
        manualDevices = Self.loadManualDevices()
        let report = DependencyReport.inspect()
        dependencies = report
        showDependencySetup = report.requiresSetup
    }
    var selected: AndroidDevice? { devices.first { $0.id == selectedID } }
    func name(for device: AndroidDevice) -> String { aliases[device.serial].flatMap { $0.isEmpty ? nil : $0 } ?? device.displayName }

    func refresh() async {
        isRefreshing = true; defer { isRefreshing = false }
        // Discovery must not depend on `adb devices`: the daemon may be stopped
        // precisely when a user is looking for a wireless device to connect.
        nearbyDevices = await ADBClient.shared.nearbyDevices()
        do {
            devices = try await ADBClient.shared.devices()
            if selectedID == nil || !devices.contains(where: { $0.id == selectedID }) { selectedID = devices.first?.id }
            status = devices.isEmpty ? "No Android devices found" : "\(devices.count) device\(devices.count == 1 ? "" : "s") found"
        } catch { present(error) }
    }
    func perform(_ action: @escaping () async throws -> Void, success: String) {
        Task {
            do {
                try await action()
                status = success
                Task { await refresh() }
            } catch {
                present(error)
            }
        }
    }
    func refreshDependencies() { dependencies = DependencyReport.inspect(); showDependencySetup = dependencies.requiresSetup }
    func addManualDevice(name: String, ipAddress: String, port: String) {
        let device = ManualDevice(name: name.trimmingCharacters(in: .whitespacesAndNewlines), ipAddress: ipAddress.trimmingCharacters(in: .whitespacesAndNewlines), port: port)
        guard !manualDevices.contains(where: { $0.endpoint.caseInsensitiveCompare(device.endpoint) == .orderedSame }) else {
            present(ADBError.invalidInput("This IP address is already in your saved devices."))
            return
        }
        manualDevices.append(device)
        connect(device)
    }
    func connect(_ device: ManualDevice) {
        Task {
            do {
                _ = try await ADBClient.shared.connect(host: device.endpoint)
                await refresh()
                guard devices.contains(where: { $0.serial.caseInsensitiveCompare(device.endpoint) == .orderedSame && $0.isOnline }) else {
                    throw ADBError.commandFailed("ADB did not confirm an online connection to \(device.endpoint). Refresh and verify the Wireless debugging port on the Android device.")
                }
                status = "Connected to \(device.displayName)"
            } catch {
                await refresh()
                present(error)
            }
        }
    }
    func removeManualDevice(_ device: ManualDevice) { manualDevices.removeAll { $0.id == device.id } }
    func present(_ error: Error) { errorMessage = error.localizedDescription; status = "Action failed" }
    func saveScreenshot(_ data: Data) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Android Screenshot.png"; panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.write(to: url); NSPasteboard.general.clearContents(); NSPasteboard.general.setData(data, forType: .png); status = "Screenshot saved and copied to clipboard" } catch { present(error) }
    }
    private func saveManualDevices() {
        guard let data = try? JSONEncoder().encode(manualDevices) else { return }
        UserDefaults.standard.set(data, forKey: "manualDevices")
    }
    private static func loadManualDevices() -> [ManualDevice] {
        guard let data = UserDefaults.standard.data(forKey: "manualDevices"),
              let devices = try? JSONDecoder().decode([ManualDevice].self, from: data) else { return [] }
        return devices
    }
}
